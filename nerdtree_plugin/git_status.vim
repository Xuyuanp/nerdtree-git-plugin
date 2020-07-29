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

" stolen from nerdtree
"Function: s:initVariable() function {{{2
"This function is used to initialise a given variable to a given value. The
"variable is only initialised if it does not exist prior
"
"Args:
"var: the name of the var to be initialised
"value: the value to initialise var to
"
"Returns:
"1 if the var is set, 0 otherwise
function! s:initVariable(var, value)
    if !exists(a:var)
        exec 'let ' . a:var . ' = ' . "'" . substitute(a:value, "'", "''", 'g') . "'"
        return 1
    endif
    return 0
endfunction

function! s:migrateVariable(oldv, newv)
    if exists(a:oldv)
        exec 'let ' . a:newv . ' = ' . a:oldv
        return 1
    endif
    return 0
endfunction

let s:default_vals = {
            \ 'g:NERDTreeGitStatusEnable':             1,
            \ 'g:NERDTreeGitStatusUpdateOnWrite':      1,
            \ 'g:NERDTreeGitStatusUpdateOnCursorHold': 1,
            \ 'g:NERDTreeGitStatusShowIgnored':        0,
            \ 'g:NERDTreeGitStatusUseNerdFonts':       0,
            \ 'g:NERDTreeGitStatusDirDirtyOnly':       1,
            \ 'g:NERDTreeGitStatusMapNextHunk':        ']c',
            \ 'g:NERDTreeGitStatusMapPrevHunk':        '[c',
            \ 'g:NERDTreeGitStatusUntrackedFilesMode': 'normal',
            \ 'g:NERDTreeGitStatusGitBinPath':         'git',
            \ }

for [var, value] in items(s:default_vals)
    call s:initVariable(var, value)
endfor

let s:need_migrate_vals = {
            \ 'g:NERDTreeShowGitStatus':      'g:NERDTreeGitStatusEnable',
            \ 'g:NERDTreeUpdateOnWrite':      'g:NERDTreeGitStatusUpdateOnWrite',
            \ 'g:NERDTreeUpdateOnCursorHold': 'g:NERDTreeGitStatusUpdateOnCursorHold',
            \ 'g:NERDTreeMapNextHunk':        'g:NERDTreeGitStatusMapNextHunk',
            \ 'g:NERDTreeMapPrevHunk':        'g:NERDTreeGitStatusMapPrevHunk',
            \ 'g:NERDTreeShowIgnoredStatus':  'g:NERDTreeGitStatusShowIgnored',
            \ 'g:NERDTreeIndicatorMapCustom': 'g:NERDTreeGitStatusIndicatorMapCustom',
            \ }

for [oldv, newv] in items(s:need_migrate_vals)
    call s:migrateVariable(oldv, newv)
endfor

if !g:NERDTreeGitStatusEnable
    finish
endif

if !executable(g:NERDTreeGitStatusGitBinPath)
    call nerdtree#echoError('[git-plugin] git command not found')
    finish
endif


if g:NERDTreeGitStatusUseNerdFonts
    let s:NERDTreeIndicatorMap = {
                \ 'Modified'  :'',
                \ 'Staged'    :'',
                \ 'Untracked' :'',
                \ 'Renamed'   :'',
                \ 'Unmerged'  :'',
                \ 'Deleted'   :'',
                \ 'Dirty'     :'',
                \ 'Ignored'   :'',
                \
                \ 'Clean'     :'',
                \ 'Unknown'   :''
                \ }
else
    let s:NERDTreeIndicatorMap = {
                \ 'Modified'  :'✹',
                \ 'Staged'    :'✚',
                \ 'Untracked' :'✭',
                \ 'Renamed'   :'➜',
                \ 'Unmerged'  :'═',
                \ 'Deleted'   :'✖',
                \ 'Dirty'     :'✗',
                \ 'Ignored'   :'☒',
                \
                \ 'Clean'     :'✔︎',
                \ 'Unknown'   :'?'
                \ }
endif

function! s:get_git_version() abort
    let l:output = systemlist(g:NERDTreeGitStatusGitBinPath . ' --version')[0] " Output: git version v2.27.0
    let l:version = split(l:output[12:], '\.')
    let l:major = l:version[0]
    let l:minor = l:version[1]
    return [major, minor]
endfunction

function! s:choose_porcelain_version(git_version) abort
    " git status supports --porcelain=v2 since v2.11.0
    let [major, minor] = a:git_version
    if major < 2
        return 'v1'
    elseif minor < 11
        return 'v1'
    endif
    return 'v2'
endfunction

function! s:process_line_v1(sline) abort
    let l:pathStr = a:sline[3:]
    let l:statusKey = s:NERDTreeGetFileGitStatusKey(a:sline[0], a:sline[1])
    return [l:pathStr, l:statusKey]
endfunction

function! s:process_line_v2(sline) abort
        if a:sline[0] ==# '1'
            let l:statusKey = s:NERDTreeGetFileGitStatusKey(a:sline[2], a:sline[3])
            let l:pathStr = a:sline[113:]
        elseif a:sline[0] ==# '2'
            let l:statusKey = 'Renamed'
            let l:pathStr = a:sline[113:]
            let l:pathStr = l:pathStr[stridx(l:pathStr, ' ')+1:]
        elseif a:sline[0] ==# 'u'
            let l:statusKey = 'Unmerged'
            let l:pathStr = a:sline[161:]
        elseif a:sline[0] ==# '?'
            let l:statusKey = 'Untracked'
            let l:pathStr = a:sline[2:]
        elseif a:sline[0] ==# '!'
            let l:statusKey = 'Ignored'
            let l:pathStr = a:sline[2:]
        else
            throw '[nerdtree_git_status] unknown status: ' . a:sline
        endif
        return [l:pathStr, l:statusKey]
endfunction


let s:porcelainVersion = s:choose_porcelain_version(s:get_git_version())
let s:process_line = function('s:process_line_' . s:porcelainVersion)

function! NERDTreeGitStatusRefreshListener(event)
    if !exists('b:NOT_A_GIT_REPOSITORY')
        call g:NERDTreeGitStatusRefresh()
    endif
    let l:path = a:event.subject
    let l:flag = g:NERDTreeGitStatusGetPrefix(l:path)
    call l:path.flagSet.clearFlags('git')
    if l:flag !=# ''
        call l:path.flagSet.addFlag('git', l:flag)
    endif
endfunction

function! s:git_workdir()
    let l:output = systemlist(g:NERDTreeGitStatusGitBinPath . ' rev-parse --show-toplevel')
    if len(l:output) > 0 && l:output[0] !~# 'fatal:.*'
        return l:output[0]
    endif
    return ''
endfunction

" FUNCTION: g:NERDTreeGitStatusRefresh() {{{2
" refresh cached git status
function! g:NERDTreeGitStatusRefresh() abort
    let b:NERDTreeCachedGitFileStatus = {}
    let b:NERDTreeCachedGitDirtyDir   = {}
    let b:NOT_A_GIT_REPOSITORY        = 1

    let l:workdir = s:git_workdir()
    if l:workdir ==# ''
        return
    endif

    let l:git_args = [
                \ g:NERDTreeGitStatusGitBinPath,
                \ 'status',
                \ '--porcelain' . (s:porcelainVersion ==# 'v2' ? '=v2' : ''),
                \ '--untracked-files=' . g:NERDTreeGitStatusUntrackedFilesMode,
                \ '-z'
                \ ]
    if g:NERDTreeGitStatusShowIgnored
        let l:git_args = l:git_args + ['--ignored=traditional']
    endif
    if exists('g:NERDTreeGitStatusIgnoreSubmodules')
        let l:ignore_args = '--ignore-submodules'
        if g:NERDTreeGitStatusIgnoreSubmodules ==# 'all' ||
                    \ g:NERDTreeGitStatusIgnoreSubmodules ==# 'dirty' ||
                    \ g:NERDTreeGitStatusIgnoreSubmodules ==# 'untracked' ||
                    \ g:NERDTreeGitStatusIgnoreSubmodules ==# 'none'
            let l:ignore_args += '=' . g:NERDTreeGitStatusIgnoreSubmodules
        endif
        let l:git_args += [l:ignore_args]
    endif
    let l:git_cmd = join(l:git_args, ' ')
    " When the -z option is given, pathnames are printed as is and without any quoting and lines are terminated with a NUL (ASCII 0x00, <C-A> in vim) byte. See `man git-status`
    let l:statusLines = split(system(l:git_cmd), "\<C-A>")

    if l:statusLines != [] && l:statusLines[0] =~# 'fatal:.*'
        return
    endif
    let b:NOT_A_GIT_REPOSITORY = 0

    let l:is_rename = v:false
    for l:statusLine in l:statusLines
        " cache git status of files
        if l:is_rename
            call s:NERDTreeCacheDirtyDir(l:workdir, l:workdir . '/' . l:statusLine, 'Dirty')
            let l:is_rename = v:false
            continue
        endif
        let [l:pathStr, l:statusKey] = s:process_line(l:statusLine)

        let l:pathStr = l:workdir . '/' . l:pathStr
        let l:is_rename = l:statusKey ==# 'Renamed'
        let b:NERDTreeCachedGitFileStatus[l:pathStr] = l:statusKey

        if l:statusKey == 'Ignored'
            if isdirectory(l:pathStr)
                let b:NERDTreeCachedGitDirtyDir[l:pathStr] = l:statusKey
            endif
        else
            call s:NERDTreeCacheDirtyDir(l:workdir, l:pathStr, l:statusKey)
        endif
    endfor
endfunction

function! s:NERDTreeCacheDirtyDir(root, pathStr, statusKey) abort
    " cache dirty dir
    let l:dirtyPath = fnamemodify(a:pathStr, ':p:h')
    while l:dirtyPath !=# a:root
        let key = get(b:NERDTreeCachedGitDirtyDir, l:dirtyPath, '')
        if g:NERDTreeGitStatusDirDirtyOnly
            if key ==# ''
                let b:NERDTreeCachedGitDirtyDir[l:dirtyPath] = 'Dirty'
            else
                return
            endif
        else
            if key ==# ''
                let b:NERDTreeCachedGitDirtyDir[l:dirtyPath] = a:statusKey
            elseif key ==# 'Dirty' || key ==# a:statusKey
                return
            else
                let b:NERDTreeCachedGitDirtyDir[l:dirtyPath] = 'Dirty'
            endif
        endif
        let l:dirtyPath = fnamemodify(l:dirtyPath, ':h')
    endwhile
endfunction

" FUNCTION: g:NERDTreeGitStatusGetPrefix(path) {{{2
" return the indicator of the path
" Args: path
let s:GitStatusCacheTimeExpiry = 2
let s:GitStatusCacheTime = 0
function! g:NERDTreeGitStatusGetPrefix(path)
    if localtime() - s:GitStatusCacheTime > s:GitStatusCacheTimeExpiry
        call g:NERDTreeGitStatusRefresh()
        let s:GitStatusCacheTime = localtime()
    endif
    let l:pathStr = a:path.str()
    if a:path.isDirectory
        let l:statusKey = get(b:NERDTreeCachedGitFileStatus, l:pathStr . '/', '')
        if l:statusKey ==# ''
            let l:statusKey = get(b:NERDTreeCachedGitDirtyDir, l:pathStr, '')
        endif
    else
        let l:statusKey = get(b:NERDTreeCachedGitFileStatus, l:pathStr, '')
    endif
    if l:statusKey ==# ''
        return ''
    endif
    return s:NERDTreeGitStatusGetIndicator(l:statusKey)
endfunction

function! s:NERDTreeGitStatusGetIndicator(statusKey)
    if exists('g:NERDTreeIndicatorMapCustom')
        let l:indicator = get(g:NERDTreeIndicatorMapCustom, a:statusKey, '')
        if l:indicator !=# ''
            return l:indicator
        endif
    endif
    let l:indicator = get(s:NERDTreeIndicatorMap, a:statusKey, '')
    if l:indicator !=# ''
        return l:indicator
    endif
    return ''
endfunction

let s:unmerged_status = {
            \ 'DD': 1,
            \ 'AU': 1,
            \ 'UD': 1,
            \ 'UA': 1,
            \ 'DU': 1,
            \ 'AA': 1,
            \ 'UU': 1,
            \ }

" Function: s:NERDTreeGetFileGitStatusKey() function {{{2
" This function is used to get git status key
"
" Args:
" us: index tree
" them: work tree
"
"Returns:
" status key
function! s:NERDTreeGetFileGitStatusKey(us, them)
    let l:xy = a:us . a:them
    if get(s:unmerged_status, l:xy, 0)
        return 'Unmerged'
    elseif l:xy ==# '??'
        return 'Untracked'
    elseif l:xy ==# '!!'
        return 'Ignored'
    elseif a:them ==# 'M'
        return 'Modified'
    elseif a:them ==# 'D'
        return 'Deleted'
    elseif a:them =~# '[RC]'
        return 'Renamed'
    elseif a:us ==# 'D'
        return 'Deleted'
    elseif a:us =~# '[MA]'
        return 'Staged'
    elseif a:us =~# '[RC]'
        return 'Renamed'
    else
        return 'Unknown'
    endif
endfunction

" FUNCTION: s:jumpToNextHunk(node) {{{2
function! s:jumpToNextHunk(node)
    let l:position = search('\[[^{RO} ].*\]', '')
    if l:position
        call nerdtree#echo('[git-status] Jump to next hunk')
    endif
endfunction

" FUNCTION: s:jumpToPrevHunk(node) {{{2
function! s:jumpToPrevHunk(node)
    let l:position = search('\[[^{RO} ].*\]', 'b')
    if l:position
        call nerdtree#echo('[git-status] Jump to prev hunk')
    endif
endfunction

" Function: s:SID()   {{{2
function s:SID()
    if !exists('s:sid')
        let s:sid = matchstr(expand('<sfile>'), '<SNR>\zs\d\+\ze_SID$')
    endif
    return s:sid
endfun

" FUNCTION: s:NERDTreeGitStatusKeyMapping {{{2
function! s:NERDTreeGitStatusKeyMapping()
    let l:s = '<SNR>' . s:SID() . '_'

    call NERDTreeAddKeyMap({
        \ 'key': g:NERDTreeGitStatusMapNextHunk,
        \ 'scope': 'Node',
        \ 'callback': l:s.'jumpToNextHunk',
        \ 'quickhelpText': 'Jump to next git hunk' })

    call NERDTreeAddKeyMap({
        \ 'key': g:NERDTreeGitStatusMapPrevHunk,
        \ 'scope': 'Node',
        \ 'callback': l:s.'jumpToPrevHunk',
        \ 'quickhelpText': 'Jump to prev git hunk' })

endfunction

" FUNCTION: s:CursorHoldUpdate() {{{2
function! s:CursorHoldUpdate()
    if !g:NERDTree.IsOpen()
        return
    endif

    " Do not update when a special buffer is selected
    if !empty(&l:buftype)
        return
    endif

    let l:winnr = winnr()
    let l:altwinnr = winnr('#')

    call g:NERDTree.CursorToTreeWin()
    call b:NERDTree.root.refreshFlags()
    call NERDTreeRender()

    exec l:altwinnr . 'wincmd w'
    exec l:winnr . 'wincmd w'
endfunction

" FUNCTION: s:FileUpdate(fname) {{{2
function! s:FileUpdate(fname)
    if !g:NERDTree.IsOpen()
        return
    endif

    let l:winnr = winnr()
    let l:altwinnr = winnr('#')

    call g:NERDTree.CursorToTreeWin()
    let l:node = b:NERDTree.root.findNode(g:NERDTreePath.New(a:fname))
    if l:node != {}
        call l:node.refreshFlags()
        let l:node = l:node.parent
        while !empty(l:node)
            call l:node.refreshDirFlags()
            let l:node = l:node.parent
        endwhile
        call NERDTreeRender()
    endif

    exec l:altwinnr . 'wincmd w'
    exec l:winnr . 'wincmd w'
endfunction

augroup AddHighlighting
    autocmd FileType nerdtree call s:AddHighlighting()
augroup END
function! s:AddHighlighting()
    let l:synmap = {
                \ 'NERDTreeGitStatusModified':  s:NERDTreeGitStatusGetIndicator('Modified'),
                \ 'NERDTreeGitStatusStaged':    s:NERDTreeGitStatusGetIndicator('Staged'),
                \ 'NERDTreeGitStatusUntracked': s:NERDTreeGitStatusGetIndicator('Untracked'),
                \ 'NERDTreeGitStatusRenamed':   s:NERDTreeGitStatusGetIndicator('Renamed'),
                \ 'NERDTreeGitStatusDeleted':   s:NERDTreeGitStatusGetIndicator('Deleted'),
                \ 'NERDTreeGitStatusIgnored':   s:NERDTreeGitStatusGetIndicator('Ignored'),
                \ 'NERDTreeGitStatusDirDirty':  s:NERDTreeGitStatusGetIndicator('Dirty'),
                \ 'NERDTreeGitStatusDirClean':  s:NERDTreeGitStatusGetIndicator('Clean')
                \ }

    for [l:name, l:value] in items(l:synmap)
        exec 'syn match ' . l:name . ' #' . escape(l:value, '#~*.\') . '# containedin=NERDTreeFlags'
    endfor

    hi def link NERDTreeGitStatusModified Special
    hi def link NERDTreeGitStatusStaged Function
    hi def link NERDTreeGitStatusRenamed Title
    hi def link NERDTreeGitStatusUnmerged Label
    hi def link NERDTreeGitStatusUntracked Comment
    hi def link NERDTreeGitStatusDirDirty Tag
    hi def link NERDTreeGitStatusDeleted Operator
    hi def link NERDTreeGitStatusIgnored SpecialKey
    hi def link NERDTreeGitStatusDirClean DiffAdd
endfunction

function! s:SetupListeners()
    call g:NERDTreePathNotifier.AddListener('init', 'NERDTreeGitStatusRefreshListener')
    call g:NERDTreePathNotifier.AddListener('refresh', 'NERDTreeGitStatusRefreshListener')
    call g:NERDTreePathNotifier.AddListener('refreshFlags', 'NERDTreeGitStatusRefreshListener')
endfunction

augroup nerdtreegitplugin
    autocmd!
    if g:NERDTreeGitStatusUpdateOnWrite
        autocmd BufWritePost * silent! call s:FileUpdate(expand('%:p'))
    endif

    if g:NERDTreeGitStatusUpdateOnCursorHold
        autocmd CursorHold * silent! call s:CursorHoldUpdate()
    endif
augroup END

call s:NERDTreeGitStatusKeyMapping()
call s:SetupListeners()
