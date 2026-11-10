#!/bin/sh
# Installs the Midi apulse fix on a station over SSH (dropbear on port 2222 by default).
# Usage: sh install.sh STATION_IP [PORT]
set -eu
ip=${1:?usage: install.sh STATION_IP [PORT]}
port=${2:-2222}
here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
sh "$here/make-libpulse.sh" "$tmp/libpulse.so.0"
remote() { ssh -p "$port" "root@$ip" "$@"; }
# dropbear has no sftp-server: copy through cat.
remote 'cat > /data/opt/libpulse.so.0.novol && chmod 755 /data/opt/libpulse.so.0.novol' < "$tmp/libpulse.so.0"
remote 'cat > /data/opt/spotiya-fix.sh && chmod 755 /data/opt/spotiya-fix.sh' < "$here/spotiya-fix.sh"
remote 'grep -q spotiya-fix /etc/init.d/S99spotify-connect || {
    mount -o remount,rw / &&
    sed -i "s#^\s*start)\$#    start)\n        [ -x /data/opt/spotiya-fix.sh ] \&\& /data/opt/spotiya-fix.sh#" /etc/init.d/S99spotify-connect
    sync; mount -o remount,ro /
}
/data/opt/spotiya-fix.sh
spotiya restart'
echo "done: select the station in Spotify and press play"
