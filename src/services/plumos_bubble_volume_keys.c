// SPDX-License-Identifier: MIT

#include <errno.h>
#include <fcntl.h>
#include <linux/input.h>
#include <poll.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/file.h>
#include <sys/ioctl.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

#define INPUT_SCAN_LIMIT 32
#define REOPEN_INTERVAL_MS 2000
#define REPEAT_DELAY_MS 450
#define REPEAT_INTERVAL_MS 120
#define PERSIST_DELAY_MS 750

static volatile sig_atomic_t running = 1;

static void stop_running(int signal_number) {
  (void)signal_number;
  running = 0;
}

static long long monotonic_ms(void) {
  struct timespec now;

  if (clock_gettime(CLOCK_MONOTONIC, &now) < 0) {
    return 0;
  }
  return (long long)now.tv_sec * 1000LL + now.tv_nsec / 1000000LL;
}

static int open_named_event(const char *target_name) {
  int index;

  for (index = 0; index < INPUT_SCAN_LIMIT; ++index) {
    char path[64];
    char name[256] = "";
    int fd;

    snprintf(path, sizeof(path), "/dev/input/event%d", index);
    fd = open(path, O_RDONLY | O_NONBLOCK | O_CLOEXEC);
    if (fd < 0) {
      continue;
    }
    if (ioctl(fd, EVIOCGNAME(sizeof(name) - 1), name) >= 0 &&
        strcmp(name, target_name) == 0) {
      fprintf(stderr, "volume-keys: opened=%s name=%s\n", path, name);
      return fd;
    }
    close(fd);
  }
  return -1;
}

static int open_volume_event(const char *configured_path) {
  int fd;

  if (!configured_path || !configured_path[0]) {
    return open_named_event("gpio-keys");
  }
  fd = open(configured_path, O_RDONLY | O_NONBLOCK | O_CLOEXEC);
  if (fd >= 0) {
    fprintf(stderr, "volume-keys: opened=%s configured=1\n", configured_path);
  }
  return fd;
}

static int run_volume_helper(const char *action) {
  const char *root = getenv("PLUMOS_ROOT");
  char helper[512];
  pid_t child;
  int status;

  if (!root || !root[0]) {
    root = "/storage/plumos";
  }
  if (snprintf(helper, sizeof(helper), "%s/bin/plumos-volume-control", root) >=
      (int)sizeof(helper)) {
    return -ENAMETOOLONG;
  }
  child = fork();
  if (child < 0) {
    return -errno;
  }
  if (child == 0) {
    execl(helper, helper, action, (char *)NULL);
    _exit(127);
  }
  while (waitpid(child, &status, 0) < 0) {
    if (errno != EINTR) {
      return -errno;
    }
  }
  if (!WIFEXITED(status) || WEXITSTATUS(status) != 0) {
    return -EIO;
  }
  return 0;
}

static int apply_direction(int direction) {
  const char *action = direction > 0 ? "runtime-up" : "runtime-down";
  int result = run_volume_helper(action);

  fprintf(stderr, "volume-keys: action=volume direction=%s rc=%d\n",
          direction > 0 ? "up" : "down", result);
  return result;
}

static void usage(const char *argv0) {
  fprintf(stderr, "usage: %s [--event PATH] [--once]\n", argv0);
}

int main(int argc, char **argv) {
  const char *runtime_root = getenv("PLUMOS_RUNTIME_ROOT");
  const char *configured_event = getenv("PLUMOS_VOLUME_INPUT_EVENT");
  char run_dir[512];
  char lock_path[512];
  long long next_reopen = 0;
  long long repeat_due = 0;
  long long persist_due = 0;
  int held_direction = 0;
  int persist_pending = 0;
  int event_fd = -1;
  int once = 0;
  int lock_fd;
  int index;

  for (index = 1; index < argc; ++index) {
    if (strcmp(argv[index], "--event") == 0 && index + 1 < argc) {
      configured_event = argv[++index];
    } else if (strcmp(argv[index], "--once") == 0) {
      once = 1;
    } else {
      usage(argv[0]);
      return 2;
    }
  }
  if (!runtime_root || !runtime_root[0]) {
    runtime_root = "/run/plumos";
  }
  if (snprintf(run_dir, sizeof(run_dir), "%s/volume-keys", runtime_root) >=
          (int)sizeof(run_dir) ||
      snprintf(lock_path, sizeof(lock_path), "%s/daemon.lock", run_dir) >=
          (int)sizeof(lock_path)) {
    fprintf(stderr, "volume-keys: runtime path is too long\n");
    return 1;
  }
  if (mkdir(run_dir, 0755) < 0 && errno != EEXIST) {
    fprintf(stderr, "volume-keys: cannot create runtime directory errno=%d\n",
            errno);
    return 1;
  }
  lock_fd = open(lock_path, O_CREAT | O_RDWR | O_CLOEXEC, 0644);
  if (lock_fd < 0 || flock(lock_fd, LOCK_EX | LOCK_NB) < 0) {
    fprintf(stderr, "volume-keys: another daemon owns the service lock\n");
    if (lock_fd >= 0) {
      close(lock_fd);
    }
    return 1;
  }

  signal(SIGINT, stop_running);
  signal(SIGTERM, stop_running);
  setvbuf(stderr, NULL, _IOLBF, 0);
  fprintf(stderr, "volume-keys: start owner=plumos device=bubble\n");
  (void)run_volume_helper("apply");

  while (running) {
    struct pollfd poll_fd;
    long long now = monotonic_ms();
    int ready;

    if (event_fd < 0 && now >= next_reopen) {
      event_fd = open_volume_event(configured_event);
      next_reopen = now + REOPEN_INTERVAL_MS;
      if (once && event_fd < 0) {
        break;
      }
    }
    poll_fd.fd = event_fd;
    poll_fd.events = POLLIN;
    poll_fd.revents = 0;
    ready = poll(&poll_fd, 1, 100);
    now = monotonic_ms();
    if (ready < 0 && errno != EINTR) {
      fprintf(stderr, "volume-keys: poll failed errno=%d\n", errno);
    }
    if (ready > 0 && event_fd >= 0 &&
        (poll_fd.revents & (POLLIN | POLLERR | POLLHUP))) {
      for (;;) {
        struct input_event event;
        ssize_t bytes = read(event_fd, &event, sizeof(event));

        if (bytes == (ssize_t)sizeof(event)) {
          if (event.type == EV_KEY &&
              (event.code == KEY_VOLUMEUP || event.code == KEY_VOLUMEDOWN)) {
            int direction = event.code == KEY_VOLUMEUP ? 1 : -1;

            if (event.value == 1) {
              held_direction = direction;
              if (apply_direction(direction) == 0) {
                persist_pending = 1;
                persist_due = now + PERSIST_DELAY_MS;
              }
              repeat_due = now + REPEAT_DELAY_MS;
            } else if (event.value == 0 && held_direction == direction) {
              held_direction = 0;
              repeat_due = 0;
            }
          }
          continue;
        }
        if (bytes < 0 && (errno == EAGAIN || errno == EWOULDBLOCK)) {
          break;
        }
        if (bytes < 0 && errno == EINTR) {
          continue;
        }
        close(event_fd);
        event_fd = -1;
        held_direction = 0;
        repeat_due = 0;
        next_reopen = 0;
        if (once) {
          running = 0;
        }
        break;
      }
    }
    now = monotonic_ms();
    if (held_direction && repeat_due > 0 && now >= repeat_due) {
      if (apply_direction(held_direction) == 0) {
        persist_pending = 1;
        persist_due = now + PERSIST_DELAY_MS;
      }
      repeat_due = now + REPEAT_INTERVAL_MS;
    }
    if (persist_pending && persist_due > 0 && now >= persist_due) {
      int result = run_volume_helper("persist-runtime");
      fprintf(stderr, "volume-keys: persist=volume rc=%d\n", result);
      if (result == 0) {
        persist_pending = 0;
      } else {
        persist_due = now + PERSIST_DELAY_MS;
      }
    }
  }

  if (persist_pending) {
    int result = run_volume_helper("persist-runtime");
    fprintf(stderr, "volume-keys: persist=volume rc=%d shutdown=1\n", result);
  }
  if (event_fd >= 0) {
    close(event_fd);
  }
  close(lock_fd);
  fprintf(stderr, "volume-keys: stopped\n");
  return 0;
}
