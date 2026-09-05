#!/bin/bash
#
# Companion to contrib/record-scene.sh. See contrib/README.md.
# Record the demo: drive nvim over RPC while ffmpeg captures the X window.
S="$(cd "$(dirname "$0")" && pwd)"
export DISPLAY=:99
SOCK="$S/demo.sock"

send() { timeout 5 nvim --server "$SOCK" --remote-send "$1" >/dev/null 2>&1; }

# Reset to a clean opening frame.
send '<Esc><Esc>'
timeout 5 nvim --server "$SOCK" --remote-expr 'execute("silent! only")' >/dev/null 2>&1
send ':1<CR>'
send '3G0'
sleep 2

ffmpeg -loglevel error -f x11grab -video_size 926x554 -framerate 12 -i :99+0,0 \
       -t 21 -y "$S/raw.mp4" &
FF=$!
sleep 1.2

send '$';        sleep 2.2     # 0x40011000
send 'j';        sleep 2.6     # 0x8040201  -- the 8.4.2.1 bit pattern
send 'j';        sleep 2.2     # 0xDEADBEEF
send 'j';        sleep 2.2     # 0b10101010
send 'j';        sleep 2.0     # 115200
send '<C-w>z';   sleep 1.4     # dismiss it
send '12G0';     sleep 0.4
for i in 1 2 3 4 5; do send 'w'; sleep 0.22; done
send 'gbi(';     sleep 3.4     # operator over the expression in ()
wait $FF
echo "captured: $(du -h "$S/raw.mp4" | cut -f1)"
