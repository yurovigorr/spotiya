#!/bin/sh
# Runs inside rust:1-bookworm (arm64 or amd64). Cross-builds spotiya for armv7 against Debian bookworm (glibc 2.36).
set -eu
dpkg --add-architecture armhf
apt-get update -qq
apt-get install -y -qq gcc-arm-linux-gnueabihf libc6-dev-armhf-cross libasound2-dev:armhf pkg-config >/dev/null
cd /src
export CARGO_TARGET_DIR=/target
export CARGO_TARGET_ARMV7_UNKNOWN_LINUX_GNUEABIHF_LINKER=arm-linux-gnueabihf-gcc
export CC_armv7_unknown_linux_gnueabihf=arm-linux-gnueabihf-gcc
export AR_armv7_unknown_linux_gnueabihf=arm-linux-gnueabihf-ar
export PKG_CONFIG_ALLOW_CROSS=1
export PKG_CONFIG_LIBDIR=/usr/lib/arm-linux-gnueabihf/pkgconfig
export CARGO_TARGET_ARMV7_UNKNOWN_LINUX_GNUEABIHF_RUSTFLAGS="-C target-cpu=cortex-a53 -C link-arg=-Wl,--gc-sections -C link-arg=-Wl,-z,max-page-size=4096"
cargo build --locked --release --target armv7-unknown-linux-gnueabihf
cp /target/armv7-unknown-linux-gnueabihf/release/spotiya /src/spotiya.armv7
ls -la /src/spotiya.armv7
echo BUILD_OK
