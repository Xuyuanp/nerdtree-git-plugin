" ============================================================================
" File:        autoload/gitstatus/job.vim
" Description: git status indicator syntax highlighting
" Maintainer:  Xuyuan Pang <xuyuanp at gmail dot com>
" License:     This program is free software. It comes without any warranty,
"              to the extent permitted by applicable law. You can redistribute
"              it and/or modify it under the terms of the Do What The Fuck You
"              Want To Public License, Version 2, as published by Sam Hocevar.
"              See http://sam.zoy.org/wtfpl/COPYING for more details.
" ============================================================================
if !get(g:, 'NERDTreeGitStatusEnable', 0)
    finish
endif

function! s:getIndicator(status) abort
    return gitstatus#getIndicator(a:status)
endfunction

if gitstatus#shouldConceal()
    " Hide the backets
    syntax match hideBracketsInNerdTreeL "\]" contained conceal containedin=NERDTreeFlags
    syntax match hideBracketsInNerdTreeR "\[" contained conceal containedin=NERDTreeFlags
    setlocal conceallevel=3
    setlocal concealcursor=nvic
endif

function! s:highlightFromGroup(group) abort
    let synid = synIDtrans(hlID(a:group))
    let [ctermfg, guifg] = [synIDattr(synid, 'fg', 'cterm'), synIDattr(synid, 'fg', 'gui')]
    return 'cterm=NONE ctermfg=' . ctermfg . ' ctermbg=NONE gui=NONE guifg=' . guifg . ' guibg=NONE'
endfunction

let s:synlist = [
            \ ['Unmerged',  'Function'],
            \ ['Modified',  'Special'],
            \ ['Staged',    'Function'],
            \ ['Renamed',   'Title'],
            \ ['Unmerged',  'Label'],
            \ ['Untracked', 'Comment'],
            \ ['Dirty',     'Tag'],
            \ ['Deleted',   'Operator'],
            \ ['Ignored',   'SpecialKey'],
            \ ['Clean',     'Method'],
            \ ]

for [s:name, s:group] in s:synlist
    let indicator = escape(s:getIndicator(s:name), '\#-*.$')
    let synname = 'NERDTreeGitStatus' . s:name
    execute 'silent! syntax match ' . synname . ' #\m\C\zs[' . indicator . ']\ze[^\]]*\]# containedin=NERDTreeFlags'
    let hipat = get(get(g:, 'NERDTreeGitStatusHighlightingCustom', {}),
                \ s:name,
                \ s:highlightFromGroup(s:group))
    execute 'silent! highlight ' . synname . ' ' . hipat
endfor
