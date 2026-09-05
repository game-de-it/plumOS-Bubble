// SPDX-License-Identifier: MIT

#include <errno.h>
#include <dirent.h>
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
#define POWER_DEBOUNCE_MS 800

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

static int open_named_event(const char *target_name, const char *log_name) {
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
      fprintf(stderr, "%s: opened=%s name=%s\n", log_name, path, name);
      return fd;
    }
    close(fd);
  }
  return -1;
}

static int open_input_event(const char *configured_path,
                            const char *target_name,
                            const char *log_name) {
  int fd;

  if (!configured_path || !configured_path[0]) {
    return open_named_event(target_name, log_name);
  }
  fd = open(configured_path, O_RDONLY | O_NONBLOCK | O_CLOEXEC);
  if (fd >= 0) {
    fprintf(stderr, "%s: opened=%s configured=1\n", log_name,
            configured_path);
  }
  return fd;
}

static int process_owns_display(pid_t pid) {
  char directory_path[64];
  DIR *directory;
  struct dirent *entry;
  int owns_display = 0;

  if (pid <= 1 ||
      snprintf(directory_path, sizeof(directory_path), "/proc/%ld/fd",
               (long)pid) >= (int)sizeof(directory_path)) {
    return 0;
  }
  directory = opendir(directory_path);
  if (!directory) {
    return 0;
  }
  while ((entry = readdir(directory)) != NULL) {
    char link_path[128];
    char target[128];
    ssize_t length;

    if (entry->d_name[0] == '.') {
      continue;
    }
    if (snprintf(link_path, sizeof(link_path), "%s/%s", directory_path,
                 entry->d_name) >= (int)sizeof(link_path)) {
      continue;
    }
    length = readlink(link_path, target, sizeof(target) - 1);
    if (length < 0) {
      continue;
    }
    target[length] = '\0';
    if (strcmp(target, "/dev/fb0") == 0 ||
        strncmp(target, "/dev/dri/", 9) == 0 ||
        strncmp(target, "/dev/mali", 9) == 0) {
      owns_display = 1;
      break;
    }
  }
  closedir(directory);
  return owns_display;
}

static pid_t frontend_ready_pid(void) {
  FILE *file = fopen("/tmp/plumos-fe-ready", "r");
  char line[64];
  long value = 0;

  if (!file) {
    return 0;
  }
  while (fgets(line, sizeof(line), file)) {
    if (sscanf(line, "pid=%ld", &value) == 1) {
      break;
    }
  }
  fclose(file);
  if (value <= 1 || kill((pid_t)value, 0) < 0) {
    return 0;
  }
  return (pid_t)value;
}

static int power_overlay_locked(void) {
  const char *runtime_root = getenv("PLUMOS_RUNTIME_ROOT");
  char path[512];

  if (!runtime_root || !runtime_root[0]) {
    runtime_root = "/run/plumos";
  }
  if (snprintf(path, sizeof(path), "%s/power-menu-overlay.lock",
               runtime_root) >= (int)sizeof(path)) {
    return 1;
  }
  return access(path, F_OK) == 0;
}

static int spawn_power_overlay(void) {
  const char *root = getenv("PLUMOS_ROOT");
  char helper[512];
  pid_t child;

  if (!root || !root[0]) {
    root = "/storage/plumos";
  }
  if (snprintf(helper, sizeof(helper), "%s/bin/plumos-power-menu-overlay",
               root) >= (int)sizeof(helper)) {
    return -ENAMETOOLONG;
  }
  child = fork();
  if (child < 0) {
    return -errno;
  }
  if (child == 0) {
    pid_t grandchild = fork();

    if (grandchild < 0) {
      _exit(127);
    }
    if (grandchild == 0) {
      (void)setsid();
      execl(helper, helper, "open", (char *)NULL);
      _exit(127);
    }
    _exit(0);
  }
  for (;;) {
    int status;
    pid_t waited = waitpid(child, &status, 0);

    if (waited >= 0) {
      return WIFEXITED(status) && WEXITSTATUS(status) == 0 ? 0 : -EIO;
    }
    if (errno != EINTR) {
      return -errno;
    }
  }
}

static int open_power_menu(void) {
  pid_t frontend_pid = frontend_ready_pid();
  int result;

  if (frontend_pid > 0 && process_owns_display(frontend_pid)) {
    fprintf(stderr,
            "power-key: action=power-menu delegated=frontend pid=%ld\n",
            (long)frontend_pid);
    return 0;
  }
  if (power_overlay_locked()) {
    fprintf(stderr, "power-key: action=power-menu skipped=already-open\n");
    return 0;
  }
  result = spawn_power_overlay();
  fprintf(stderr, "power-key: action=power-menu overlay=1 rc=%d\n", result);
  return result;
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
  fprintf(stderr,
          "usage: %s [--event PATH] [--power-event PATH] [--once]\n",
          argv0);
}

int main(int argc, char **argv) {
  const char *runtime_root = getenv("PLUMOS_RUNTIME_ROOT");
  const char *configured_event = getenv("PLUMOS_VOLUME_INPUT_EVENT");
  const char *configured_power_event = getenv("PLUMOS_POWER_INPUT_EVENT");
  char run_dir[512];
  char lock_path[512];
  long long next_volume_reopen = 0;
  long long next_power_reopen = 0;
  long long repeat_due = 0;
  long long persist_due = 0;
  long long power_debounce_until = 0;
  int held_direction = 0;
  int persist_pending = 0;
  int event_fd = -1;
  int power_event_fd = -1;
  int volume_done = 0;
  int power_done = 0;
  int once = 0;
  int lock_fd;
  int index;

  for (index = 1; index < argc; ++index) {
    if (strcmp(argv[index], "--event") == 0 && index + 1 < argc) {
      configured_event = argv[++index];
    } else if (strcmp(argv[index], "--power-event") == 0 &&
               index + 1 < argc) {
      configured_power_event = argv[++index];
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

  if (once) {
    volume_done = !configured_event || !configured_event[0];
    power_done = !configured_power_event || !configured_power_event[0];
  }

  while (running) {
    struct pollfd poll_fds[2];
    long long now = monotonic_ms();
    int ready;

    if (!volume_done && event_fd < 0 && now >= next_volume_reopen) {
      event_fd = open_input_event(configured_event, "gpio-keys", "volume-keys");
      next_volume_reopen = now + REOPEN_INTERVAL_MS;
      if (once && event_fd < 0) {
        volume_done = 1;
      }
    }
    if (!power_done && power_event_fd < 0 && now >= next_power_reopen) {
      power_event_fd = open_input_event(configured_power_event,
                                        "rk805 pwrkey", "power-key");
      next_power_reopen = now + REOPEN_INTERVAL_MS;
      if (once && power_event_fd < 0) {
        power_done = 1;
      }
    }
    if (once && volume_done && power_done) {
      break;
    }
    poll_fds[0].fd = event_fd;
    poll_fds[0].events = POLLIN;
    poll_fds[0].revents = 0;
    poll_fds[1].fd = power_event_fd;
    poll_fds[1].events = POLLIN;
    poll_fds[1].revents = 0;
    ready = poll(poll_fds, 2, 100);
    now = monotonic_ms();
    if (ready < 0 && errno != EINTR) {
      fprintf(stderr, "volume-keys: poll failed errno=%d\n", errno);
    }
    if (ready > 0 && event_fd >= 0 &&
        (poll_fds[0].revents & (POLLIN | POLLERR | POLLHUP))) {
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
        next_volume_reopen = 0;
        if (once) {
          volume_done = 1;
        }
        break;
      }
    }
    if (ready > 0 && power_event_fd >= 0 &&
        (poll_fds[1].revents & (POLLIN | POLLERR | POLLHUP))) {
      for (;;) {
        struct input_event event;
        ssize_t bytes = read(power_event_fd, &event, sizeof(event));

        if (bytes == (ssize_t)sizeof(event)) {
          now = monotonic_ms();
          if (event.type == EV_KEY && event.code == KEY_POWER &&
              event.value == 1 && now >= power_debounce_until) {
            power_debounce_until = now + POWER_DEBOUNCE_MS;
            (void)open_power_menu();
          }
          continue;
        }
        if (bytes < 0 && (errno == EAGAIN || errno == EWOULDBLOCK)) {
          break;
        }
        if (bytes < 0 && errno == EINTR) {
          continue;
        }
        close(power_event_fd);
        power_event_fd = -1;
        next_power_reopen = 0;
        if (once) {
          power_done = 1;
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
  if (power_event_fd >= 0) {
    close(power_event_fd);
  }
  close(lock_fd);
  fprintf(stderr, "volume-keys: stopped\n");
  return 0;
}
