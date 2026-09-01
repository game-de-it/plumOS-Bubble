# Bubble stock initramfs System A/B boundary

Date: 2026-09-02

Source Image SHA-256:
a6674c54976bf1bea36891bdb7f7a17c6f895437973adbda78fa7556570bfaab

## Purpose

V90S型のp1 System A/Bとp3 managed runtimeをBubbleに移植する前に、kernel sourceがない
stock Imageのinitramfsがどの境界をkernel command lineから変更できるかを固定した。

scripts/inspect-bubble-stock-initramfs.py はhash未知のImageを拒否し、embedded gzip/newcを
自動検出し、initとfunctionsをメモリ上で検査する。

## Reproducible result

    gzip_offset=15670320
    gzip_size=2301667
    gzip_sha256=c0997b00b3b822d52cf69acbd6616ed45304d078153651b57c455f9ad6bea2c4
    cpio_size=5269504
    cpio_sha256=ba76e49f2538d86ece15527b263ce92ab024657c41110525a192acc23d16a865
    init_size=39378
    init_sha256=db3842ce427aa98ee47edd031d6ac3957cbecaa2e24ed3ea5061e555e85a74d1
    functions_size=3879
    functions_sha256=77dcc28cebb2426f7345f84dec385315628487add415df719c9823a7321df015

stock initはSYSTEM_IMAGE引数をparseし、先頭slashを除いたpathをIMAGE_SYSTEMへ入れる。
そのためbootargsへSYSTEM_IMAGE=System/system-a.squashfsを渡せば、p1上のA/B SquashFS
pathは選択できる。

一方で、Bubble vendor変更のmount pathは次のように固定されている。

    mount_part "/dev/mmcblk1p1" "/flash" "ro,noatime"
    mount_part "/dev/mmcblk1p2" "/storage" "rw,noatime"

このままではp2をmatching boot payload、p3をPLUMOS_SYS runtimeとする4 partition contractを
実行できない。stock kernel/DTB/module ABIは維持し、正式Bubble seedはp3のgeometry検査、
中断再開、p4作成、System slot検証、recovery shellを所有する外部initramfsをmatching boot
setに含める必要がある。

## Next gate

1. external initramfsをp1からloadするone-shot imageをhostで構築する。
2. initramfsはまだpartitionを書き換えず、p1/p2/p3 candidateのidentityとgeometryだけを記録する。
3. recovery SSH/logを維持した実機boot後にだけ、V90S由来first-boot state machineのhost fixtureと
   物理SD試験へ進む。
