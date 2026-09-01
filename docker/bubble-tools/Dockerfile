FROM debian:bookworm-slim@sha256:60eac759739651111db372c07be67863818726f754804b8707c90979bda511df

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        busybox-static dosfstools e2fsprogs fdisk git mtools parted python3 squashfs-tools \
    && rm -rf /var/lib/apt/lists/*
