/*
 * Host-side check for GGFE artwork resolution.
 *
 * Points the resolver at a card tree and prints which rule matched each ROM,
 * so the GGFE sources and the stock frontend's scheme can both be verified
 * without a device.
 *
 *   gcc -std=gnu99 -O2 scripts/ggfe-art-test.c -o ggfe-art-test
 *   ./ggfe-art-test <ggfe.json> <sdcard-root>
 */

#include <stdio.h>

#include "../src/frontend/plumos_ggfe_art.h"

int main(int argc, char **argv) {
  struct ggfe_config cfg;
  struct ggfe_roots roots;
  struct ggfe_entry *entries;
  int count, i, width = 5;

  if (argc < 3) {
    fprintf(stderr, "usage: %s <ggfe.json> <sdcard-root>\n", argv[0]);
    return 2;
  }
  if (!ggfe_config_load(&cfg, argv[1])) {
    fprintf(stderr, "ggfe-art-test: cannot read %s, using defaults\n", argv[1]);
  }
  memset(&roots, 0, sizeof(roots));
  copy_string(roots.sdcard, sizeof(roots.sdcard), argv[2]);
  join_path(roots.roms, sizeof(roots.roms), argv[2], "Roms");
  join_path(roots.plumos, sizeof(roots.plumos), argv[2], "plumos");

  entries = (struct ggfe_entry *)calloc(GGFE_MAX_ENTRIES,
                                        sizeof(struct ggfe_entry));
  if (!entries) {
    return 1;
  }
  count = ggfe_scan(&cfg, &roots, entries, GGFE_MAX_ENTRIES);

  for (i = 0; i < count; i++) {
    int n = (int)strlen(entries[i].title);
    if (n > width) {
      width = n;
    }
  }
  printf("%-*s  %-9s %-7s %s\n", width, "TITLE", "ROM DIR", "KIND",
         "MATCHED BY");
  for (i = 0; i < count; i++) {
    const char *kind = entries[i].kind == GGFE_ART_TITLE    ? "title"
                       : entries[i].kind == GGFE_ART_BOXART ? "boxart"
                                                            : "by-aspect";
    printf("%-*s  %-9s %-7s %s\n", width, entries[i].title, entries[i].alias,
           entries[i].art[0] ? kind : "-",
           entries[i].art[0] ? entries[i].rule : "(no artwork)");
  }
  {
    int with_art = 0;
    for (i = 0; i < count; i++) {
      if (entries[i].art[0]) {
        with_art++;
      }
    }
    printf("\n%d ROMs, %d with artwork\n", count, with_art);
  }
  free(entries);
  return 0;
}
