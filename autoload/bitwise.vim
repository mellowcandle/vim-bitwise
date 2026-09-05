" autoload/bitwise.vim -- implementation for vim-bitwise
" Author: Ramon Fried <rfried.dev@gmail.com>
" URL: https://github.com/mellowcandle/vim-bitwise

let s:save_cpo = &cpo
set cpo&vim

function! s:executable() abort
  return get(g:, 'bitwise_executable', 'bitwise')
endfunction

function! s:flags() abort
  return get(g:, 'bitwise_flags', ['--no-color'])
endfunction

function! s:error(msg) abort
  echohl ErrorMsg
  echomsg 'bitwise: ' . a:msg
  echohl None
endfunction

function! s:trim(str) abort
  return substitute(a:str, '^\_s\+\|\_s\+$', '', 'g')
endfunction

" Squash a (possibly multi-line) yank into a single expression.
function! s:flatten(str) abort
  return s:trim(substitute(a:str, '\_s\+', ' ', 'g'))
endfunction

" Results are cached by expression: the hover re-runs on every cursor stop,
" and bitwise is a pure function of its input.
let s:cache = {}
let s:cache_order = []
let s:cache_max = 256

function! s:remember(expr, lines) abort
  if !has_key(s:cache, a:expr)
    call add(s:cache_order, a:expr)
    if len(s:cache_order) > s:cache_max
      call remove(s:cache, remove(s:cache_order, 0))
    endif
  endif
  let s:cache[a:expr] = a:lines
endfunction

" True when the configured bitwise binary can be found.
function! bitwise#available() abort
  return executable(s:executable())
endfunction

" Drop trailing blank lines so output windows are sized correctly.
function! s:strip_blanks(lines) abort
  let l:lines = copy(a:lines)
  while !empty(l:lines) && empty(s:trim(l:lines[-1]))
    call remove(l:lines, -1)
  endwhile
  return l:lines
endfunction

" Run bitwise on {expr}. Returns the output as a list of lines, or an empty
" list when anything went wrong. Errors are reported unless {quiet} is set,
" which the hover uses so that a stray token never spams the message area.
function! bitwise#run(expr, ...) abort
  let l:quiet = a:0 ? a:1 : 0
  let l:expr = s:flatten(a:expr)

  if empty(l:expr)
    if !l:quiet
      call s:error('no expression given')
    endif
    return []
  endif

  if !bitwise#available()
    if !l:quiet
      call s:error(printf("'%s' was not found in $PATH -- see %s",
            \ s:executable(), 'https://github.com/mellowcandle/bitwise'))
    endif
    return []
  endif

  if has_key(s:cache, l:expr)
    return s:cache[l:expr]
  endif

  let l:argv = [s:executable()] + s:flags() + [l:expr]
  let l:cmd = join(map(copy(l:argv), 'shellescape(v:val)'))
  let l:out = systemlist(l:cmd)

  if v:shell_error
    if !l:quiet
      call s:error(printf('%s exited with %d: %s', s:executable(),
            \ v:shell_error, empty(l:out) ? '(no output)' : join(l:out, ' ')))
    endif
    return []
  endif

  let l:out = s:strip_blanks(l:out)

  if empty(l:out)
    if !l:quiet
      call s:error(printf('%s produced no output for %s', s:executable(), l:expr))
    endif
    return []
  endif

  call s:remember(l:expr, l:out)
  return l:out
endfunction

" Run bitwise on {expr} and display the result.
function! bitwise#show(expr) abort
  let l:lines = bitwise#run(a:expr)
  if empty(l:lines)
    return
  endif

  let l:title = '# ' . s:flatten(a:expr)
  let l:content = [l:title, repeat('=', strdisplaywidth(l:title))] + l:lines

  if s:style() ==# 'echo'
    call s:show_echo(l:lines)
  elseif s:style() ==# 'float'
    call s:open_float(l:content)
  else
    call s:open_split(l:content)
  endif
endfunction

" :Bitwise [expression] -- with no argument, use the word under the cursor.
function! bitwise#command(args) abort
  let l:expr = empty(s:trim(a:args)) ? expand('<cword>') : a:args
  call bitwise#show(l:expr)
endfunction

" 'operatorfunc' callback, also used directly for visual mode.
function! bitwise#operator(type) abort
  let l:reg_save = getreg('"')
  let l:regtype_save = getregtype('"')
  let l:sel_save = &selection
  set selection=inclusive

  try
    if a:type ==# 'v' || a:type ==# 'V' || a:type ==# "\<C-v>"
      silent normal! gvy
    elseif a:type ==# 'char'
      silent normal! `[v`]y
    elseif a:type ==# 'line'
      silent normal! `[V`]y
    elseif a:type ==# 'block'
      silent execute "normal! `[\<C-v>`]y"
    else
      return
    endif
    let l:expr = @@
  finally
    call setreg('"', l:reg_save, l:regtype_save)
    let &selection = l:sel_save
  endtry

  call bitwise#show(l:expr)
endfunction

" --- output ----------------------------------------------------------------

function! s:has_float() abort
  return has('nvim') && exists('*nvim_open_win')
endfunction

function! s:style() abort
  let l:style = get(g:, 'bitwise_output', s:has_float() ? 'float' : 'split')
  if l:style ==# 'float' && !s:has_float()
    return 'split'
  endif
  return l:style
endfunction

function! s:show_echo(lines) abort
  for l:line in a:lines
    echomsg l:line
  endfor
endfunction

" Configure the current buffer as the scratch output buffer.
function! s:fill(lines) abort
  setlocal modifiable noreadonly
  silent keepjumps %delete _
  call setline(1, a:lines)
  setlocal buftype=nofile bufhidden=wipe nobuflisted noswapfile
  setlocal nowrap nomodifiable nomodified readonly nonumber norelativenumber
  setlocal filetype=bitwise
  nnoremap <buffer><silent> q :close<CR>
  keepjumps 1
endfunction

" Find an already open output window in the current tab page.
function! s:find_win() abort
  for l:win in range(1, winnr('$'))
    if getwinvar(l:win, 'bitwise_output', 0)
      return l:win
    endif
  endfor
  return 0
endfunction

function! s:height(lines) abort
  let l:height = get(g:, 'bitwise_height', 0)
  if l:height > 0
    return l:height
  endif
  return min([len(a:lines), max([&lines / 2, 5])])
endfunction

function! s:open_split(lines) abort
  let l:win = s:find_win()
  if l:win
    execute l:win . 'wincmd w'
    execute 'resize' s:height(a:lines)
  else
    execute 'botright' s:height(a:lines) 'new'
    let w:bitwise_output = 1
  endif
  call s:fill(a:lines)
endfunction

function! s:open_float(lines) abort
  let l:width = 0
  for l:line in a:lines
    let l:width = max([l:width, strdisplaywidth(l:line)])
  endfor
  let l:width = min([max([l:width, 20]), &columns - 4])
  let l:height = min([len(a:lines), &lines - 4])

  let l:buf = nvim_create_buf(v:false, v:true)
  call nvim_buf_set_lines(l:buf, 0, -1, v:true, a:lines)

  let l:win = nvim_open_win(l:buf, v:true, {
        \ 'relative': 'editor',
        \ 'width': l:width,
        \ 'height': l:height,
        \ 'row': (&lines - l:height) / 2 - 1,
        \ 'col': (&columns - l:width) / 2,
        \ 'style': 'minimal',
        \ 'border': get(g:, 'bitwise_border', 'rounded'),
        \ })

  call s:fill(a:lines)
  setlocal winhighlight=Normal:NormalFloat,FloatBorder:FloatBorder
  nnoremap <buffer><silent> <Esc> :close<CR>
  augroup bitwise_float
    autocmd! * <buffer>
    execute printf('autocmd BufLeave,WinLeave <buffer> ++once silent! call nvim_win_close(%d, v:true)', l:win)
  augroup END
endfunction


" --- number under the cursor -----------------------------------------------

" A numeric literal: hex, binary, octal or decimal, with optional digit
" separators and an optional size suffix (UL, u8, usize, f64...). Anchored at
" word boundaries so identifiers like `foo123` or `deadbeef` are not mistaken
" for numbers, and guarded against grabbing one half of a float like `1.5`.
" Group 1 is the numeric core, without the suffix.
let s:suffix_pattern =
      \ '\%([uU]\?[lL]\{1,2}\|[lL]\{1,2}[uU]\?\|[uUiIfF]\d\+\|[uU]\?size\|[uUfF]\)'

let s:number_pattern =
      \ '\C\<\(0[xX]\x[0-9A-Fa-f_'']*'
      \ . '\|0[bB][01][01_'']*'
      \ . '\|0[oO][0-7][0-7_'']*'
      \ . '\|\%(\d\.\)\@<!\d[0-9_'']*\%(\.\d\)\@!'
      \ . '\)' . s:suffix_pattern . '\?\>'

" Reduce a matched token to something bitwise can parse: drop the size suffix
" (0xFFu8 -> 0xFF) and any digit separators (1_000 -> 1000).
function! s:normalize(token) abort
  let l:parts = matchlist(a:token, '^' . s:number_pattern . '$')
  let l:core = empty(l:parts) ? a:token : l:parts[1]
  return substitute(l:core, '[_'']', '', 'g')
endfunction

" The numeric literal at byte column {col} (0-based) of {line}, or ''.
function! bitwise#number_in(line, col) abort
  let l:idx = 0
  while l:idx <= len(a:line)
    let l:start = match(a:line, s:number_pattern, l:idx)
    if l:start < 0
      break
    endif
    let l:end = matchend(a:line, s:number_pattern, l:idx)
    if a:col >= l:start && a:col < l:end
      return s:normalize(strpart(a:line, l:start, l:end - l:start))
    endif
    let l:idx = l:end > l:idx ? l:end : l:idx + 1
  endwhile
  return ''
endfunction

" The numeric literal under the cursor, or ''.
function! bitwise#number_under_cursor() abort
  return bitwise#number_in(getline('.'), col('.') - 1)
endfunction

" --- hover -----------------------------------------------------------------

let s:hover_win = -1
let s:hover_expr = ''
let s:hover_timer = -1
let s:hover_seq = 0

" The literal the user explicitly dismissed. Kept until the cursor reaches a
" different one, so dismissing means dismissed rather than 'back in 250ms'.
let s:dismissed = ''

function! s:has_popup() abort
  return !has('nvim') && has('popupwin')
endfunction

" True when this editor can show a hover at the cursor at all.
function! bitwise#hover_supported() abort
  return s:has_float() || s:has_popup()
endfunction

" On by default under Neovim, where bitwise runs off the main loop. Vim has no
" async job here, so its hover is opt-in rather than a blocking surprise.
function! bitwise#hover_default() abort
  return has('nvim') ? 1 : 0
endfunction

function! bitwise#hover_enabled() abort
  return get(g:, 'bitwise_hover', bitwise#hover_default()) && bitwise#hover_supported()
endfunction

function! bitwise#hover_toggle() abort
  let g:bitwise_hover = !get(g:, 'bitwise_hover', bitwise#hover_default())
  if !g:bitwise_hover
    call bitwise#hover_close()
  endif
  echo 'bitwise: hover ' . (g:bitwise_hover ? 'enabled' : 'disabled')
endfunction

" Explicitly dismiss the hover and keep it away for the literal under the
" cursor. Unlike hover_close(), which is the plumbing used when the cursor
" moves, this records the user's intent.
function! bitwise#hover_dismiss() abort
  let s:dismissed = bitwise#number_under_cursor()
  call s:cancel_timer()
  " Invalidate anything still in flight, so a late job cannot re-open it.
  let s:hover_seq += 1
  call bitwise#hover_close()
endfunction

function! s:cancel_timer() abort
  if s:hover_timer >= 0
    call timer_stop(s:hover_timer)
    let s:hover_timer = -1
  endif
endfunction

function! bitwise#hover_close() abort
  let s:hover_expr = ''
  if s:hover_win > 0
    if has('nvim')
      silent! call nvim_win_close(s:hover_win, v:true)
    else
      silent! call popup_close(s:hover_win)
    endif
  endif
  let s:hover_win = -1
endfunction

function! s:hover_visible() abort
  if s:hover_win <= 0
    return 0
  endif
  return has('nvim') ? nvim_win_is_valid(s:hover_win) : !empty(popup_getpos(s:hover_win))
endfunction

" Buffers where a hover would be noise rather than help.
function! s:hover_blocked() abort
  return mode() !=# 'n'
        \ || pumvisible()
        \ || !empty(&buftype)
        \ || &filetype ==# 'bitwise'
endfunction

" The hover is otherwise silent, but a missing binary is a setup problem the
" user has to know about: say so once, then never again for the session.
let s:warned_missing = 0

function! s:warn_missing_once() abort
  if s:warned_missing
    return
  endif
  let s:warned_missing = 1
  echohl WarningMsg
  echomsg printf("bitwise: hover is idle -- '%s' was not found in $PATH "
        \ . '(:checkhealth bitwise, or :help bitwise-troubleshooting)',
        \ s:executable())
  echohl None
endfunction

" Called from CursorMoved: debounce, so we only run once the cursor settles.
function! bitwise#hover_schedule() abort
  call s:cancel_timer()

  if !bitwise#hover_enabled()
    call bitwise#hover_close()
    return
  endif

  " A dismissal lapses as soon as the cursor reaches a different literal.
  let l:here = bitwise#number_under_cursor()
  if l:here !=# s:dismissed
    let s:dismissed = ''
  elseif !empty(s:dismissed)
    call bitwise#hover_close()
    return
  endif

  " Keep an open hover up while the cursor stays on the same literal.
  if s:hover_visible() && bitwise#number_under_cursor() ==# s:hover_expr
        \ && !empty(s:hover_expr)
    return
  endif
  call bitwise#hover_close()

  if s:hover_blocked()
    return
  endif

  let l:delay = max([get(g:, 'bitwise_hover_delay', 250), 1])
  let s:hover_timer = timer_start(l:delay, function('s:hover_fire'))
endfunction

function! s:hover_fire(...) abort
  let s:hover_timer = -1
  call bitwise#hover(1)
endfunction

" Show the hover for the literal under the cursor. With {quiet} set (the
" automatic path) an absent or unparsable number is silently ignored.
function! bitwise#hover(...) abort
  let l:quiet = a:0 ? a:1 : 0

  if !l:quiet
    let s:dismissed = ''
  endif

  if !bitwise#hover_supported()
    if !l:quiet
      call bitwise#show(expand('<cword>'))
    endif
    return
  endif

  if l:quiet && s:hover_blocked()
    return
  endif

  let l:expr = bitwise#number_under_cursor()
  if empty(l:expr)
    if !l:quiet
      call s:error('no number under the cursor')
    endif
    return
  endif

  if !bitwise#available()
    if l:quiet
      call s:warn_missing_once()
    else
      call s:error(printf("'%s' was not found in $PATH -- see %s",
            \ s:executable(), 'https://github.com/mellowcandle/bitwise'))
    endif
    return
  endif

  let s:hover_seq += 1
  let l:seq = s:hover_seq

  if has('nvim')
    call s:run_async(l:expr, l:seq)
  else
    let l:lines = bitwise#run(l:expr, 1)
    if !empty(l:lines)
      call s:hover_open(l:expr, l:lines)
    endif
  endif
endfunction

" Neovim: run bitwise off the main loop so a cursor stop never blocks input.
function! s:run_async(expr, seq) abort
  if has_key(s:cache, a:expr)
    call s:hover_ready(a:expr, a:seq, s:cache[a:expr])
    return
  endif

  let l:out = []
  let l:argv = [s:executable()] + s:flags() + [a:expr]

  call jobstart(l:argv, {
        \ 'stdout_buffered': v:true,
        \ 'on_stdout': {job, data, event -> extend(l:out, data)},
        \ 'on_exit': {job, code, event -> code == 0
        \     ? s:hover_ready(a:expr, a:seq, s:strip_blanks(l:out)) : 0},
        \ })
endfunction

function! s:hover_ready(expr, seq, lines) abort
  " A newer request, or a cursor that has since moved on, wins.
  if a:seq != s:hover_seq || empty(a:lines)
    return
  endif
  if bitwise#number_under_cursor() !=# a:expr
    return
  endif
  call s:remember(a:expr, a:lines)
  call s:hover_open(a:expr, a:lines)
endfunction

function! s:hover_open(expr, lines) abort
  call bitwise#hover_close()

  if s:has_popup()
    let s:hover_win = popup_atcursor(a:lines, {
          \ 'padding': [0, 1, 0, 1],
          \ 'border': [],
          \ 'borderchars': ['─', '│', '─', '│', '╭', '╮', '╯', '╰'],
          \ 'moved': 'any',
          \ 'highlight': 'Pmenu',
          \ })
    let s:hover_expr = a:expr
    return
  endif

  let l:width = 0
  for l:line in a:lines
    let l:width = max([l:width, strdisplaywidth(l:line)])
  endfor
  let l:width = min([l:width, &columns - 4])
  let l:height = min([len(a:lines), &lines - 4])

  let l:buf = nvim_create_buf(v:false, v:true)
  call nvim_buf_set_lines(l:buf, 0, -1, v:true, a:lines)
  call setbufvar(l:buf, '&modifiable', 0)
  call setbufvar(l:buf, '&bufhidden', 'wipe')
  call setbufvar(l:buf, '&filetype', 'bitwise')

  " Prefer below the cursor, flip above when there is no room.
  let l:below = (&lines - screenrow()) > (l:height + 2)

  let s:hover_win = nvim_open_win(l:buf, v:false, {
        \ 'relative': 'cursor',
        \ 'anchor': l:below ? 'NW' : 'SW',
        \ 'row': l:below ? 1 : 0,
        \ 'col': 0,
        \ 'width': l:width,
        \ 'height': l:height,
        \ 'style': 'minimal',
        \ 'border': get(g:, 'bitwise_border', 'rounded'),
        \ 'focusable': v:false,
        \ 'noautocmd': v:true,
        \ })

  call setwinvar(s:hover_win, '&winhighlight', 'Normal:NormalFloat,FloatBorder:FloatBorder')
  call setwinvar(s:hover_win, '&wrap', 0)
  let s:hover_expr = a:expr
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: ts=2 sw=2 et
