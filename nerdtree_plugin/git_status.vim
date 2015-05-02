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

if g:NERDTreeShowGitStatus == 0
    finish
endif

if !exists('g:NERDTreeMapNextHunk')
    let g:NERDTreeMapNextHunk = "]c"
endif

if !exists('g:NERDTreeMapPrevHunk')
    let g:NERDTreeMapPrevHunk = "[c"
endif

if !exists('g:NERDTreeUpdateOnWrite')
    let g:NERDTreeUpdateOnWrite = 1
endif

if !exists('g:NERDTreeUpdateOnCursorHold')
    let g:NERDTreeUpdateOnCursorHold = 1
endif

if !exists('g:NERDTreeIndicatorMap')
    let g:NERDTreeIndicatorMap = {
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


function! NERDTreeGitStatusRefreshListener(event)
    if !exists('b:NOT_A_GIT_REPOSITORY')
        call g:NERDTreeGitStatusRefresh()
    endif
    let path = a:event.subject
    let flag = g:NERDTreeGetGitStatusPrefix(path)
    call path.flagSet.clearFlags("git")
    if flag != ''
        call path.flagSet.addFlag("git", flag)
    endif
endfunction

" FUNCTION: g:NERDTreeGitStatusRefresh() {{{2
" refresh cached git status
function! g:NERDTreeGitStatusRefresh()
    let b:NERDTreeCachedGitFileStatus = {}
    let b:NERDTreeCachedGitDirtyDir   = {}
    let b:NOT_A_GIT_REPOSITORY        = 1

    let root = b:NERDTreeRoot.path.str()
    let statusesStr = system("cd " . root . " && git status -s")
    let statusesSplit = split(statusesStr, '\n')
    if statusesSplit != [] && statusesSplit[0] =~# "fatal:.*"
        let statusesSplit = []
        return
    endif
    let b:NOT_A_GIT_REPOSITORY = 0

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
        let statusKey = s:NERDTreeGetFileGitStatusKey(statusLine[0], statusLine[1])
        let b:NERDTreeCachedGitFileStatus[fnameescape(pathStr)] = statusKey

        call s:NERDTreeCacheDirtyDir(pathStr)
    endfor
endfunction

function! s:NERDTreeCacheDirtyDir(pathStr)
    " cache dirty dir
    let dirtyPath = s:NERDTreeTrimDoubleQuotes(a:pathStr)
    if dirtyPath =~# '\.\./.*'
        return
    endif
    let dirtyPath = substitute(dirtyPath, '/[^/]*$', "/", "")
    while dirtyPath =~# '.\+/.*' && has_key(b:NERDTreeCachedGitDirtyDir, fnameescape(dirtyPath)) == 0
        let b:NERDTreeCachedGitDirtyDir[fnameescape(dirtyPath)] = "Dirty"
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
let s:GitStatusCacheTimeExpiry = 2
let s:GitStatusCacheTime = 0
function! g:NERDTreeGetGitStatusPrefix(path)
    if localtime() - s:GitStatusCacheTime > s:GitStatusCacheTimeExpiry
        let s:GitStatusCacheTime = localtime()
        call g:NERDTreeGitStatusRefresh()
    endif
    let pathStr = a:path.str()
    let cwd = b:NERDTreeRoot.path.str() . a:path.Slash()
    if nerdtree#runningWindows()
        let pathStr = a:path.WinToUnixPath(pathStr)
        let cwd = a:path.WinToUnixPath(cwd)
    endif
    let pathStr = substitute(pathStr, fnameescape(cwd), "", "")
    let statusKey = ""
    if a:path.isDirectory
        let statusKey = get(b:NERDTreeCachedGitDirtyDir, fnameescape(pathStr . '/'), "")
    else
        let statusKey = get(b:NERDTreeCachedGitFileStatus, fnameescape(pathStr), "")
    endif
    return s:NERDTreeGetIndicator(statusKey)
endfunction

" FUNCTION: s:NERDTreeGetCWDGitStatus() {{{2
" return the indicator of cwd
function! g:NERDTreeGetCWDGitStatus()
    if b:NOT_A_GIT_REPOSITORY
        return ""
    elseif b:NERDTreeCachedGitDirtyDir == {} && b:NERDTreeCachedGitFileStatus == {}
        return s:NERDTreeGetIndicator("Clean")
    endif
    return s:NERDTreeGetIndicator("Dirty")
endfunction

function! s:NERDTreeGetIndicator(statusKey)
    let indicator = get(g:NERDTreeIndicatorMap, a:statusKey, "")
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

augroup nerdtreegitplugin
    autocmd CursorHold * silent! call s:CursorHoldUpdate()
augroup END
" FUNCTION: s:CursorHoldUpdate() {{{2
function! s:CursorHoldUpdate()
    if g:NERDTreeUpdateOnCursorHold != 1
        return
    endif

    if !g:NERDTree.IsOpen()
        return
    endif

    let winnr = winnr()
    call g:NERDTree.CursorToTreeWin()
    let node = b:NERDTreeRoot.refreshFlags()
    call NERDTreeRender()
    exec winnr . "wincmd w"
endfunction

augroup nerdtreegitplugin
    autocmd BufWritePost * call s:FileUpdate(expand("%:p"))
augroup END

" FUNCTION: s:FileUpdate(fname) {{{2
function! s:FileUpdate(fname)
    if g:NERDTreeUpdateOnWrite != 1
        return
    endif
    if !g:NERDTree.IsOpen()
        return
    endif

    let winnr = winnr()

    call g:NERDTree.CursorToTreeWin()
    let node = b:NERDTreeRoot.findNode(g:NERDTreePath.New(a:fname))
    if node == {}
        return
    endif
    call node.refreshFlags()
    let node = node.parent
    while !empty(node)
        call node.refreshDirFlags()
        let node = node.parent
    endwhile

    call NERDTreeRender()
    exec winnr . "wincmd w"
endfunction

autocmd FileType nerdtree call s:AddHighlighting()
function! s:AddHighlighting()
    syn match NERDTreeGitStatusModified #✹# containedin=NERDTreeFlags
    syn match NERDTreeGitStatusAdded #✚# containedin=NERDTreeFlags
    syn match NERDTreeGitStatusUntracked #✭# containedin=NERDTreeFlags
    syn match NERDTreeGitStatusRenamed #➜# containedin=NERDTreeFlags
    syn match NERDTreeGitStatusDirDirty #✗# containedin=NERDTreeFlags
    syn match NERDTreeGitStatusDirClean #✔︎# containedin=NERDTreeFlags
 
    hi def link NERDTreeGitStatusModified Special
    hi def link NERDTreeGitStatusAdded Function
    hi def link NERDTreeGitStatusRenamed Title
    hi def link NERDTreeGitStatusUnmerged Label
    hi def link NERDTreeGitStatusUntracked Comment
    hi def link NERDTreeGitStatusDirDirty Tag
    hi def link NERDTreeGitStatusDirClean DiffAdd
endfunction

function! s:SetupListeners()
    call g:NERDTreePathNotifier.AddListener("init", "NERDTreeGitStatusRefreshListener")
    call g:NERDTreePathNotifier.AddListener("refresh", "NERDTreeGitStatusRefreshListener")
    call g:NERDTreePathNotifier.AddListener("refreshFlags", "NERDTreeGitStatusRefreshListener")
endfunction

if g:NERDTreeShowGitStatus && executable('git')
    call s:NERDTreeGitStatusKeyMapping()
    call s:SetupListeners()
endif
