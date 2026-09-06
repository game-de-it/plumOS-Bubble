FROM debian:bookworm-slim@sha256:60eac759739651111db372c07be67863818726f754804b8707c90979bda511df

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        alsa-utils autoconf automake binutils build-essential busybox-static ca-certificates cmake curl \
        dosfstools dropbear-bin e2fsprogs fdisk file git jq libasound2-dev libdrm-dev \
        libbrotli-dev libbz2-dev libegl1-mesa-dev libflac-dev libfreetype6-dev \
        libgbm-dev libgles2-mesa-dev libglib2.0-0 libharfbuzz-dev libjpeg-dev \
        liblz4-dev liblzma-dev liblzo2-2 liblzo2-dev libmpg123-dev libncurses-dev \
        libogg-dev libopus-dev libopusfile-dev libpixman-1-dev libpng-dev \
        libreadline-dev libsdl2-dev libsdl2-gfx-dev libsdl2-image-dev \
        libsdl2-mixer-dev libsdl2-ttf-dev libsndfile1-dev libtool libudev-dev \
        libvorbis-dev libxkbcommon-dev meson mtools ninja-build parted \
        pkg-config python3 python3-pip rsync squashfs-tools unzip wpasupplicant \
        xz-utils zip zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*
