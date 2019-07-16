" Vim plug-in
" Author: Ramon Fried <rfried.dev@gmail.com>
" Last Change: July 14, 2019
" URL: https://github.com/mellowcandle/vim-bitwise

" Don't source the plug-in when it's already been loaded or &compatible is set.
if &cp || exists('g:loaded_vim_bitwise')
  finish
endif

if !executable('bitwise')
		echom "Bitwise is not installed on this system or not in path"
    finish
endif

" Make sure the plug-in is only loaded once.
let g:loaded_vim_bitwise = 1

" Taken from https://vim.fandom.com/wiki/Display_output_of_shell_commands_in_new_window
command! -complete=shellcmd -nargs=+ Shell call s:RunShellCommand(<q-args>)
function! s:RunShellCommand(cmdline)
  echo a:cmdline
  let expanded_cmdline = a:cmdline
  for part in split(a:cmdline, ' ')
     if part[0] =~ '\v[%#<]'
        let expanded_part = fnameescape(expand(part))
        let expanded_cmdline = substitute(expanded_cmdline, part, expanded_part, '')
     endif
  endfor
  botright new
  setlocal buftype=nofile bufhidden=wipe nobuflisted noswapfile nowrap
  call setline(1, '# ' . a:cmdline)
  call setline(2,substitute(getline(2),'.','=','g'))
  execute '$read !'. expanded_cmdline
  setlocal nomodifiable
  1
endfunction

command! -nargs=+ Bitwise call s:RunShellCommand('bitwise --no-color '.<q-args>)
noremap <silent> <leader>b :call <SID>RunShellCommand('bitwise --no-color '.expand('<cword>'))<CR>
" vim: ts=2 sw=2 et
