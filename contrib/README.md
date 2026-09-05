# Recording the demo GIF

`assets/demo.gif` is recorded headlessly, so it comes out identical every time
and needs no desktop session. Requires `Xvfb`, `xfce4-terminal`, `xdotool` and
`ffmpeg`.

```sh
Xvfb :99 -screen 0 1100x680x24 &     # virtual display
./contrib/record-scene.sh            # terminal + nvim on :99, sample file
./contrib/record-demo.sh             # drives nvim over RPC while ffmpeg captures
```

Then turn the capture into a GIF:

```sh
cd <scratch dir used by the scripts>
ffmpeg -i raw.mp4 -vf "fps=10,scale=780:-1:flags=lanczos,palettegen=stats_mode=diff" -y palette.png
ffmpeg -i raw.mp4 -i palette.png \
  -lavfi "fps=10,scale=780:-1:flags=lanczos[x];[x][1:v]paletteuse=dither=bayer:bayer_scale=3:diff_mode=rectangle" \
  -loop 0 -y demo.gif
```

Notes:

* Keystrokes go in over `--remote-send` rather than `xdotool type`, so the
  timing is deterministic and does not depend on window focus.
* Navigation uses `$`, `j` and `w` on purpose. `f{char}` would be intercepted
  by flash.nvim, which paints jump labels over the very numbers being shown.
* The pointer is parked in the corner; otherwise it sits in the middle of
  every frame.
