# vim-bitwise
Vim plugin for Bitwise integration

# Synopsys
This vim plugin adds integration for [Bitwise](https://github.com/mellowcandle/bitwise "Bitwise")
into vim.

Currently it supports:
* *:Bitwise <expression>* command, that will launch _bitwise_ in command mode and output the result in a new split.
* <LEADER>b binding that will run _bitwise_ in command mode on the word under cursor.

## Installation
Make sure you have _bitwise_ installed and available in your $PATH.
### Manual
Just drop the bitwise.vim into ~/.vim/plugin folder.
### Vundle
Add the following line to _Vundle_
```Plugin 'mellowcandle/vim-bitwise'```
Run ```BundleInstall```

## Contribution
I'm not a real vim-script developer and I'm sure that the plugin can be
standarized and made better, if you happen to know vim-script, contributions are most welcome.



