#!/bin/sh
# Runs on the station before Spotify Connect starts (see README.md in this directory).
# Reinstalling or updating the Soloist add-on restores the broken apulse; put ours back.
GOOD=/data/opt/libpulse.so.0.novol
CUR=/data/opt/solo/lib/libpulse.so.0
[ -f "$GOOD" ] && [ -f "$CUR" ] || exit 0
if ! cmp -s "$GOOD" "$CUR"; then
    cp "$CUR" "$CUR.orig" 2>/dev/null
    cp "$GOOD" "$CUR" && chmod 755 "$CUR"
    echo "spotiya-fix: libpulse.so.0 restored" >> /tmp/spotiya-fix.log
fi
