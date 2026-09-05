// SPDX-License-Identifier: MIT

#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>
#include <drm.h>

static int operate_via_broker(pid_t pid, int set_master) {
  const char *runtime_root = getenv("PLUMOS_RUNTIME_ROOT");
  char socket_path[sizeof(((struct sockaddr_un *)0)->sun_path)];
  char status_path[64];
  char status[512];
  char request[8];
  struct sockaddr_un address;
  int attempts;

  if (!runtime_root || !runtime_root[0]) {
    runtime_root = "/run/plumos";
  }
  for (attempts = 0; attempts < 32 && pid > 1; attempts++) {
    FILE *file;
    long parent = 0;
    int socket_fd;
    ssize_t length;

    if (snprintf(socket_path, sizeof(socket_path),
                 "%s/drm-handoff/%ld.sock", runtime_root, (long)pid) <
        (int)sizeof(socket_path)) {
      socket_fd = socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0);
      if (socket_fd >= 0) {
        memset(&address, 0, sizeof(address));
        address.sun_family = AF_UNIX;
        snprintf(address.sun_path, sizeof(address.sun_path), "%s",
                 socket_path);
        if (connect(socket_fd, (struct sockaddr *)&address,
                    sizeof(address)) == 0) {
          snprintf(request, sizeof(request), "%s\n",
                   set_master ? "set" : "drop");
          if (write(socket_fd, request, strlen(request)) ==
              (ssize_t)strlen(request)) {
            length = read(socket_fd, status, sizeof(status) - 1);
            if (length > 0) {
              status[length] = '\0';
              close(socket_fd);
              return strncmp(status, "ok", 2) == 0 ? 0 : 1;
            }
          }
        }
        close(socket_fd);
      }
    }
    if (snprintf(status_path, sizeof(status_path), "/proc/%ld/status",
                 (long)pid) >= (int)sizeof(status_path)) {
      break;
    }
    file = fopen(status_path, "r");
    if (!file) {
      break;
    }
    while (fgets(status, sizeof(status), file)) {
      if (sscanf(status, "PPid:%ld", &parent) == 1) {
        break;
      }
    }
    fclose(file);
    if (parent <= 1 || parent == pid) {
      break;
    }
    pid = (pid_t)parent;
  }
  return 1;
}

static int operate_on_pid(pid_t pid, int set_master) {
  char directory_path[64];
  DIR *directory;
  struct dirent *entry;
  int result = 1;

  if (pid <= 1 ||
      snprintf(directory_path, sizeof(directory_path), "/proc/%ld/fd",
               (long)pid) >= (int)sizeof(directory_path)) {
    return 1;
  }
  directory = opendir(directory_path);
  if (!directory) {
    return 1;
  }
  while ((entry = readdir(directory)) != NULL) {
    char fd_path[128];
    char target[128];
    ssize_t length;
    int fd;
    int rc;

    if (entry->d_name[0] == '.') {
      continue;
    }
    if (snprintf(fd_path, sizeof(fd_path), "%s/%s", directory_path,
                 entry->d_name) >= (int)sizeof(fd_path)) {
      continue;
    }
    length = readlink(fd_path, target, sizeof(target) - 1);
    if (length < 0) {
      continue;
    }
    target[length] = '\0';
    if (strncmp(target, "/dev/dri/card", 13) != 0) {
      continue;
    }
    fd = open(fd_path, O_RDWR | O_CLOEXEC);
    if (fd < 0) {
      continue;
    }
    rc = ioctl(fd, set_master ? DRM_IOCTL_SET_MASTER : DRM_IOCTL_DROP_MASTER,
               0);
    close(fd);
    if (rc == 0) {
      result = 0;
      break;
    }
  }
  closedir(directory);
  return result;
}

int main(int argc, char **argv) {
  char *end;
  long pid_value;
  int set_master;

  if (argc != 3 ||
      (strcmp(argv[1], "drop") != 0 && strcmp(argv[1], "set") != 0)) {
    fprintf(stderr, "usage: %s drop|set PID\n", argv[0]);
    return 2;
  }
  errno = 0;
  pid_value = strtol(argv[2], &end, 10);
  if (errno || end == argv[2] || *end != '\0' || pid_value <= 1) {
    fprintf(stderr, "invalid PID: %s\n", argv[2]);
    return 2;
  }
  set_master = strcmp(argv[1], "set") == 0;
  if (operate_via_broker((pid_t)pid_value, set_master) == 0) {
    return 0;
  }
  return operate_on_pid((pid_t)pid_value, set_master);
}
