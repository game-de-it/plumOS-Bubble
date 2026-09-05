// SPDX-License-Identifier: MIT

#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif
#include <dlfcn.h>
#include <errno.h>
#include <fcntl.h>
#include <stdarg.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>

/*
 * The foreground broker starts before the runtime shell and passes one Unix
 * datagram fd through PLUMOS_DRM_BROKER_FD.  When a descendant opens the KMS
 * card, pass that exact open file description to the broker with SCM_RIGHTS.
 * The external power overlay can then drop and restore DRM master while the
 * emulator itself is stopped.  Opening /proc/PID/fd/N is not equivalent for a
 * DRM character device on the Bubble 4.19 kernel: it creates a new drm_file
 * and DRM_IOCTL_DROP_MASTER fails.
 */

static int path_is_kms_card(const char *path) {
  return path && strncmp(path, "/dev/dri/card", 13) == 0;
}

static void share_kms_fd(const char *path, int fd) {
  const char *value;
  char *end;
  long channel;
  char byte = 'F';
  struct iovec iov;
  struct msghdr message;
  char control[CMSG_SPACE(sizeof(int))];
  struct cmsghdr *header;

  if (fd < 0 || !path_is_kms_card(path)) {
    return;
  }
  value = getenv("PLUMOS_DRM_BROKER_FD");
  if (!value || !value[0]) {
    return;
  }
  errno = 0;
  channel = strtol(value, &end, 10);
  if (errno || end == value || *end != '\0' || channel < 0) {
    return;
  }

  memset(&message, 0, sizeof(message));
  memset(control, 0, sizeof(control));
  iov.iov_base = &byte;
  iov.iov_len = 1;
  message.msg_iov = &iov;
  message.msg_iovlen = 1;
  message.msg_control = control;
  message.msg_controllen = sizeof(control);
  header = CMSG_FIRSTHDR(&message);
  header->cmsg_level = SOL_SOCKET;
  header->cmsg_type = SCM_RIGHTS;
  header->cmsg_len = CMSG_LEN(sizeof(int));
  memcpy(CMSG_DATA(header), &fd, sizeof(fd));
  (void)sendmsg((int)channel, &message, MSG_NOSIGNAL);
}

static int mode_required(int flags) {
  if (flags & O_CREAT) {
    return 1;
  }
#ifdef O_TMPFILE
  if ((flags & O_TMPFILE) == O_TMPFILE) {
    return 1;
  }
#endif
  return 0;
}

static mode_t create_mode(int flags, va_list *args) {
  return mode_required(flags) ? (mode_t)va_arg(*args, int) : 0;
}

int open(const char *path, int flags, ...) {
  static int (*real_open)(const char *, int, ...);
  va_list args;
  mode_t mode;
  int fd;

  if (!real_open) {
    real_open = (int (*)(const char *, int, ...))dlsym(RTLD_NEXT, "open");
  }
  if (!real_open) {
    errno = ENOSYS;
    return -1;
  }
  va_start(args, flags);
  mode = create_mode(flags, &args);
  va_end(args);
  fd = mode_required(flags) ? real_open(path, flags, mode)
                            : real_open(path, flags);
  share_kms_fd(path, fd);
  return fd;
}

int open64(const char *path, int flags, ...) {
  static int (*real_open64)(const char *, int, ...);
  va_list args;
  mode_t mode;
  int fd;

  if (!real_open64) {
    real_open64 =
        (int (*)(const char *, int, ...))dlsym(RTLD_NEXT, "open64");
  }
  if (!real_open64) {
    errno = ENOSYS;
    return -1;
  }
  va_start(args, flags);
  mode = create_mode(flags, &args);
  va_end(args);
  fd = mode_required(flags) ? real_open64(path, flags, mode)
                            : real_open64(path, flags);
  share_kms_fd(path, fd);
  return fd;
}

int openat(int directory, const char *path, int flags, ...) {
  static int (*real_openat)(int, const char *, int, ...);
  va_list args;
  mode_t mode;
  int fd;

  if (!real_openat) {
    real_openat =
        (int (*)(int, const char *, int, ...))dlsym(RTLD_NEXT, "openat");
  }
  if (!real_openat) {
    errno = ENOSYS;
    return -1;
  }
  va_start(args, flags);
  mode = create_mode(flags, &args);
  va_end(args);
  fd = mode_required(flags) ? real_openat(directory, path, flags, mode)
                            : real_openat(directory, path, flags);
  share_kms_fd(path, fd);
  return fd;
}

int openat64(int directory, const char *path, int flags, ...) {
  static int (*real_openat64)(int, const char *, int, ...);
  va_list args;
  mode_t mode;
  int fd;

  if (!real_openat64) {
    real_openat64 = (int (*)(int, const char *, int, ...))dlsym(
        RTLD_NEXT, "openat64");
  }
  if (!real_openat64) {
    errno = ENOSYS;
    return -1;
  }
  va_start(args, flags);
  mode = create_mode(flags, &args);
  va_end(args);
  fd = mode_required(flags) ? real_openat64(directory, path, flags, mode)
                            : real_openat64(directory, path, flags);
  share_kms_fd(path, fd);
  return fd;
}
