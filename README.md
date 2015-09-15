nerdtree-git-plugin
===================

A plugin of NERDTree showing git status flags. Works with the **LATEST** version of NERDTree.

The original project [git-nerdtree](https://github.com/Xuyuanp/git-nerdtree) will not be maintained any longer.


![Imgur](http://i.imgur.com/jSCwGjU.gif?1)

## Installation

For Vundle

`Plugin 'scrooloose/nerdtree'`

`Plugin 'Xuyuanp/nerdtree-git-plugin'`

For NeoBundle

`NeoBundle 'scrooloose/nerdtree'`

`NeoBundle 'Xuyuanp/nerdtree-git-plugin'`

## Configuration

Use this variable to change symbols.

**Note** that `~` is only allowed for modified and dirty

```vimscript
let g:NERDTreeIndicatorMapCustom = {
    \ "Modified"  : "✹",
    \ "Staged"    : "✚",
    \ "Untracked" : "✭",
    \ "Renamed"   : "➜",
    \ "Unmerged"  : "═",
    \ "Deleted"   : "✖",
    \ "Dirty"     : "✗",
    \ "Clean"     : "✔︎",
    \ "Unknown"   : "?"
    \ }
```

## Credits

*  [scrooloose](https://github.com/scrooloose): Open API for me.
*  [git_nerd](https://github.com/swerner/git_nerd): Where my idea comes from.
