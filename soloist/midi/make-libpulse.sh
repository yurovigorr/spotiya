#!/bin/sh
# Builds a working PulseAudio->ALSA shim (libpulse.so.0) for Soloist on Yandex Station Midi.
#
# The apulse shipped in the Spotiya 0.10.1 Soloist compatibility package does not work on
# Midi: it fails to load (undefined __ldexp/__frexp) and, once loaded, aborts in ALSA
# (snd1_pcm_hw_param_get_min assertion) or segfaults. The stock Ubuntu 24.04 armhf apulse
# works with the bundled glibc 2.38. One instruction is changed so that
# pa_context_set_sink_input_volume only acknowledges the request: Spotiya already drives
# the ALSA Master control, and stock apulse would attenuate the stream a second time.
#
# Usage: sh make-libpulse.sh [OUTPUT]      (default: ./libpulse.so.0)
# Needs: curl, tar with zstd support (GNU tar + zstd, or bsdtar), sha256sum or shasum, dd.
set -eu
out=${1:-libpulse.so.0}
deb_url=https://ports.ubuntu.com/pool/universe/a/apulse/apulse_0.1.13-2build2_armhf.deb
deb_sha=07892e71a00f7a807a95a9f37b10625e394c145ab8199279bd607ec4c5143882
lib_sha=9431aaf13fe3a232d6dad5adf3555fdbfa72c8daedd35ef381cd8e65f9e0e5bb
out_sha=2c6ad47b4cdfa064c7e878a2c0fa945a9985df89e61f1821fad148d387bb7809
lib_path=usr/lib/arm-linux-gnueabihf/apulse/libpulse.so.0

sha() {
    if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1
    else shasum -a 256 "$1" | cut -d' ' -f1; fi
}
check() {
    [ "$(sha "$1")" = "$2" ] || { echo "checksum mismatch: $1" >&2; exit 1; }
}

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT HUP INT TERM
curl --fail --location --retry 3 --output "$work/apulse.deb" "$deb_url"
check "$work/apulse.deb" "$deb_sha"
if command -v ar >/dev/null 2>&1; then
    (cd "$work" && ar x apulse.deb data.tar.zst)
else
    tar -xf "$work/apulse.deb" -C "$work" data.tar.zst
fi
tar -xf "$work/data.tar.zst" -C "$work" "./$lib_path"
check "$work/$lib_path" "$lib_sha"
cp "$work/$lib_path" "$work/libpulse.so.0"
# pa_context_set_sink_input_volume_impl, file offset 0x7610: "movs r2, #0x80" -> "b +0x2c"
# (skip copying the requested volume into the stream; still report success).
printf '\026\340' | dd of="$work/libpulse.so.0" bs=1 seek=30224 conv=notrunc 2>/dev/null
check "$work/libpulse.so.0" "$out_sha"
cp "$work/libpulse.so.0" "$out"
chmod 755 "$out"
echo "wrote $out"
