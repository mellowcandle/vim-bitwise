" Syntax for the vim-bitwise output buffer and hover.
"
" Calibrated against bitwise v0.60 output, which looks like:
"
"   Unsigned decimal: 48
"   Hexadecimal: 0x30
"   IPv4 (Network byte order - Big):  0.0.0.48
"   Binary:
"   0 0 1 1 0 0 0 0
"        7 -  0

if exists('b:current_syntax')
  finish
endif

" Generic values first; the more specific items below are defined afterwards
" so they win where both could match at the same position.
syntax match bitwiseNumber "\<\d\+\>"
syntax match bitwiseHex    "\<0[xX]\x\+\>"
syntax match bitwiseBinary "\<0[bB][01]\+\>"

" `Unsigned decimal:`, `IPv4 (Network byte order - Big):`, ...
syntax match bitwiseLabel  "^\s*\a[^:]*\ze:"

" The bit grid, and the `31 - 24    23 - 16` ruler beneath it. Set bits are
" picked out so the pattern is readable at a glance.
syntax match bitwiseRuler  "^[ 0-9|-]*\d\+\s*-\s*\d\+[ 0-9|-]*$"
syntax match bitwiseBits   "^[01][01 |]*$" contains=bitwiseBitSet
syntax match bitwiseBitSet "1" contained

" Header written by :Bitwise and the split output.
syntax match bitwiseHeader "^#.*$"
syntax match bitwiseRule   "^=\+$"

highlight default link bitwiseHeader Title
highlight default link bitwiseRule   Comment
highlight default link bitwiseLabel  Identifier
highlight default link bitwiseNumber Number
highlight default link bitwiseHex    Number
highlight default link bitwiseBinary Constant
highlight default link bitwiseRuler  Comment
highlight default link bitwiseBits   Comment
highlight default link bitwiseBitSet Constant

let b:current_syntax = 'bitwise'

" vim: ts=2 sw=2 et
