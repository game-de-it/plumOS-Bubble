#ifndef PLUMOS_PATH_H
#define PLUMOS_PATH_H

/*
 * Path and string helpers shared by the frontend tools.
 *
 * Lifted verbatim from plumos_library_scan.c so GGFE resolves artwork with
 * byte-for-byte the same rules as the stock frontend.  Note in particular
 * that find_case_insensitive_file() only relaxes case on the final path
 * component: any directory part must match exactly.  On the FAT32 SD card
 * that distinction disappears, but on ext4 it does not, and GGFE must not
 * quietly resolve a file the stock frontend would miss.
 *
 * plumos_library_scan.c still carries its own copies; adopting this header
 * there is a separate, mechanical change and is tracked in TODO.md.
 */

#include <ctype.h>
#include <dirent.h>
#include <limits.h>
#include <stddef.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>

#ifndef PATH_MAX
#define PATH_MAX 4096
#endif

static int copy_string(char *out, size_t out_size, const char *in) {
  size_t len;
  if (!out || out_size == 0) {
    return 0;
  }
  out[0] = '\0';
  if (!in) {
    return 0;
  }
  len = strlen(in);
  if (len + 1 > out_size) {
    return 0;
  }
  memcpy(out, in, len + 1);
  return 1;
}

static int append_string(char *out, size_t out_size, size_t *pos, const char *in) {
  size_t len;
  if (!out || !pos || !in) {
    return 0;
  }
  len = strlen(in);
  if (*pos + len + 1 > out_size) {
    return 0;
  }
  memcpy(out + *pos, in, len);
  *pos += len;
  out[*pos] = '\0';
  return 1;
}

static int path_parent(char *out, size_t out_size, const char *path) {
  const char *slash;
  size_t len;

  if (!path || !path[0]) {
    return copy_string(out, out_size, ".");
  }

  slash = strrchr(path, '/');
  if (!slash) {
    return copy_string(out, out_size, ".");
  }
  if (slash == path) {
    return copy_string(out, out_size, "/");
  }

  len = (size_t)(slash - path);
  if (len + 1 > out_size) {
    if (out_size > 0) {
      out[0] = '\0';
    }
    return 0;
  }
  memcpy(out, path, len);
  out[len] = '\0';
  return 1;
}

static const char *path_basename(const char *path) {
  const char *slash = strrchr(path, '/');
  return slash ? slash + 1 : path;
}

static int is_regular_file(const char *path) {
  struct stat st;
  return stat(path, &st) == 0 && S_ISREG(st.st_mode);
}

static int is_directory(const char *path) {
  struct stat st;
  return stat(path, &st) == 0 && S_ISDIR(st.st_mode);
}

static int ascii_equal_ci(const char *a, const char *b) {
  while (*a && *b) {
    if (tolower((unsigned char)*a) != tolower((unsigned char)*b)) {
      return 0;
    }
    a++;
    b++;
  }
  return *a == '\0' && *b == '\0';
}

static int ignored_sidecar_name(const char *name) {
  if (!name || !name[0]) {
    return 1;
  }
  if (strncmp(name, "._", 2) == 0) {
    return 1;
  }
  if (strcmp(name, ".DS_Store") == 0 || strcmp(name, "Thumbs.db") == 0 ||
      strcmp(name, "desktop.ini") == 0 || strcmp(name, "__MACOSX") == 0) {
    return 1;
  }
  return 0;
}

static void lower_string(char *s) {
  while (*s) {
    *s = (char)tolower((unsigned char)*s);
    s++;
  }
}

static int join_path(char *out, size_t out_size, const char *a, const char *b) {
  size_t len_a;
  size_t len_b;
  size_t pos = 0;

  if (!out || out_size == 0 || !a || !b) {
    return 0;
  }

  out[0] = '\0';
  if (b[0] == '/') {
    return copy_string(out, out_size, b);
  }

  len_a = strlen(a);
  len_b = strlen(b);
  if (len_a + (len_a && a[len_a - 1] != '/' ? 1 : 0) + len_b + 1 > out_size) {
    return 0;
  }

  if (!append_string(out, out_size, &pos, a)) {
    return 0;
  }
  if (pos > 0 && out[pos - 1] != '/') {
    if (!append_string(out, out_size, &pos, "/")) {
      return 0;
    }
  }
  return append_string(out, out_size, &pos, b);
}

static int build_stem_ext_name(char *out, size_t out_size, const char *stem, const char *ext) {
  size_t stem_len = strlen(stem);
  size_t ext_len = strlen(ext);

  if (stem_len + 1 + ext_len + 1 > out_size) {
    if (out_size > 0) {
      out[0] = '\0';
    }
    return 0;
  }
  memcpy(out, stem, stem_len);
  out[stem_len] = '.';
  memcpy(out + stem_len + 1, ext, ext_len);
  out[stem_len + 1 + ext_len] = '\0';
  return 1;
}

static int find_case_insensitive_file(const char *candidate, char *out, size_t out_size) {
  char dir_path[PATH_MAX];
  const char *base_name;
  DIR *dir;
  struct dirent *ent;

  if (is_regular_file(candidate)) {
    return copy_string(out, out_size, candidate);
  }

  if (!path_parent(dir_path, sizeof(dir_path), candidate)) {
    return 0;
  }
  base_name = path_basename(candidate);
  dir = opendir(dir_path);
  if (!dir) {
    return 0;
  }
  while ((ent = readdir(dir)) != NULL) {
    char found[PATH_MAX];
    if (ignored_sidecar_name(ent->d_name)) {
      continue;
    }
    if (!ascii_equal_ci(ent->d_name, base_name)) {
      continue;
    }
    if (!join_path(found, sizeof(found), dir_path, ent->d_name)) {
      continue;
    }
    if (is_regular_file(found)) {
      closedir(dir);
      return copy_string(out, out_size, found);
    }
  }
  closedir(dir);
  return 0;
}

#endif /* PLUMOS_PATH_H */
