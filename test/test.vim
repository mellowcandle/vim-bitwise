" Test suite for vim-bitwise. Runs under both vim and neovim:
"   vim  -es -u test/vimrc -S test/test.vim
"   nvim --headless -u test/vimrc -S test/test.vim
" Exits non-zero when a check fails.

let s:failures = []
let s:checks = 0

function! s:ok(cond, name) abort
  let s:checks += 1
  if a:cond
    call s:out('ok   - ' . a:name)
  else
    call add(s:failures, a:name)
    call s:out('FAIL - ' . a:name)
  endif
endfunction

function! s:eq(got, want, name) abort
  call s:ok(a:got ==# a:want, a:name . ' (got ' . string(a:got) . ', want ' . string(a:want) . ')')
endfunction

function! s:out(msg) abort
  verbose echomsg a:msg
endfunction

" Contents of the visible bitwise output window, if any.
function! s:output() abort
  for l:win in range(1, winnr('$'))
    if getbufvar(winbufnr(l:win), '&filetype') ==# 'bitwise'
      return getbufline(winbufnr(l:win), 1, '$')
    endif
  endfor
  return []
endfunction

function! s:close_output() abort
  for l:win in range(1, winnr('$'))
    if getbufvar(winbufnr(l:win), '&filetype') ==# 'bitwise'
      execute l:win . 'wincmd w'
      close!
      return
    endif
  endfor
endfunction

" --- setup -----------------------------------------------------------------

let $PATH = expand('<sfile>:p:h') . '/stub:' . $PATH
" test/vimrc may have pointed at a real binary; the suite always uses the stub.
let g:bitwise_executable = 'bitwise'
let g:bitwise_output = 'split'
" The automatic hover fires from a timer; keep it out of the other tests and
" enable it explicitly in the hover section below.
let g:bitwise_hover = 0

" --- tests -----------------------------------------------------------------

call s:ok(exists(':Bitwise') == 2, ':Bitwise command is defined')
call s:ok(bitwise#available(), 'stub bitwise is found on $PATH')

" :Bitwise with an explicit expression
Bitwise 0x30
let s:lines = s:output()
call s:eq(get(s:lines, 0, ''), '# 0x30', ':Bitwise writes a header line')
call s:eq(get(s:lines, 1, ''), '======', ':Bitwise underlines the header')
call s:eq(get(s:lines, 2, ''), 'Decimal: [0x30]', ':Bitwise passes the expression through')
call s:ok(index(s:lines, '') < 0, 'trailing blank lines are stripped')
call s:eq(&filetype, 'bitwise', 'output buffer gets filetype=bitwise')
call s:eq(&modifiable, 0, 'output buffer is not modifiable')
call s:ok(!empty(maparg('q', 'n')), 'q is mapped to close the output window')

" Multi-word expressions survive :command splitting
Bitwise 1 + 2
call s:eq(get(s:output(), 2, ''), 'Decimal: [1 + 2]', ':Bitwise keeps multi-word expressions intact')

" Reuse: a second run must not stack windows
let s:before = winnr('$')
Bitwise 0x40
call s:eq(winnr('$'), s:before, 'output window is reused, not stacked')
call s:eq(get(s:output(), 2, ''), 'Decimal: [0x40]', 'reused window shows the new result')
call s:close_output()

" Operator, charwise (<Leader>biw over a word)
new
call setline(1, 'value = 0xdeadbeef;')
normal! 1G0fx
execute "normal \<Plug>(bitwise-operator)iw"
call s:eq(get(s:output(), 2, ''), 'Decimal: [0xdeadbeef]', 'operator + iw runs on the word under cursor')
call s:close_output()

" Operator, charwise inside parentheses
call setline(1, 'foo(1 << 4)')
normal! 1G0
execute "normal \<Plug>(bitwise-operator)i("
call s:eq(get(s:output(), 2, ''), 'Decimal: [1 << 4]', 'operator + i( runs on the text inside ()')
call s:close_output()

" Visual charwise
call setline(1, 'mask 0xff end')
normal! 1G0w
execute "normal v3l\<Plug>(bitwise-operator)"
call s:eq(get(s:output(), 2, ''), 'Decimal: [0xff]', 'charwise visual selection is used verbatim')
call s:close_output()

" Visual linewise: trailing newline must not leak into the expression
call setline(1, '  0x11  ')
normal! 1G0
execute "normal V\<Plug>(bitwise-operator)"
call s:eq(get(s:output(), 2, ''), 'Decimal: [0x11]', 'linewise visual selection is trimmed')
call s:close_output()

" Visual blockwise
call setline(1, ['a 0x1 b', 'c 0x2 d'])
normal! 1G0
execute "normal \<C-v>jll\<Plug>(bitwise-operator)"
call s:eq(get(s:output(), 2, ''), 'Decimal: [a 0 c 0]', 'blockwise visual selection is flattened')
call s:close_output()

" The unnamed register must survive the operator
call setline(1, 'keepme 0x22')
normal! 1G0
let @" = 'sentinel'
normal! 1G0f0
execute "normal \<Plug>(bitwise-operator)iw"
call s:eq(@", 'sentinel', 'operator restores the unnamed register')
call s:close_output()

" :Bitwise with no argument falls back to the word under the cursor
call setline(1, 'cword 0x99')
normal! 1G0f9
Bitwise
call s:eq(get(s:output(), 2, ''), 'Decimal: [0x99]', ':Bitwise with no argument uses <cword>')
call s:close_output()

" bitwise#run returns the raw output
call s:eq(bitwise#run('0x7')[0], 'Decimal: [0x7]', 'bitwise#run returns the output lines')

" Failure paths must not open a window and must not throw
let s:before = winnr('$')
silent! call bitwise#show('fail')
call s:eq(winnr('$'), s:before, 'a failing bitwise run opens no window')
silent! call bitwise#show('empty')
call s:eq(winnr('$'), s:before, 'empty bitwise output opens no window')
silent! call bitwise#show('   ')
call s:eq(winnr('$'), s:before, 'a blank expression opens no window')

" Missing executable is reported instead of crashing
let g:bitwise_executable = 'bitwise-does-not-exist'
call s:ok(!bitwise#available(), 'a missing binary is detected')
silent! call bitwise#show('0x1')
call s:eq(winnr('$'), s:before, 'a missing binary opens no window')
unlet g:bitwise_executable

" Configuration knobs
let g:bitwise_flags = ['--no-color', '--version']
call s:eq(bitwise#run('0x1')[0], 'bitwise stub 0.0', 'g:bitwise_flags is honoured')
unlet g:bitwise_flags

let g:bitwise_height = 3
Bitwise 0x50
call s:eq(winheight(0), 3, 'g:bitwise_height sets the split height')
call s:close_output()
unlet g:bitwise_height

" Neovim float output
if has('nvim') && exists('*nvim_open_win')
  let g:bitwise_output = 'float'
  let s:before = winnr('$')
  Bitwise 0x60
  let s:cfg = nvim_win_get_config(win_getid())
  call s:eq(get(s:cfg, 'relative', ''), 'editor', 'float output opens a floating window')
  call s:eq(get(s:output(), 2, ''), 'Decimal: [0x60]', 'float window shows the result')
  call s:ok(!empty(maparg('<Esc>', 'n')), '<Esc> closes the float')
  call s:close_output()
  let g:bitwise_output = 'split'
" The automatic hover fires from a timer; keep it out of the other tests and
" enable it explicitly in the hover section below.
let g:bitwise_hover = 0

  " Health check must load and run
  call s:ok(luaeval('pcall(require, "bitwise.health")'), ':checkhealth module loads')
  call s:ok(luaeval('pcall(require("bitwise.health").check)'), ':checkhealth bitwise runs')
endif

" --- number detection ------------------------------------------------------

function! s:num(line, col) abort
  return bitwise#number_in(a:line, a:col)
endfunction

call s:eq(s:num('x = 0x30;', 5), '0x30', 'detects hex literal')
call s:eq(s:num('x = 0x30;', 4), '0x30', 'detects hex from its first char')
call s:eq(s:num('x = 0x30;', 7), '0x30', 'detects hex from its last char')
call s:eq(s:num('x = 0b1010;', 6), '0b1010', 'detects binary literal')
call s:eq(s:num('x = 0o17;', 6), '0o17', 'detects octal literal')
call s:eq(s:num('x = 42;', 4), '42', 'detects decimal literal')
call s:eq(s:num('mask 0xDEADBEEF end', 10), '0xDEADBEEF', 'detects uppercase hex')
call s:eq(s:num('x = 0xFFu8;', 6), '0xFF', 'strips a size suffix')
call s:eq(s:num('x = 1_000;', 5), '1000', 'strips digit separators')
call s:eq(s:num('x = 0x1f_u8 + 1;', 6), '0x1f', 'strips separators and suffix together')
call s:eq(s:num('a + b', 2), '', 'no number means no match')
call s:eq(s:num('foo123 = 1', 4), '', 'digits inside an identifier are ignored')
call s:eq(s:num('deadbeef', 3), '', 'a bare hex-looking word is ignored')
call s:eq(s:num('x = 1.5;', 6), '', 'the fraction part of a float is ignored')
call s:eq(s:num('x = 1.5;', 4), '', 'the integer part of a float is ignored')
call s:eq(s:num('', 0), '', 'an empty line is handled')
call s:eq(s:num('x = 5', 99), '', 'a column past the end is handled')
call s:eq(s:num('1 22 333', 5), '333', 'picks the literal the cursor is on')
call s:eq(s:num('1 22 333', 2), '22', 'picks the middle literal')

" --- hover -----------------------------------------------------------------

call s:ok(exists(':BitwiseHover') == 2, ':BitwiseHover is defined')
call s:ok(exists(':BitwiseHoverToggle') == 2, ':BitwiseHoverToggle is defined')
call s:ok(exists(':BitwiseHoverClose') == 2, ':BitwiseHoverClose is defined')
call s:ok(!empty(maparg('<Plug>(bitwise-hover-close)', 'n')),
      \ '<Plug>(bitwise-hover-close) is defined')
" <Esc> must not be claimed unless asked for.
call s:eq(maparg('<Esc>', 'n'), '', '<Esc> is left alone by default')

if bitwise#hover_supported()
  unlet g:bitwise_hover
  call s:eq(bitwise#hover_enabled(), has('nvim') ? 1 : 0,
        \ 'hover defaults on under neovim and off under vim')
  let g:bitwise_hover = 1

  new
  call setline(1, 'let mask = 0x30;')
  normal! 1G0fx
  call s:eq(bitwise#number_under_cursor(), '0x30', 'number_under_cursor reads the cursor position')

  " Synchronous hover, so the test does not race the async job.
  let s:lines = bitwise#run('0x30', 1)
  call s:eq(get(s:lines, 0, ''), 'Decimal: [0x30]', 'hover payload comes from bitwise')

  " Hover on a number opens a window without moving focus.
  let s:curwin = win_getid()
  call bitwise#hover()
  if has('nvim')
    " The nvim path is async; give the job a moment to land.
    let s:waited = 0
    while s:waited < 2000 && winnr('$') < 2
      sleep 20m
      let s:waited += 20
    endwhile
  endif
  call s:eq(win_getid(), s:curwin, 'hover does not steal focus')

  let s:hover = 0
  for s:w in range(1, winnr('$'))
    if getbufvar(winbufnr(s:w), '&filetype') ==# 'bitwise' && winbufnr(s:w) != bufnr('%')
      let s:hover = s:w
    endif
  endfor
  if has('nvim')
    call s:ok(s:hover > 0, 'hover opens a window')
    call s:eq(get(getbufline(winbufnr(s:hover), 1), 0, ''), 'Decimal: [0x30]', 'hover shows the value')
    let s:cfg = nvim_win_get_config(win_getid(s:hover))
    " nvim reports a cursor-relative float back as window-relative.
    call s:ok(!empty(get(s:cfg, 'relative', '')), 'hover is a floating window')
    call s:eq(get(s:cfg, 'win', s:curwin), s:curwin, 'hover floats over the current window')
    call s:eq(get(s:cfg, 'focusable', v:true), v:false, 'hover window is not focusable')
  else
    call s:ok(!empty(popup_list()), 'hover opens a popup')
  endif

  " Moving off the number closes it.
  call bitwise#hover_close()
  let s:still_open = 0
  if has('nvim')
    for s:w in range(1, winnr('$'))
      if getbufvar(winbufnr(s:w), '&filetype') ==# 'bitwise' && winbufnr(s:w) != bufnr('%')
        let s:still_open = 1
      endif
    endfor
  else
    let s:still_open = !empty(popup_list())
  endif
  call s:ok(!s:still_open, 'hover_close closes the hover')

  " Hover on a non-number is a no-op, not an error.
  call setline(1, 'plain words here')
  normal! 1G0
  let s:before = winnr('$')
  silent! call bitwise#hover(1)
  call s:eq(winnr('$'), s:before, 'quiet hover on a non-number opens nothing')

  " Toggling off must suppress scheduling.
  let g:bitwise_hover = 0
  call s:ok(!bitwise#hover_enabled(), 'g:bitwise_hover = 0 disables the hover')
  call bitwise#hover_schedule()
  call s:eq(winnr('$'), s:before, 'a disabled hover schedules nothing')
  let g:bitwise_hover = 1

  " A missing binary must be reported once, and only once: the hover is
  " otherwise silent, so without this it just looks broken.
  "
  " Only runs under Neovim: the vim half of the suite runs in Ex mode (-es),
  " where mode() is not 'n' and the automatic hover correctly declines to fire.
  if mode() ==# 'n'
  new
  call setline(1, 'mask = 0x30;')
  normal! 1G0fx
  let g:bitwise_executable = 'bitwise-does-not-exist'
  messages clear
  " Not :silent -- that would keep the warning out of the message history,
  " which is exactly what we need to inspect here.
  call bitwise#hover(1)
  call bitwise#hover(1)
  call bitwise#hover(1)
  let s:msgs = filter(split(execute('messages'), '\n'), 'v:val =~# "hover is idle"')
  call s:eq(len(s:msgs), 1, 'a missing binary warns exactly once')
  call s:ok(s:msgs[0] =~# 'not found in \$PATH', 'the warning says what is wrong')
  unlet g:bitwise_executable
  bwipe!
  endif

  " Note: the automatic (CursorMoved-driven) hover cannot be tested here --
  " CursorMoved does not fire for a script run with -S. See test/integration.sh.

  bwipe!
endif

" --- report ----------------------------------------------------------------

call s:out(printf('%d checks, %d failures', s:checks, len(s:failures)))
if empty(s:failures)
  qall!
else
  cquit!
endif
