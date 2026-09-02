#include <errno.h>
#include <fcntl.h>
#include <linux/input-event-codes.h>
#include <linux/joystick.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <sys/ioctl.h>
#include <unistd.h>

int main(int argc, char **argv) {
  const char *path = argc > 1 ? argv[1] : "/dev/input/js0";
  uint8_t axes = 0;
  uint8_t buttons = 0;
  uint8_t axis_map[ABS_CNT] = {0};
  uint16_t button_map[KEY_MAX - BTN_MISC + 1] = {0};
  int fd = open(path, O_RDONLY | O_CLOEXEC);
  int i;

  if (fd < 0) {
    fprintf(stderr, "open %s: %s\n", path, strerror(errno));
    return 1;
  }
  if (ioctl(fd, JSIOCGAXES, &axes) < 0 ||
      ioctl(fd, JSIOCGBUTTONS, &buttons) < 0 ||
      ioctl(fd, JSIOCGAXMAP, axis_map) < 0 ||
      ioctl(fd, JSIOCGBTNMAP, button_map) < 0) {
    fprintf(stderr, "joystick ioctl: %s\n", strerror(errno));
    close(fd);
    return 1;
  }

  printf("device=%s axes=%u buttons=%u\n", path, axes, buttons);
  for (i = 0; i < axes; ++i)
    printf("axis[%d]=%u\n", i, axis_map[i]);
  for (i = 0; i < buttons; ++i)
    printf("button[%d]=%u\n", i, button_map[i]);
  close(fd);
  return 0;
}
