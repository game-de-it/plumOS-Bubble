#ifndef PLUMOS_GGFE_MODEL_H
#define PLUMOS_GGFE_MODEL_H

/*
 * Game Gear cartridge and case geometry for GGFE, in millimetres.
 *
 * Measured off photographs of real shells.  Every constant here is what a
 * port to another machine replaces: swap this header's numbers (or drive them
 * from a per-system JSON profile) and the renderer, animation and artwork
 * paths are unchanged.
 */

#include "plumos_cart3d.h"

#define GGFE_CART_W 68.0f
#define GGFE_CART_H 62.0f
#define GGFE_CART_D 5.6f

/* Raised front bracket: a top bar whose ends run down the sides as arms.  Its
 * outer run is flush with the shell silhouette - same extent, same corner
 * radius - so its wall continues the body wall instead of standing on the
 * face.  A step shows only on the inner edge. */
#define GGFE_BR_X_OUT 34.0f
#define GGFE_BR_X_IN 29.2f
#define GGFE_BR_Y_TOP 31.0f
#define GGFE_BR_Y_BAR 21.5f
#define GGFE_BR_Y_ARM 8.0f
#define GGFE_BLOCK_RISE 1.8f
#define GGFE_CORNER_R_TOP 5.5f
#define GGFE_CORNER_R_BOT 5.0f

/* Grip trough moulded into the top bar: a shallow recess holding the ridges
 * that stop fingers slipping when the cartridge is pulled out. */
#define GGFE_GRIP_X 17.0f
#define GGFE_GRIP_Y0 23.2f
#define GGFE_GRIP_Y1 28.2f
#define GGFE_GRIP_SINK 0.9f

/* Label, sized so its artwork aperture is exactly 160:144. */
#define GGFE_LABEL_X 26.13f
#define GGFE_LABEL_Y0 -18.5f
#define GGFE_LABEL_Y1 21.0f

#define GGFE_CART_TRIS 512
#define GGFE_CASE_TRIS 256

static const unsigned char ggfe_shell[3] = {46, 47, 54};
static const unsigned char ggfe_shell_back[3] = {26, 26, 31};
static const unsigned char ggfe_shell_side[3] = {78, 80, 88};
static const unsigned char ggfe_bracket[3] = {36, 37, 43};
static const unsigned char ggfe_edge_lit[3] = {62, 64, 72};
static const unsigned char ggfe_trough[3] = {24, 24, 29};
static const unsigned char ggfe_trough_wall[3] = {66, 68, 76};
static const unsigned char ggfe_ridge[3] = {13, 13, 16};
static const unsigned char ggfe_emboss_lip[3] = {72, 74, 82};
static const unsigned char ggfe_emboss[3] = {33, 34, 39};
static const unsigned char ggfe_black[3] = {0, 0, 0};
static const unsigned char ggfe_case_tint[3] = {150, 168, 166};
static const unsigned char ggfe_case_back[3] = {128, 144, 142};
static const unsigned char ggfe_case_side[3] = {186, 202, 200};
static const unsigned char ggfe_case_tab[3] = {208, 224, 220};

#define GGFE_CASE_ALPHA 0.24f
#define GGFE_CASE_Z (-3.5f)
#define GGFE_CASE_PIVOT_Z 1.8f

/* Contact shadow the bracket drops onto the recessed plate.  Stepped strips
 * approximate a soft falloff; this is what reads as height in a dead-on view,
 * where the bracket walls project to zero width. */
static const float ggfe_shadow_steps[5][2] = {
    {0.45f, 0.34f}, {0.45f, 0.24f}, {0.60f, 0.16f},
    {0.85f, 0.09f}, {1.20f, 0.045f}};

/* Silhouette: a plain rounded rectangle.  The step near the top of a real
 * shell comes from the bracket, not from any notch in the sides. */
static int ggfe_shell_outline(float (*out)[2], int capacity) {
  return cart3d_rounded_rect(out, capacity, -GGFE_CART_W / 2.0f,
                             GGFE_CART_W / 2.0f, -GGFE_CART_H / 2.0f,
                             GGFE_CART_H / 2.0f, GGFE_CORNER_R_TOP,
                             GGFE_CORNER_R_BOT, 6);
}

/* Concave outline of the raised bracket, counter-clockwise. */
static int ggfe_bracket_outline(float (*p)[2], int capacity) {
  const float xo = GGFE_BR_X_OUT, xi = GGFE_BR_X_IN;
  const float yt = GGFE_BR_Y_TOP, yb = GGFE_BR_Y_BAR, ya = GGFE_BR_Y_ARM;
  const float r = GGFE_CORNER_R_TOP, e = 1.4f;
  const float pi = 3.14159265358979f;
  int n = 0, i;

#define GGFE_PUSH(px, py)          \
  do {                             \
    if (n >= capacity) return n;   \
    p[n][0] = (px);                \
    p[n][1] = (py);                \
    n++;                           \
  } while (0)

  GGFE_PUSH(xo, ya + e);
  GGFE_PUSH(xo, yt - r);
  for (i = 1; i <= 6; i++) {
    float a = (pi / 2.0f) * (float)i / 6.0f;
    GGFE_PUSH(xo - r + r * cosf(a), yt - r + r * sinf(a));
  }
  GGFE_PUSH(-xo + r, yt);
  for (i = 1; i <= 6; i++) {
    float a = pi / 2.0f + (pi / 2.0f) * (float)i / 6.0f;
    GGFE_PUSH(-xo + r + r * cosf(a), yt - r + r * sinf(a));
  }
  GGFE_PUSH(-xo, ya + e);
  GGFE_PUSH(-xo + e, ya);
  GGFE_PUSH(-xi - e, ya);
  GGFE_PUSH(-xi, ya + e);
  GGFE_PUSH(-xi, yb);
  GGFE_PUSH(xi, yb);
  GGFE_PUSH(xi, ya + e);
  GGFE_PUSH(xi + e, ya);
  GGFE_PUSH(xo - e, ya);
#undef GGFE_PUSH
  return n;
}

/* Build one cartridge.  label must outlive the mesh. */
static int ggfe_build_cartridge(struct cart3d_mesh *m,
                                const struct cart3d_tex *label) {
#define GGFE_SHELL_PTS CART3D_RR_POINTS(6)
#define GGFE_PANEL_PTS CART3D_RR_POINTS(4)
#define GGFE_PILL_PTS CART3D_RR_POINTS(5)
#define GGFE_BRACKET_PTS 32
  float outline[GGFE_SHELL_PTS][2], (*ol)[2] = outline;
  float block[GGFE_PANEL_PTS][2], (*bl)[2] = block;
  float trough[GGFE_PANEL_PTS][2], (*tr)[2] = trough;
  float bar_out[GGFE_PANEL_PTS][2], (*bo)[2] = bar_out;
  float pill[GGFE_PILL_PTS][2], (*pl)[2] = pill;
  float brk[GGFE_BRACKET_PTS][2], (*bk)[2] = brk;
  int n_outline, n_trough, n_bar, n_brk, n_pill, i, s;
  const float z_back = -GGFE_CART_D / 2.0f;
  const float z_face = GGFE_CART_D / 2.0f;
  const float z_block = z_face + GGFE_BLOCK_RISE;
  const float z_grip = z_block - GGFE_GRIP_SINK;
  const float lz = z_face + 0.25f;

  if (!cart3d_mesh_init(m, GGFE_CART_TRIS)) {
    return 0;
  }

  n_outline = ggfe_shell_outline(ol, GGFE_SHELL_PTS);
  cart3d_face(m, ol, n_outline, z_face, ggfe_shell, 0, 1.0f);
  cart3d_face(m, ol, n_outline, z_back, ggfe_shell_back, 1, 1.0f);
  cart3d_wall(m, ol, n_outline, z_face, z_back, ggfe_shell_side, 1.0f);

  /* bracket: three convex fills at one height, one wall along the real
   * outline.  The bar is a ring so the grip trough behind it survives the
   * depth test. */
  n_trough = cart3d_rounded_rect(tr, GGFE_PANEL_PTS, -GGFE_GRIP_X, GGFE_GRIP_X,
                                 GGFE_GRIP_Y0, GGFE_GRIP_Y1, 1.6f, 1.6f, 4);
  n_bar = cart3d_rounded_rect(bo, GGFE_PANEL_PTS, -GGFE_BR_X_OUT, GGFE_BR_X_OUT,
                              GGFE_BR_Y_BAR, GGFE_BR_Y_TOP,
                              GGFE_CORNER_R_TOP, 0.2f, 4);
  if (n_bar == n_trough) {
    cart3d_ring(m, bo, tr, n_bar, z_block, ggfe_bracket, 1.0f);
  } else {
    cart3d_face(m, bo, n_bar, z_block, ggfe_bracket, 0, 1.0f);
  }
  for (s = 0; s < 2; s++) {
    float sx = s ? 1.0f : -1.0f;
    float a = sx * GGFE_BR_X_OUT, b = sx * GGFE_BR_X_IN;
    int n_arm = cart3d_rounded_rect(bl, GGFE_PANEL_PTS, a < b ? a : b, a < b ? b : a,
                                    GGFE_BR_Y_ARM, GGFE_BR_Y_BAR + 0.2f,
                                    0.2f, 1.4f, 4);
    cart3d_face(m, bl, n_arm, z_block, ggfe_bracket, 0, 1.0f);
  }
  n_brk = ggfe_bracket_outline(bk, GGFE_BRACKET_PTS);
  cart3d_wall(m, bk, n_brk, z_block, z_face, ggfe_shell_side, 1.0f);
  cart3d_quad(m, -GGFE_BR_X_OUT + 4.5f, GGFE_BR_X_OUT - 4.5f,
              GGFE_BR_Y_TOP - 0.45f, GGFE_BR_Y_TOP, z_block + 0.02f,
              ggfe_edge_lit, 1.0f);

  /* grip trough and its anti-slip ridges */
  cart3d_face(m, tr, n_trough, z_grip, ggfe_trough, 0, 1.0f);
  {
    float rev[GGFE_PANEL_PTS][2], (*rv)[2] = rev;
    for (i = 0; i < n_trough; i++) {
      rv[i][0] = tr[n_trough - 1 - i][0];
      rv[i][1] = tr[n_trough - 1 - i][1];
    }
    cart3d_wall(m, rv, n_trough, z_block, z_grip, ggfe_trough_wall, 1.0f);
  }
  for (i = 0; i < 3; i++) {
    float y = GGFE_GRIP_Y0 + 1.2f + (float)i * 1.3f;
    cart3d_quad(m, -GGFE_GRIP_X + 1.8f, GGFE_GRIP_X - 1.8f, y, y + 0.62f,
                z_grip + 0.05f, ggfe_ridge, 1.0f);
  }

  /* label */
  {
    float a[3], b[3], c[3], d[3];
    float uv0[3][2] = {{0, 0}, {0, 1}, {1, 1}};
    float uv1[3][2] = {{0, 0}, {1, 1}, {1, 0}};
    a[0] = -GGFE_LABEL_X; a[1] = GGFE_LABEL_Y1; a[2] = lz;
    b[0] = -GGFE_LABEL_X; b[1] = GGFE_LABEL_Y0; b[2] = lz;
    c[0] = GGFE_LABEL_X;  c[1] = GGFE_LABEL_Y0; c[2] = lz;
    d[0] = GGFE_LABEL_X;  d[1] = GGFE_LABEL_Y1; d[2] = lz;
    cart3d_add_tex(m, a, b, c, uv0, label, 1);
    cart3d_add_tex(m, a, c, d, uv1, label, 1);
  }

  /* contact shadow, appended after the label so it blends over it */
  {
    float off = 0.0f;
    for (i = 0; i < 5; i++) {
      float w = ggfe_shadow_steps[i][0], al = ggfe_shadow_steps[i][1];
      cart3d_quad(m, -GGFE_BR_X_IN, GGFE_BR_X_IN, GGFE_BR_Y_BAR - off - w,
                  GGFE_BR_Y_BAR - off, lz + 0.08f, ggfe_black, al);
      off += w;
    }
    for (s = 0; s < 2; s++) {
      float sx = s ? 1.0f : -1.0f;
      float scale = s ? 0.35f : 1.0f;
      off = 0.0f;
      for (i = 0; i < 5; i++) {
        float w = ggfe_shadow_steps[i][0], al = ggfe_shadow_steps[i][1];
        float xa = sx * GGFE_BR_X_IN - sx * off;
        float xb = xa - sx * w;
        cart3d_quad(m, xa < xb ? xa : xb, xa < xb ? xb : xa, GGFE_BR_Y_ARM,
                    GGFE_BR_Y_BAR, lz + 0.08f, ggfe_black, al * scale);
        off += w;
      }
    }
  }

  /* SEGA emboss: a recess with a lit lower lip */
  n_pill = cart3d_rounded_rect(pl, GGFE_PILL_PTS, -14.0f, 14.0f, -3.5f, 3.5f, 3.5f, 3.5f, 5);
  for (i = 0; i < n_pill; i++) {
    pl[i][1] -= 23.5f;
  }
  cart3d_face(m, pl, n_pill, z_face + 0.10f, ggfe_emboss_lip, 0, 1.0f);
  for (i = 0; i < n_pill; i++) {
    pl[i][1] -= 0.6f;
  }
  cart3d_face(m, pl, n_pill, z_face + 0.16f, ggfe_emboss, 0, 1.0f);
  return 1;
}

/* Translucent clamshell: an open back tray and a lid hinged at the top. */
static int ggfe_build_case(struct cart3d_mesh *tray, struct cart3d_mesh *lid,
                           float *height_out) {
#define GGFE_CASE_PTS CART3D_RR_POINTS(5)
#define GGFE_TAB_PTS CART3D_RR_POINTS(3)
  float outer[GGFE_CASE_PTS][2], (*ou)[2] = outer;
  float inner[GGFE_CASE_PTS][2], (*in)[2] = inner;
  float rev[GGFE_CASE_PTS][2], (*rv)[2] = rev;
  float tab[GGFE_TAB_PTS][2], (*tb)[2] = tab;
  const float w = GGFE_CART_W + 9.0f, h = GGFE_CART_H + 9.0f;
  const float z_f = 1.6f, z_b = -9.0f;
  int n, n_in, n_tab, i;

  if (!cart3d_mesh_init(tray, GGFE_CASE_TRIS) ||
      !cart3d_mesh_init(lid, GGFE_CASE_TRIS)) {
    return 0;
  }
  n = cart3d_rounded_rect(ou, GGFE_CASE_PTS, -w / 2.0f, w / 2.0f, -h / 2.0f, h / 2.0f,
                          6.0f, 6.0f, 5);
  n_in = cart3d_rounded_rect(in, GGFE_CASE_PTS, -w / 2.0f + 4.5f, w / 2.0f - 4.5f,
                             -h / 2.0f + 4.5f, h / 2.0f - 4.5f, 4.5f, 4.5f, 5);
  for (i = 0; i < n_in; i++) {
    rv[i][0] = in[n_in - 1 - i][0];
    rv[i][1] = in[n_in - 1 - i][1];
  }
  cart3d_face(tray, ou, n, z_b, ggfe_case_back, 0, 1.0f);
  cart3d_wall(tray, ou, n, z_f, z_b, ggfe_case_side, 1.0f);
  cart3d_wall(tray, rv, n_in, z_f, z_b, ggfe_case_side, 1.0f);
  if (n == n_in) {
    cart3d_ring(tray, ou, in, n, z_f, ggfe_case_tint, 1.0f);
  }

  cart3d_face(lid, ou, n, 4.4f, ggfe_case_tint, 0, 1.0f);
  cart3d_face(lid, ou, n, 1.8f, ggfe_case_back, 1, 1.0f);
  cart3d_wall(lid, ou, n, 4.4f, 1.8f, ggfe_case_side, 1.0f);
  n_tab = cart3d_rounded_rect(tb, GGFE_TAB_PTS, -10.0f, 10.0f, -3.0f, 3.0f, 2.5f, 2.5f, 3);
  for (i = 0; i < n_tab; i++) {
    tb[i][1] += h / 2.0f - 4.0f;
  }
  cart3d_face(lid, tb, n_tab, 5.8f, ggfe_case_tab, 0, 1.0f);
  cart3d_wall(lid, tb, n_tab, 5.8f, 4.4f, ggfe_case_tab, 1.0f);

  if (height_out) {
    *height_out = h;
  }
  return 1;
}

#endif /* PLUMOS_GGFE_MODEL_H */
