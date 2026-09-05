// SPDX-License-Identifier: MIT

#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif
#include <drm.h>
#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <signal.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/prctl.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/un.h>
#include <sys/wait.h>
#include <unistd.h>

#define MAX_SHARED_FDS 8

struct shared_drm_fd {
  int fd;
  int dropped;
};

static volatile sig_atomic_t caught_signal;

static void catch_signal(int signal_number) { caught_signal = signal_number; }

static int make_directory(const char *path) {
  return mkdir(path, 0755) == 0 || errno == EEXIST;
}

static int receive_shared_fd(int channel) {
  char byte;
  struct iovec iov;
  struct msghdr message;
  char control[CMSG_SPACE(sizeof(int))];
  struct cmsghdr *header;
  ssize_t received;
  int fd = -1;

  memset(&message, 0, sizeof(message));
  memset(control, 0, sizeof(control));
  iov.iov_base = &byte;
  iov.iov_len = 1;
  message.msg_iov = &iov;
  message.msg_iovlen = 1;
  message.msg_control = control;
  message.msg_controllen = sizeof(control);
  received = recvmsg(channel, &message, 0);
  if (received <= 0) {
    return -1;
  }
  for (header = CMSG_FIRSTHDR(&message); header;
       header = CMSG_NXTHDR(&message, header)) {
    if (header->cmsg_level == SOL_SOCKET && header->cmsg_type == SCM_RIGHTS &&
        header->cmsg_len >= CMSG_LEN(sizeof(int))) {
      memcpy(&fd, CMSG_DATA(header), sizeof(fd));
      break;
    }
  }
  return fd;
}

static int operate_on_shared_fds(struct shared_drm_fd *fds, size_t count,
                                 int set_master, int *saved_errno) {
  size_t index;
  int success = 0;
  int error_value = ENODEV;

  for (index = 0; index < count; index++) {
    if (set_master && !fds[index].dropped) {
      continue;
    }
    if (ioctl(fds[index].fd, set_master ? DRM_IOCTL_SET_MASTER
                                        : DRM_IOCTL_DROP_MASTER,
              0) == 0) {
      success = 1;
      fds[index].dropped = set_master ? 0 : 1;
    } else {
      error_value = errno;
    }
  }
  if (saved_errno) {
    *saved_errno = success ? 0 : error_value;
  }
  return success;
}

static void serve_client(int client, struct shared_drm_fd *fds,
                         size_t fd_count) {
  char request[32];
  char reply[96];
  ssize_t length;
  int set_master;
  int saved_errno = 0;

  length = read(client, request, sizeof(request) - 1);
  if (length <= 0) {
    return;
  }
  request[length] = '\0';
  if (strncmp(request, "drop", 4) == 0) {
    set_master = 0;
  } else if (strncmp(request, "set", 3) == 0) {
    set_master = 1;
  } else {
    (void)write(client, "error command\n", 14);
    return;
  }
  if (operate_on_shared_fds(fds, fd_count, set_master, &saved_errno)) {
    (void)write(client, "ok\n", 3);
  } else {
    int reply_length = snprintf(reply, sizeof(reply), "error %d %s\n",
                                saved_errno, strerror(saved_errno));
    if (reply_length > 0) {
      (void)write(client, reply, (size_t)reply_length);
    }
  }
}

static int child_exit_code(int status) {
  if (WIFEXITED(status)) {
    return WEXITSTATUS(status);
  }
  if (WIFSIGNALED(status)) {
    return 128 + WTERMSIG(status);
  }
  return 1;
}

int main(int argc, char **argv) {
  const char *library = NULL;
  const char *runtime_root;
  char handoff_directory[256];
  char socket_path[sizeof(((struct sockaddr_un *)0)->sun_path)];
  char channel_value[32];
  int command_index = 1;
  int channels[2] = {-1, -1};
  int server = -1;
  struct shared_drm_fd shared_fds[MAX_SHARED_FDS];
  size_t shared_count = 0;
  pid_t child;
  int status = 0;
  int child_finished = 0;
  struct sockaddr_un address;
  struct sigaction action;

  while (command_index < argc) {
    if (strcmp(argv[command_index], "--library") == 0 &&
        command_index + 1 < argc) {
      library = argv[command_index + 1];
      command_index += 2;
    } else if (strcmp(argv[command_index], "--") == 0) {
      command_index++;
      break;
    } else {
      break;
    }
  }
  if (!library || !library[0] || command_index >= argc) {
    fprintf(stderr, "usage: %s --library PATH -- COMMAND [ARG...]\n", argv[0]);
    return 2;
  }
  runtime_root = getenv("PLUMOS_RUNTIME_ROOT");
  if (!runtime_root || !runtime_root[0]) {
    runtime_root = "/run/plumos";
  }
  if (snprintf(handoff_directory, sizeof(handoff_directory),
               "%s/drm-handoff", runtime_root) >=
      (int)sizeof(handoff_directory) || !make_directory(runtime_root) ||
      !make_directory(handoff_directory)) {
    fprintf(stderr, "plumos-drm-broker: cannot create handoff directory\n");
    return 1;
  }
  if (socketpair(AF_UNIX, SOCK_DGRAM, 0, channels) != 0) {
    perror("plumos-drm-broker: socketpair");
    return 1;
  }
  if (fcntl(channels[1], F_SETFD, 0) != 0) {
    perror("plumos-drm-broker: channel inheritance");
    close(channels[0]);
    close(channels[1]);
    return 1;
  }

  child = fork();
  if (child < 0) {
    perror("plumos-drm-broker: fork");
    close(channels[0]);
    close(channels[1]);
    return 1;
  }
  if (child == 0) {
    close(channels[0]);
    (void)prctl(PR_SET_PDEATHSIG, SIGTERM);
    snprintf(channel_value, sizeof(channel_value), "%d", channels[1]);
    if (setenv("PLUMOS_DRM_BROKER_FD", channel_value, 1) != 0 ||
        setenv("PLUMOS_DRM_SHARE_LIBRARY", library, 1) != 0) {
      _exit(126);
    }
    execvp(argv[command_index], &argv[command_index]);
    _exit(127);
  }

  close(channels[1]);
  channels[1] = -1;
  (void)prctl(PR_SET_NAME, "plumos-drm-broker");
  if (snprintf(socket_path, sizeof(socket_path), "%s/%ld.sock",
               handoff_directory, (long)getpid()) >= (int)sizeof(socket_path)) {
    kill(child, SIGTERM);
    close(channels[0]);
    (void)waitpid(child, &status, 0);
    return 1;
  }
  server = socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0);
  if (server < 0) {
    perror("plumos-drm-broker: socket");
    kill(child, SIGTERM);
    close(channels[0]);
    (void)waitpid(child, &status, 0);
    return 1;
  }
  memset(&address, 0, sizeof(address));
  address.sun_family = AF_UNIX;
  snprintf(address.sun_path, sizeof(address.sun_path), "%s", socket_path);
  unlink(socket_path);
  if (bind(server, (struct sockaddr *)&address, sizeof(address)) != 0 ||
      chmod(socket_path, 0600) != 0 || listen(server, 4) != 0) {
    perror("plumos-drm-broker: bind/listen");
    kill(child, SIGTERM);
    close(server);
    close(channels[0]);
    unlink(socket_path);
    (void)waitpid(child, &status, 0);
    return 1;
  }

  memset(&action, 0, sizeof(action));
  action.sa_handler = catch_signal;
  sigemptyset(&action.sa_mask);
  (void)sigaction(SIGTERM, &action, NULL);
  (void)sigaction(SIGINT, &action, NULL);
  (void)sigaction(SIGHUP, &action, NULL);

  while (!child_finished) {
    struct pollfd poll_fds[2];
    int poll_result;
    pid_t waited;

    if (caught_signal) {
      kill(child, caught_signal);
    }
    poll_fds[0].fd = channels[0];
    poll_fds[0].events = POLLIN;
    poll_fds[0].revents = 0;
    poll_fds[1].fd = server;
    poll_fds[1].events = POLLIN;
    poll_fds[1].revents = 0;
    poll_result = poll(poll_fds, 2, 100);
    if (poll_result > 0 && (poll_fds[0].revents & POLLIN)) {
      int shared_fd = receive_shared_fd(channels[0]);
      if (shared_fd >= 0) {
        if (shared_count < MAX_SHARED_FDS) {
          shared_fds[shared_count].fd = shared_fd;
          shared_fds[shared_count].dropped = 0;
          shared_count++;
        } else {
          close(shared_fd);
        }
      }
    }
    if (poll_result > 0 && (poll_fds[1].revents & POLLIN)) {
      int client = accept4(server, NULL, NULL, SOCK_CLOEXEC);
      if (client >= 0) {
        serve_client(client, shared_fds, shared_count);
        close(client);
      }
    }
    waited = waitpid(child, &status, WNOHANG);
    if (waited == child) {
      child_finished = 1;
    } else if (waited < 0 && errno != EINTR) {
      status = 1 << 8;
      child_finished = 1;
    }
  }

  close(server);
  close(channels[0]);
  while (shared_count > 0) {
    close(shared_fds[--shared_count].fd);
  }
  unlink(socket_path);
  return child_exit_code(status);
}
