#!/bin/sh
# Run the vim-bitwise test suite against every editor available.
set -e
cd "$(dirname "$0")/.."

status=0
ran=0

if command -v vim >/dev/null 2>&1; then
  ran=1
  echo "== vim =="
  vim -es -u test/vimrc -S test/test.vim 2>&1 || status=1
fi

if command -v nvim >/dev/null 2>&1; then
  ran=1
  echo "== nvim =="
  nvim --headless -u test/vimrc -S test/test.vim 2>&1 || status=1
fi

echo "== integration (nvim hover) =="
./test/integration.sh || status=1

if [ "$ran" -eq 0 ]; then
  echo "neither vim nor nvim found" >&2
  exit 1
fi

exit "$status"
