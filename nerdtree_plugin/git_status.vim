" ============================================================================
" File:        git_status.vim
" Description: plugin for NERD Tree that provides git status support
" Maintainer:  Xuyuan Pang <xuyuanp at gmail dot com>
" Last Change: 4 Apr 2014
" License:     This program is free software. It comes without any warranty,
"              to the extent permitted by applicable law. You can redistribute
"              it and/or modify it under the terms of the Do What The Fuck You
"              Want To Public License, Version 2, as published by Sam Hocevar.
"              See http://sam.zoy.org/wtfpl/COPYING for more details.
" ============================================================================
if exists('g:loaded_nerdtree_git_status')
    finish
endif
let g:loaded_nerdtree_git_status = 1

if !exists('g:NERDTreeShowGitStatus')
    let g:NERDTreeShowGitStatus = 1
endif

if !exists('g:NERDTreeMapNextHunk')
    let g:NERDTreeMapNextHunk = "]c"
endif

if !exists('g:NERDTreeMapPrevHunk')
    let g:NERDTreeMapPrevHunk = "[c"
endif

if !exists('g:NERDTreeUseSimpleIndicator')
    let g:NERDTreeUseSimpleIndicator = 0
endif

if !exists("g:NERDTreeUseGitToMove")
    let g:NERDTreeUseGitToMove = 1
endif

if !exists("g:NERDTreeUseGitToDelete")
    let g:NERDTreeUseGitToDelete = 1
endif

if !exists('s:NERDTreeIndicatorMap')
    let s:NERDTreeIndicatorMap = {}
    if g:NERDTreeUseSimpleIndicator
        let s:NERDTreeIndicatorMap = {
                    \ "Modified"  : "~",
                    \ "Staged"    : "+",
                    \ "Untracked" : "*",
                    \ "Renamed"   : "»",
                    \ "Unmerged"  : "=",
                    \ "Deleted"   : "-",
                    \ "Dirty"     : "×",
                    \ "Clean"     : "ø",
                    \ "Unknown"   : "?"
                    \ }
    else
        let s:NERDTreeIndicatorMap = {
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
    endif
endif

function! g:NERDTreeGitStatusRefreshListener(path, params)
    let flag = g:NERDTreeGetGitStatusPrefix(a:path)
    if flag != ''
        call a:path.flagSet.clearFlags("git", '')
        call a:path.flagSet.addFlag("git", flag)
    else
        call a:path.flagSet.clearFlags("git", '')
    endif
endfunction

function! g:NERDTreeGitStatusRefreshPathListener(path, params)
    call g:NERDTreeGitStatusRefresh(a:path)
endfunction

" FUNCTION: g:NERDTreeGitStatusRefresh() {{{2
" refresh cached git status
function! g:NERDTreeGitStatusRefresh(path)
    let g:NERDTreeCachedGitFileStatus = {}
    let g:NERDTreeCachedGitDirtyDir   = {}
    let s:NOT_A_GIT_REPOSITORY        = 1

    " check if git command exists
    if !executable('git')
        call nerdtree#echo("Please install git command first.")
        return
    endif

    let root = a:path.str()
    " let root = getcwd()
    let statusesStr = system("cd " . root . " && git status -s")
    " let statusesStr = system("git status -s")
    let statusesSplit = split(statusesStr, '\n')
    if statusesSplit != [] && statusesSplit[0] =~# "fatal:.*"
        let statusesSplit = []
        return
    endif
    let s:NOT_A_GIT_REPOSITORY = 0

    for statusLine in statusesSplit
        " cache git status of files
        let pathStr = substitute(statusLine, '...', "", "")
        let pathSplit = split(pathStr, ' -> ')
        if len(pathSplit) == 2
            call s:NERDTreeCacheDirtyDir(pathSplit[0])
            let pathStr = pathSplit[1]
        else
            let pathStr = pathSplit[0]
        endif
        let pathStr = s:NERDTreeTrimDoubleQuotes(pathStr)
        if pathStr =~# '\.\./.*'
            continue
        endif
        let statusKey     = s:NERDTreeGetFileGitStatusKey(statusLine[0], statusLine[1])
        let g:NERDTreeCachedGitFileStatus[fnameescape(pathStr)] = statusKey

        call s:NERDTreeCacheDirtyDir(pathStr)
    endfor
endfunction

function! s:NERDTreeCacheDirtyDir(pathStr)
    " cache dirty dir
    let dirtyPath = s:NERDTreeTrimDoubleQuotes(a:pathStr)
    if dirtyPath =~# '\.\./.*'
        return
    endif
    let dirtyPath = dirtyPath
    let dirtyPath = substitute(dirtyPath, '/[^/]*$', "/", "")
    let cwd = fnameescape('./')
    while dirtyPath =~# '.\+/.*' && has_key(g:NERDTreeCachedGitDirtyDir, fnameescape(dirtyPath)) == 0
        let g:NERDTreeCachedGitDirtyDir[fnameescape(dirtyPath)] = "Dirty"
        let dirtyPath = substitute(dirtyPath, '/[^/]*/$', "/", "")
    endwhile
endfunction

function! s:NERDTreeTrimDoubleQuotes(pathStr)
    let toReturn = substitute(a:pathStr, '^"', "", "")
    let toReturn = substitute(toReturn, '"$', "", "")
    return toReturn
endfunction

" FUNCTION: g:NERDTreeGetGitStatusPrefix(path) {{{2
" return the indicator of the path
" Args: path
function! g:NERDTreeGetGitStatusPrefix(path)
    let pathStr = a:path._str()
    let cwd = b:NERDTreeRoot.path._str() . a:path.Slash()
    if nerdtree#runningWindows()
        let pathStr = a:path.WinToUnixPath(pathStr)
        let cwd = a:path.WinToUnixPath(cwd)
    endif
    let pathStr = substitute(pathStr, fnameescape(cwd), "", "")
    let statusKey = ""
    if a:path.isDirectory
        let statusKey = get(g:NERDTreeCachedGitDirtyDir, fnameescape(pathStr . '/'), "")
    else
        let statusKey = get(g:NERDTreeCachedGitFileStatus, fnameescape(pathStr), "")
    endif
    return s:NERDTreeGetIndicator(statusKey)
endfunction

" FUNCTION: s:NERDTreeGetCWDGitStatus() {{{2
" return the indicator of cwd
function! g:NERDTreeGetCWDGitStatus()
    if s:NOT_A_GIT_REPOSITORY
        return ""
    elseif g:NERDTreeCachedGitDirtyDir == {} && g:NERDTreeCachedGitFileStatus == {}
        return s:NERDTreeGetIndicator("Clean")
    endif
    return s:NERDTreeGetIndicator("Dirty")
endfunction

function! s:NERDTreeGetIndicator(statusKey)
    let indicator = get(s:NERDTreeIndicatorMap, a:statusKey, "")
    if indicator != ""
        return indicator
    endif
    return ''
endfunction

function! s:NERDTreeGetFileGitStatusKey(us, them)
    if a:us == '?' && a:them == '?'
        return "Untracked"
    elseif a:us == ' ' && a:them == 'M'
        return "Modified"
    elseif a:us =~# '[MAC]'
        return "Staged"
    elseif a:us == 'R'
        return "Renamed"
    elseif a:us == 'U' || a:them == 'U' || a:us == 'A' && a:them == 'A' || a:us == 'D' && a:them == 'D'
        return "Unmerged"
    elseif a:them == 'D'
        return "Deleted"
    else
        return "Unknown"
    endif
endfunction

" FUNCTION: s:jumpToNextHunk(node) {{{2
function! s:jumpToNextHunk(node)
    let position = search('\[[^{RO}]\+\]', "")
    if position
        call nerdtree#echo("Jump to next hunk ")
    endif
endfunction

" FUNCTION: s:jumpToPrevHunk(node) {{{2
function! s:jumpToPrevHunk(node)
    let position = search('\[[^{RO}]\+\]', "b")
    if position
        call nerdtree#echo("Jump to prev hunk ")
    endif
endfunction

" Function: s:SID()   {{{2
function s:SID()
    if !exists("s:sid")
        let s:sid = matchstr(expand('<sfile>'), '<SNR>\zs\d\+\ze_SID$')
    endif
    return s:sid
endfun

" FUNCTION: s:NERDTreeGitStatusKeyMapping {{{2
function! s:NERDTreeGitStatusKeyMapping()
    let s = '<SNR>' . s:SID() . '_'
    call NERDTreeAddKeyMap({'key': g:NERDTreeMapNextHunk, 'scope': "Node", 'callback': s."jumpToNextHunk"})
    call NERDTreeAddKeyMap({'key': g:NERDTreeMapPrevHunk, 'scope': "Node", 'callback': s."jumpToPrevHunk"})
endfunction

if g:NERDTreeShowGitStatus
    call s:NERDTreeGitStatusKeyMapping()

    call g:NERDTreeRefreshNotifier.AddListenerForAction('RenderView', 'g:NERDTreeGitStatusRefreshPathListener')
    call g:NERDTreeRefreshNotifier.AddListenerForAction('CacheDisplayString', 'g:NERDTreeGitStatusRefreshListener')
    call g:NERDTreeRefreshNotifier.AddListenerForAction('RootRefresh', 'g:NERDTreeGitStatusRefreshPathListener')
    call g:NERDTreeRefreshNotifier.AddListenerForAction('CurrentNodeRefresh', 'g:NERDTreeGitStatusRefreshPathListener')
endif
