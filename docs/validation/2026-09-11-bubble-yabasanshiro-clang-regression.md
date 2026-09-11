# Bubble YabaSanshiro compiler regression and physical acceptance

Date: 2026-09-11

## Regression

The release-candidate image built from `a96eb3b` contained the standalone
YabaSanshiro binary rebuilt by `2379b87`.  That clean-build change explicitly
replaced the previously device-validated Clang/Clang++ toolchain with GCC/G++.
The build and package checksum gates passed, but the replacement artifact had
not been launched on the physical Bubble.

On the device the GCC binary reached the launcher but failed before content
display:

```text
context renderer string: "(null)"
context vendor string: "(null)"
version string: "(null)"
Could not initialize NanoVG!
yabasanshiro_exit=rc-134
```

ELF comparison found that the GCC artifact did not retain `libEGL.so.1` in its
`DT_NEEDED` entries.  The Clang artifact retains both `libEGL.so.1` and
`libGLESv2.so.2`.  The exact compiler-sensitive cause is therefore observable
at the runtime dependency boundary even though both binaries compile and link.

## Correction and device result

Source `4a8285f` restores explicit Clang/Clang++ selection and changes the
standalone clean-build contract to require Clang and reject a GCC substitution.
The complete standalone component and app-layer metadata were rebuilt and
deployed atomically with the additional Clang-linked Boost/ICU dependencies.
Device verification passed 863 standalone component entries and 12,477 global
app-layer entries.

The user then launched `Virtual Hydlide (1995)(Sega)(JP).ccd` through the normal
frontend route and confirmed normal operation.  The device log recorded:

```text
yabasanshiro_start=renderer-mali-g52-gles content-Virtual Hydlide (1995)(Sega)(JP).ccd
context renderer string: "Mali-G52"
context vendor string: "ARM"
version string: "OpenGL ES 3.2 v1.g13p0-01eac0.fdf91928d758c45c1787782175b35c6a"
yabasanshiro_exit=rc-0
```

The frontend was again the sole display owner after exit.

## Compiler-history audit

Repository history contains no other explicit Clang-to-GCC replacement.  The
libretro YabaSanshiro builder still selects Clang for the same pinned AArch64
runtime.  PCSX-ReARMed, DraStic, PPSSPP and OpenBOR use their original
toolchains; `2379b87` did not change their compiler selection.  Current
DraStic and PPSSPP artifacts retain their required EGL/GLES dependencies and
have successful physical-device `rc-0` logs.

The image produced from `a96eb3b` is superseded and must not be used as the
release candidate.  A new clean image is required from `4a8285f` or later.
