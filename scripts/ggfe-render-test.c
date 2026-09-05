/*
 * Host-side check for the GGFE software 3D path.
 *
 * Renders the cartridge with no framebuffer, no DRM and no device, and writes
 * PNGs, so the projection, depth test, shading and mesh construction can be
 * verified on a build machine before anything is deployed.
 *
 *   gcc -std=gnu99 -O2 scripts/ggfe-render-test.c -o ggfe-render-test \
 *       -lm $(pkg-config --cflags --libs libpng)
 *   ./ggfe-render-test <label.png> <out-dir>
 */

#include <png.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "../src/frontend/plumos_ggfe_model.h"

#define W 640
#define H 480

static int load_png_rgb(const char *path, unsigned char **out, int *w, int *h) {
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
  *w = (int)png_get_image_width(png, info);
  *h = (int)png_get_image_height(png, info);
  png_set_strip_16(png);
  png_set_palette_to_rgb(png);
  png_set_expand_gray_1_2_4_to_8(png);
  png_set_gray_to_rgb(png);
  png_set_strip_alpha(png);
  png_read_update_info(png, info);

  *out = (unsigned char *)malloc((size_t)*w * (size_t)*h * 3);
  rows = (png_bytep *)malloc(sizeof(png_bytep) * (size_t)*h);
  for (y = 0; y < *h; y++) {
    rows[y] = *out + (size_t)y * (size_t)*w * 3;
  }
  png_read_image(png, rows);
  free(rows);
  png_destroy_read_struct(&png, &info, NULL);
  fclose(f);
  return 1;
}

static int write_png_rgb(const char *path, const unsigned char *rgb, int w,
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

static void clear_background(struct cart3d_target *t) {
  int x, y;
  for (y = 0; y < t->height; y++) {
    float k = (float)y / (float)(t->height - 1);
    unsigned char r = (unsigned char)(11.0f * (1.0f - k) + 3.0f * k);
    unsigned char g = (unsigned char)(17.0f * (1.0f - k) + 4.0f * k);
    unsigned char b = (unsigned char)(19.0f * (1.0f - k) + 4.0f * k);
    for (x = 0; x < t->width; x++) {
      unsigned char *p = t->rgb + ((size_t)y * (size_t)t->width + (size_t)x) * 3;
      p[0] = r;
      p[1] = g;
      p[2] = b;
    }
  }
  cart3d_target_clear_depth(t);
}

int main(int argc, char **argv) {
  const char *label_path = argc > 1 ? argv[1] : "/tmp/ggfe-label.png";
  const char *out_dir = argc > 2 ? argv[2] : "/tmp";
  unsigned char *label_rgb = NULL;
  int label_w = 0, label_h = 0;
  struct cart3d_tex label;
  struct cart3d_mesh cart, tray, lid;
  struct cart3d_camera cam;
  struct cart3d_target target;
  struct cart3d_draw *draws;
  float case_h = 0.0f;
  static const struct {
    const char *name;
    float ry, rx;
    int cased;
  } views[] = {{"c-front", 0.0f, 0.0f, 0},
               {"c-3q", -34.0f, 6.0f, 0},
               {"c-side", -72.0f, 4.0f, 0},
               {"c-cased", -20.0f, 6.0f, 1}};
  size_t v;

  if (!load_png_rgb(label_path, &label_rgb, &label_w, &label_h)) {
    fprintf(stderr, "ggfe-render-test: cannot read %s\n", label_path);
    return 1;
  }
  label.rgb = label_rgb;
  label.width = label_w;
  label.height = label_h;
  label.filter_nearest = 0;

  if (!ggfe_build_cartridge(&cart, &label) ||
      !ggfe_build_case(&tray, &lid, &case_h)) {
    fprintf(stderr, "ggfe-render-test: mesh build failed\n");
    return 1;
  }
  printf("triangles: cartridge=%d tray=%d lid=%d\n", cart.count, tray.count,
         lid.count);

  cart3d_camera_init(&cam, W, H);
  target.width = W;
  target.height = H;
  target.rgb = (unsigned char *)malloc((size_t)W * H * 3);
  target.depth = (float *)malloc((size_t)W * H * sizeof(float));
  draws = (struct cart3d_draw *)malloc(sizeof(struct cart3d_draw) * 4096);

  for (v = 0; v < sizeof(views) / sizeof(views[0]); v++) {
    float trans[16], rot[16], model[16], tmp[16];
    char path[512];
    int n = 0;
    const float deg = 3.14159265358979f / 180.0f;

    clear_background(&target);
    cart3d_translate(trans, 0.0f, 4.0f, -CART3D_CAM_DIST + 22.0f +
                                            (views[v].cased ? -20.0f : 0.0f));
    cart3d_rotate(rot, views[v].rx * deg, views[v].ry * deg, 0.0f);
    cart3d_mul(trans, rot, model);

    if (views[v].cased) {
      float shift[16];
      cart3d_translate(shift, 0.0f, 0.0f, GGFE_CASE_Z);
      cart3d_mul(model, shift, tmp);
      n = cart3d_emit(draws, n, 4096, &cart, tmp, &cam, 1.0f, 1.0f);
    } else {
      n = cart3d_emit(draws, n, 4096, &cart, model, &cam, 1.0f, 1.0f);
    }
    cart3d_draw_list(&target, draws, n, 1);

    if (views[v].cased) {
      int g = 0;
      struct cart3d_draw *glass = draws + n;
      g = cart3d_emit(glass, g, 2048, &tray, model, &cam, 1.0f,
                      GGFE_CASE_ALPHA);
      g = cart3d_emit(glass, g, 2048, &lid, model, &cam, 1.0f, GGFE_CASE_ALPHA);
      cart3d_sort(glass, g);
      cart3d_draw_list(&target, glass, g, 0);
    }

    snprintf(path, sizeof(path), "%s/%s.png", out_dir, views[v].name);
    if (!write_png_rgb(path, target.rgb, W, H)) {
      fprintf(stderr, "ggfe-render-test: cannot write %s\n", path);
      return 1;
    }
    printf("wrote %s\n", path);
  }

  free(draws);
  free(target.rgb);
  free(target.depth);
  cart3d_mesh_free(&cart);
  cart3d_mesh_free(&tray);
  cart3d_mesh_free(&lid);
  free(label_rgb);
  return 0;
}
