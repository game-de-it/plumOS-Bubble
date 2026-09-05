#ifndef PLUMOS_GGFE_ART_H
#define PLUMOS_GGFE_ART_H

/*
 * GGFE artwork resolution.
 *
 * Two lookup schemes run side by side.
 *
 * 1. GGFE sources - "artwork.sources" in ggfe.json.  Each entry declares a
 *    kind ("title" or "boxart"), so a libretro thumbnail tree can be pointed
 *    at directly and GGFE knows what it is looking at.  Ordered by
 *    "artwork.prefer", then by list order.
 *
 * 2. The stock frontend's scheme - byte for byte the rules of
 *    find_thumbnail() in plumos_library_scan.c, so artwork already on the
 *    card for the stock frontend is picked up with no extra work:
 *
 *      <sdcard>/Images/<ROM directory alias>/   tried first
 *      <sdcard>/Images/gamegear/                the system's artwork lookup
 *
 *    Within a directory: extensions png, jpg, jpeg, webp in that order; the
 *    ROM's path relative to its system directory (subdirectories preserved)
 *    tried before its bare basename; final path component matched
 *    case-insensitively.
 *
 * The stock scheme carries no kind, so a hit from it is returned as UNKNOWN
 * and classified from the decoded image's aspect: 160:144 is a title screen,
 * anything else is treated as box art.  That is the same test the cartridge
 * label uses to decide whether to print the GAME GEAR strip, so the two stay
 * consistent by construction.
 */

#include "plumos_json.h"
#include "plumos_path.h"

#define GGFE_MAX_SOURCES 8
#define GGFE_MAX_ROM_DIRS 8
#define GGFE_MAX_EXTS 6
#define GGFE_MAX_LOOKUPS 4
#define GGFE_MAX_PREFER 12

enum ggfe_art_kind {
  GGFE_ART_UNKNOWN = 0,
  GGFE_ART_TITLE,
  GGFE_ART_BOXART
};

struct ggfe_art_source {
  char kind[8];
  char root[16];
  char path[256];
};

struct ggfe_config {
  char system[64];
  char rom_dirs[GGFE_MAX_ROM_DIRS][64];
  int rom_dir_count;
  char exts[GGFE_MAX_EXTS][8];
  int ext_count;
  char rom_exts[GGFE_MAX_EXTS][8];
  int rom_ext_count;
  char prefer[2][8];
  int prefer_count;
  struct ggfe_art_source sources[GGFE_MAX_SOURCES];
  int source_count;
  struct ggfe_art_source lookups[GGFE_MAX_LOOKUPS];
  int lookup_count;
  int use_plumos_lookup;
  int classify_by_aspect;
  int title_aspect_w;
  int title_aspect_h;
  int title_aspect_tol_permille;
  /* How a selected cartridge is launched.  GGFE decides which profile;
   * plumos-text-ui builds and runs the command.  There is deliberately no
   * CPU policy here: it is resolved by the same chain inside that tool, and
   * forcing a value would override what the user set in the stock frontend. */
  char resolver[160];         /* bin/plumos-text-ui */
  char launch_system[64];     /* systems.json id, e.g. gamegear */
  char launch_profile[128];   /* GGFE system-scope choice, may be empty */
  char systems_path[160];
  char ggfe_overrides[160];   /* GGFE writes only this one */
  char plumos_overrides[160]; /* read as a reference, never written */
  int use_plumos_overrides;
  char launch_prefer[GGFE_MAX_PREFER][128];
  int launch_prefer_count;
};

struct ggfe_roots {
  char sdcard[PATH_MAX];
  char roms[PATH_MAX];
  char plumos[PATH_MAX];
};

/* Defaults match the shipped ggfe.json, so a missing or unreadable config
 * still resolves everything the stock frontend would. */
static void ggfe_config_defaults(struct ggfe_config *cfg) {
  static const char *dirs[] = {"GG", "GameGear", "MD", "gamegear"};
  static const char *exts[] = {"png", "jpg", "jpeg", "webp"};
  static const char *rom_exts[] = {"gg", "sms", "zip", "7z"};
  size_t i;

  memset(cfg, 0, sizeof(*cfg));
  copy_string(cfg->system, sizeof(cfg->system), "gamegear");
  for (i = 0; i < sizeof(dirs) / sizeof(dirs[0]); i++) {
    copy_string(cfg->rom_dirs[cfg->rom_dir_count++],
                sizeof(cfg->rom_dirs[0]), dirs[i]);
  }
  for (i = 0; i < sizeof(exts) / sizeof(exts[0]); i++) {
    copy_string(cfg->exts[cfg->ext_count++], sizeof(cfg->exts[0]), exts[i]);
  }
  for (i = 0; i < sizeof(rom_exts) / sizeof(rom_exts[0]); i++) {
    copy_string(cfg->rom_exts[cfg->rom_ext_count++], sizeof(cfg->rom_exts[0]),
                rom_exts[i]);
  }
  copy_string(cfg->prefer[cfg->prefer_count++], sizeof(cfg->prefer[0]), "title");
  copy_string(cfg->prefer[cfg->prefer_count++], sizeof(cfg->prefer[0]),
              "boxart");
  copy_string(cfg->lookups[0].root, sizeof(cfg->lookups[0].root), "sdcard");
  copy_string(cfg->lookups[0].path, sizeof(cfg->lookups[0].path),
              "Images/gamegear");
  cfg->lookup_count = 1;
  cfg->use_plumos_lookup = 1;
  cfg->classify_by_aspect = 1;
  cfg->title_aspect_w = 160;
  cfg->title_aspect_h = 144;
  cfg->title_aspect_tol_permille = 30;
  copy_string(cfg->resolver, sizeof(cfg->resolver), "bin/plumos-text-ui");
  copy_string(cfg->launch_system, sizeof(cfg->launch_system), "gamegear");
  copy_string(cfg->systems_path, sizeof(cfg->systems_path),
              "config/frontend/systems.json");
  copy_string(cfg->ggfe_overrides, sizeof(cfg->ggfe_overrides),
              "state/frontend/ggfe-overrides.json");
  copy_string(cfg->plumos_overrides, sizeof(cfg->plumos_overrides),
              "state/frontend/core-overrides.json");
  cfg->use_plumos_overrides = 1;
}

static int ggfe_read_file(const char *path, char **out, size_t *len_out) {
  FILE *f = fopen(path, "rb");
  long size;
  char *buf;

  if (!f) {
    return 0;
  }
  if (fseek(f, 0, SEEK_END) != 0 || (size = ftell(f)) < 0 ||
      fseek(f, 0, SEEK_SET) != 0 || size > (1 << 20)) {
    fclose(f);
    return 0;
  }
  buf = (char *)malloc((size_t)size + 1);
  if (!buf) {
    fclose(f);
    return 0;
  }
  if (fread(buf, 1, (size_t)size, f) != (size_t)size) {
    free(buf);
    fclose(f);
    return 0;
  }
  buf[size] = '\0';
  fclose(f);
  *out = buf;
  *len_out = (size_t)size;
  return 1;
}

/* Read a JSON array of plain strings into a fixed table. */
static int ggfe_read_string_array(const char *json, const char *end,
                                  const char *key, char *base, int capacity,
                                  size_t item_size) {
  const char *start, *stop, *cursor;
  int count = 0;

  if (!json_find_array(json, end, key, &start, &stop)) {
    return -1;
  }
  cursor = start;
  while (cursor < stop && count < capacity) {
    while (cursor < stop && *cursor != '"') {
      cursor++;
    }
    if (cursor >= stop) {
      break;
    }
    if (!json_decode_string(&cursor, stop, base + (size_t)count * item_size,
                            item_size)) {
      break;
    }
    count++;
  }
  return count;
}

static int ggfe_read_sources(const char *json, const char *end, const char *key,
                             struct ggfe_art_source *out, int capacity) {
  const char *start, *stop, *cursor;
  int count = 0;

  if (!json_find_array(json, end, key, &start, &stop)) {
    return -1;
  }
  cursor = start;
  while (count < capacity) {
    const char *obj, *obj_end;
    if (!json_next_object(&cursor, stop, &obj, &obj_end)) {
      break;
    }
    memset(&out[count], 0, sizeof(out[count]));
    if (!json_get_string(obj, obj_end, "kind", out[count].kind,
                         sizeof(out[count].kind))) {
      copy_string(out[count].kind, sizeof(out[count].kind), "boxart");
    }
    if (!json_get_string(obj, obj_end, "root", out[count].root,
                         sizeof(out[count].root))) {
      copy_string(out[count].root, sizeof(out[count].root), "sdcard");
    }
    if (!json_get_string(obj, obj_end, "path", out[count].path,
                         sizeof(out[count].path))) {
      continue;
    }
    count++;
  }
  return count;
}

static int ggfe_config_load(struct ggfe_config *cfg, const char *path) {
  char *text = NULL;
  size_t len = 0;
  const char *end, *art, *art_end;
  int n;

  ggfe_config_defaults(cfg);
  if (!ggfe_read_file(path, &text, &len)) {
    return 0;
  }
  end = text + len;

  json_get_string(text, end, "system", cfg->system, sizeof(cfg->system));
  n = ggfe_read_string_array(text, end, "rom_dirs", cfg->rom_dirs[0],
                             GGFE_MAX_ROM_DIRS, sizeof(cfg->rom_dirs[0]));
  if (n > 0) {
    cfg->rom_dir_count = n;
  }
  n = ggfe_read_string_array(text, end, "extensions", cfg->exts[0],
                             GGFE_MAX_EXTS, sizeof(cfg->exts[0]));
  if (n > 0) {
    cfg->ext_count = n;
  }
  n = ggfe_read_string_array(text, end, "rom_extensions", cfg->rom_exts[0],
                             GGFE_MAX_EXTS, sizeof(cfg->rom_exts[0]));
  if (n > 0) {
    cfg->rom_ext_count = n;
  }

  if (json_find_object(text, end, "artwork", &art, &art_end)) {
    n = ggfe_read_string_array(art, art_end, "prefer", cfg->prefer[0], 2,
                               sizeof(cfg->prefer[0]));
    if (n > 0) {
      cfg->prefer_count = n;
    }
    n = ggfe_read_sources(art, art_end, "sources", cfg->sources,
                          GGFE_MAX_SOURCES);
    if (n >= 0) {
      cfg->source_count = n;
    }
    n = ggfe_read_sources(art, art_end, "plumos_lookup", cfg->lookups,
                          GGFE_MAX_LOOKUPS);
    if (n > 0) {
      cfg->lookup_count = n;
    }
    cfg->use_plumos_lookup =
        json_get_bool(art, art_end, "use_plumos_lookup", 1);
    cfg->classify_by_aspect =
        json_get_bool(art, art_end, "classify_by_aspect", 1);
  }
  {
    const char *launch, *launch_end;
    if (json_find_object(text, end, "launch", &launch, &launch_end)) {
      int m;
      json_get_string(launch, launch_end, "resolver", cfg->resolver,
                      sizeof(cfg->resolver));
      json_get_string(launch, launch_end, "system", cfg->launch_system,
                      sizeof(cfg->launch_system));
      json_get_string(launch, launch_end, "profile", cfg->launch_profile,
                      sizeof(cfg->launch_profile));
      json_get_string(launch, launch_end, "systems", cfg->systems_path,
                      sizeof(cfg->systems_path));
      json_get_string(launch, launch_end, "overrides", cfg->ggfe_overrides,
                      sizeof(cfg->ggfe_overrides));
      json_get_string(launch, launch_end, "plumos_overrides",
                      cfg->plumos_overrides, sizeof(cfg->plumos_overrides));
      cfg->use_plumos_overrides =
          json_get_bool(launch, launch_end, "use_plumos_overrides", 1);
      m = ggfe_read_string_array(launch, launch_end, "prefer",
                                 cfg->launch_prefer[0], GGFE_MAX_PREFER,
                                 sizeof(cfg->launch_prefer[0]));
      if (m > 0) {
        cfg->launch_prefer_count = m;
      }
    }
  }
  free(text);
  return 1;
}

static int ggfe_resolve_root(const struct ggfe_roots *roots, const char *root,
                             const char *path, char *out, size_t out_size) {
  if (path[0] == '/') {
    return copy_string(out, out_size, path);
  }
  if (strcmp(root, "plumos") == 0) {
    return join_path(out, out_size, roots->plumos, path);
  }
  return join_path(out, out_size, roots->sdcard, path);
}

/* find_thumbnail_in_dir(): relative stem across every extension first, then
 * the flat stem across every extension. */
static int ggfe_find_in_dir(const struct ggfe_config *cfg, const char *art_dir,
                            const char *relative_stem, const char *flat_stem,
                            char *out, size_t out_size) {
  const char *stems[2];
  int s, e;

  if (!is_directory(art_dir)) {
    return 0;
  }
  stems[0] = relative_stem;
  stems[1] = flat_stem;
  for (s = 0; s < 2; s++) {
    if (!stems[s] || !stems[s][0]) {
      continue;
    }
    for (e = 0; e < cfg->ext_count; e++) {
      char name[PATH_MAX];
      char candidate[PATH_MAX];
      char found[PATH_MAX];
      if (build_stem_ext_name(name, sizeof(name), stems[s], cfg->exts[e]) &&
          join_path(candidate, sizeof(candidate), art_dir, name) &&
          find_case_insensitive_file(candidate, found, sizeof(found))) {
        return copy_string(out, out_size, found);
      }
    }
  }
  return 0;
}

/*
 * Artwork for one ROM.
 *
 * rom_rel   path of the ROM relative to its system directory
 * alias_dir the ROM directory alias it was found under, e.g. "GG"
 * rule      short label naming which rule matched, for logs and diagnostics
 *
 * Returns 1 on a hit.  kind_out is GGFE_ART_UNKNOWN for stock-scheme hits;
 * classify those with ggfe_classify_size() once the image is decoded.
 */
static int ggfe_resolve_art(const struct ggfe_config *cfg,
                            const struct ggfe_roots *roots, const char *rom_rel,
                            const char *alias_dir, char *out, size_t out_size,
                            enum ggfe_art_kind *kind_out, char *rule,
                            size_t rule_size) {
  char rel_stem[PATH_MAX];
  char flat_stem[256];
  const char *dot;
  int p, i;

  if (out_size) {
    out[0] = '\0';
  }
  if (rule_size) {
    rule[0] = '\0';
  }
  *kind_out = GGFE_ART_UNKNOWN;

  copy_string(rel_stem, sizeof(rel_stem), rom_rel);
  dot = strrchr(rel_stem, '.');
  if (dot && dot > strrchr(rel_stem, '/')) {
    rel_stem[dot - rel_stem] = '\0';
  }
  copy_string(flat_stem, sizeof(flat_stem), path_basename(rel_stem));

  /* 1. GGFE sources, ordered by the configured preference */
  for (p = 0; p <= cfg->prefer_count; p++) {
    const char *want = (p < cfg->prefer_count) ? cfg->prefer[p] : NULL;
    for (i = 0; i < cfg->source_count; i++) {
      char art_dir[PATH_MAX];
      if (want) {
        if (strcmp(cfg->sources[i].kind, want) != 0) {
          continue;
        }
      } else {
        int listed = 0, k;
        for (k = 0; k < cfg->prefer_count; k++) {
          if (strcmp(cfg->sources[i].kind, cfg->prefer[k]) == 0) {
            listed = 1;
          }
        }
        if (listed) {
          continue; /* already tried in its preference slot */
        }
      }
      if (!ggfe_resolve_root(roots, cfg->sources[i].root, cfg->sources[i].path,
                             art_dir, sizeof(art_dir))) {
        continue;
      }
      if (ggfe_find_in_dir(cfg, art_dir, rel_stem, flat_stem, out, out_size)) {
        *kind_out = (strcmp(cfg->sources[i].kind, "title") == 0)
                        ? GGFE_ART_TITLE
                        : GGFE_ART_BOXART;
        snprintf(rule, rule_size, "ggfe:%s", cfg->sources[i].path);
        return 1;
      }
    }
  }

  if (!cfg->use_plumos_lookup) {
    return 0;
  }

  /* 2. stock scheme: the ROM's own directory alias first ... */
  if (alias_dir && alias_dir[0]) {
    char images_dir[PATH_MAX];
    char alias_dir_path[PATH_MAX];
    if (join_path(images_dir, sizeof(images_dir), roots->sdcard, "Images") &&
        join_path(alias_dir_path, sizeof(alias_dir_path), images_dir,
                  alias_dir) &&
        ggfe_find_in_dir(cfg, alias_dir_path, rel_stem, flat_stem, out,
                         out_size)) {
      snprintf(rule, rule_size, "plumos:Images/%s", alias_dir);
      return 1;
    }
  }

  /* ... then the system's artwork lookup directories */
  for (i = 0; i < cfg->lookup_count; i++) {
    char art_dir[PATH_MAX];
    if (!ggfe_resolve_root(roots, cfg->lookups[i].root, cfg->lookups[i].path,
                           art_dir, sizeof(art_dir))) {
      continue;
    }
    if (ggfe_find_in_dir(cfg, art_dir, rel_stem, flat_stem, out, out_size)) {
      snprintf(rule, rule_size, "plumos:%s", cfg->lookups[i].path);
      return 1;
    }
  }
  return 0;
}

/* Title screen or box art?  Used for stock-scheme hits, which carry no kind. */
static enum ggfe_art_kind ggfe_classify_size(const struct ggfe_config *cfg,
                                             int width, int height) {
  float ratio, want, tol;

  if (!cfg->classify_by_aspect || width <= 0 || height <= 0) {
    return GGFE_ART_BOXART;
  }
  ratio = (float)width / (float)height;
  want = (float)cfg->title_aspect_w / (float)cfg->title_aspect_h;
  tol = (float)cfg->title_aspect_tol_permille / 1000.0f;
  return (ratio > want - tol && ratio < want + tol) ? GGFE_ART_TITLE
                                                    : GGFE_ART_BOXART;
}

/* ------------------------------------------------------------------ */
/* library scan                                                       */
/* ------------------------------------------------------------------ */

#define GGFE_MAX_ENTRIES 512

struct ggfe_entry {
  char title[192];
  char rom[PATH_MAX];
  char rel[PATH_MAX];
  char alias[64];
  char art[PATH_MAX];
  char rule[160];
  enum ggfe_art_kind kind;
};

static int ggfe_has_rom_ext(const struct ggfe_config *cfg, const char *name) {
  const char *dot = strrchr(name, '.');
  int i;
  if (!dot || !dot[1]) {
    return 0;
  }
  for (i = 0; i < cfg->rom_ext_count; i++) {
    if (ascii_equal_ci(dot + 1, cfg->rom_exts[i])) {
      return 1;
    }
  }
  return 0;
}

static void ggfe_walk(const struct ggfe_config *cfg,
                      const struct ggfe_roots *roots, const char *base,
                      const char *dir, const char *alias,
                      struct ggfe_entry *out, int *count, int capacity,
                      int depth) {
  DIR *d = opendir(dir);
  struct dirent *ent;

  if (!d) {
    return;
  }
  while ((ent = readdir(d)) != NULL && *count < capacity) {
    char full[PATH_MAX];
    if (ent->d_name[0] == '.' || ignored_sidecar_name(ent->d_name)) {
      continue;
    }
    if (!join_path(full, sizeof(full), dir, ent->d_name)) {
      continue;
    }
    if (is_directory(full)) {
      if (depth < 4) {
        ggfe_walk(cfg, roots, base, full, alias, out, count, capacity,
                  depth + 1);
      }
      continue;
    }
    if (!is_regular_file(full) || !ggfe_has_rom_ext(cfg, ent->d_name)) {
      continue;
    }
    {
      struct ggfe_entry *e = &out[*count];
      size_t base_len = strlen(base);
      const char *art_rel = full;
      char *dot;
      int dup = 0, i;

      if (strncmp(full, base, base_len) == 0) {
        art_rel = full + base_len;
        while (*art_rel == '/') {
          art_rel++;
        }
      }
      memset(e, 0, sizeof(*e));
      copy_string(e->rom, sizeof(e->rom), full);
      /* plumOS scan-cache identities include the directory alias
       * (gamegear/Sonic.gg).  Artwork lookup is relative to that alias and
       * therefore continues to use art_rel below. */
      if (!join_path(e->rel, sizeof(e->rel), alias, art_rel)) {
        continue;
      }
      copy_string(e->alias, sizeof(e->alias), alias);
      copy_string(e->title, sizeof(e->title), path_basename(art_rel));
      dot = strrchr(e->title, '.');
      if (dot) {
        *dot = '\0';
      }
      /* MD is marked shared in systems.json - the directory also holds Mega
       * Drive ROMs - so the same title can appear under several aliases. */
      for (i = 0; i < *count; i++) {
        if (ascii_equal_ci(out[i].title, e->title)) {
          dup = 1;
          break;
        }
      }
      if (dup) {
        continue;
      }
      ggfe_resolve_art(cfg, roots, art_rel, e->alias, e->art, sizeof(e->art),
                       &e->kind, e->rule, sizeof(e->rule));
      (*count)++;
    }
  }
  closedir(d);
}

static int ggfe_entry_cmp(const void *a, const void *b) {
  const struct ggfe_entry *ea = (const struct ggfe_entry *)a;
  const struct ggfe_entry *eb = (const struct ggfe_entry *)b;
  const unsigned char *pa = (const unsigned char *)ea->title;
  const unsigned char *pb = (const unsigned char *)eb->title;
  while (*pa && *pb) {
    int ca = tolower(*pa++);
    int cb = tolower(*pb++);
    if (ca != cb) {
      return ca - cb;
    }
  }
  return (int)*pa - (int)*pb;
}

/* Walk every configured ROM directory and resolve artwork for each ROM. */
static int ggfe_scan(const struct ggfe_config *cfg,
                     const struct ggfe_roots *roots, struct ggfe_entry *out,
                     int capacity) {
  int count = 0, i;

  for (i = 0; i < cfg->rom_dir_count && count < capacity; i++) {
    char base[PATH_MAX];
    if (!join_path(base, sizeof(base), roots->roms, cfg->rom_dirs[i]) ||
        !is_directory(base)) {
      continue;
    }
    ggfe_walk(cfg, roots, base, base, cfg->rom_dirs[i], out, &count, capacity,
              0);
  }
  qsort(out, (size_t)count, sizeof(struct ggfe_entry), ggfe_entry_cmp);
  return count;
}

#endif /* PLUMOS_GGFE_ART_H */
