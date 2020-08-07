" ============================================================================
" File:        autoload/gitstatus.vim
" Description: library for indicators
" Maintainer:  Xuyuan Pang <xuyuanp at gmail dot com>
" License:     This program is free software. It comes without any warranty,
"              to the extent permitted by applicable law. You can redistribute
"              it and/or modify it under the terms of the Do What The Fuck You
"              Want To Public License, Version 2, as published by Sam Hocevar.
"              See http://sam.zoy.org/wtfpl/COPYING for more details.
" ============================================================================
scriptencoding utf-8

if exists('g:loaded_nerdtree_git_status_autoload')
    finish
endif
let g:loaded_nerdtree_git_status_autoload = 1

function! gitstatus#isWin() abort
    return has('win16') || has('win32') || has('win64')
endfunction

if get(g:, 'NERDTreeGitStatusUseNerdFonts', 0)
    let s:indicatorMap = {
                \ 'Modified'  :'',
                \ 'Staged'    :'',
                \ 'Untracked' :'',
                \ 'Renamed'   :'',
                \ 'Unmerged'  :'',
                \ 'Deleted'   :'',
                \ 'Dirty'     :'',
                \ 'Ignored'   :'',
                \ 'Clean'     :'',
                \ 'Unknown'   :''
                \ }
else
    let s:indicatorMap = {
                \ 'Modified'  :'✹',
                \ 'Staged'    :'✚',
                \ 'Untracked' :'✭',
                \ 'Renamed'   :'➜',
                \ 'Unmerged'  :'═',
                \ 'Deleted'   :'✖',
                \ 'Dirty'     :'✗',
                \ 'Ignored'   :'☒',
                \ 'Clean'     :'✔︎',
                \ 'Unknown'   :'?'
                \ }
endif

function! gitstatus#getIndicator(status) abort
    return get(get(g:, 'NERDTreeGitStatusIndicatorMapCustom', {}),
                \ a:status,
                \ s:indicatorMap[a:status])
endfunction

function! gitstatus#shouldConceal() abort
    return has('conceal') && g:NERDTreeGitStatusConcealBrackets
endfunction
