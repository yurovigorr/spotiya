#!/bin/sh
# Installs the Midi apulse fix on a station over SSH (dropbear on port 2222 by default).
# Usage: sh install.sh STATION_IP [PORT]   (after build-libpulse.sh produced libpulse.so.0)
set -eu
ip=${1:?usage: install.sh STATION_IP [PORT]}
port=${2:-2222}
here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
lib=${SPOTIYA_LIBPULSE:-"$here/../../libpulse.so.0"}
[ -f "$lib" ] || { echo "build libpulse.so.0 first (see soloist/midi/README.md)" >&2; exit 1; }
remote() { ssh -p "$port" "root@$ip" "$@"; }
# dropbear has no sftp-server: copy through cat.
remote 'cat > /data/opt/libpulse.so.0.novol && chmod 755 /data/opt/libpulse.so.0.novol' < "$lib"
remote 'cat > /data/opt/spotiya-fix.sh && chmod 755 /data/opt/spotiya-fix.sh' < "$here/spotiya-fix.sh"
remote 'grep -q spotiya-fix /etc/init.d/S99spotify-connect || {
    mount -o remount,rw / &&
    sed -i "s#^\s*start)\$#    start)\n        [ -x /data/opt/spotiya-fix.sh ] \&\& /data/opt/spotiya-fix.sh#" /etc/init.d/S99spotify-connect
    sync; mount -o remount,ro /
}
/data/opt/spotiya-fix.sh
spotiya restart'
echo "done: select the station in Spotify and press play"
