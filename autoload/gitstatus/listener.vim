" ============================================================================
" File:        autoload/gitstatus/listener.vim
" Description: nerdtree event listener
" Maintainer:  Xuyuan Pang <xuyuanp at gmail dot com>
" License:     This program is free software. It comes without any warranty,
"              to the extent permitted by applicable law. You can redistribute
"              it and/or modify it under the terms of the Do What The Fuck You
"              Want To Public License, Version 2, as published by Sam Hocevar.
"              See http://sam.zoy.org/wtfpl/COPYING for more details.
" ============================================================================
if exists('g:loaded_nerdtree_git_status_listener')
    finish
endif
let g:loaded_nerdtree_git_status_listener = 1

let s:Listener = {
            \ 'current': {},
            \ 'next': {},
            \ }

" disabled ProhibitImplicitScopeVariable because we will use lots of `self`
" vint: -ProhibitImplicitScopeVariable
function! s:Listener.OnInit(event) abort
    call self.callback(a:event)
endfunction

function! s:Listener.OnRefresh(event) abort
    call self.callback(a:event)
endfunction

function! s:Listener.OnRefreshFlags(event) abort
    call self.callback(a:event)
endfunction

function! s:Listener.callback(event) abort
    let l:path = a:event.subject
    let l:indicator = self.getIndicatorByPath(l:path)
    call l:path.flagSet.clearFlags('git')
    if l:indicator !=# ''
        if gitstatus#shouldConceal()
            let l:indicator = printf(' %s ', l:indicator)
        endif
        call l:path.flagSet.addFlag('git', l:indicator)
    endif
endfunction

function!s:Listener.getIndicatorByPath(path) abort
    let l:pathStr = gitstatus#util#FormatPath(a:path)
    let l:statusKey = get(self.current, l:pathStr, '')

    if l:statusKey !=# ''
        return gitstatus#getIndicator(l:statusKey)
    endif

    if get(self.opts, 'NERDTreeGitStatusShowClean', 0)
        return gitstatus#getIndicator('Clean')
    endif

    if get(self.opts, 'NERDTreeGitStatusConcealBrackets', 0) && get(self.opts, 'NERDTreeGitStatusAlignIfConceal', 0)
        return ' '
    endif
    return ''
endfunction

function! s:Listener.SetNext(cache) abort
    let self.next = a:cache
    return self.Changed()
endfunction

function! s:Listener.Changed() abort
    return !s:dictEqual(self.current, self.next)
endfunction

function! s:Listener.Update() abort
    let self.current = self.next
endfunction
" vint: +ProhibitImplicitScopeVariable

function! s:dictEqual(c1, c2) abort
    if len(a:c1) != len(a:c2)
        return 0
    endif
    for [l:key, l:value] in items(a:c1)
        if !has_key(a:c2, l:key) || a:c2[l:key] !=# l:value
            return 0
        endif
    endfor
    return 1
endfunction

function! gitstatus#listener#New(opts) abort
    return extend(deepcopy(s:Listener), {'opts': a:opts})
endfunction
