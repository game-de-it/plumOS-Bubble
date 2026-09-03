#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <xf86drm.h>
#include <xf86drmMode.h>

static void print_properties(int fd, uint32_t object_id, uint32_t object_type,
                             const char *kind) {
  drmModeObjectProperties *properties =
      drmModeObjectGetProperties(fd, object_id, object_type);
  uint32_t index;

  if (!properties) {
    printf("object=%s id=%u properties=unavailable errno=%d\n", kind,
           object_id, errno);
    return;
  }
  printf("object=%s id=%u property_count=%u\n", kind, object_id,
         properties->count_props);
  for (index = 0; index < properties->count_props; ++index) {
    drmModePropertyRes *property =
        drmModeGetProperty(fd, properties->props[index]);
    if (!property) {
      continue;
    }
    printf("property object=%s id=%u name=%s value=%llu flags=0x%x\n", kind,
           property->prop_id, property->name,
           (unsigned long long)properties->prop_values[index],
           property->flags);
    for (int value_index = 0; value_index < property->count_values;
         ++value_index) {
      printf("property-value object=%s id=%u index=%d value=%llu\n", kind,
             property->prop_id, value_index,
             (unsigned long long)property->values[value_index]);
    }
    drmModeFreeProperty(property);
  }
  drmModeFreeObjectProperties(properties);
}

int main(int argc, char **argv) {
  const char *device = argc > 1 ? argv[1] : "/dev/dri/card0";
  drmModeRes *resources;
  int fd;
  int index;

  fd = open(device, O_RDWR | O_CLOEXEC);
  if (fd < 0) {
    fprintf(stderr, "open %s: %s\n", device, strerror(errno));
    return 1;
  }
  resources = drmModeGetResources(fd);
  if (!resources) {
    fprintf(stderr, "drmModeGetResources: %s\n", strerror(errno));
    close(fd);
    return 1;
  }
  printf("device=%s crtcs=%d connectors=%d encoders=%d min=%ux%u max=%ux%u\n",
         device, resources->count_crtcs, resources->count_connectors,
         resources->count_encoders, resources->min_width, resources->min_height,
         resources->max_width, resources->max_height);
  for (index = 0; index < resources->count_crtcs; ++index) {
    drmModeCrtc *crtc = drmModeGetCrtc(fd, resources->crtcs[index]);
    if (crtc) {
      printf("crtc id=%u gamma_size=%d mode_valid=%d size=%ux%u\n",
             crtc->crtc_id, crtc->gamma_size, crtc->mode_valid, crtc->width,
             crtc->height);
      drmModeFreeCrtc(crtc);
    }
    print_properties(fd, resources->crtcs[index], DRM_MODE_OBJECT_CRTC, "crtc");
  }
  for (index = 0; index < resources->count_connectors; ++index) {
    drmModeConnector *connector =
        drmModeGetConnector(fd, resources->connectors[index]);
    if (connector) {
      printf("connector id=%u type=%u connection=%u encoder=%u modes=%d\n",
             connector->connector_id, connector->connector_type,
             connector->connection, connector->encoder_id,
             connector->count_modes);
      drmModeFreeConnector(connector);
    }
    print_properties(fd, resources->connectors[index],
                     DRM_MODE_OBJECT_CONNECTOR, "connector");
  }
  drmModeFreeResources(resources);
  close(fd);
  return 0;
}
