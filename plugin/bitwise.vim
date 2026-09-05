" Vim plug-in
" Author: Ramon Fried <rfried.dev@gmail.com>
" URL: https://github.com/mellowcandle/vim-bitwise
"
" Integration for bitwise: https://github.com/mellowcandle/bitwise

" Don't source the plug-in when it's already been loaded or &compatible is set.
if &cp || exists('g:loaded_vim_bitwise')
  finish
endif
let g:loaded_vim_bitwise = 1

let s:save_cpo = &cpo
set cpo&vim

" Note: the bitwise binary is looked up when a command is run, not here, so
" that installing bitwise afterwards doesn't require restarting vim.

command! -nargs=* Bitwise      call bitwise#command(<q-args>)
command! -nargs=0 BitwiseHover call bitwise#hover()
command! -nargs=0 BitwiseHoverToggle call bitwise#hover_toggle()
command! -nargs=0 BitwiseHoverClose  call bitwise#hover_dismiss()

nnoremap <silent> <Plug>(bitwise-operator) :<C-u>set operatorfunc=bitwise#operator<CR>g@
xnoremap <silent> <Plug>(bitwise-operator) :<C-u>call bitwise#operator(visualmode())<CR>
nnoremap <silent> <Plug>(bitwise-line)     :<C-u>call bitwise#show(getline('.'))<CR>
nnoremap <silent> <Plug>(bitwise-cword)    :<C-u>call bitwise#show(expand('<cword>'))<CR>
nnoremap <silent> <Plug>(bitwise-hover)    :<C-u>call bitwise#hover()<CR>
nnoremap <silent> <Plug>(bitwise-hover-close) :<C-u>call bitwise#hover_dismiss()<CR>

if !get(g:, 'bitwise_no_mappings', 0)
  if !hasmapto('<Plug>(bitwise-operator)', 'n') && empty(maparg('<Leader>b', 'n'))
    nmap <Leader>b <Plug>(bitwise-operator)
  endif
  if !hasmapto('<Plug>(bitwise-operator)', 'x') && empty(maparg('<Leader>b', 'x'))
    xmap <Leader>b <Plug>(bitwise-operator)
  endif
endif

" Opt-in <Esc> dismissal. Off by default: mapping <Esc> in normal mode makes
" the editor wait 'ttimeoutlen' to tell a real <Esc> from an arrow key's escape
" sequence, which is a poor default to impose. Only claims <Esc> if nothing
" else has it.
if get(g:, 'bitwise_hover_esc', 0) && empty(maparg('<Esc>', 'n'))
  nmap <Esc> <Plug>(bitwise-hover-close)
endif

" Hover: show the value under the cursor in a floating window / popup as soon
" as the cursor settles on a numeric literal. On by default under Neovim, where
" bitwise runs off the main loop; opt in with g:bitwise_hover = 1 under Vim,
" whose popup path runs bitwise synchronously.
if has('nvim') ? exists('*nvim_open_win') : has('popupwin')
  augroup bitwise_hover
    autocmd!
    autocmd CursorMoved,BufEnter *
          \ if get(g:, 'bitwise_hover', has('nvim')) | call bitwise#hover_schedule() | endif
    autocmd InsertEnter,BufLeave,WinLeave,TabLeave,CmdlineEnter *
          \ if get(g:, 'bitwise_hover', has('nvim')) | call bitwise#hover_close() | endif
  augroup END
endif

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: ts=2 sw=2 et
