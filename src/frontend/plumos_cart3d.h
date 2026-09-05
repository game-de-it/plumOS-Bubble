#ifndef PLUMOS_CART3D_H
#define PLUMOS_CART3D_H

/*
 * Software 3D for the Game Gear frontend (GGFE).
 *
 * The Bubble frontend already owns a CPU renderer that composes into a RAM
 * shadow buffer and memcpy's it into a DRM dumb buffer.  This adds the small
 * amount of 3D needed to draw cartridges into that same surface, so GGFE
 * needs no GL, no EGL and no /dev/mali0, and never competes with RetroArch
 * for the GPU or for DRM master.
 *
 *   model space (mm)
 *     -> 4x4 model transform
 *     -> perspective projection, 1/w kept for correct interpolation
 *     -> triangle raster with a 1/w depth buffer
 *     -> optional translucent pass, sorted far to near, depth test on and
 *        depth writes off
 *
 * The target is a plain RGB byte buffer so the whole path can be rendered and
 * inspected on a host with no hardware.
 */

#include <math.h>
#include <stdlib.h>
#include <string.h>

#ifndef CART3D_MAX_TRIS
#define CART3D_MAX_TRIS 512
#endif

struct cart3d_target {
  unsigned char *rgb; /* width * height * 3 */
  float *depth;       /* width * height, holds 1/w; larger is nearer */
  int width;
  int height;
};

/* RGB8 texture.  filter_nearest keeps native captures crisp on upscale. */
struct cart3d_tex {
  const unsigned char *rgb;
  int width;
  int height;
  int filter_nearest;
};

struct cart3d_tri {
  float v[3][3];
  float uv[3][2];
  unsigned char colour[3];
  const struct cart3d_tex *tex;
  float alpha;
  int gloss;
};

struct cart3d_mesh {
  struct cart3d_tri *tris;
  int count;
  int capacity;
};

/* One projected, lit triangle ready to rasterise. */
struct cart3d_draw {
  float s[3][3]; /* screen x, screen y, 1/w */
  float uv[3][2];
  const struct cart3d_tex *tex;
  unsigned char colour[3];
  float shade;
  float alpha;
  float rim;
  float depth;
  int gloss;
};

/* ------------------------------------------------------------------ */
/* camera                                                             */
/* ------------------------------------------------------------------ */

#ifndef CART3D_FOV_DEG
#define CART3D_FOV_DEG 40.0f
#endif
#ifndef CART3D_CAM_DIST
#define CART3D_CAM_DIST 190.0f
#endif

struct cart3d_camera {
  float focal;
  float aspect;
  int width;
  int height;
};

static void cart3d_camera_init(struct cart3d_camera *c, int width, int height) {
  c->focal = 1.0f / tanf(CART3D_FOV_DEG * 3.14159265358979f / 360.0f);
  c->aspect = (float)width / (float)height;
  c->width = width;
  c->height = height;
}

static void cart3d_project(const struct cart3d_camera *c, const float p[3],
                           float out[3]) {
  float w = -p[2];
  if (w < 1e-3f) {
    w = 1e-3f;
  }
  out[0] = (((c->focal / c->aspect) * p[0] / w) * 0.5f + 0.5f) * (float)c->width;
  out[1] = (1.0f - ((c->focal * p[1] / w) * 0.5f + 0.5f)) * (float)c->height;
  out[2] = 1.0f / w;
}

/* ------------------------------------------------------------------ */
/* 4x4 matrices, row major                                            */
/* ------------------------------------------------------------------ */

static void cart3d_identity(float m[16]) {
  memset(m, 0, sizeof(float) * 16);
  m[0] = m[5] = m[10] = m[15] = 1.0f;
}

static void cart3d_mul(const float a[16], const float b[16], float out[16]) {
  float t[16];
  int i, j, k;
  for (i = 0; i < 4; i++) {
    for (j = 0; j < 4; j++) {
      float s = 0.0f;
      for (k = 0; k < 4; k++) {
        s += a[i * 4 + k] * b[k * 4 + j];
      }
      t[i * 4 + j] = s;
    }
  }
  memcpy(out, t, sizeof(t));
}

static void cart3d_translate(float m[16], float x, float y, float z) {
  cart3d_identity(m);
  m[3] = x;
  m[7] = y;
  m[11] = z;
}

static void cart3d_scale(float m[16], float x, float y, float z) {
  cart3d_identity(m);
  m[0] = x;
  m[5] = y;
  m[10] = z;
}

static void cart3d_rotate(float m[16], float rx, float ry, float rz) {
  float mx[16], my[16], mz[16], tmp[16];
  float cx = cosf(rx), sx = sinf(rx);
  float cy = cosf(ry), sy = sinf(ry);
  float cz = cosf(rz), sz = sinf(rz);
  cart3d_identity(mx);
  mx[5] = cx;  mx[6] = -sx; mx[9] = sx;  mx[10] = cx;
  cart3d_identity(my);
  my[0] = cy;  my[2] = sy;  my[8] = -sy; my[10] = cy;
  cart3d_identity(mz);
  mz[0] = cz;  mz[1] = -sz; mz[4] = sz;  mz[5] = cz;
  cart3d_mul(mz, my, tmp);
  cart3d_mul(tmp, mx, m);
}

static void cart3d_apply(const float m[16], const float v[3], float out[3]) {
  out[0] = m[0] * v[0] + m[1] * v[1] + m[2] * v[2] + m[3];
  out[1] = m[4] * v[0] + m[5] * v[1] + m[6] * v[2] + m[7];
  out[2] = m[8] * v[0] + m[9] * v[1] + m[10] * v[2] + m[11];
}

/* ------------------------------------------------------------------ */
/* mesh building                                                      */
/* ------------------------------------------------------------------ */

static int cart3d_mesh_init(struct cart3d_mesh *m, int capacity) {
  m->tris = (struct cart3d_tri *)calloc((size_t)capacity,
                                        sizeof(struct cart3d_tri));
  m->count = 0;
  m->capacity = m->tris ? capacity : 0;
  return m->tris != NULL;
}

static void cart3d_mesh_free(struct cart3d_mesh *m) {
  free(m->tris);
  m->tris = NULL;
  m->count = 0;
  m->capacity = 0;
}

static struct cart3d_tri *cart3d_mesh_next(struct cart3d_mesh *m) {
  struct cart3d_tri *t;
  if (m->count >= m->capacity) {
    return NULL;
  }
  t = &m->tris[m->count++];
  memset(t, 0, sizeof(*t));
  t->alpha = 1.0f;
  return t;
}

static void cart3d_add(struct cart3d_mesh *m, const float a[3], const float b[3],
                       const float c[3], const unsigned char colour[3],
                       float alpha) {
  struct cart3d_tri *t = cart3d_mesh_next(m);
  if (!t) {
    return;
  }
  memcpy(t->v[0], a, sizeof(float) * 3);
  memcpy(t->v[1], b, sizeof(float) * 3);
  memcpy(t->v[2], c, sizeof(float) * 3);
  memcpy(t->colour, colour, 3);
  t->alpha = alpha;
}

static void cart3d_add_tex(struct cart3d_mesh *m, const float a[3],
                           const float b[3], const float c[3],
                           const float uv[3][2], const struct cart3d_tex *tex,
                           int gloss) {
  struct cart3d_tri *t = cart3d_mesh_next(m);
  if (!t) {
    return;
  }
  memcpy(t->v[0], a, sizeof(float) * 3);
  memcpy(t->v[1], b, sizeof(float) * 3);
  memcpy(t->v[2], c, sizeof(float) * 3);
  memcpy(t->uv, uv, sizeof(float) * 6);
  t->tex = tex;
  t->gloss = gloss;
  t->colour[0] = t->colour[1] = t->colour[2] = 255;
}

/* Axis aligned quad on a constant-z plane, wound to face +Z. */
static void cart3d_quad(struct cart3d_mesh *m, float x0, float x1, float y0,
                        float y1, float z, const unsigned char colour[3],
                        float alpha) {
  float a[3], b[3], c[3], d[3];
  a[0] = x0; a[1] = y1; a[2] = z;
  b[0] = x0; b[1] = y0; b[2] = z;
  c[0] = x1; c[1] = y0; c[2] = z;
  d[0] = x1; d[1] = y1; d[2] = z;
  cart3d_add(m, a, b, c, colour, alpha);
  cart3d_add(m, a, c, d, colour, alpha);
}

/* Filled polygon on a constant-z plane, as a fan from its centroid.  Only
 * valid for outlines that are star shaped about that centroid; concave shapes
 * are built from several convex fills plus one wall along the real outline. */
static void cart3d_face(struct cart3d_mesh *m, const float (*pts)[2], int n,
                        float z, const unsigned char colour[3], int flip,
                        float alpha) {
  float cx = 0.0f, cy = 0.0f, ctr[3], a[3], b[3];
  int i;
  if (n < 3) {
    return;
  }
  for (i = 0; i < n; i++) {
    cx += pts[i][0];
    cy += pts[i][1];
  }
  ctr[0] = cx / (float)n;
  ctr[1] = cy / (float)n;
  ctr[2] = z;
  for (i = 0; i < n; i++) {
    const float *p0 = pts[i];
    const float *p1 = pts[(i + 1) % n];
    a[0] = p0[0]; a[1] = p0[1]; a[2] = z;
    b[0] = p1[0]; b[1] = p1[1]; b[2] = z;
    if (flip) {
      cart3d_add(m, ctr, b, a, colour, alpha);
    } else {
      cart3d_add(m, ctr, a, b, colour, alpha);
    }
  }
}

/* Extruded wall along a closed outline.  A counter-clockwise outline gives
 * outward normals, so reversing the point order turns a wall inward. */
static void cart3d_wall(struct cart3d_mesh *m, const float (*pts)[2], int n,
                        float z_front, float z_back,
                        const unsigned char colour[3], float alpha) {
  int i;
  for (i = 0; i < n; i++) {
    const float *p0 = pts[i];
    const float *p1 = pts[(i + 1) % n];
    float a[3], b[3], c[3], d[3];
    a[0] = p0[0]; a[1] = p0[1]; a[2] = z_front;
    b[0] = p0[0]; b[1] = p0[1]; b[2] = z_back;
    c[0] = p1[0]; c[1] = p1[1]; c[2] = z_back;
    d[0] = p1[0]; d[1] = p1[1]; d[2] = z_front;
    cart3d_add(m, a, b, c, colour, alpha);
    cart3d_add(m, a, c, d, colour, alpha);
  }
}

/* Annulus between two outlines of equal point count, facing +Z.  A solid fill
 * behind a recess would sit in front of it and the depth test would drop the
 * recess, so rings are how a moulding around a sunken panel is filled. */
static void cart3d_ring(struct cart3d_mesh *m, const float (*outer)[2],
                        const float (*inner)[2], int n, float z,
                        const unsigned char colour[3], float alpha) {
  int i;
  for (i = 0; i < n; i++) {
    float a[3], b[3], c[3], d[3];
    a[0] = outer[i][0]; a[1] = outer[i][1]; a[2] = z;
    b[0] = inner[i][0]; b[1] = inner[i][1]; b[2] = z;
    c[0] = inner[(i + 1) % n][0]; c[1] = inner[(i + 1) % n][1]; c[2] = z;
    d[0] = outer[(i + 1) % n][0]; d[1] = outer[(i + 1) % n][1]; d[2] = z;
    cart3d_add(m, a, c, b, colour, alpha);
    cart3d_add(m, a, d, c, colour, alpha);
  }
}

/* Rounded rectangle outline, counter-clockwise from the bottom right. */
static int cart3d_rounded_rect(float (*out)[2], int capacity, float x0,
                               float x1, float y0, float y1, float r_top,
                               float r_bot, int seg) {
  float hw = (x1 - x0) * 0.5f, hh = (y1 - y0) * 0.5f;
  float cx = (x0 + x1) * 0.5f, cy = (y0 + y1) * 0.5f;
  int n = 0, i;
  struct {
    float ox, oy, r, a0, a1;
  } arcs[4];
  int k;
  const float pi = 3.14159265358979f;

  if (r_top > hw) r_top = hw;
  if (r_top > hh) r_top = hh;
  if (r_bot > hw) r_bot = hw;
  if (r_bot > hh) r_bot = hh;

  arcs[0].ox = hw - r_bot; arcs[0].oy = -hh + r_bot; arcs[0].r = r_bot;
  arcs[0].a0 = -pi / 2.0f;  arcs[0].a1 = 0.0f;
  arcs[1].ox = hw - r_top;  arcs[1].oy = hh - r_top;  arcs[1].r = r_top;
  arcs[1].a0 = 0.0f;        arcs[1].a1 = pi / 2.0f;
  arcs[2].ox = -hw + r_top; arcs[2].oy = hh - r_top;  arcs[2].r = r_top;
  arcs[2].a0 = pi / 2.0f;   arcs[2].a1 = pi;
  arcs[3].ox = -hw + r_bot; arcs[3].oy = -hh + r_bot; arcs[3].r = r_bot;
  arcs[3].a0 = pi;          arcs[3].a1 = 3.0f * pi / 2.0f;

  for (k = 0; k < 4; k++) {
    for (i = 0; i <= seg; i++) {
      float a;
      if (n >= capacity) {
        return n;
      }
      a = arcs[k].a0 + (arcs[k].a1 - arcs[k].a0) * (float)i / (float)seg;
      out[n][0] = cx + arcs[k].ox + arcs[k].r * cosf(a);
      out[n][1] = cy + arcs[k].oy + arcs[k].r * sinf(a);
      n++;
    }
  }
  return n;
}

/* ------------------------------------------------------------------ */
/* lighting and emit                                                  */
/* ------------------------------------------------------------------ */

static const float cart3d_key[3] = {-0.30f, 0.45f, 0.84f};
static const float cart3d_fill[3] = {0.55f, -0.35f, 0.75f};

static void cart3d_normalise(float v[3]) {
  float l = sqrtf(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);
  if (l > 1e-9f) {
    v[0] /= l;
    v[1] /= l;
    v[2] /= l;
  }
}

/* Transform, light and project one mesh into the draw list. */
static int cart3d_emit(struct cart3d_draw *out, int count, int capacity,
                       const struct cart3d_mesh *mesh, const float model[16],
                       const struct cart3d_camera *cam, float tint,
                       float alpha) {
  int i, j;
  float key[3], fill[3];
  memcpy(key, cart3d_key, sizeof(key));
  memcpy(fill, cart3d_fill, sizeof(fill));
  cart3d_normalise(key);
  cart3d_normalise(fill);

  for (i = 0; i < mesh->count; i++) {
    const struct cart3d_tri *t = &mesh->tris[i];
    float p[3][3], e1[3], e2[3], n[3], len, kd, fd, shade;
    struct cart3d_draw *d;
    float tri_alpha = alpha * t->alpha;

    if (count >= capacity || tri_alpha <= 0.004f) {
      continue;
    }
    for (j = 0; j < 3; j++) {
      cart3d_apply(model, t->v[j], p[j]);
    }
    for (j = 0; j < 3; j++) {
      e1[j] = p[1][j] - p[0][j];
      e2[j] = p[2][j] - p[0][j];
    }
    n[0] = e1[1] * e2[2] - e1[2] * e2[1];
    n[1] = e1[2] * e2[0] - e1[0] * e2[2];
    n[2] = e1[0] * e2[1] - e1[1] * e2[0];
    len = sqrtf(n[0] * n[0] + n[1] * n[1] + n[2] * n[2]);
    if (len < 1e-9f) {
      continue;
    }
    n[0] /= len; n[1] /= len; n[2] /= len;

    kd = n[0] * key[0] + n[1] * key[1] + n[2] * key[2];
    fd = n[0] * fill[0] + n[1] * fill[1] + n[2] * fill[2];
    if (kd < 0.0f) kd = 0.0f;
    if (fd < 0.0f) fd = 0.0f;
    shade = 0.30f + 0.62f * kd + 0.26f * fd;

    d = &out[count++];
    memset(d, 0, sizeof(*d));
    for (j = 0; j < 3; j++) {
      cart3d_project(cam, p[j], d->s[j]);
    }
    memcpy(d->uv, t->uv, sizeof(d->uv));
    memcpy(d->colour, t->colour, 3);
    d->tex = t->tex;
    d->gloss = t->gloss;
    d->shade = tint * shade;
    d->alpha = tri_alpha;
    d->depth = (d->s[0][2] + d->s[1][2] + d->s[2][2]) / 3.0f;
    /* Grazing angles brighten translucent plastic, as frosted edges do. */
    if (tri_alpha < 0.999f) {
      float f = 1.0f - fabsf(n[2]);
      d->rim = 30.0f * f * f;
    }
  }
  return count;
}

static int cart3d_depth_cmp(const void *a, const void *b) {
  float da = ((const struct cart3d_draw *)a)->depth;
  float db = ((const struct cart3d_draw *)b)->depth;
  return (da < db) ? -1 : (da > db) ? 1 : 0;
}

/* Far to near, for the translucent pass. */
static void cart3d_sort(struct cart3d_draw *draws, int count) {
  qsort(draws, (size_t)count, sizeof(struct cart3d_draw), cart3d_depth_cmp);
}

/* ------------------------------------------------------------------ */
/* raster                                                             */
/* ------------------------------------------------------------------ */

static void cart3d_sample(const struct cart3d_tex *tex, float u, float v,
                          float out[3]) {
  float fx, fy, tu, tv;
  int x0, y0, x1, y1;
  const unsigned char *p00, *p10, *p01, *p11;
  int i;

  tu = u * (float)(tex->width - 1);
  tv = v * (float)(tex->height - 1);
  if (tu < 0.0f) tu = 0.0f;
  if (tv < 0.0f) tv = 0.0f;
  if (tu > (float)(tex->width - 1)) tu = (float)(tex->width - 1);
  if (tv > (float)(tex->height - 1)) tv = (float)(tex->height - 1);

  if (tex->filter_nearest) {
    x0 = (int)(tu + 0.5f);
    y0 = (int)(tv + 0.5f);
    p00 = tex->rgb + ((size_t)y0 * (size_t)tex->width + (size_t)x0) * 3;
    out[0] = p00[0];
    out[1] = p00[1];
    out[2] = p00[2];
    return;
  }

  x0 = (int)tu;
  y0 = (int)tv;
  x1 = (x0 + 1 < tex->width) ? x0 + 1 : x0;
  y1 = (y0 + 1 < tex->height) ? y0 + 1 : y0;
  fx = tu - (float)x0;
  fy = tv - (float)y0;
  p00 = tex->rgb + ((size_t)y0 * (size_t)tex->width + (size_t)x0) * 3;
  p10 = tex->rgb + ((size_t)y0 * (size_t)tex->width + (size_t)x1) * 3;
  p01 = tex->rgb + ((size_t)y1 * (size_t)tex->width + (size_t)x0) * 3;
  p11 = tex->rgb + ((size_t)y1 * (size_t)tex->width + (size_t)x1) * 3;
  for (i = 0; i < 3; i++) {
    float a = (float)p00[i] + ((float)p10[i] - (float)p00[i]) * fx;
    float b = (float)p01[i] + ((float)p11[i] - (float)p01[i]) * fx;
    out[i] = a + (b - a) * fy;
  }
}

static void cart3d_raster(struct cart3d_target *t, const struct cart3d_draw *d,
                          int zwrite) {
  float x0 = d->s[0][0], y0 = d->s[0][1];
  float x1 = d->s[1][0], y1 = d->s[1][1];
  float x2 = d->s[2][0], y2 = d->s[2][1];
  float area = (x1 - x0) * (y2 - y0) - (x2 - x0) * (y1 - y0);
  float inv_area, dw0dx, dw1dx, dw2dx, dw0dy, dw1dy, dw2dy;
  float row0, row1, row2;
  int minx, maxx, miny, maxy, x, y;

  if (area >= -1e-6f) {
    return; /* back-facing or degenerate */
  }
  inv_area = 1.0f / area;

  minx = (int)floorf(fminf(x0, fminf(x1, x2)));
  maxx = (int)ceilf(fmaxf(x0, fmaxf(x1, x2)));
  miny = (int)floorf(fminf(y0, fminf(y1, y2)));
  maxy = (int)ceilf(fmaxf(y0, fmaxf(y1, y2)));
  if (minx < 0) minx = 0;
  if (miny < 0) miny = 0;
  if (maxx > t->width - 1) maxx = t->width - 1;
  if (maxy > t->height - 1) maxy = t->height - 1;
  if (minx > maxx || miny > maxy) {
    return;
  }

  dw0dx = -(y2 - y1);
  dw1dx = -(y0 - y2);
  dw2dx = -(y1 - y0);
  dw0dy = (x2 - x1);
  dw1dy = (x0 - x2);
  dw2dy = (x1 - x0);

  {
    float px = (float)minx + 0.5f, py = (float)miny + 0.5f;
    row0 = (x2 - x1) * (py - y1) - (y2 - y1) * (px - x1);
    row1 = (x0 - x2) * (py - y2) - (y0 - y2) * (px - x2);
    row2 = (x1 - x0) * (py - y0) - (y1 - y0) * (px - x0);
  }

  for (y = miny; y <= maxy; y++) {
    float w0 = row0, w1 = row1, w2 = row2;
    size_t base = (size_t)y * (size_t)t->width;
    for (x = minx; x <= maxx; x++) {
      if (w0 <= 0.0f && w1 <= 0.0f && w2 <= 0.0f) {
        float l0 = w0 * inv_area, l1 = w1 * inv_area, l2 = w2 * inv_area;
        float iw = l0 * d->s[0][2] + l1 * d->s[1][2] + l2 * d->s[2][2];
        size_t idx = base + (size_t)x;
        if (iw > t->depth[idx]) {
          float src[3];
          unsigned char *dst = t->rgb + idx * 3;
          int i;
          if (d->tex) {
            float u = (l0 * d->uv[0][0] * d->s[0][2] +
                       l1 * d->uv[1][0] * d->s[1][2] +
                       l2 * d->uv[2][0] * d->s[2][2]) / iw;
            float v = (l0 * d->uv[0][1] * d->s[0][2] +
                       l1 * d->uv[1][1] * d->s[1][2] +
                       l2 * d->uv[2][1] * d->s[2][2]) / iw;
            cart3d_sample(d->tex, u, v, src);
            if (d->gloss) {
              float e = (u * 0.75f + v - 0.40f) / 0.17f;
              float streak = expf(-e * e);
              float lift = 1.0f + 0.15f * (1.0f - v);
              for (i = 0; i < 3; i++) {
                src[i] = src[i] * lift + 24.0f * streak;
              }
            }
          } else {
            src[0] = d->colour[0];
            src[1] = d->colour[1];
            src[2] = d->colour[2];
          }
          for (i = 0; i < 3; i++) {
            float c = src[i] * d->shade + d->rim;
            if (c < 0.0f) c = 0.0f;
            if (c > 255.0f) c = 255.0f;
            if (d->alpha < 0.999f) {
              c = (float)dst[i] * (1.0f - d->alpha) + c * d->alpha;
            }
            dst[i] = (unsigned char)(c + 0.5f);
          }
          if (zwrite) {
            t->depth[idx] = iw;
          }
        }
      }
      w0 += dw0dx;
      w1 += dw1dx;
      w2 += dw2dx;
    }
    row0 += dw0dy;
    row1 += dw1dy;
    row2 += dw2dy;
  }
}

static void cart3d_draw_list(struct cart3d_target *t,
                             const struct cart3d_draw *draws, int count,
                             int zwrite) {
  int i;
  for (i = 0; i < count; i++) {
    cart3d_raster(t, &draws[i], zwrite);
  }
}

static void cart3d_target_clear_depth(struct cart3d_target *t) {
  memset(t->depth, 0, (size_t)t->width * (size_t)t->height * sizeof(float));
}

#endif /* PLUMOS_CART3D_H */
