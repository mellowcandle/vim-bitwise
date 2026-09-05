#!/bin/sh
# Integration test for the automatic hover (Neovim only).
#
# CursorMoved does not fire for a script driven with -S, so the hover cannot be
# tested in-process: this drives a real headless Neovim over RPC with
# --remote-send, which goes through the normal input loop.
set -u
cd "$(dirname "$0")/.."

if ! command -v nvim >/dev/null 2>&1; then
  echo "nvim not found, skipping integration tests"
  exit 0
fi

TMP=$(mktemp -d)
SOCK="$TMP/nvim.sock"
trap 'kill $SRV 2>/dev/null; rm -rf "$TMP"' EXIT

checks=0
failures=0

ok() {
  checks=$((checks + 1))
  if [ "$2" = "$3" ]; then
    echo "ok   - $1"
  else
    failures=$((failures + 1))
    echo "FAIL - $1 (got '$2', want '$3')"
  fi
}

cat > "$TMP/init.vim" <<'EOF'
set noswapfile nobackup nowritebackup
let &runtimepath = $BITWISE_ROOT . ',' . &runtimepath
let $PATH = $BITWISE_ROOT . '/test/stub:' . $PATH
let g:bitwise_executable = 'bitwise'
filetype plugin on
syntax enable
let g:bitwise_hover_delay = 30
let g:moved = 0
augroup bitwise_integration
  autocmd!
  autocmd CursorMoved * let g:moved += 1
augroup END
enew
call setline(1, ['nothing here', 'let mask = 0x41;', 'let n = 42;'])
EOF

BITWISE_ROOT=$(pwd); export BITWISE_ROOT
nvim --headless --listen "$SOCK" -u "$TMP/init.vim" >/dev/null 2>&1 &
SRV=$!

i=0
while [ ! -S "$SOCK" ] && [ $i -lt 50 ]; do
  sleep 0.1
  i=$((i + 1))
done
if [ ! -S "$SOCK" ]; then
  echo "FAIL - the test server did not start"
  exit 1
fi

send() { nvim --server "$SOCK" --remote-send "$1" >/dev/null 2>&1; sleep 0.5; }
q() { nvim --server "$SOCK" --remote-expr "$1" 2>&1; }

floats="len(filter(map(nvim_list_wins(), {_,w -> nvim_win_get_config(w)}), {_,c -> !empty(c.relative)}))"
first_float="filter(nvim_list_wins(), {_,w -> !empty(nvim_win_get_config(w).relative)})"
content="join(nvim_buf_get_lines(nvim_win_get_buf(($first_float)[0]), 0, 1, 0), '')"

send '2G0fx'
ok "the cursor reaches the literal"        "$(q 'bitwise#number_under_cursor()')" "0x41"
ok "CursorMoved reaches the plugin"        "$(q 'g:moved > 0')"                   "1"
ok "moving onto a hex literal opens a hover" "$(q "$floats")"                     "1"
ok "the hover shows the value"             "$(q "$content")"                      "Decimal: [0x41]"
ok "the hover does not steal focus"        "$(q 'empty(nvim_win_get_config(win_getid()).relative)')" "1"

send '1G0'
ok "moving off the literal closes the hover" "$(q "$floats")"                     "0"

send '3G0f4'
ok "a decimal literal opens a hover"       "$(q "$floats")"                       "1"
ok "the decimal hover shows the value"     "$(q "$content")"                      "Decimal: [42]"

send 'i'
ok "entering insert mode closes the hover" "$(q "$floats")"                       "0"
send '<Esc>'

nvim --server "$SOCK" --remote-expr 'execute("let g:bitwise_hover = 0")' >/dev/null 2>&1
send '1G0'
send '2G0fx'
ok "g:bitwise_hover = 0 suppresses the hover" "$(q "$floats")"                    "0"

nvim --server "$SOCK" --remote-expr 'execute("let g:bitwise_hover = 1")' >/dev/null 2>&1
send '1G0w'
ok "a non-numeric word opens no hover"     "$(q "$floats")"                       "0"

# --- explicit dismissal --------------------------------------------------
send '1G0'
send '2G0fx'
ok "hover is up before dismissing"          "$(q "$floats")"                     "1"
send ':BitwiseHoverClose<CR>'
ok ":BitwiseHoverClose closes the hover"    "$(q "$floats")"                     "0"
send 'l'
ok "it stays dismissed within the literal"  "$(q "$floats")"                     "0"
send '3G0f4'
ok "a different literal hovers again"       "$(q "$floats")"                     "1"
send ':BitwiseHoverClose<CR>'
send ':BitwiseHover<CR>'
ok ":BitwiseHover overrides a dismissal"    "$(q "$floats")"                     "1"

nvim --server "$SOCK" --remote-send ':qall!<CR>' >/dev/null 2>&1

echo "$checks checks, $failures failures"
[ "$failures" -eq 0 ]
