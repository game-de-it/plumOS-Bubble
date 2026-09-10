# Low-level boot forensics scope

Date: 2026-09-10

## Decision

Bubbleだけに、U-Boot active environmentの保存offset・冗長性、UART `printenv`、boot source
fallbackの故意の発動をrelease必須条件として要求しない。他のplumOSシリーズと同じく、再現imageを
安全に起動・復旧できるために必要なboot substrateとmatching setの証跡を acceptance boundary とする。

## Evidence retained

- SD先頭16 MiB、RKNS/FIT/BL3X主要header、boot payloadのsize/hash
- kernel、DTB/overlay、boot script、uEnv、System A/Bのmatching set
- image write後のblock readbackとcold boot
- runtime cmdline、root UUID、initramfs handoff、`${filesize}`による実size採用
- persistent boot stage、Wi-Fi/SSH recovery、known-good SD交換とnormal poweroff

これらの証跡は削除しない。将来bootloader自体を置換する場合はscopeを再評価し、その時点でactive
environment位置とfallbackを調べる。現状のvendor substrateを維持するreleaseでは追加forensicsを
行わない。
