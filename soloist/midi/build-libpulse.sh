#!/bin/sh
# Runs inside rust:1-bookworm or debian:bookworm. Cross-builds apulse 0.1.13 with
# apulse-midi.patch for armhf against Debian bookworm's ALSA and GLib.
# Linking against the real, versioned libasound matters: unversioned references to
# snd_pcm_hw_params_*_near bind to the obsolete ALSA_0.9 ABI on the station and abort.
set -eu
here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
out=${1:-"$here/../../libpulse.so.0"}
dpkg --add-architecture armhf
apt-get update -qq
apt-get install -y -qq git gcc-arm-linux-gnueabihf libc6-dev-armhf-cross \
    libasound2-dev:armhf libglib2.0-dev:armhf >/dev/null
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT HUP INT TERM
git clone -q https://github.com/i-rinat/apulse "$work/apulse"
cd "$work/apulse"
git checkout -q 0f9f84877baec02e72435fdfc27ef6d273ff5a8b
git apply "$here/apulse-midi.patch"
mkdir build
for f in apulse-channel-map apulse-common apulse-context apulse-ext apulse-format-info \
    apulse-mainloop apulse-misc apulse-operation apulse-proplist apulse-signal \
    apulse-stream apulse-threaded-mainloop apulse-volume ringbuffer util trace; do
    arm-linux-gnueabihf-gcc -std=gnu99 -O2 -fPIC -fvisibility=hidden -pthread \
        -DCONFIG_TRACE_LEVEL=0 -DCONFIG_LOG_TO_STDERR=0 \
        -Isrc -I3rdparty/pulseaudio-headers \
        -I/usr/include/glib-2.0 -I/usr/lib/arm-linux-gnueabihf/glib-2.0/include \
        -c "src/$f.c" -o "build/$f.o"
done
arm-linux-gnueabihf-gcc -shared -pthread -o build/libpulse.so.0 -Wl,-soname,libpulse.so.0 \
    -Wl,--version-script=src/symbolmap build/*.o -lglib-2.0 -lasound -lm
arm-linux-gnueabihf-strip --strip-unneeded build/libpulse.so.0
if ! arm-linux-gnueabihf-readelf -V build/libpulse.so.0 | grep -q 'Name: ALSA_0.9.0rc4'; then
    echo 'libpulse.so.0 is not bound to the versioned ALSA ABI' >&2
    exit 1
fi
cp build/libpulse.so.0 "$out"
chmod 755 "$out"
ls -la "$out"
echo LIBPULSE_OK
