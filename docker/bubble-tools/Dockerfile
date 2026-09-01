FROM debian:bookworm-slim@sha256:60eac759739651111db372c07be67863818726f754804b8707c90979bda511df

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        alsa-utils binutils build-essential busybox-static ca-certificates curl \
        dosfstools dropbear-bin e2fsprogs fdisk git jq libasound2-dev libdrm-dev \
        libfreetype6-dev libpng-dev libudev-dev libxkbcommon-dev mtools parted \
        pkg-config python3 squashfs-tools wpasupplicant xz-utils \
    && rm -rf /var/lib/apt/lists/*
