#include <errno.h>
#include <fcntl.h>
#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <drm_fourcc.h>
#include <xf86drm.h>
#include <xf86drmMode.h>

static void fourcc_string(uint32_t value, char out[5]) {
  out[0] = (char)(value & 0xff);
  out[1] = (char)((value >> 8) & 0xff);
  out[2] = (char)((value >> 16) & 0xff);
  out[3] = (char)((value >> 24) & 0xff);
  out[4] = '\0';
}

static const char *connector_type_name(uint32_t type) {
  switch (type) {
  case DRM_MODE_CONNECTOR_Unknown: return "Unknown";
  case DRM_MODE_CONNECTOR_VGA: return "VGA";
  case DRM_MODE_CONNECTOR_DVII: return "DVI-I";
  case DRM_MODE_CONNECTOR_DVID: return "DVI-D";
  case DRM_MODE_CONNECTOR_DVIA: return "DVI-A";
  case DRM_MODE_CONNECTOR_Composite: return "Composite";
  case DRM_MODE_CONNECTOR_SVIDEO: return "SVIDEO";
  case DRM_MODE_CONNECTOR_LVDS: return "LVDS";
  case DRM_MODE_CONNECTOR_Component: return "Component";
  case DRM_MODE_CONNECTOR_9PinDIN: return "DIN";
  case DRM_MODE_CONNECTOR_DisplayPort: return "DP";
  case DRM_MODE_CONNECTOR_HDMIA: return "HDMI-A";
  case DRM_MODE_CONNECTOR_HDMIB: return "HDMI-B";
  case DRM_MODE_CONNECTOR_TV: return "TV";
  case DRM_MODE_CONNECTOR_eDP: return "eDP";
  case DRM_MODE_CONNECTOR_VIRTUAL: return "Virtual";
  case DRM_MODE_CONNECTOR_DSI: return "DSI";
#ifdef DRM_MODE_CONNECTOR_DPI
  case DRM_MODE_CONNECTOR_DPI: return "DPI";
#endif
#ifdef DRM_MODE_CONNECTOR_WRITEBACK
  case DRM_MODE_CONNECTOR_WRITEBACK: return "Writeback";
#endif
  default: return "other";
  }
}

static drmModePropertyRes *find_property(int fd,
                                         const drmModeObjectProperties *props,
                                         const char *name,
                                         uint64_t *value) {
  uint32_t i;
  for (i = 0; props && i < props->count_props; ++i) {
    drmModePropertyRes *property = drmModeGetProperty(fd, props->props[i]);
    if (!property) continue;
    if (strcmp(property->name, name) == 0) {
      if (value) *value = props->prop_values[i];
      return property;
    }
    drmModeFreeProperty(property);
  }
  return NULL;
}

static void print_properties(int fd, uint32_t object_id, uint32_t object_type,
                             const char *kind) {
  drmModeObjectProperties *props =
      drmModeObjectGetProperties(fd, object_id, object_type);
  uint32_t i;
  if (!props) {
    printf("object=%s id=%u properties=unavailable errno=%d\n", kind,
           object_id, errno);
    return;
  }
  printf("object=%s id=%u property_count=%u\n", kind, object_id,
         props->count_props);
  for (i = 0; i < props->count_props; ++i) {
    drmModePropertyRes *property = drmModeGetProperty(fd, props->props[i]);
    if (!property) continue;
    printf("property object=%s object_id=%u property_id=%u name=%s value=%" PRIu64
           " flags=0x%x\n", kind, object_id, property->prop_id,
           property->name, props->prop_values[i], property->flags);
    drmModeFreeProperty(property);
  }
  drmModeFreeObjectProperties(props);
}

static void print_modifier_blob(int fd, uint32_t plane_id,
                                drmModeObjectProperties *props) {
  drmModePropertyRes *property;
  drmModePropertyBlobRes *blob;
  struct drm_format_modifier_blob *header;
  struct drm_format_modifier *modifiers;
  uint32_t *formats;
  uint64_t blob_id = 0;
  uint32_t i, j;

  property = find_property(fd, props, "IN_FORMATS", &blob_id);
  if (!property) {
    printf("plane-in-formats plane_id=%u status=absent\n", plane_id);
    return;
  }
  drmModeFreeProperty(property);
  blob = drmModeGetPropertyBlob(fd, (uint32_t)blob_id);
  if (!blob || blob->length < sizeof(*header)) {
    printf("plane-in-formats plane_id=%u blob=%" PRIu64
           " status=unavailable errno=%d\n", plane_id, blob_id, errno);
    if (blob) drmModeFreePropertyBlob(blob);
    return;
  }
  header = (struct drm_format_modifier_blob *)blob->data;
  if ((uint64_t)header->formats_offset +
          (uint64_t)header->count_formats * sizeof(*formats) > blob->length ||
      (uint64_t)header->modifiers_offset +
          (uint64_t)header->count_modifiers * sizeof(*modifiers) > blob->length) {
    printf("plane-in-formats plane_id=%u blob=%" PRIu64 " status=invalid\n",
           plane_id, blob_id);
    drmModeFreePropertyBlob(blob);
    return;
  }
  formats = (uint32_t *)((uint8_t *)blob->data + header->formats_offset);
  modifiers = (struct drm_format_modifier *)
      ((uint8_t *)blob->data + header->modifiers_offset);
  printf("plane-in-formats plane_id=%u blob=%" PRIu64
         " formats=%u modifiers=%u\n", plane_id, blob_id,
         header->count_formats, header->count_modifiers);
  for (i = 0; i < header->count_modifiers; ++i) {
    for (j = 0; j < 64; ++j) {
      uint32_t format_index = modifiers[i].offset + j;
      char name[5];
      if (!(modifiers[i].formats & (UINT64_C(1) << j)) ||
          format_index >= header->count_formats)
        continue;
      fourcc_string(formats[format_index], name);
      printf("plane-modifier plane_id=%u format=%s modifier=0x%016" PRIx64
             "\n", plane_id, name, (uint64_t)modifiers[i].modifier);
    }
  }
  drmModeFreePropertyBlob(blob);
}

static void print_framebuffer(int fd, uint32_t fb_id, const char *source,
                              uint32_t source_id) {
  drmModeFB2 *fb;
  unsigned int i;
  char name[5];
  if (!fb_id) return;
  fb = drmModeGetFB2(fd, fb_id);
  if (!fb) {
    int fb2_errno = errno;
    drmModeFB *legacy = drmModeGetFB(fd, fb_id);
    if (legacy) {
      printf("framebuffer source=%s source_id=%u fb_id=%u size=%ux%u "
             "depth=%u bpp=%u pitch=%u metadata=legacy-getfb "
             "getfb2_errno=%d handle_visible=%s\n", source, source_id,
             fb_id, legacy->width, legacy->height, legacy->depth,
             legacy->bpp, legacy->pitch, fb2_errno,
             legacy->handle ? "yes" : "no");
      drmModeFreeFB(legacy);
    } else {
      printf("framebuffer source=%s source_id=%u fb_id=%u "
             "status=unavailable getfb2_errno=%d getfb_errno=%d\n",
             source, source_id, fb_id, fb2_errno, errno);
    }
    return;
  }
  fourcc_string(fb->pixel_format, name);
  printf("framebuffer source=%s source_id=%u fb_id=%u size=%ux%u format=%s "
         "flags=0x%x\n", source, source_id, fb_id, fb->width, fb->height,
         name, fb->flags);
  for (i = 0; i < 4; ++i) {
    if (!fb->pitches[i] && !fb->handles[i]) continue;
    printf("framebuffer-plane fb_id=%u index=%u pitch=%u offset=%u "
           "modifier=0x%016" PRIx64 " handle_visible=%s\n", fb_id, i,
           fb->pitches[i], fb->offsets[i], (uint64_t)fb->modifier,
           fb->handles[i] ? "yes" : "no");
  }
  drmModeFreeFB2(fb);
}

int main(int argc, char **argv) {
  const char *device = argc > 1 ? argv[1] : "/dev/dri/card0";
  drmModeRes *resources;
  drmModePlaneRes *plane_resources;
  int fd, index, rc, saved_errno;

  fd = open(device, O_RDONLY | O_CLOEXEC);
  if (fd < 0) {
    fprintf(stderr, "open %s: %s\n", device, strerror(errno));
    return 1;
  }
  errno = 0;
  rc = drmSetClientCap(fd, DRM_CLIENT_CAP_UNIVERSAL_PLANES, 1);
  saved_errno = errno;
  printf("client-cap name=universal-planes rc=%d errno=%d\n", rc, saved_errno);
  errno = 0;
  rc = drmSetClientCap(fd, DRM_CLIENT_CAP_ATOMIC, 1);
  saved_errno = errno;
  printf("client-cap name=atomic rc=%d errno=%d\n", rc, saved_errno);

  resources = drmModeGetResources(fd);
  if (!resources) {
    fprintf(stderr, "drmModeGetResources: %s\n", strerror(errno));
    close(fd);
    return 1;
  }
  printf("device=%s open_mode=read-only crtcs=%d connectors=%d encoders=%d "
         "min=%ux%u max=%ux%u\n", device, resources->count_crtcs,
         resources->count_connectors, resources->count_encoders,
         resources->min_width, resources->min_height, resources->max_width,
         resources->max_height);

  for (index = 0; index < resources->count_encoders; ++index) {
    drmModeEncoder *encoder = drmModeGetEncoder(fd, resources->encoders[index]);
    if (!encoder) continue;
    printf("encoder id=%u type=%u crtc_id=%u possible_crtcs=0x%x "
           "possible_clones=0x%x\n", encoder->encoder_id, encoder->encoder_type,
           encoder->crtc_id, encoder->possible_crtcs, encoder->possible_clones);
    drmModeFreeEncoder(encoder);
  }

  for (index = 0; index < resources->count_crtcs; ++index) {
    drmModeCrtc *crtc = drmModeGetCrtc(fd, resources->crtcs[index]);
    if (crtc) {
      printf("crtc id=%u buffer_id=%u gamma_size=%d mode_valid=%d "
             "position=%u,%u size=%ux%u mode=%s clock_khz=%u "
             "htotal=%u vtotal=%u vrefresh=%u flags=0x%x\n", crtc->crtc_id,
             crtc->buffer_id, crtc->gamma_size, crtc->mode_valid, crtc->x,
             crtc->y, crtc->width, crtc->height,
             crtc->mode_valid ? crtc->mode.name : "none",
             crtc->mode_valid ? crtc->mode.clock : 0,
             crtc->mode_valid ? crtc->mode.htotal : 0,
             crtc->mode_valid ? crtc->mode.vtotal : 0,
             crtc->mode_valid ? crtc->mode.vrefresh : 0,
             crtc->mode_valid ? crtc->mode.flags : 0);
      print_framebuffer(fd, crtc->buffer_id, "crtc", crtc->crtc_id);
      drmModeFreeCrtc(crtc);
    }
    print_properties(fd, resources->crtcs[index], DRM_MODE_OBJECT_CRTC, "crtc");
  }

  for (index = 0; index < resources->count_connectors; ++index) {
    drmModeConnector *connector =
        drmModeGetConnector(fd, resources->connectors[index]);
    if (connector) {
      int mode_index;
      printf("connector id=%u name=%s-%u type=%u connection=%u encoder=%u "
             "modes=%d physical_mm=%ux%u subpixel=%u\n",
             connector->connector_id,
             connector_type_name(connector->connector_type),
             connector->connector_type_id, connector->connector_type,
             connector->connection, connector->encoder_id,
             connector->count_modes, connector->mmWidth, connector->mmHeight,
             connector->subpixel);
      for (mode_index = 0; mode_index < connector->count_modes; ++mode_index) {
        drmModeModeInfo *mode = &connector->modes[mode_index];
        printf("connector-mode connector_id=%u index=%d name=%s size=%ux%u "
               "clock_khz=%u htotal=%u vtotal=%u vrefresh=%u type=0x%x "
               "flags=0x%x\n", connector->connector_id, mode_index,
               mode->name, mode->hdisplay, mode->vdisplay, mode->clock,
               mode->htotal, mode->vtotal, mode->vrefresh, mode->type,
               mode->flags);
      }
      drmModeFreeConnector(connector);
    }
    print_properties(fd, resources->connectors[index],
                     DRM_MODE_OBJECT_CONNECTOR, "connector");
  }

  plane_resources = drmModeGetPlaneResources(fd);
  if (!plane_resources) {
    printf("planes status=unavailable errno=%d\n", errno);
  } else {
    printf("planes count=%u\n", plane_resources->count_planes);
    for (index = 0; index < (int)plane_resources->count_planes; ++index) {
      drmModePlane *plane = drmModeGetPlane(fd, plane_resources->planes[index]);
      drmModeObjectProperties *props;
      uint32_t format_index;
      if (!plane) continue;
      printf("plane id=%u crtc_id=%u fb_id=%u possible_crtcs=0x%x "
             "gamma_size=%u formats=%u\n", plane->plane_id, plane->crtc_id,
             plane->fb_id, plane->possible_crtcs, plane->gamma_size,
             plane->count_formats);
      for (format_index = 0; format_index < plane->count_formats;
           ++format_index) {
        char name[5];
        fourcc_string(plane->formats[format_index], name);
        printf("plane-format plane_id=%u index=%u format=%s value=0x%08x\n",
               plane->plane_id, format_index, name,
               plane->formats[format_index]);
      }
      print_framebuffer(fd, plane->fb_id, "plane", plane->plane_id);
      props = drmModeObjectGetProperties(fd, plane->plane_id,
                                         DRM_MODE_OBJECT_PLANE);
      print_modifier_blob(fd, plane->plane_id, props);
      if (props) drmModeFreeObjectProperties(props);
      print_properties(fd, plane->plane_id, DRM_MODE_OBJECT_PLANE, "plane");
      drmModeFreePlane(plane);
    }
    drmModeFreePlaneResources(plane_resources);
  }

  drmModeFreeResources(resources);
  close(fd);
  return 0;
}
