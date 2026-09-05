/*
 * plumos-ggfe - the Game Gear frontend for plumOS Bubble.
 *
 * A cartridge carousel drawn with CPU software 3D.  GGFE owns no GL context
 * and never opens /dev/mali0, so launching RetroArch is the same DRM handoff
 * the stock frontend already performs: release the renderer, run the launcher
 * in its own process group, reacquire on return.
 *
 * GGFE is a separate binary rather than a mode inside plumos-controller-ui.
 * The stock frontend keeps every common plumOS menu item untouched, and GGFE
 * can be tested, replaced or skipped without putting that frontend at risk.
 *
 * With --png it renders one frame of the launch sequence to a file with no
 * framebuffer and no device, so the whole scene is verifiable on a host.
 */

#include <errno.h>
#include <signal.h>
#include <stdarg.h>
#include <sys/ioctl.h>
#include <sys/wait.h>

#include <ft2build.h>
#include FT_FREETYPE_H

/*
 * PLUMOS_GGFE_HOST builds everything above the panel - artwork resolution,
 * label compositing, the scene and the animation - without linux/fb.h, so the
 * whole frontend can be rendered to PNG and reviewed on a build machine.  The
 * device build takes the same code with the framebuffer attached.
 */
#ifdef PLUMOS_GGFE_HOST
#include <png.h>
#else
#define PLUMOS_ENABLE_FBDEV_RENDERER 1
#include "plumos_fbdev_renderer.h"
#endif

#include "plumos_ggfe_art.h"
#include "plumos_ggfe_launch.h"
#include "plumos_ggfe_model.h"

#ifdef PLUMOS_GGFE_HOST
/* Same contract as the renderer's loader: RGBA8888, caller frees. */
static int plumos_fbdev_load_png_rgba(const char *path, unsigned char **out,
                                      int *width_out, int *height_out) {
  FILE *f = fopen(path, "rb");
  png_structp png;
  png_infop info;
  png_bytep *rows;
  int y;

  if (!f) {
    return 0;
  }
  png = png_create_read_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
  info = png_create_info_struct(png);
  if (setjmp(png_jmpbuf(png))) {
    png_destroy_read_struct(&png, &info, NULL);
    fclose(f);
    return 0;
  }
  png_init_io(png, f);
  png_read_info(png, info);
  *width_out = (int)png_get_image_width(png, info);
  *height_out = (int)png_get_image_height(png, info);
  png_set_strip_16(png);
  png_set_palette_to_rgb(png);
  png_set_expand_gray_1_2_4_to_8(png);
  png_set_gray_to_rgb(png);
  png_set_tRNS_to_alpha(png);
  png_set_filler(png, 0xff, PNG_FILLER_AFTER);
  png_read_update_info(png, info);
  *out = (unsigned char *)malloc((size_t)*width_out * (size_t)*height_out * 4);
  rows = (png_bytep *)malloc(sizeof(png_bytep) * (size_t)*height_out);
  for (y = 0; y < *height_out; y++) {
    rows[y] = *out + (size_t)y * (size_t)*width_out * 4;
  }
  png_read_image(png, rows);
  free(rows);
  png_destroy_read_struct(&png, &info, NULL);
  fclose(f);
  return 1;
}
#endif

#define GGFE_W 640
#define GGFE_H 480

/* Console top edge.  Hidden while browsing; rises only to receive a game. */
#define GGFE_FACE_TOP 366
#define GGFE_BOSS_X0 184
#define GGFE_BOSS_Y0 372
#define GGFE_BOSS_X1 456
#define GGFE_BOSS_Y1 416
#define GGFE_OPEN_X0 196
#define GGFE_OPEN_Y0 379
#define GGFE_OPEN_X1 444
#define GGFE_OPEN_Y1 398
#define GGFE_MOUTH_FRONT GGFE_OPEN_Y1
#define GGFE_CONSOLE_TRAVEL 130.0f
#define GGFE_TOP_FACE 424

#define GGFE_Y_IDLE 10.0f
#define GGFE_Y_INSERTED (-50.0f)
#define GGFE_CAROUSEL_SPAN 3.2f
#define GGFE_NEIGHBOUR_DIM 0.52f

#define GGFE_LABEL_TEX_W 381
#define GGFE_LABEL_TEX_H 288
#define GGFE_STRIP_W 61
#define GGFE_LABEL_CACHE 12
#define GGFE_MAX_DRAWS 6144
#define GGFE_TARGET_FPS 60.0f
#define GGFE_SCROLL_MS 360

struct ggfe_image {
  unsigned char *rgb; /* RGB8 */
  unsigned char *alpha;
  int width;
  int height;
};

struct ggfe_text {
  FT_Library library;
  FT_Face face;
  FT_Face fallback;
  int ready;
  int size;
};

struct ggfe_label_slot {
  int entry;
  int valid;
  unsigned long used;
  unsigned char *rgb;
  struct cart3d_tex tex;
};

struct ggfe_app {
  struct ggfe_config cfg;
  struct ggfe_catalog catalog;
  struct ggfe_override_set ggfe_overrides;
  struct ggfe_override_set plumos_overrides;
  struct ggfe_roots roots;
  struct ggfe_entry *entries;
  int entry_count;

  struct cart3d_mesh cart;
  struct cart3d_mesh tray;
  struct cart3d_mesh lid;
  int label_tri[2];
  float case_h;

  struct cart3d_camera cam;
  struct cart3d_target target;
  struct cart3d_draw *draws;

  struct ggfe_label_slot labels[GGFE_LABEL_CACHE];
  unsigned long label_tick;

  struct ggfe_image logo_strip;  /* red GAME GEAR strip for the label */
  struct ggfe_image header_logo; /* wordmark for the top left of the header */
  struct ggfe_text text;

  char plumos_root[PATH_MAX];
  char theme_root[PATH_MAX];
  int log_fd;
};

/* ------------------------------------------------------------------ */
/* image helpers                                                      */
/* ------------------------------------------------------------------ */

static void ggfe_image_free(struct ggfe_image *img) {
  free(img->rgb);
  free(img->alpha);
  memset(img, 0, sizeof(*img));
}

/* Only PNG is decoded.  The resolver still honours jpg/jpeg/webp so it stays
 * faithful to the stock frontend's rules, but this build links libpng alone -
 * a jpg hit falls back to the no-artwork plate rather than silently showing
 * the wrong thing. */
static int ggfe_path_is_png(const char *path) {
  const char *dot = strrchr(path, '.');
  return dot && ascii_equal_ci(dot + 1, "png");
}

static int ggfe_image_load_png(const char *path, struct ggfe_image *out) {
  unsigned char *rgba = NULL;
  int w = 0, h = 0;
  long i, n;

  memset(out, 0, sizeof(*out));
  if (!ggfe_path_is_png(path)) {
    return 0;
  }
  if (!plumos_fbdev_load_png_rgba(path, &rgba, &w, &h) || w <= 0 || h <= 0) {
    return 0;
  }
  n = (long)w * (long)h;
  out->rgb = (unsigned char *)malloc((size_t)n * 3);
  out->alpha = (unsigned char *)malloc((size_t)n);
  if (!out->rgb || !out->alpha) {
    free(rgba);
    ggfe_image_free(out);
    return 0;
  }
  for (i = 0; i < n; i++) {
    out->rgb[i * 3 + 0] = rgba[i * 4 + 0];
    out->rgb[i * 3 + 1] = rgba[i * 4 + 1];
    out->rgb[i * 3 + 2] = rgba[i * 4 + 2];
    out->alpha[i] = rgba[i * 4 + 3];
  }
  free(rgba);
  out->width = w;
  out->height = h;
  return 1;
}

static void ggfe_scale_rgb(const unsigned char *src, int sw, int sh,
                           unsigned char *dst, int dw, int dh, int nearest) {
  int x, y, c;
  for (y = 0; y < dh; y++) {
    float fy = ((float)y + 0.5f) * (float)sh / (float)dh - 0.5f;
    int y0 = (int)floorf(fy);
    float wy = fy - (float)y0;
    int y1;
    if (nearest) {
      y0 = (int)((float)y * (float)sh / (float)dh);
      wy = 0.0f;
    }
    if (y0 < 0) { y0 = 0; wy = 0.0f; }
    if (y0 > sh - 1) { y0 = sh - 1; wy = 0.0f; }
    y1 = (y0 + 1 < sh) ? y0 + 1 : y0;
    for (x = 0; x < dw; x++) {
      float fx = ((float)x + 0.5f) * (float)sw / (float)dw - 0.5f;
      int x0 = (int)floorf(fx);
      float wx = fx - (float)x0;
      int x1;
      if (nearest) {
        x0 = (int)((float)x * (float)sw / (float)dw);
        wx = 0.0f;
      }
      if (x0 < 0) { x0 = 0; wx = 0.0f; }
      if (x0 > sw - 1) { x0 = sw - 1; wx = 0.0f; }
      x1 = (x0 + 1 < sw) ? x0 + 1 : x0;
      for (c = 0; c < 3; c++) {
        float a = (float)src[((size_t)y0 * sw + x0) * 3 + c] * (1.0f - wx) +
                  (float)src[((size_t)y0 * sw + x1) * 3 + c] * wx;
        float b = (float)src[((size_t)y1 * sw + x0) * 3 + c] * (1.0f - wx) +
                  (float)src[((size_t)y1 * sw + x1) * 3 + c] * wx;
        float v = a + (b - a) * wy;
        dst[((size_t)y * dw + x) * 3 + c] = (unsigned char)(v + 0.5f);
      }
    }
  }
}

/* ------------------------------------------------------------------ */
/* label compositing                                                  */
/* ------------------------------------------------------------------ */

/*
 * The aperture is exactly 160:144 - 320 x 288 texels, a 2x integer upscale of
 * a native Game Gear frame - so a title capture fills it edge to edge with no
 * letterbox and no resampling blur.  Box art still letterboxes; the remaining
 * bars are filled with the artwork downscaled to a handful of pixels and
 * scaled back up, which costs nothing next to a real blur and happens once per
 * cartridge.
 *
 * The GAME GEAR strip is printed only for title-aspect artwork.  Box-art scans
 * already carry the logo on the box, and printing it again would duplicate it.
 */
static void ggfe_label_backdrop(const struct ggfe_image *art,
                                unsigned char *dst, int dw, int dh) {
  unsigned char small[10 * 7 * 3];
  int i;
  ggfe_scale_rgb(art->rgb, art->width, art->height, small, 10, 7, 0);
  ggfe_scale_rgb(small, 10, 7, dst, dw, dh, 0);
  for (i = 0; i < dw * dh * 3; i++) {
    dst[i] = (unsigned char)((float)dst[i] * 0.26f);
  }
}

static void ggfe_label_build(struct ggfe_app *app, const struct ggfe_image *art,
                             enum ggfe_art_kind kind, unsigned char *out) {
  int ax = 0, aw = GGFE_LABEL_TEX_W, ah = GGFE_LABEL_TEX_H;
  int fw, fh, fx, fy, x, y, c;
  float k;
  unsigned char *fitted, *back;

  memset(out, 12, (size_t)GGFE_LABEL_TEX_W * GGFE_LABEL_TEX_H * 3);

  if (kind == GGFE_ART_TITLE && app->logo_strip.rgb) {
    unsigned char *strip = (unsigned char *)malloc((size_t)GGFE_STRIP_W *
                                                   GGFE_LABEL_TEX_H * 3);
    if (strip) {
      ggfe_scale_rgb(app->logo_strip.rgb, app->logo_strip.width,
                     app->logo_strip.height, strip, GGFE_STRIP_W,
                     GGFE_LABEL_TEX_H, 0);
      for (y = 0; y < GGFE_LABEL_TEX_H; y++) {
        memcpy(out + ((size_t)y * GGFE_LABEL_TEX_W) * 3,
               strip + ((size_t)y * GGFE_STRIP_W) * 3, (size_t)GGFE_STRIP_W * 3);
      }
      free(strip);
      ax = GGFE_STRIP_W;
      aw = GGFE_LABEL_TEX_W - GGFE_STRIP_W;
    }
  }
  if (!art || !art->rgb) {
    return;
  }

  back = (unsigned char *)malloc((size_t)aw * ah * 3);
  if (back) {
    ggfe_label_backdrop(art, back, aw, ah);
    for (y = 0; y < ah; y++) {
      memcpy(out + ((size_t)y * GGFE_LABEL_TEX_W + ax) * 3,
             back + ((size_t)y * aw) * 3, (size_t)aw * 3);
    }
    free(back);
  }

  k = (float)aw / (float)art->width;
  if ((float)ah / (float)art->height < k) {
    k = (float)ah / (float)art->height;
  }
  fw = (int)(art->width * k + 0.5f);
  fh = (int)(art->height * k + 0.5f);
  if (fw < 1) fw = 1;
  if (fh < 1) fh = 1;
  fitted = (unsigned char *)malloc((size_t)fw * fh * 3);
  if (!fitted) {
    return;
  }
  /* An exact integer upscale of a native capture stays nearest, so pixels
   * stay crisp instead of being smeared by the filter. */
  ggfe_scale_rgb(art->rgb, art->width, art->height, fitted, fw, fh,
                 (k >= 1.0f && fabsf(k - floorf(k + 0.5f)) < 0.02f));
  fx = ax + (aw - fw) / 2;
  fy = (ah - fh) / 2;
  for (y = 0; y < fh; y++) {
    for (x = 0; x < fw; x++) {
      for (c = 0; c < 3; c++) {
        out[(((size_t)(fy + y) * GGFE_LABEL_TEX_W) + (size_t)(fx + x)) * 3 + c] =
            fitted[((size_t)y * fw + x) * 3 + c];
      }
    }
  }
  free(fitted);
}

/* ------------------------------------------------------------------ */
/* text                                                               */
/*                                                                    */
/* GGFE draws its own glyphs into its own RGB target rather than going */
/* through the panel renderer, so the whole scene - 3D, console, HUD - */
/* is composed in one buffer and renders identically on a host.        */
/* ------------------------------------------------------------------ */


static int ggfe_text_init(struct ggfe_text *t, const char *font_path,
                          const char *fallback_path) {
  memset(t, 0, sizeof(*t));
  if (FT_Init_FreeType(&t->library) != 0) {
    return 0;
  }
  if (FT_New_Face(t->library, font_path, 0, &t->face) != 0) {
    FT_Done_FreeType(t->library);
    t->library = NULL;
    return 0;
  }
  if (fallback_path && fallback_path[0]) {
    if (FT_New_Face(t->library, fallback_path, 0, &t->fallback) != 0) {
      t->fallback = NULL;
    }
  }
  t->ready = 1;
  return 1;
}

static void ggfe_text_free(struct ggfe_text *t) {
  if (t->face) {
    FT_Done_Face(t->face);
  }
  if (t->fallback) {
    FT_Done_Face(t->fallback);
  }
  if (t->library) {
    FT_Done_FreeType(t->library);
  }
  memset(t, 0, sizeof(*t));
}

static unsigned int ggfe_utf8_next(const char **p) {
  const unsigned char *s = (const unsigned char *)*p;
  unsigned int cp = *s;
  int extra = 0;

  if (cp < 0x80) {
    extra = 0;
  } else if ((cp & 0xe0) == 0xc0) {
    cp &= 0x1f;
    extra = 1;
  } else if ((cp & 0xf0) == 0xe0) {
    cp &= 0x0f;
    extra = 2;
  } else if ((cp & 0xf8) == 0xf0) {
    cp &= 0x07;
    extra = 3;
  } else {
    cp = '?';
  }
  s++;
  while (extra-- > 0 && (*s & 0xc0) == 0x80) {
    cp = (cp << 6) | (unsigned int)(*s & 0x3f);
    s++;
  }
  *p = (const char *)s;
  return cp;
}

static FT_Face ggfe_face_for(struct ggfe_text *t, unsigned int cp, int size) {
  FT_Face face = t->face;
  if (FT_Get_Char_Index(face, cp) == 0 && t->fallback &&
      FT_Get_Char_Index(t->fallback, cp) != 0) {
    face = t->fallback;
  }
  FT_Set_Pixel_Sizes(face, 0, (FT_UInt)size);
  return face;
}

static int ggfe_text_width(struct ggfe_text *t, int size, const char *utf8) {
  const char *p = utf8;
  int w = 0;
  if (!t->ready) {
    return 0;
  }
  while (*p) {
    unsigned int cp = ggfe_utf8_next(&p);
    FT_Face face = ggfe_face_for(t, cp, size);
    if (FT_Load_Char(face, cp, FT_LOAD_DEFAULT) == 0) {
      w += (int)(face->glyph->advance.x >> 6);
    }
  }
  return w;
}

static void ggfe_draw_text(struct cart3d_target *tg, struct ggfe_text *t, int x,
                           int y, int size, const char *utf8,
                           const unsigned char rgb[3], float alpha) {
  const char *p = utf8;
  int pen = x;

  if (!t->ready || alpha <= 0.01f) {
    return;
  }
  while (*p) {
    unsigned int cp = ggfe_utf8_next(&p);
    FT_Face face = ggfe_face_for(t, cp, size);
    FT_GlyphSlot g;
    int gx, gy;

    if (FT_Load_Char(face, cp, FT_LOAD_RENDER) != 0) {
      continue;
    }
    g = face->glyph;
    for (gy = 0; gy < (int)g->bitmap.rows; gy++) {
      int py = y + size - g->bitmap_top + gy;
      if (py < 0 || py >= tg->height) {
        continue;
      }
      for (gx = 0; gx < (int)g->bitmap.width; gx++) {
        int px = pen + g->bitmap_left + gx;
        unsigned char cov = g->bitmap.buffer[gy * g->bitmap.pitch + gx];
        float a;
        int c;
        if (px < 0 || px >= tg->width || cov == 0) {
          continue;
        }
        a = ((float)cov / 255.0f) * alpha;
        for (c = 0; c < 3; c++) {
          unsigned char *d =
              tg->rgb + (((size_t)py * tg->width) + (size_t)px) * 3 + c;
          *d = (unsigned char)((float)*d * (1.0f - a) + (float)rgb[c] * a +
                               0.5f);
        }
      }
    }
    pen += (int)(g->advance.x >> 6);
  }
}

/* ------------------------------------------------------------------ */
/* 2D primitives on the render target                                 */
/* ------------------------------------------------------------------ */

static void ggfe_blend_px(struct cart3d_target *t, int x, int y,
                          const unsigned char rgb[3], float a) {
  int c;
  if (x < 0 || y < 0 || x >= t->width || y >= t->height || a <= 0.0f) {
    return;
  }
  if (a > 1.0f) {
    a = 1.0f;
  }
  for (c = 0; c < 3; c++) {
    unsigned char *d = t->rgb + (((size_t)y * t->width) + (size_t)x) * 3 + c;
    *d = (unsigned char)((float)*d * (1.0f - a) + (float)rgb[c] * a + 0.5f);
  }
}

static void ggfe_rect(struct cart3d_target *t, int x0, int y0, int x1, int y1,
                      const unsigned char rgb[3], float a) {
  int x, y;
  for (y = y0; y <= y1; y++) {
    for (x = x0; x <= x1; x++) {
      ggfe_blend_px(t, x, y, rgb, a);
    }
  }
}

/* Rounded rectangle by per-scanline inset, with a soft edge. */
static void ggfe_rounded_rect(struct cart3d_target *t, int x0, int y0, int x1,
                              int y1, int r, const unsigned char rgb[3],
                              float a) {
  int y;
  for (y = y0; y <= y1; y++) {
    float inset = 0.0f;
    int dy = 0;
    if (y < y0 + r) {
      dy = y0 + r - y;
    } else if (y > y1 - r) {
      dy = y - (y1 - r);
    }
    if (dy > 0) {
      float d = (float)(r * r - dy * dy);
      inset = (float)r - (d > 0.0f ? sqrtf(d) : 0.0f);
    }
    ggfe_rect(t, x0 + (int)(inset + 0.5f), y, x1 - (int)(inset + 0.5f), y, rgb,
              a);
  }
}

static void ggfe_blit_rgba(struct cart3d_target *t, const struct ggfe_image *img,
                           int dx, int dy, int dw, int dh, float alpha) {
  unsigned char *rgb;
  int x, y;

  if (!img->rgb || dw <= 0 || dh <= 0) {
    return;
  }
  rgb = (unsigned char *)malloc((size_t)dw * dh * 3);
  if (!rgb) {
    return;
  }
  ggfe_scale_rgb(img->rgb, img->width, img->height, rgb, dw, dh, 0);
  for (y = 0; y < dh; y++) {
    int sy = (int)((float)y * img->height / (float)dh);
    for (x = 0; x < dw; x++) {
      int sx = (int)((float)x * img->width / (float)dw);
      float a = alpha;
      if (img->alpha) {
        a *= (float)img->alpha[(size_t)sy * img->width + sx] / 255.0f;
      }
      ggfe_blend_px(t, dx + x, dy + y, rgb + ((size_t)y * dw + x) * 3, a);
    }
  }
  free(rgb);
}

/* ------------------------------------------------------------------ */
/* scene                                                              */
/* ------------------------------------------------------------------ */

static const unsigned char ggfe_accent[3] = {255, 133, 13};
static const unsigned char ggfe_muted[3] = {133, 166, 166};
static const unsigned char ggfe_sel_fg[3] = {255, 230, 122};
static const unsigned char ggfe_rule[3] = {30, 42, 44};

/* The background never changes, so it is built once and memcpy'd per frame
 * rather than re-evaluating two gaussians over 307k pixels every 16 ms. */
static void ggfe_background_build(unsigned char *out) {
  int x, y;
  for (y = 0; y < GGFE_H; y++) {
    float k = (float)y / (float)(GGFE_H - 1);
    for (x = 0; x < GGFE_W; x++) {
      float gx = ((float)x - 320.0f) / 250.0f;
      float gy = ((float)y - 185.0f) / 170.0f;
      float hx = ((float)x - 320.0f) / 150.0f;
      float hy = ((float)y - 180.0f) / 130.0f;
      float glow = expf(-(gx * gx + gy * gy));
      float halo = expf(-(hx * hx + hy * hy));
      float c[3];
      int i;
      c[0] = 11.0f * (1.0f - k) + 3.0f * k + glow * 13.0f + halo * 18.0f;
      c[1] = 17.0f * (1.0f - k) + 4.0f * k + glow * 30.0f + halo * 10.0f;
      c[2] = 19.0f * (1.0f - k) + 4.0f * k + glow * 28.0f + halo * 1.0f;
      for (i = 0; i < 3; i++) {
        if (c[i] > 255.0f) c[i] = 255.0f;
        out[((size_t)y * GGFE_W + x) * 3 + i] = (unsigned char)(c[i] + 0.5f);
      }
    }
  }
}

/*
 * The console is drawn twice around the cartridge mouth: everything below the
 * mouth is in FRONT of the cartridge, everything above it is behind.  That
 * single split is what makes the cartridge read as inserted rather than
 * hidden behind a panel.
 */
static void ggfe_draw_console(struct cart3d_target *t, float dy, float shadow_k,
                              int front_only) {
  int off = (int)(dy + 0.5f);
  int y, i;
  const int clip = GGFE_MOUTH_FRONT + off;
  unsigned char col[3];

#define GGFE_ROW_OK(row) (!front_only || (row) >= clip)

  for (y = GGFE_FACE_TOP + off; y < GGFE_H; y++) {
    int local = y - off;
    float k;
    if (!GGFE_ROW_OK(y) || y < 0) {
      continue;
    }
    if (local < GGFE_TOP_FACE) {
      k = (float)(local - GGFE_FACE_TOP) / (float)(GGFE_TOP_FACE - GGFE_FACE_TOP);
      col[0] = (unsigned char)(70.0f - 16.0f * k);
      col[1] = (unsigned char)(74.0f - 17.0f * k);
      col[2] = (unsigned char)(80.0f - 18.0f * k);
    } else {
      k = (float)(local - GGFE_TOP_FACE) / (float)(GGFE_H - GGFE_TOP_FACE);
      col[0] = (unsigned char)(48.0f - 26.0f * k);
      col[1] = (unsigned char)(51.0f - 28.0f * k);
      col[2] = (unsigned char)(56.0f - 31.0f * k);
    }
    ggfe_rect(t, 0, y, GGFE_W - 1, y, col, 1.0f);
  }
  if (GGFE_ROW_OK(GGFE_FACE_TOP + off)) {
    unsigned char lip[3] = {116, 124, 132};
    unsigned char lip2[3] = {82, 88, 94};
    ggfe_rect(t, 0, GGFE_FACE_TOP + off, GGFE_W - 1, GGFE_FACE_TOP + off, lip,
              1.0f);
    ggfe_rect(t, 0, GGFE_FACE_TOP + off + 1, GGFE_W - 1,
              GGFE_FACE_TOP + off + 1, lip2, 1.0f);
  }

  {
    unsigned char boss[3] = {78, 82, 89};
    unsigned char boss_in[3] = {58, 62, 69};
    unsigned char mouth[3] = {6, 7, 8};
    unsigned char pin[3] = {96, 92, 74};
    unsigned char lip_lo[3] = {120, 128, 136};
    int by0 = GGFE_BOSS_Y0 + off, by1 = GGFE_BOSS_Y1 + off;
    int oy0 = GGFE_OPEN_Y0 + off, oy1 = GGFE_OPEN_Y1 + off;

    if (!front_only) {
      ggfe_rounded_rect(t, GGFE_BOSS_X0, by0, GGFE_BOSS_X1, by1, 9, boss, 1.0f);
      ggfe_rounded_rect(t, GGFE_BOSS_X0 + 5, by0 + 4, GGFE_BOSS_X1 - 5, by1 - 6,
                        6, boss_in, 1.0f);
      ggfe_rounded_rect(t, GGFE_OPEN_X0, oy0, GGFE_OPEN_X1, oy1, 3, mouth,
                        1.0f);
      for (i = GGFE_OPEN_X0 + 7; i < GGFE_OPEN_X1 - 5; i += 4) {
        ggfe_rect(t, i, oy0 + 7, i, oy1 - 4, pin, 1.0f);
      }
    } else {
      /* the front lip of the mouth, and the plate below it */
      ggfe_rounded_rect(t, GGFE_BOSS_X0, clip, GGFE_BOSS_X1, by1, 9, boss,
                        1.0f);
      ggfe_rect(t, GGFE_OPEN_X0 + 3, oy1 - 1, GGFE_OPEN_X1 - 3, oy1 - 1, lip_lo,
                1.0f);
      ggfe_rect(t, GGFE_OPEN_X0, oy1 + 3, GGFE_OPEN_X1, oy1 + 3, lip_lo, 1.0f);
    }
  }

  if (!front_only) {
    /* volume wheel, phones jack, DC in, power switch */
    unsigned char body[3] = {40, 43, 48};
    unsigned char wheel[3] = {96, 100, 108};
    unsigned char rib[3] = {52, 55, 61};
    unsigned char ring[3] = {46, 49, 55};
    unsigned char hole[3] = {8, 9, 10};
    unsigned char orange[3] = {214, 92, 24};
    unsigned char orange_rib[3] = {150, 60, 14};
    int b = off;
    ggfe_rounded_rect(t, 38, 380 + b, 78, 400 + b, 5, body, 1.0f);
    ggfe_rounded_rect(t, 41, 382 + b, 75, 398 + b, 4, wheel, 1.0f);
    for (i = 45; i < 74; i += 4) {
      ggfe_rect(t, i, 383 + b, i, 397 + b, rib, 1.0f);
    }
    ggfe_rounded_rect(t, 98, 380 + b, 120, 402 + b, 11, ring, 1.0f);
    ggfe_rounded_rect(t, 104, 386 + b, 114, 396 + b, 5, hole, 1.0f);
    ggfe_rounded_rect(t, 520, 380 + b, 542, 402 + b, 11, ring, 1.0f);
    ggfe_rounded_rect(t, 526, 386 + b, 536, 396 + b, 5, hole, 1.0f);
    ggfe_rounded_rect(t, 562, 378 + b, 600, 402 + b, 4, body, 1.0f);
    ggfe_rounded_rect(t, 566, 381 + b, 584, 399 + b, 3, orange, 1.0f);
    for (i = 569; i < 583; i += 4) {
      ggfe_rect(t, i, 383 + b, i, 397 + b, orange_rib, 1.0f);
    }

    if (shadow_k > 0.0f) {
      /* soft contact shadow under the hovering cartridge */
      int cy = GGFE_FACE_TOP + off + 10;
      float rw = 130.0f, rh = 26.0f;
      int sx, sy;
      unsigned char black[3] = {0, 0, 0};
      for (sy = -(int)rh; sy <= (int)rh; sy++) {
        for (sx = -(int)rw; sx <= (int)rw; sx++) {
          float u = (float)sx / rw, v = (float)sy / rh;
          float d = u * u + v * v;
          float a;
          if (d > 1.0f) {
            continue;
          }
          a = (1.0f - d) * (1.0f - d) * 0.55f * shadow_k;
          ggfe_blend_px(t, 320 + sx, cy + sy, black, a);
        }
      }
    }
  }
#undef GGFE_ROW_OK
}

/* Placement of the cartridge d slots away from the current selection. */
static void ggfe_carousel_slot(float d, float *x, float *z, float *ry,
                               float *rx, float *alpha, float *dim) {
  float ad = fabsf(d);
  float hero = 1.0f - ad;
  if (hero < 0.0f) {
    hero = 0.0f;
  }
  *x = (ad > 1e-6f) ? copysignf(84.0f * powf(ad, 0.90f), d) : 0.0f;
  *z = -58.0f * powf(ad, 0.95f);
  *ry = -40.0f * tanhf(1.1f * d) - 14.0f * hero;
  *rx = 5.0f + 2.0f * hero;
  *alpha = 1.35f - 0.42f * ad;
  if (*alpha > 1.0f) *alpha = 1.0f;
  if (*alpha < 0.0f) *alpha = 0.0f;
  *dim = 1.0f - (1.0f - GGFE_NEIGHBOUR_DIM) * (ad < 1.0f ? ad : 1.0f);
}

/* ------------------------------------------------------------------ */
/* launch timeline                                                    */
/* ------------------------------------------------------------------ */

#define GGFE_LAUNCH_END 1.44f
#define GGFE_HANDOFF 0.35f

struct ggfe_frame {
  float pos;
  int has_hero;
  float hero[16];
  float others;
  float flash;
  float hud;
  float shadow;
  float console_dy;
  int cased;
  float case_deg;
  float case_alpha;
  float case_lid_alpha;
  float case_y;
};

static float ggfe_lerp(float a, float b, float k) { return a + (b - a) * k; }

static float ggfe_seg(float t, float a, float b) {
  if (t <= a) return 0.0f;
  if (t >= b) return 1.0f;
  return (t - a) / (b - a);
}

static float ggfe_ease_out(float k) {
  float i = 1.0f - k;
  return 1.0f - i * i * i;
}

static float ggfe_ease_in(float k) { return k * k * k; }

static float ggfe_ease_in_out(float k) { return 3.0f * k * k - 2.0f * k * k * k; }

/* Slide into the mouth, then seat with a small overshoot. */
static float ggfe_insert_curve(float t, float a, float b, float c) {
  float y = ggfe_lerp(GGFE_Y_IDLE, GGFE_Y_INSERTED - 3.0f,
                      ggfe_ease_in_out(ggfe_seg(t, a, b)));
  if (t > b) {
    y = ggfe_lerp(GGFE_Y_INSERTED - 3.0f, GGFE_Y_INSERTED,
                  ggfe_ease_out(ggfe_seg(t, b, c)));
  }
  return y;
}

static void ggfe_cart_matrix(float out[16], float x, float y, float z, float rx,
                             float ry, float sx, float sy) {
  float trans[16], rot[16], scale[16], tmp[16];
  cart3d_translate(trans, x, y, -CART3D_CAM_DIST + z);
  cart3d_rotate(rot, rx, ry, 0.0f);
  cart3d_scale(scale, sx, sy, 1.0f);
  cart3d_mul(trans, rot, tmp);
  cart3d_mul(tmp, scale, out);
}

/*
 * The lid swings toward the viewer, as a real clamshell must.  Opening it away
 * puts it behind the cartridge within a few degrees and the motion is
 * invisible; a fully open lid does not fit 480 px, so it dissolves once it is
 * edge-on.
 */
static void ggfe_launch_frame(float t, float pos, struct ggfe_frame *f) {
  const float deg = 3.14159265358979f / 180.0f;
  float y = GGFE_Y_IDLE, sx = 1.0f, sy = 1.0f, dz = GGFE_CASE_Z;
  float rx = 7.0f * deg, ry = -14.0f * deg;
  float lid, rise, k;

  memset(f, 0, sizeof(*f));
  f->pos = pos;
  f->cased = 1;

  lid = -96.0f * ggfe_ease_out(ggfe_seg(t, 0.02f, 0.30f));
  lid += 6.0f * sinf(3.14159265f * ggfe_seg(t, 0.30f, 0.44f));

  if (t < 0.34f) {
    k = ggfe_seg(t, 0.24f, 0.34f);
    sx = ggfe_lerp(1.0f, 1.06f, k);
    sy = ggfe_lerp(1.0f, 0.91f, k);
  } else if (t < 0.58f) {
    k = ggfe_ease_out(ggfe_seg(t, 0.34f, 0.58f));
    y = ggfe_lerp(GGFE_Y_IDLE, GGFE_Y_IDLE + 26.0f, k);
    dz = ggfe_lerp(GGFE_CASE_Z, 1.0f, k);
    sx = ggfe_lerp(1.06f, 0.95f, k);
    sy = ggfe_lerp(0.91f, 1.08f, k);
    rx = ggfe_lerp(7.0f, 0.0f, k) * deg;
    ry = ggfe_lerp(-14.0f, 0.0f, k) * deg;
  } else if (t < 0.76f) {
    k = ggfe_ease_in(ggfe_seg(t, 0.58f, 0.76f));
    y = ggfe_lerp(GGFE_Y_IDLE + 26.0f, GGFE_Y_IDLE, k);
    dz = ggfe_lerp(1.0f, 0.0f, k);
    sx = ggfe_lerp(0.95f, 1.05f, k);
    sy = ggfe_lerp(1.08f, 0.93f, k);
    rx = ry = 0.0f;
  } else if (t < 0.86f) {
    k = ggfe_ease_out(ggfe_seg(t, 0.76f, 0.86f));
    sx = ggfe_lerp(1.05f, 1.0f, k);
    sy = ggfe_lerp(0.93f, 1.0f, k);
    dz = 0.0f;
    rx = ry = 0.0f;
  } else {
    y = ggfe_insert_curve(t, 0.86f, 1.16f, 1.26f);
    dz = 0.0f;
    rx = ry = 0.0f;
  }

  ggfe_cart_matrix(f->hero, 0.0f, y, dz, rx, ry, sx, sy);
  f->has_hero = 1;
  f->case_deg = lid;
  f->case_alpha = GGFE_CASE_ALPHA * (1.0f - ggfe_seg(t, 0.60f, 0.86f));
  f->case_lid_alpha = GGFE_CASE_ALPHA * (1.0f - ggfe_seg(t, 0.30f, 0.46f));
  f->case_y = GGFE_Y_IDLE - 34.0f * ggfe_ease_in(ggfe_seg(t, 0.60f, 0.86f));
  f->others = 1.0f - 0.70f * ggfe_seg(t, 0.04f, 0.40f) -
              0.30f * ggfe_seg(t, 0.40f, 0.72f);
  if (f->others < 0.0f) f->others = 0.0f;
  f->hud = 1.0f - ggfe_seg(t, 0.72f, 0.90f);
  f->flash = 0.88f * ggfe_seg(t, 1.30f, GGFE_LAUNCH_END);
  /* the console climbs into place while the cartridge is still in the air */
  rise = ggfe_ease_out(ggfe_seg(t, 0.54f, 0.88f));
  f->console_dy = GGFE_CONSOLE_TRAVEL * (1.0f - rise);
  f->shadow = rise * (1.0f - ggfe_seg(t, 0.86f, 1.10f));
  if (f->shadow < 0.0f) f->shadow = 0.0f;
}

static void ggfe_browse_frame(float pos, struct ggfe_frame *f) {
  memset(f, 0, sizeof(*f));
  f->pos = pos;
  f->cased = 1;
  f->others = 1.0f;
  f->hud = 1.0f;
  f->case_alpha = GGFE_CASE_ALPHA;
  f->case_lid_alpha = GGFE_CASE_ALPHA;
  f->case_y = GGFE_Y_IDLE;
  f->console_dy = GGFE_CONSOLE_TRAVEL;
}

/* ------------------------------------------------------------------ */
/* label cache and frame composition                                  */
/* ------------------------------------------------------------------ */

/* Only the cartridges near the selection are ever on screen, so labels are
 * built on demand into a small LRU.  A full library's worth of 381x288
 * textures would be hundreds of megabytes. */
static struct cart3d_tex *ggfe_label_tex(struct ggfe_app *app, int entry) {
  int i, victim = 0;
  unsigned long oldest = ~0UL;
  struct ggfe_label_slot *slot;
  struct ggfe_image art;
  enum ggfe_art_kind kind;

  for (i = 0; i < GGFE_LABEL_CACHE; i++) {
    if (app->labels[i].valid && app->labels[i].entry == entry) {
      app->labels[i].used = ++app->label_tick;
      return &app->labels[i].tex;
    }
    if (!app->labels[i].valid) {
      victim = i;
      oldest = 0;
    } else if (app->labels[i].used < oldest) {
      oldest = app->labels[i].used;
      victim = i;
    }
  }
  slot = &app->labels[victim];
  if (!slot->rgb) {
    slot->rgb = (unsigned char *)malloc((size_t)GGFE_LABEL_TEX_W *
                                        GGFE_LABEL_TEX_H * 3);
    if (!slot->rgb) {
      return NULL;
    }
  }

  memset(&art, 0, sizeof(art));
  kind = app->entries[entry].kind;
  if (app->entries[entry].art[0] &&
      ggfe_image_load_png(app->entries[entry].art, &art)) {
    if (kind == GGFE_ART_UNKNOWN) {
      /* a stock-scheme hit carries no kind; the decoded aspect decides */
      kind = ggfe_classify_size(&app->cfg, art.width, art.height);
    }
    ggfe_label_build(app, &art, kind, slot->rgb);
    ggfe_image_free(&art);
  } else {
    /* No artwork: say so plainly rather than inventing a fake screenshot. */
    struct cart3d_target plate;
    const unsigned char dim[3] = {150, 172, 168};
    const unsigned char faint[3] = {92, 112, 110};
    const char *title = app->entries[entry].title;
    int w;
    ggfe_label_build(app, NULL, GGFE_ART_BOXART, slot->rgb);
    plate.rgb = slot->rgb;
    plate.depth = NULL;
    plate.width = GGFE_LABEL_TEX_W;
    plate.height = GGFE_LABEL_TEX_H;
    w = ggfe_text_width(&app->text, 24, title);
    ggfe_draw_text(&plate, &app->text, (GGFE_LABEL_TEX_W - w) / 2,
                   GGFE_LABEL_TEX_H / 2 - 34, 24, title, dim, 1.0f);
    w = ggfe_text_width(&app->text, 15, "NO ARTWORK");
    ggfe_draw_text(&plate, &app->text, (GGFE_LABEL_TEX_W - w) / 2,
                   GGFE_LABEL_TEX_H / 2 + 8, 15, "NO ARTWORK", faint, 1.0f);
  }
  slot->entry = entry;
  slot->valid = 1;
  slot->used = ++app->label_tick;
  slot->tex.rgb = slot->rgb;
  slot->tex.width = GGFE_LABEL_TEX_W;
  slot->tex.height = GGFE_LABEL_TEX_H;
  slot->tex.filter_nearest = 0;
  return &slot->tex;
}

/* Decode every label that can enter the visible carousel before motion starts.
 * PNG decode and resize are intentionally kept out of the transition frames:
 * advancing by wall time across that one-off stall made a one-slot move look
 * like a jump on Bubble. */
static void ggfe_warm_labels(struct ggfe_app *app, int center) {
  int first = center - 4;
  int last = center + 4;
  int i;

  if (!app) {
    return;
  }
  if (first < 0) {
    first = 0;
  }
  if (last >= app->entry_count) {
    last = app->entry_count - 1;
  }
  for (i = first; i <= last; i++) {
    (void)ggfe_label_tex(app, i);
  }
}

static void ggfe_set_label(struct ggfe_app *app, const struct cart3d_tex *tex) {
  int i;
  for (i = 0; i < 2; i++) {
    if (app->label_tri[i] >= 0) {
      app->cart.tris[app->label_tri[i]].tex = tex;
    }
  }
}

struct ggfe_order {
  int index;
  float d;
};

static int ggfe_order_cmp(const void *a, const void *b) {
  float da = fabsf(((const struct ggfe_order *)a)->d);
  float db = fabsf(((const struct ggfe_order *)b)->d);
  return (da > db) ? -1 : (da < db) ? 1 : 0;
}

static void ggfe_draw_hud(struct ggfe_app *app, const struct ggfe_frame *f,
                          int sel) {
  char label[64];
  float settle = 1.0f - 2.2f * fabsf(f->pos - (float)sel);
  int w;

  if (app->header_logo.rgb) {
    int lh = 38;
    int lw = (int)((float)app->header_logo.width * (float)lh /
                   (float)app->header_logo.height);
    ggfe_blit_rgba(&app->target, &app->header_logo, 16, 8, lw, lh, 1.0f);
  } else {
    ggfe_draw_text(&app->target, &app->text, 16, 11, 17, "GAME GEAR", ggfe_accent,
                   1.0f);
  }
  snprintf(label, sizeof(label), "%d / %d", sel + 1, app->entry_count);
  w = ggfe_text_width(&app->text, 14, label);
  ggfe_draw_text(&app->target, &app->text, GGFE_W - 16 - w, 20, 14, label, ggfe_muted,
                 1.0f);
  ggfe_rect(&app->target, 16, 54, GGFE_W - 17, 54, ggfe_rule, 1.0f);

  if (settle < 0.0f) {
    settle = 0.0f;
  }
  if (f->hud * settle > 0.02f && sel >= 0 && sel < app->entry_count) {
    const char *title = app->entries[sel].title;
    w = ggfe_text_width(&app->text, 25, title);
    ggfe_draw_text(&app->target, &app->text, (GGFE_W - w) / 2, 330, 25, title,
                   ggfe_sel_fg, f->hud * settle);
  }
}

/*
 * Stage timing for the compose pass.  Compiled out entirely unless
 * GGFE_PROFILE is defined, so the shipped frontend pays nothing: a low frame
 * rate has to be attributable to a stage, not guessed at.
 */
#ifdef GGFE_PROFILE
enum {
  GGFE_STAGE_CLEAR = 0,
  GGFE_STAGE_CONSOLE,
  GGFE_STAGE_LABEL,
  GGFE_STAGE_CART,
  GGFE_STAGE_GLASS,
  GGFE_STAGE_FRONT,
  GGFE_STAGE_HUD,
  GGFE_STAGE_FLASH,
  GGFE_STAGE_COUNT
};
static const char *ggfe_stage_name[GGFE_STAGE_COUNT] = {
    "clear", "console", "label", "cart3d", "glass", "console_front", "hud",
    "flash"};
static long long ggfe_stage_us[GGFE_STAGE_COUNT];
static long long ggfe_stage_mark;
static long long ggfe_profile_now_us(void) {
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return (long long)ts.tv_sec * 1000000LL + ts.tv_nsec / 1000LL;
}
#define GGFE_STAGE_BEGIN() (ggfe_stage_mark = ggfe_profile_now_us())
#define GGFE_STAGE_END(stage)                                    \
  do {                                                           \
    long long now_us = ggfe_profile_now_us();                    \
    ggfe_stage_us[stage] += now_us - ggfe_stage_mark;            \
    ggfe_stage_mark = now_us;                                    \
  } while (0)
#else
#define GGFE_STAGE_BEGIN() ((void)0)
#define GGFE_STAGE_END(stage) ((void)0)
#endif

static void ggfe_compose(struct ggfe_app *app, const struct ggfe_frame *f,
                         const unsigned char *background) {
  const float deg = 3.14159265358979f / 180.0f;
  int show_console = f->console_dy < GGFE_CONSOLE_TRAVEL - 0.5f;
  struct ggfe_order order[16];
  int n_order = 0, i, n = 0, glass_n = 0;
  struct cart3d_draw *glass;
  int sel = (int)(f->pos + (f->pos < 0.0f ? -0.5f : 0.5f));

  if (sel < 0) sel = 0;
  if (sel > app->entry_count - 1) sel = app->entry_count - 1;

  GGFE_STAGE_BEGIN();
  memcpy(app->target.rgb, background, (size_t)GGFE_W * GGFE_H * 3);
  cart3d_target_clear_depth(&app->target);
  GGFE_STAGE_END(GGFE_STAGE_CLEAR);
  if (show_console) {
    ggfe_draw_console(&app->target, f->console_dy, f->shadow, 0);
  }
  GGFE_STAGE_END(GGFE_STAGE_CONSOLE);

  for (i = 0; i < app->entry_count && n_order < 16; i++) {
    float d = (float)i - f->pos;
    if (fabsf(d) > GGFE_CAROUSEL_SPAN) {
      continue;
    }
    order[n_order].index = i;
    order[n_order].d = d;
    n_order++;
  }
  qsort(order, (size_t)n_order, sizeof(order[0]), ggfe_order_cmp);

  glass = app->draws + GGFE_MAX_DRAWS / 2;
  for (i = 0; i < n_order; i++) {
    int idx = order[i].index;
    float x, z, ry, rx, alpha, dim, model[16], base[16];
    int is_sel = (idx == sel);
    float amul = is_sel ? 1.0f : f->others;
    const struct cart3d_tex *tex;

    ggfe_carousel_slot(order[i].d, &x, &z, &ry, &rx, &alpha, &dim);
    if (alpha * amul <= 0.02f) {
      continue;
    }
    if (alpha * amul > 1.0f) {
      amul = 1.0f / alpha;
    }
    tex = ggfe_label_tex(app, idx);
    ggfe_set_label(app, tex);
    GGFE_STAGE_END(GGFE_STAGE_LABEL);

    ggfe_cart_matrix(base, x, GGFE_Y_IDLE, z, rx * deg, ry * deg, 1.0f, 1.0f);
    if (is_sel && f->has_hero) {
      memcpy(model, f->hero, sizeof(model));
    } else {
      ggfe_cart_matrix(model, x, GGFE_Y_IDLE,
                       z + (f->cased ? GGFE_CASE_Z : 0.0f), rx * deg, ry * deg,
                       1.0f, 1.0f);
    }
    n = cart3d_emit(app->draws, n, GGFE_MAX_DRAWS / 2, &app->cart, model,
                    &app->cam, dim, alpha * amul);
    cart3d_draw_list(&app->target, app->draws, n, 1);
    n = 0;
    GGFE_STAGE_END(GGFE_STAGE_CART);

    if (f->cased) {
      float lid_model[16], pivot[16], back[16], rot[16], tmp[16];
      float tray_a = is_sel ? f->case_alpha : GGFE_CASE_ALPHA * alpha * amul;
      float lid_a = is_sel ? f->case_lid_alpha : tray_a;
      float case_base[16];

      if (is_sel && f->has_hero) {
        ggfe_cart_matrix(case_base, 0.0f, f->case_y, 0.0f, rx * deg, ry * deg,
                         1.0f, 1.0f);
      } else {
        memcpy(case_base, base, sizeof(case_base));
      }
      if (tray_a > 0.02f) {
        glass_n = cart3d_emit(glass, glass_n, GGFE_MAX_DRAWS / 2, &app->tray,
                              case_base, &app->cam, 1.0f, tray_a);
      }
      if (lid_a > 0.02f) {
        cart3d_translate(pivot, 0.0f, app->case_h / 2.0f, GGFE_CASE_PIVOT_Z);
        cart3d_rotate(rot, (is_sel ? f->case_deg : 0.0f) * deg, 0.0f, 0.0f);
        cart3d_translate(back, 0.0f, -app->case_h / 2.0f, -GGFE_CASE_PIVOT_Z);
        cart3d_mul(case_base, pivot, tmp);
        cart3d_mul(tmp, rot, lid_model);
        cart3d_mul(lid_model, back, tmp);
        glass_n = cart3d_emit(glass, glass_n, GGFE_MAX_DRAWS / 2, &app->lid,
                              tmp, &app->cam, 1.0f, lid_a);
      }
    }
  }

  GGFE_STAGE_END(GGFE_STAGE_CART);
  cart3d_sort(glass, glass_n);
  cart3d_draw_list(&app->target, glass, glass_n, 0);
  GGFE_STAGE_END(GGFE_STAGE_GLASS);

  if (show_console) {
    ggfe_draw_console(&app->target, f->console_dy, f->shadow, 1);
  }
  GGFE_STAGE_END(GGFE_STAGE_FRONT);
  ggfe_draw_hud(app, f, sel);
  GGFE_STAGE_END(GGFE_STAGE_HUD);

  if (f->flash > 0.0f) {
    long i2, total = (long)GGFE_W * GGFE_H * 3;
    float a = f->flash > 1.0f ? 1.0f : f->flash;
    for (i2 = 0; i2 < total; i2++) {
      app->target.rgb[i2] =
          (unsigned char)((float)app->target.rgb[i2] * (1.0f - a) + 255.0f * a);
    }
  }
  GGFE_STAGE_END(GGFE_STAGE_FLASH);
}

/* ------------------------------------------------------------------ */
/* setup                                                              */
/* ------------------------------------------------------------------ */

static void ggfe_load_asset(struct ggfe_app *app, const char *rel,
                            struct ggfe_image *out) {
  char path[PATH_MAX];
  memset(out, 0, sizeof(*out));
  if (join_path(path, sizeof(path), app->theme_root, rel)) {
    ggfe_image_load_png(path, out);
  }
}

static int ggfe_app_init(struct ggfe_app *app, const char *plumos_root,
                         const char *sdcard_root) {
  char cfg_path[PATH_MAX];
  int i;

  memset(app, 0, sizeof(*app));
  app->log_fd = -1;
  copy_string(app->plumos_root, sizeof(app->plumos_root), plumos_root);
  join_path(app->theme_root, sizeof(app->theme_root), plumos_root,
            "themes/default/ggfe");
  copy_string(app->roots.sdcard, sizeof(app->roots.sdcard), sdcard_root);
  join_path(app->roots.roms, sizeof(app->roots.roms), sdcard_root, "Roms");
  copy_string(app->roots.plumos, sizeof(app->roots.plumos), plumos_root);

  join_path(cfg_path, sizeof(cfg_path), plumos_root,
            "config/frontend/ggfe.json");
  if (!ggfe_config_load(&app->cfg, cfg_path)) {
    char factory[PATH_MAX];
    join_path(factory, sizeof(factory), plumos_root,
              "factory-defaults/frontend/ggfe.json");
    ggfe_config_load(&app->cfg, factory);
  }

  app->entries = (struct ggfe_entry *)calloc(GGFE_MAX_ENTRIES,
                                             sizeof(struct ggfe_entry));
  if (!app->entries) {
    return 0;
  }
  app->entry_count = ggfe_scan(&app->cfg, &app->roots, app->entries,
                               GGFE_MAX_ENTRIES);

  {
    char path[PATH_MAX];
    if (join_path(path, sizeof(path), plumos_root, app->cfg.systems_path)) {
      ggfe_catalog_load(&app->catalog, path, app->cfg.launch_system);
      ggfe_probe_profiles(&app->catalog, plumos_root);
    }
    if (join_path(path, sizeof(path), plumos_root, app->cfg.ggfe_overrides)) {
      ggfe_overrides_load(&app->ggfe_overrides, path, app->cfg.launch_system);
    }
    if (app->cfg.use_plumos_overrides &&
        join_path(path, sizeof(path), plumos_root, app->cfg.plumos_overrides)) {
      ggfe_overrides_load(&app->plumos_overrides, path,
                          app->cfg.launch_system);
    }
  }

  if (!ggfe_build_cartridge(&app->cart, NULL) ||
      !ggfe_build_case(&app->tray, &app->lid, &app->case_h)) {
    return 0;
  }
  app->label_tri[0] = app->label_tri[1] = -1;
  for (i = 0; i < app->cart.count; i++) {
    if (app->cart.tris[i].gloss) {
      if (app->label_tri[0] < 0) {
        app->label_tri[0] = i;
      } else if (app->label_tri[1] < 0) {
        app->label_tri[1] = i;
      }
    }
  }

  cart3d_camera_init(&app->cam, GGFE_W, GGFE_H);
  app->target.width = GGFE_W;
  app->target.height = GGFE_H;
  app->target.rgb = (unsigned char *)malloc((size_t)GGFE_W * GGFE_H * 3);
  app->target.depth = (float *)malloc((size_t)GGFE_W * GGFE_H * sizeof(float));
  app->draws = (struct cart3d_draw *)malloc(sizeof(struct cart3d_draw) *
                                            GGFE_MAX_DRAWS);
  if (!app->target.rgb || !app->target.depth || !app->draws) {
    return 0;
  }

  ggfe_load_asset(app, "logo-strip.png", &app->logo_strip);
  ggfe_load_asset(app, "header-logo.png", &app->header_logo);

  {
    char font[PATH_MAX], fallback[PATH_MAX];
    join_path(font, sizeof(font), plumos_root, "fonts/default.otf");
    join_path(fallback, sizeof(fallback), plumos_root,
              "fonts/cjk-fallback.ttc");
    if (!ggfe_text_init(&app->text, font, fallback)) {
      return 0;
    }
  }
  return 1;
}

static void ggfe_app_free(struct ggfe_app *app) {
  int i;
  ggfe_text_free(&app->text);
  ggfe_overrides_free(&app->ggfe_overrides);
  ggfe_overrides_free(&app->plumos_overrides);
  for (i = 0; i < GGFE_LABEL_CACHE; i++) {
    free(app->labels[i].rgb);
  }
  ggfe_image_free(&app->logo_strip);
  ggfe_image_free(&app->header_logo);
  cart3d_mesh_free(&app->cart);
  cart3d_mesh_free(&app->tray);
  cart3d_mesh_free(&app->lid);
  free(app->target.rgb);
  free(app->target.depth);
  free(app->draws);
  free(app->entries);
}

#ifndef PLUMOS_GGFE_HOST
/* ------------------------------------------------------------------ */
/* device: panel, input and the launch handoff                        */
/* ------------------------------------------------------------------ */

#include <linux/input.h>
#include <poll.h>

/* One packed write per pixel when the panel is the usual 32bpp unrotated
 * surface; put_pixel otherwise.  307k put_pixel calls a frame would not fit
 * the budget. */
static void ggfe_blit_panel(struct plumos_fbdev_renderer *r,
                            const unsigned char *rgb) {
  int x, y;
  int fast = (r->bytes_per_pixel == 4 && !r->rotation_180 &&
              r->var.red.length == 8 && r->var.green.length == 8 &&
              r->var.blue.length == 8 && (int)r->var.xres == GGFE_W &&
              (int)r->var.yres == GGFE_H);

  if (fast) {
    unsigned char *base = r->shadow ? r->shadow : r->mem + r->active_offset;
    uint32_t alpha = 0;
    if (r->var.transp.length) {
      alpha = plumos_fbdev_scale_channel(255, r->var.transp.length,
                                         r->var.transp.offset);
    }
    for (y = 0; y < GGFE_H; y++) {
      uint32_t *out = (uint32_t *)(base + (size_t)y * r->fix.line_length);
      const unsigned char *in = rgb + (size_t)y * GGFE_W * 3;
      for (x = 0; x < GGFE_W; x++) {
        out[x] = ((uint32_t)in[0] << r->var.red.offset) |
                 ((uint32_t)in[1] << r->var.green.offset) |
                 ((uint32_t)in[2] << r->var.blue.offset) | alpha;
        in += 3;
      }
    }
    return;
  }
  for (y = 0; y < GGFE_H; y++) {
    const unsigned char *in = rgb + (size_t)y * GGFE_W * 3;
    for (x = 0; x < GGFE_W; x++) {
      plumos_fbdev_put_pixel(r, x, y,
                             plumos_fbdev_pack_color(r, in[0], in[1], in[2]));
      in += 3;
    }
  }
}

/* Pick the joypad by capability rather than by a hard-coded node: the
 * controller map names event2, but nothing guarantees enumeration order. */
static int ggfe_open_input(void) {
  const char *forced = getenv("PLUMOS_INPUT_EVENT");
  char path[64];
  int i;

  if (forced && forced[0]) {
    return open(forced, O_RDONLY | O_NONBLOCK | O_CLOEXEC);
  }
  for (i = 0; i < 16; i++) {
    unsigned long bits[(KEY_MAX + 1) / (8 * sizeof(unsigned long)) + 1];
    int fd;
    snprintf(path, sizeof(path), "/dev/input/event%d", i);
    fd = open(path, O_RDONLY | O_NONBLOCK | O_CLOEXEC);
    if (fd < 0) {
      continue;
    }
    memset(bits, 0, sizeof(bits));
    if (ioctl(fd, EVIOCGBIT(EV_KEY, sizeof(bits)), bits) >= 0) {
      int have_south = (bits[BTN_SOUTH / (8 * sizeof(unsigned long))] >>
                        (BTN_SOUTH % (8 * sizeof(unsigned long)))) & 1UL;
      int have_left = (bits[BTN_DPAD_LEFT / (8 * sizeof(unsigned long))] >>
                       (BTN_DPAD_LEFT % (8 * sizeof(unsigned long)))) & 1UL;
      if (have_south && have_left) {
        return fd;
      }
    }
    close(fd);
  }
  return -1;
}

static void ggfe_log(struct ggfe_app *app, const char *fmt, ...) {
  char line[512];
  va_list ap;
  int n;

  if (app->log_fd < 0) {
    return;
  }
  va_start(ap, fmt);
  n = vsnprintf(line, sizeof(line), fmt, ap);
  va_end(ap);
  if (n > 0) {
    ssize_t written = write(app->log_fd, line, (size_t)n);
    (void)written;
  }
}

static void ggfe_terminate_group(pid_t pgid) {
  int attempt;
  if (pgid <= 0 || kill(-pgid, 0) != 0) {
    return;
  }
  (void)kill(-pgid, SIGTERM);
  for (attempt = 0; attempt < 10; attempt++) {
    if (kill(-pgid, 0) != 0 && errno == ESRCH) {
      return;
    }
    usleep(50000);
  }
  (void)kill(-pgid, SIGKILL);
}

/*
 * Hand the panel to the launcher and take it back afterwards.
 *
 * This is the same shape the stock frontend uses: release the renderer before
 * the child starts so DRM master is free, run the child in its own process
 * group, then clean up any descendants a launcher leaves behind before
 * reacquiring.  GGFE holds no GL context, so there is nothing else to give up.
 */
static int ggfe_launch_rom(struct ggfe_app *app,
                           struct plumos_fbdev_renderer *renderer,
                           const struct ggfe_entry *entry) {
  struct ggfe_launch_choice choice;
  char resolver[PATH_MAX];
  char error[256];
  char *argv[8];
  int argc = 0;
  pid_t pid;
  int status = 0;

  if (!ggfe_choose_profile(&app->catalog, &app->cfg, &app->ggfe_overrides,
                           &app->plumos_overrides, entry->rel, &choice)) {
    ggfe_log(app, "ggfe_launch=no-profile rom=%s reason=%s\n", entry->rel,
             choice.source);
    return -1;
  }
  if (!join_path(resolver, sizeof(resolver), app->plumos_root,
                 app->cfg.resolver) ||
      !is_regular_file(resolver)) {
    ggfe_log(app, "ggfe_launch=missing-resolver path=%s\n", resolver);
    return -1;
  }
  ggfe_log(app, "ggfe_launch=start rom=%s profile=%s source=%s\n", entry->rel,
           choice.profile->id, choice.source);

  /* GGFE picked the profile; plumos-text-ui builds the command for whichever
   * runtime it names, validates the ROM and core paths, and records recent
   * and resume state.  The three runtimes disagree on calling convention, so
   * this is the one place that knowledge should live. */
  argv[argc++] = resolver;
  argv[argc++] = (char *)"launch";
  argv[argc++] = (char *)app->cfg.launch_system;
  argv[argc++] = (char *)entry->rel;
  argv[argc++] = (char *)"--profile";
  argv[argc++] = (char *)choice.profile->id;
  argv[argc++] = (char *)"--execute";
  argv[argc] = NULL;

  plumos_fbdev_renderer_shutdown(renderer);

  pid = fork();
  if (pid == 0) {
    if (setpgid(0, 0) != 0) {
      _exit(126);
    }
    execv(resolver, argv);
    _exit(127);
  }
  if (pid > 0) {
    (void)setpgid(pid, pid);
    while (waitpid(pid, &status, 0) < 0 && errno == EINTR) {
      continue;
    }
    ggfe_terminate_group(pid);
  }
  ggfe_log(app, "ggfe_launch=done status=%d\n", status);

  error[0] = '\0';
  if (!plumos_fbdev_renderer_init(renderer, getenv("PLUMOS_FB"), error,
                                  sizeof(error))) {
    ggfe_log(app, "ggfe_renderer=reacquire-failed error=%s\n", error);
    return -1;
  }
  return status;
}

/* Whether pressing A on this cartridge can do anything.  Checked before the
 * insert animation starts, so a game with no runnable core never plays a
 * launch sequence that would end in nothing. */
static int ggfe_can_launch(struct ggfe_app *app, const struct ggfe_entry *entry,
                           char *why, size_t why_size) {
  struct ggfe_launch_choice choice;
  if (ggfe_choose_profile(&app->catalog, &app->cfg, &app->ggfe_overrides,
                          &app->plumos_overrides, entry->rel, &choice)) {
    return 1;
  }
  if (app->catalog.profile_count > 0) {
    copy_string(why, why_size, app->catalog.profiles[0].reason);
  } else {
    copy_string(why, why_size, "no launch profile listed for this system");
  }
  return 0;
}

static long long ggfe_now_ms(void) {
  struct timespec ts;
  if (clock_gettime(CLOCK_MONOTONIC, &ts) != 0) {
    return 0;
  }
  return (long long)ts.tv_sec * 1000LL + ts.tv_nsec / 1000000LL;
}

static long long ggfe_now_us(void) {
  struct timespec ts;
  if (clock_gettime(CLOCK_MONOTONIC, &ts) != 0) {
    return 0;
  }
  return (long long)ts.tv_sec * 1000000LL + ts.tv_nsec / 1000LL;
}

/* Match plumOS gallery motion: one time-based smoothstep is allowed to finish,
 * while one further direction press is queued behind it.  This keeps a held
 * or rapidly tapped D-pad from snapping the interpolation origin repeatedly. */
struct ggfe_scroll_state {
  int target;
  int from;
  int to;
  int active;
  int pending_target;
  int pending_active;
  long long start_ms;
};

static void ggfe_scroll_request(struct ggfe_app *app,
                                struct ggfe_scroll_state *scroll, int delta) {
  int next;

  if (!app || !scroll || delta == 0) {
    return;
  }
  next = scroll->target + (delta < 0 ? -1 : 1);
  if (next < 0 || next >= app->entry_count) {
    return;
  }
  ggfe_warm_labels(app, next);
  if (scroll->active) {
    scroll->pending_target = next;
    scroll->pending_active = 1;
    ggfe_log(app, "ggfe_scroll=queued target=%d\n", next);
    return;
  }
  scroll->from = scroll->target;
  scroll->target = next;
  scroll->to = next;
  scroll->start_ms = ggfe_now_ms();
  scroll->active = 1;
  ggfe_log(app, "ggfe_scroll=start from=%d to=%d duration_ms=%d\n",
           scroll->from, scroll->to, GGFE_SCROLL_MS);
}

static float ggfe_scroll_position(struct ggfe_app *app,
                                  struct ggfe_scroll_state *scroll,
                                  long long now_ms) {
  long long elapsed;
  float progress;

  if (!scroll->active) {
    return (float)scroll->target;
  }
  elapsed = now_ms - scroll->start_ms;
  if (elapsed >= GGFE_SCROLL_MS) {
    scroll->active = 0;
    if (scroll->pending_active) {
      int next = scroll->pending_target;
      scroll->pending_active = 0;
      scroll->from = scroll->target;
      scroll->target = next;
      scroll->to = next;
      scroll->start_ms = now_ms;
      scroll->active = 1;
      ggfe_log(app, "ggfe_scroll=start from=%d to=%d duration_ms=%d queued=1\n",
               scroll->from, scroll->to, GGFE_SCROLL_MS);
      return (float)scroll->from;
    }
    return (float)scroll->target;
  }
  if (elapsed <= 0) {
    return (float)scroll->from;
  }
  progress = (float)elapsed / (float)GGFE_SCROLL_MS;
  return ggfe_lerp((float)scroll->from, (float)scroll->to,
                   ggfe_ease_in_out(progress));
}

int main(int argc, char **argv) {
  struct ggfe_app app;
  struct ggfe_frame frame;
  struct plumos_fbdev_renderer renderer;
  unsigned char *background;
  char error[256];
  const char *plumos_root = getenv("PLUMOS_ROOT");
  const char *sdcard_root = getenv("PLUMOS_SDCARD_ROOT");
  char log_path[PATH_MAX];
  int input_fd;
  struct ggfe_scroll_state scroll;
  float launch_t = -1.0f;
  long long last_ms;
  long long last_present_ms;
  long long stats_start_ms;
  long long stats_max_frame_ms = 0;
  long long stats_compose_us = 0;
  long long stats_blit_us = 0;
  long long stats_present_us = 0;
  long long stats_max_compose_us = 0;
  long long stats_max_blit_us = 0;
  long long stats_max_present_us = 0;
  unsigned long stats_frames = 0;
  unsigned long stats_slow_frames = 0;
  int running = 1;

  (void)argc;
  (void)argv;
  if (!plumos_root || !plumos_root[0]) {
    plumos_root = "/storage/plumos";
  }
  if (!sdcard_root || !sdcard_root[0]) {
    sdcard_root = "/storage";
  }
  if (!ggfe_app_init(&app, plumos_root, sdcard_root)) {
    fprintf(stderr, "ggfe: init failed\n");
    return 1;
  }
  if (join_path(log_path, sizeof(log_path), plumos_root, "logs/ggfe.log")) {
    app.log_fd = open(log_path, O_WRONLY | O_CREAT | O_APPEND | O_CLOEXEC, 0644);
  }
  ggfe_log(&app, "ggfe_start=ok roms=%d\n", app.entry_count);
  if (app.entry_count == 0) {
    ggfe_log(&app, "ggfe_start=no-roms root=%s\n", app.roots.roms);
    ggfe_app_free(&app);
    return 0;
  }

  error[0] = '\0';
  if (!plumos_fbdev_renderer_init(&renderer, getenv("PLUMOS_FB"), error,
                                  sizeof(error))) {
    ggfe_log(&app, "ggfe_renderer=init-failed error=%s\n", error);
    fprintf(stderr, "ggfe: renderer init failed: %s\n", error);
    ggfe_app_free(&app);
    return 1;
  }
  ggfe_log(&app,
           "ggfe_renderer=ready backend=%s xres=%u yres=%u bpp=%d "
           "shadow=%d double_buffer=%d\n",
#ifdef PLUMOS_FBDEV_ENABLE_DRM
           renderer.drm_active ? "drm" : "fbdev",
#else
           "fbdev",
#endif
           renderer.var.xres, renderer.var.yres, renderer.bytes_per_pixel * 8,
           renderer.shadow != NULL, renderer.double_buffer);
  input_fd = ggfe_open_input();
  if (input_fd < 0) {
    ggfe_log(&app, "ggfe_input=not-found\n");
  }

  background = (unsigned char *)malloc((size_t)GGFE_W * GGFE_H * 3);
  if (!background) {
    return 1;
  }
  ggfe_background_build(background);
  last_ms = ggfe_now_ms();
  last_present_ms = last_ms;
  stats_start_ms = last_ms;
  memset(&scroll, 0, sizeof(scroll));

  while (running) {
    long long now = ggfe_now_ms();
    float dt = (float)(now - last_ms) / 1000.0f;
    struct pollfd pfd;
    float pos;
    int present_ok;
    long long compose_start_us;
    long long compose_end_us;
    long long blit_end_us;
    long long present_end_us;
    long long compose_us;
    long long blit_us;
    long long present_us;

    last_ms = now;
    if (dt > 0.1f) {
      dt = 0.1f; /* a launch or a stall must not fling the animation */
    }

    if (input_fd >= 0) {
      pfd.fd = input_fd;
      pfd.events = POLLIN;
      while (poll(&pfd, 1, 0) > 0 && (pfd.revents & POLLIN)) {
        struct input_event ev;
        if (read(input_fd, &ev, sizeof(ev)) != (ssize_t)sizeof(ev)) {
          break;
        }
        if (ev.type != EV_KEY || ev.value != 1) {
          continue;
        }
        if (launch_t >= 0.0f) {
          continue; /* the launch sequence owns input until it completes */
        }
        switch (ev.code) {
          case BTN_DPAD_LEFT:
          case BTN_DPAD_UP:
            ggfe_scroll_request(&app, &scroll, -1);
            break;
          case BTN_DPAD_RIGHT:
          case BTN_DPAD_DOWN:
            ggfe_scroll_request(&app, &scroll, 1);
            break;
          case BTN_EAST: /* physical A on Bubble */
          {
            char why[96];
            ggfe_log(&app, "ggfe_input=launch code=%u physical=A target=%d\n",
                     (unsigned int)ev.code, scroll.target);
            if (ggfe_can_launch(&app, &app.entries[scroll.target], why,
                                sizeof(why))) {
              launch_t = 0.0f;
            } else {
              ggfe_log(&app, "ggfe_launch=unavailable rom=%s reason=%s\n",
                       app.entries[scroll.target].rel, why);
            }
            break;
          }
          case BTN_SOUTH: /* physical B on Bubble */
          case BTN_START:
            ggfe_log(&app, "ggfe_input=exit code=%u physical=%s\n",
                     (unsigned int)ev.code,
                     ev.code == BTN_SOUTH ? "B" : "START");
            running = 0;
            break;
          default:
            break;
        }
      }
    }

    pos = ggfe_scroll_position(&app, &scroll, ggfe_now_ms());

    if (launch_t >= 0.0f) {
      ggfe_launch_frame(launch_t, (float)scroll.target, &frame);
      launch_t += dt;
    } else {
      ggfe_browse_frame(pos, &frame);
    }

    compose_start_us = ggfe_now_us();
    ggfe_compose(&app, &frame, background);
    compose_end_us = ggfe_now_us();
    ggfe_blit_panel(&renderer, app.target.rgb);
    blit_end_us = ggfe_now_us();
    present_ok = plumos_fbdev_present(&renderer);
    present_end_us = ggfe_now_us();
    compose_us = compose_end_us - compose_start_us;
    blit_us = blit_end_us - compose_end_us;
    present_us = present_end_us - blit_end_us;
    stats_compose_us += compose_us;
    stats_blit_us += blit_us;
    stats_present_us += present_us;
    if (compose_us > stats_max_compose_us) stats_max_compose_us = compose_us;
    if (blit_us > stats_max_blit_us) stats_max_blit_us = blit_us;
    if (present_us > stats_max_present_us) stats_max_present_us = present_us;

    if (present_ok) {
      long long present_ms = ggfe_now_ms();
      long long frame_ms = present_ms - last_present_ms;
      long long stats_elapsed;

      last_present_ms = present_ms;
      stats_frames++;
      if (frame_ms > stats_max_frame_ms) {
        stats_max_frame_ms = frame_ms;
      }
      if (frame_ms > 20) {
        stats_slow_frames++;
      }
      stats_elapsed = present_ms - stats_start_ms;
      if (stats_elapsed >= 1000) {
        ggfe_log(&app,
                 "ggfe_frames=fps=%.2f frames=%lu elapsed_ms=%lld "
                 "max_frame_ms=%lld slow_frames=%lu "
                 "compose_us=%lld/%lld blit_us=%lld/%lld "
                 "present_us=%lld/%lld\n",
                 1000.0 * (double)stats_frames / (double)stats_elapsed,
                 stats_frames, stats_elapsed, stats_max_frame_ms,
                 stats_slow_frames, stats_compose_us / (long long)stats_frames,
                 stats_max_compose_us, stats_blit_us / (long long)stats_frames,
                 stats_max_blit_us, stats_present_us / (long long)stats_frames,
                 stats_max_present_us);
        stats_start_ms = present_ms;
        stats_frames = 0;
        stats_slow_frames = 0;
        stats_max_frame_ms = 0;
        stats_compose_us = 0;
        stats_blit_us = 0;
        stats_present_us = 0;
        stats_max_compose_us = 0;
        stats_max_blit_us = 0;
        stats_max_present_us = 0;
      }
    }

    if (launch_t > GGFE_LAUNCH_END) {
      /* RetroArch exits with SELECT+START on Bubble.  Do not keep GGFE's
       * evdev queue open while the child owns the controls, or that START
       * key-down is delivered after return and immediately exits GGFE too. */
      if (input_fd >= 0) {
        close(input_fd);
        input_fd = -1;
      }
      ggfe_launch_rom(&app, &renderer, &app.entries[scroll.target]);
      input_fd = ggfe_open_input();
      if (input_fd < 0) {
        ggfe_log(&app, "ggfe_input=reopen-failed\n");
      } else {
        ggfe_log(&app, "ggfe_input=reopened-after-launch\n");
      }
      launch_t = -1.0f;
      last_ms = ggfe_now_ms();
      last_present_ms = last_ms;
      stats_start_ms = last_ms;
      stats_frames = 0;
      stats_slow_frames = 0;
      stats_max_frame_ms = 0;
      stats_compose_us = 0;
      stats_blit_us = 0;
      stats_present_us = 0;
      stats_max_compose_us = 0;
      stats_max_blit_us = 0;
      stats_max_present_us = 0;
    }

    {
      long long spent = ggfe_now_ms() - now;
      if (spent < 16) {
        usleep((useconds_t)((16 - spent) * 1000));
      }
    }
  }

  ggfe_log(&app, "ggfe_exit=ok\n");
  if (input_fd >= 0) {
    close(input_fd);
  }
  plumos_fbdev_renderer_shutdown(&renderer);
  if (app.log_fd >= 0) {
    close(app.log_fd);
  }
  free(background);
  ggfe_app_free(&app);
  return 0;
}
#endif /* !PLUMOS_GGFE_HOST */

#ifdef PLUMOS_GGFE_HOST
static int ggfe_write_png(const char *path, const unsigned char *rgb, int w,
                          int h) {
  FILE *f = fopen(path, "wb");
  png_structp png;
  png_infop info;
  int y;

  if (!f) {
    return 0;
  }
  png = png_create_write_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
  info = png_create_info_struct(png);
  if (setjmp(png_jmpbuf(png))) {
    png_destroy_write_struct(&png, &info);
    fclose(f);
    return 0;
  }
  png_init_io(png, f);
  png_set_IHDR(png, info, (png_uint_32)w, (png_uint_32)h, 8, PNG_COLOR_TYPE_RGB,
               PNG_INTERLACE_NONE, PNG_COMPRESSION_TYPE_DEFAULT,
               PNG_FILTER_TYPE_DEFAULT);
  png_write_info(png, info);
  for (y = 0; y < h; y++) {
    png_write_row(png, (png_bytep)(rgb + (size_t)y * (size_t)w * 3));
  }
  png_write_end(png, NULL);
  png_destroy_write_struct(&png, &info);
  fclose(f);
  return 1;
}

int main(int argc, char **argv) {
  struct ggfe_app app;
  struct ggfe_frame frame;
  unsigned char *background;
  const char *plumos_root = argc > 1 ? argv[1] : "package/frontend-bubble/plumos";
  const char *sdcard_root = argc > 2 ? argv[2] : "demo";
  const char *out_dir = argc > 3 ? argv[3] : "/tmp";
  char path[PATH_MAX];
  static const struct {
    const char *name;
    float pos;
    float t;
  } shots[] = {{"g-library", 2.0f, -1.0f},   {"g-browse", 2.5f, -1.0f},
               {"g-open", 2.0f, 0.14f},      {"g-hop", 2.0f, 0.50f},
               {"g-insert", 2.0f, 1.02f},    {"g-seated", 2.0f, 1.28f}};
  size_t s;
  int i;

  if (!ggfe_app_init(&app, plumos_root, sdcard_root)) {
    fprintf(stderr, "ggfe: init failed\n");
    return 1;
  }
  printf("scanned %d ROMs, cartridge %d tris, label tri %d/%d\n",
         app.entry_count, app.cart.count, app.label_tri[0], app.label_tri[1]);
  for (i = 0; i < app.entry_count; i++) {
    printf("  %-40s %s\n", app.entries[i].title,
           app.entries[i].art[0] ? app.entries[i].rule : "(no artwork)");
  }
  printf("\nlaunch profiles for %s (default %s):\n", app.catalog.system_id,
         app.catalog.default_profile[0] ? app.catalog.default_profile : "-");
  for (i = 0; i < app.catalog.profile_count; i++) {
    printf("  %-34s %s\n", app.catalog.profiles[i].id,
           app.catalog.profiles[i].available ? "available"
                                             : app.catalog.profiles[i].reason);
  }
  printf("\nresolved launch:\n");
  for (i = 0; i < app.entry_count; i++) {
    struct ggfe_launch_choice choice;
    int ok = ggfe_choose_profile(&app.catalog, &app.cfg, &app.ggfe_overrides,
                                 &app.plumos_overrides, app.entries[i].rel,
                                 &choice);
    printf("  %-40s %-30s %s\n", app.entries[i].title,
           ok ? choice.profile->id : "(cannot launch)", choice.source);
  }
  if (app.entry_count == 0) {
    fprintf(stderr, "ggfe: no ROMs under %s\n", app.roots.roms);
    return 1;
  }

  background = (unsigned char *)malloc((size_t)GGFE_W * GGFE_H * 3);
  ggfe_background_build(background);

  for (s = 0; s < sizeof(shots) / sizeof(shots[0]); s++) {
    float pos = shots[s].pos;
    if (pos > (float)(app.entry_count - 1)) {
      pos = (float)(app.entry_count - 1);
    }
    if (shots[s].t < 0.0f) {
      ggfe_browse_frame(pos, &frame);
    } else {
      ggfe_launch_frame(shots[s].t, pos, &frame);
    }
    ggfe_compose(&app, &frame, background);
    snprintf(path, sizeof(path), "%s/%s.png", out_dir, shots[s].name);
    if (!ggfe_write_png(path, app.target.rgb, GGFE_W, GGFE_H)) {
      fprintf(stderr, "ggfe: cannot write %s\n", path);
      return 1;
    }
    printf("wrote %s\n", path);
  }

#ifdef GGFE_PROFILE
  {
    const int bench_frames = 300;
    long long start_us, total_us;
    int fr, st;

    memset(ggfe_stage_us, 0, sizeof(ggfe_stage_us));
    start_us = ggfe_profile_now_us();
    for (fr = 0; fr < bench_frames; fr++) {
      /* a continuous scroll: the state the frame rate complaint came from */
      float k = (float)fr / (float)bench_frames;
      float scroll = 1.0f + k * (float)(app.entry_count - 1);
      ggfe_browse_frame(scroll, &frame);
      ggfe_compose(&app, &frame, background);
    }
    total_us = ggfe_profile_now_us() - start_us;
    printf("\nbench: %d frames, %.2f ms/frame (%.1f fps equivalent)\n",
           bench_frames, (double)total_us / bench_frames / 1000.0,
           1000000.0 * bench_frames / (double)total_us);
    for (st = 0; st < GGFE_STAGE_COUNT; st++) {
      printf("  %-14s %7.3f ms/frame  %5.1f%%\n", ggfe_stage_name[st],
             (double)ggfe_stage_us[st] / bench_frames / 1000.0,
             100.0 * (double)ggfe_stage_us[st] / (double)total_us);
    }
  }
#endif

  free(background);
  ggfe_app_free(&app);
  return 0;
}
#endif /* PLUMOS_GGFE_HOST */
