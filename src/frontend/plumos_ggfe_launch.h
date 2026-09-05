#ifndef PLUMOS_GGFE_LAUNCH_H
#define PLUMOS_GGFE_LAUNCH_H

/*
 * GGFE launch resolution.
 *
 * The division of labour is deliberate:
 *
 *   GGFE decides *which* launch profile.
 *   plumos-text-ui decides *how* to run it.
 *
 * `plumos-text-ui launch SYSTEM RELATIVE_PATH [--profile ID] [--execute]`
 * already builds the command for every runtime, and the three runtimes do not
 * agree on a calling convention - RetroArch takes named flags and an absolute
 * core path, picoarch and standalone take two positional arguments with the
 * system and CPU policy passed through the environment.  It also validates
 * that the profile is listed for the system, that the ROM sits under the
 * configured ROM root and the core under the managed core directory, and it
 * records recent and resume state on the way through.
 *
 * Reimplementing any of that in GGFE would duplicate roughly three hundred
 * lines that must stay byte-identical to keep both frontends launching a game
 * the same way.  So GGFE contributes the one thing it is better placed to
 * decide - the choice - and delegates the rest.
 *
 * GGFE keeps its own override file and never writes plumOS's.  It reads
 * plumOS's as a reference so a per-ROM core picked in the stock frontend is
 * honoured here, but the two files stay independently owned.
 *
 * CPU policy is intentionally absent from GGFE's config.  It is resolved by
 * the same chain inside plumos-text-ui from systems.json and core-overrides,
 * and GGFE forcing a value would silently override a setting the user made in
 * the stock frontend.
 */

#include "plumos_ggfe_art.h"

#define GGFE_MAX_PROFILES 12

enum ggfe_runtime {
  GGFE_RT_UNKNOWN = 0,
  GGFE_RT_RETROARCH,
  GGFE_RT_PICOARCH,
  GGFE_RT_STANDALONE
};

struct ggfe_profile {
  char id[128]; /* "retroarch:genesis_plus_gx" */
  enum ggfe_runtime runtime;
  char core[96];
  int available;
  char reason[96]; /* why not, when unavailable */
};

/* The candidate set, straight from systems.json.  GGFE reorders these; it
 * never invents a profile the catalogue does not list. */
struct ggfe_catalog {
  char system_id[64];
  struct ggfe_profile profiles[GGFE_MAX_PROFILES];
  int profile_count;
  char default_profile[128];
};

struct ggfe_profile_override {
  char relative_path[PATH_MAX]; /* empty means system scope */
  char launch_profile[128];
};

#define GGFE_MAX_ROM_OVERRIDES 256

struct ggfe_override_set {
  struct ggfe_profile_override system;
  int has_system;
  struct ggfe_profile_override *rom;
  int rom_count;
};

struct ggfe_launch_choice {
  const struct ggfe_profile *profile;
  char source[48]; /* which layer decided, for the log and the picker */
};

static enum ggfe_runtime ggfe_runtime_of(const char *profile, char *core,
                                         size_t core_size) {
  static const struct {
    const char *prefix;
    enum ggfe_runtime runtime;
  } kinds[] = {{"retroarch:", GGFE_RT_RETROARCH},
               {"picoarch:", GGFE_RT_PICOARCH},
               {"standalone:", GGFE_RT_STANDALONE}};
  size_t i;

  if (core_size) {
    core[0] = '\0';
  }
  for (i = 0; i < sizeof(kinds) / sizeof(kinds[0]); i++) {
    size_t n = strlen(kinds[i].prefix);
    if (strncmp(profile, kinds[i].prefix, n) == 0 && profile[n]) {
      copy_string(core, core_size, profile + n);
      return kinds[i].runtime;
    }
  }
  return GGFE_RT_UNKNOWN;
}

/* Read the system's launch_profiles and default_launch_profile. */
static int ggfe_catalog_load(struct ggfe_catalog *cat, const char *systems_path,
                             const char *system_id) {
  char *text = NULL;
  size_t len = 0;
  const char *end, *array, *array_end, *cursor;
  int found = 0;

  memset(cat, 0, sizeof(*cat));
  copy_string(cat->system_id, sizeof(cat->system_id), system_id);
  if (!ggfe_read_file(systems_path, &text, &len)) {
    return 0;
  }
  end = text + len;
  if (!json_find_array(text, end, "systems", &array, &array_end)) {
    free(text);
    return 0;
  }
  cursor = array;
  while (!found) {
    const char *obj, *obj_end, *profiles, *profiles_end, *p;
    char id[64];

    if (!json_next_object(&cursor, array_end, &obj, &obj_end)) {
      break;
    }
    if (!json_get_string(obj, obj_end, "id", id, sizeof(id)) ||
        strcmp(id, system_id) != 0) {
      continue;
    }
    found = 1;
    json_get_string(obj, obj_end, "default_launch_profile", cat->default_profile,
                    sizeof(cat->default_profile));
    if (!json_find_array(obj, obj_end, "launch_profiles", &profiles,
                         &profiles_end)) {
      break;
    }
    p = profiles;
    while (cat->profile_count < GGFE_MAX_PROFILES) {
      struct ggfe_profile *entry = &cat->profiles[cat->profile_count];
      while (p < profiles_end && *p != '"') {
        p++;
      }
      if (p >= profiles_end) {
        break;
      }
      if (!json_decode_string(&p, profiles_end, entry->id, sizeof(entry->id))) {
        break;
      }
      entry->runtime =
          ggfe_runtime_of(entry->id, entry->core, sizeof(entry->core));
      if (entry->runtime != GGFE_RT_UNKNOWN) {
        cat->profile_count++;
      }
    }
  }
  free(text);
  return found;
}

/*
 * A profile counts only if its runtime and core are actually on this device.
 * Unavailable profiles are kept, not dropped: the frontend has to be able to
 * say why a core it lists cannot run.
 */
static void ggfe_probe_profiles(struct ggfe_catalog *cat,
                                const char *plumos_root) {
  int i;
  for (i = 0; i < cat->profile_count; i++) {
    struct ggfe_profile *p = &cat->profiles[i];
    char path[PATH_MAX];
    char rel[PATH_MAX];

    p->available = 0;
    p->reason[0] = '\0';
    switch (p->runtime) {
      case GGFE_RT_RETROARCH:
      case GGFE_RT_PICOARCH:
        snprintf(rel, sizeof(rel), "cores/%s_libretro.so", p->core);
        if (!join_path(path, sizeof(path), plumos_root, rel) ||
            !is_regular_file(path)) {
          snprintf(p->reason, sizeof(p->reason), "core not packaged: %s",
                   p->core);
          continue;
        }
        if (p->runtime == GGFE_RT_PICOARCH) {
          if (!join_path(path, sizeof(path), plumos_root,
                         "picoarch/bin/picoarch") ||
              !is_regular_file(path)) {
            copy_string(p->reason, sizeof(p->reason), "picoarch not packaged");
            continue;
          }
        }
        p->available = 1;
        break;
      case GGFE_RT_STANDALONE:
        if (!join_path(path, sizeof(path), plumos_root,
                       "bin/plumos-standalone-launch") ||
            !is_regular_file(path)) {
          copy_string(p->reason, sizeof(p->reason), "standalone not packaged");
          continue;
        }
        p->available = 1;
        break;
      default:
        copy_string(p->reason, sizeof(p->reason), "unknown runtime");
        break;
    }
  }
}

static const struct ggfe_profile *ggfe_profile_find(
    const struct ggfe_catalog *cat, const char *id) {
  int i;
  if (!id || !id[0]) {
    return NULL;
  }
  for (i = 0; i < cat->profile_count; i++) {
    if (strcmp(cat->profiles[i].id, id) == 0) {
      return &cat->profiles[i];
    }
  }
  return NULL;
}

/* Both override files share plumOS's schema; GGFE only reads launch_profile
 * from them and only ever writes its own file. */
static int ggfe_overrides_load(struct ggfe_override_set *set, const char *path,
                               const char *system_id) {
  char *text = NULL;
  size_t len = 0;
  const char *end, *array, *array_end, *cursor;

  memset(set, 0, sizeof(*set));
  if (!ggfe_read_file(path, &text, &len)) {
    return 0;
  }
  end = text + len;

  if (json_find_array(text, end, "system_overrides", &array, &array_end)) {
    cursor = array;
    for (;;) {
      const char *obj, *obj_end;
      char id[64];
      if (!json_next_object(&cursor, array_end, &obj, &obj_end)) {
        break;
      }
      if (!json_get_string(obj, obj_end, "system_id", id, sizeof(id)) ||
          strcmp(id, system_id) != 0) {
        continue;
      }
      if (json_get_string(obj, obj_end, "launch_profile",
                          set->system.launch_profile,
                          sizeof(set->system.launch_profile))) {
        set->has_system = 1;
      }
    }
  }

  if (json_find_array(text, end, "rom_overrides", &array, &array_end)) {
    set->rom = (struct ggfe_profile_override *)calloc(
        GGFE_MAX_ROM_OVERRIDES, sizeof(struct ggfe_profile_override));
    cursor = array;
    while (set->rom && set->rom_count < GGFE_MAX_ROM_OVERRIDES) {
      const char *obj, *obj_end;
      struct ggfe_profile_override *entry = &set->rom[set->rom_count];
      char id[64];
      if (!json_next_object(&cursor, array_end, &obj, &obj_end)) {
        break;
      }
      if (!json_get_string(obj, obj_end, "system_id", id, sizeof(id)) ||
          strcmp(id, system_id) != 0) {
        continue;
      }
      if (json_get_string(obj, obj_end, "relative_path", entry->relative_path,
                          sizeof(entry->relative_path)) &&
          json_get_string(obj, obj_end, "launch_profile", entry->launch_profile,
                          sizeof(entry->launch_profile))) {
        set->rom_count++;
      }
    }
  }
  free(text);
  return 1;
}

static void ggfe_overrides_free(struct ggfe_override_set *set) {
  free(set->rom);
  memset(set, 0, sizeof(*set));
}

static const char *ggfe_override_for_rom(const struct ggfe_override_set *set,
                                         const char *rom_rel) {
  int i;
  for (i = 0; i < set->rom_count; i++) {
    if (strcmp(set->rom[i].relative_path, rom_rel) == 0) {
      return set->rom[i].launch_profile;
    }
  }
  return NULL;
}

/*
 * Scope beats origin, and within a scope GGFE beats plumOS.
 *
 *   1 ROM,    GGFE     ggfe-overrides.json
 *   2 ROM,    plumOS   core-overrides.json
 *   3 system, GGFE     ggfe.json  launch.profile
 *   4 system, plumOS   core-overrides.json
 *   5 catalogue        systems.json  default_launch_profile
 *   6 preference       ggfe.json  launch.prefer
 *   7 first available
 *
 * A candidate is taken only if the catalogue lists it and the device has it.
 */
static int ggfe_choose_profile(const struct ggfe_catalog *cat,
                               const struct ggfe_config *cfg,
                               const struct ggfe_override_set *ggfe_ov,
                               const struct ggfe_override_set *plumos_ov,
                               const char *rom_rel,
                               struct ggfe_launch_choice *choice) {
  struct {
    const char *id;
    const char *source;
  } chain[6];
  int n = 0, i;

  memset(choice, 0, sizeof(*choice));
  chain[n].id = ggfe_override_for_rom(ggfe_ov, rom_rel);
  chain[n++].source = "ggfe rom override";
  if (cfg->use_plumos_overrides) {
    chain[n].id = ggfe_override_for_rom(plumos_ov, rom_rel);
    chain[n++].source = "plumos rom override";
  }
  chain[n].id = cfg->launch_profile[0] ? cfg->launch_profile : NULL;
  chain[n++].source = "ggfe system default";
  if (cfg->use_plumos_overrides) {
    chain[n].id = plumos_ov->has_system ? plumos_ov->system.launch_profile : NULL;
    chain[n++].source = "plumos system override";
  }
  chain[n].id = cat->default_profile[0] ? cat->default_profile : NULL;
  chain[n++].source = "systems.json default";

  for (i = 0; i < n; i++) {
    const struct ggfe_profile *p = ggfe_profile_find(cat, chain[i].id);
    if (p && p->available) {
      choice->profile = p;
      copy_string(choice->source, sizeof(choice->source), chain[i].source);
      return 1;
    }
  }
  for (i = 0; i < cfg->launch_prefer_count; i++) {
    const struct ggfe_profile *p =
        ggfe_profile_find(cat, cfg->launch_prefer[i]);
    if (p && p->available) {
      choice->profile = p;
      copy_string(choice->source, sizeof(choice->source), "ggfe preference");
      return 1;
    }
  }
  for (i = 0; i < cat->profile_count; i++) {
    if (cat->profiles[i].available) {
      choice->profile = &cat->profiles[i];
      copy_string(choice->source, sizeof(choice->source), "first available");
      return 1;
    }
  }
  copy_string(choice->source, sizeof(choice->source), "none available");
  return 0;
}

#endif /* PLUMOS_GGFE_LAUNCH_H */
