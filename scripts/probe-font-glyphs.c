#include <errno.h>
#include <stdio.h>
#include <stdlib.h>

#include <ft2build.h>
#include FT_FREETYPE_H

int main(int argc, char **argv) {
  FT_Library library = NULL;
  FT_Face face = NULL;
  int rc = 1;
  int i;

  if (argc < 3) {
    fprintf(stderr, "usage: %s FONT CODEPOINT_HEX...\n", argv[0]);
    return 2;
  }
  if (FT_Init_FreeType(&library) != 0 ||
      FT_New_Face(library, argv[1], 0, &face) != 0) {
    fprintf(stderr, "cannot load font face 0: %s\n", argv[1]);
    goto out;
  }
  for (i = 2; i < argc; i++) {
    char *end = NULL;
    unsigned long codepoint;

    errno = 0;
    codepoint = strtoul(argv[i], &end, 16);
    if (errno != 0 || !end || *end != '\0' || codepoint > 0x10ffffUL) {
      fprintf(stderr, "invalid codepoint: %s\n", argv[i]);
      goto out;
    }
    if (FT_Get_Char_Index(face, (FT_ULong)codepoint) == 0) {
      fprintf(stderr, "missing glyph U+%04lX in %s\n", codepoint, argv[1]);
      goto out;
    }
  }
  printf("font_glyph_probe=result-ok font=%s glyphs=%d\n", argv[1], argc - 2);
  rc = 0;

out:
  if (face) {
    FT_Done_Face(face);
  }
  if (library) {
    FT_Done_FreeType(library);
  }
  return rc;
}
