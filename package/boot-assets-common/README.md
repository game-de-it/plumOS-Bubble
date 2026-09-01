# Shared plumOS boot asset

`plumos-640x480.bmp` is the existing repository-owned plumOS 640x480 boot
design reused by the V90S, A30, and MF ports. Bubble must not add device
branding to this image. Its device-specific code only converts the validated
24-bit BMP pixels to the XRGB8888 layout exposed by Bubble `fb0`.

```text
format=Windows 3.x BMP, uncompressed 24-bit, 640x480
sha256=6b4be39f18289bffe0a9ea65c11f0d479fd12946bd67154ae7332350df795fa8
source=plumOS-V90S_v2-public/package/boot-assets-v90s/bootlogo.bmp
```
