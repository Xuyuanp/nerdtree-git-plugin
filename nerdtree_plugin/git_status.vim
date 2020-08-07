" ============================================================================
" File:        git_status.vim
" Description: plugin for NERD Tree that provides git status support
" Maintainer:  Xuyuan Pang <xuyuanp at gmail dot com>
" License:     This program is free software. It comes without any warranty,
"              to the extent permitted by applicable law. You can redistribute
"              it and/or modify it under the terms of the Do What The Fuck You
"              Want To Public License, Version 2, as published by Sam Hocevar.
"              See http://sam.zoy.org/wtfpl/COPYING for more details.
" ============================================================================
scriptencoding utf-8

if exists('g:loaded_nerdtree_git_status')
    finish
endif
let g:loaded_nerdtree_git_status = 1

let s:is_win = gitstatus#isWin()

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
function! s:initVariable(var, value) abort
    if !exists(a:var)
        exec 'let ' . a:var . ' = ' . "'" . substitute(a:value, "'", "''", 'g') . "'"
        return 1
    endif
    return 0
endfunction

function! s:deprecated(oldv, newv) abort
    call s:logger.warning(printf("option '%s' is deprecated, please use '%s'", a:oldv, a:newv))
endfunction

function! s:migrateVariable(oldv, newv) abort
    if exists(a:oldv)
        call s:deprecated(a:oldv, a:newv)
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
            \ 'g:NERDTreeGitStatusConcealBrackets':    0,
            \ 'g:NERDTreeGitStatusAlignIfConceal':     1,
            \ 'g:NERDTreeGitStatusShowClean':          0,
            \ 'g:NERDTreeGitStatusLogLevel':           3,
            \ 'g:NERDTreeGitStatusPorcelainVersion':   2,
            \ 'g:NERDTreeGitStatusMapNextHunk':        ']c',
            \ 'g:NERDTreeGitStatusMapPrevHunk':        '[c',
            \ 'g:NERDTreeGitStatusUntrackedFilesMode': 'normal',
            \ 'g:NERDTreeGitStatusGitBinPath':         'git',
            \ }

for [var, value] in items(s:default_vals)
    call s:initVariable(var, value)
endfor

let s:logger = gitstatus#log#NewLogger(g:NERDTreeGitStatusLogLevel)

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
    call s:logger.error('git command not found')
    finish
endif

let g:NERDTreeGitStatusCache = {}

function! s:formatIndicator(indicator) abort
    return gitstatus#shouldConceal() ? printf(' %s ', a:indicator) : a:indicator
endfunction

if g:NERDTreeGitStatusPorcelainVersion ==# 2
    function! s:processLine(sline) abort
        if a:sline[0] ==# '1'
            let l:statusKey = s:getStatusKey(a:sline[2], a:sline[3])
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
else
    function! s:processLine(sline) abort
        let l:pathStr = a:sline[3:]
        let l:statusKey = s:getStatusKey(a:sline[0], a:sline[1])
        return [l:pathStr, l:statusKey]
    endfunction
endif

" FUNCTION: path2str
" This function is used to format nerdtree.Path.
" For Windows, returns in format 'C:/path/to/file'
"
" ARGS:
" path: nerdtree.Path
"
" RETURNS:
" absolute path
if s:is_win
    if exists('+shellslash')
        function! s:path2str(path) abort
            let sslbak = &shellslash
            try
                set shellslash
                return a:path.str()
            finally
                let &shellslash = sslbak
            endtry
        endfunction
    else
        function! s:path2str(path) abort
            let l:pathStr = a:path.str()
            let l:pathStr = a:path.WinToUnixPath(l:pathStr)
            let l:pathStr = a:path.drive . l:pathStr
            return l:pathStr
        endfunction
    endif
else
    function! s:path2str(path) abort
        return a:path.str()
    endfunction
endif

function! s:onGitWorkdirSuccessCB(job) abort
    let g:NTGitWorkdir = split(join(a:job.chunks, ''), "\n")[0]
    call s:logger.debug(printf("'%s' is in this git repo: '%s'", a:job.opts.cwd, g:NTGitWorkdir))
    call s:enableLiveUpdate()

    call s:refreshGitStatus('init', g:NTGitWorkdir)
endfunction

function! s:onGitWorkdirFailedCB(job) abort
    let errormsg = join(a:job.err_chunks, '')
    if errormsg =~# 'fatal: Not a git repository'
        call s:logger.debug(printf("'%s' is not in a git repo", a:job.opts.cwd))
    endif
    call s:disableLiveUpdate()
    unlet! g:NTGitWorkdir
endfunction

function! s:getGitWorkdir(ntRoot) abort
    let job = gitstatus#job#Spawn('git-workdir',
                \ s:buildGitWorkdirCommand(a:ntRoot),
                \ {
                \ 'on_success_cb': function('s:onGitWorkdirSuccessCB'),
                \ 'on_failed_cb': function('s:onGitWorkdirFailedCB'),
                \ 'cwd': a:ntRoot,
                \ })
endfunction

function! s:buildGitWorkdirCommand(ntRoot) abort
    return [
                \ g:NERDTreeGitStatusGitBinPath,
                \ '-C', a:ntRoot,
                \ 'rev-parse',
                \ '--show-toplevel'
                \ ]
endfunction

function! s:buildGitStatusCommand(workdir) abort
    let l:git_args = [
                \ g:NERDTreeGitStatusGitBinPath,
                \ '-C', a:workdir,
                \ 'status',
                \ '--porcelain' . (g:NERDTreeGitStatusPorcelainVersion ==# 2 ? '=v2' : ''),
                \ '--untracked-files=' . g:NERDTreeGitStatusUntrackedFilesMode,
                \ '-z'
                \ ]
    if g:NERDTreeGitStatusShowIgnored
        let l:git_args += ['--ignored=traditional']
    endif
    if exists('g:NERDTreeGitStatusIgnoreSubmodules')
        let l:ignore_args = '--ignore-submodules'
        if g:NERDTreeGitStatusIgnoreSubmodules is# 'all' ||
                    \ g:NERDTreeGitStatusIgnoreSubmodules is# 'dirty' ||
                    \ g:NERDTreeGitStatusIgnoreSubmodules is# 'untracked' ||
                    \ g:NERDTreeGitStatusIgnoreSubmodules is# 'none'
            let l:ignore_args += '=' . g:NERDTreeGitStatusIgnoreSubmodules
        endif
        let l:git_args += [l:ignore_args]
    endif
    return l:git_args
endfunction

function! s:parseGitStatusLines(workdir, statusLines) abort
    let l:cache = {}
    let l:opts = {'dir-dirty-only': g:NERDTreeGitStatusDirDirtyOnly}
    let l:is_rename = 0
    for l:statusLine in a:statusLines
        " cache git status of files
        if l:is_rename
            call s:recursiveCacheDir(l:cache, a:workdir, a:workdir . '/' . l:statusLine, 'Dirty', l:opts)
            let l:is_rename = 0
            continue
        endif
        let [l:pathStr, l:statusKey] = s:processLine(l:statusLine)

        let l:pathStr = a:workdir . '/' . l:pathStr
        if l:pathStr[-1:-1] is# '/'
            let l:pathStr = l:pathStr[:-2]
        endif
        let l:is_rename = l:statusKey is# 'Renamed'
        let l:cache[l:pathStr] = l:statusKey

        if l:statusKey ==# 'Ignored'
            if isdirectory(l:pathStr)
                let l:cache[l:pathStr] = l:statusKey
            endif
        else
            call s:recursiveCacheDir(l:cache, a:workdir, l:pathStr, l:statusKey, l:opts)
        endif
    endfor
    return l:cache
endfunction

function! s:recursiveCacheDir(cache, root, pathStr, statusKey, opts) abort
    let l:dirtyPath = fnamemodify(a:pathStr, ':p:h')
    while l:dirtyPath !=# a:root
        let key = get(a:cache, l:dirtyPath, '')
        if get(a:opts, 'dir-dirty-only', 1)
            if key ==# ''
                let a:cache[l:dirtyPath] = 'Dirty'
            else
                return
            endif
        else
            if key ==# ''
                let a:cache[l:dirtyPath] = a:statusKey
            elseif key ==# 'Dirty' || key ==# a:statusKey
                return
            else
                let a:cache[l:dirtyPath] = 'Dirty'
            endif
        endif
        let l:dirtyPath = fnamemodify(l:dirtyPath, ':h')
    endwhile
endfunction

" FUNCTION: s:getIndicatorByPath(path) {{{2
" return the indicator of the path
" Args: path
function! s:getIndicatorByPath(path) abort
    let l:pathStr = s:path2str(a:path)
    let l:statusKey = get(g:NERDTreeGitStatusCache, l:pathStr, '')

    if l:statusKey !=# ''
        return s:getIndicator(l:statusKey)
    endif

    if g:NERDTreeGitStatusShowClean
        return s:getIndicator('Clean')
    endif

    if g:NERDTreeGitStatusConcealBrackets && g:NERDTreeGitStatusAlignIfConceal
        return ' '
    endif
    return ''
endfunction

function! s:getIndicator(statusKey) abort
    return gitstatus#getIndicator(a:statusKey)
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

" Function: s:getStatusKey() function {{{2
" This function is used to get git status key
"
" Args:
" x: index tree
" y: work tree
"
"Returns:
" status key
"
" man git-status
" X          Y     Meaning
" -------------------------------------------------
"           [MD]   not updated
" M        [ MD]   updated in index
" A        [ MD]   added to index
" D         [ M]   deleted from index
" R        [ MD]   renamed in index
" C        [ MD]   copied in index
" [MARC]           index and work tree matches
" [ MARC]     M    work tree changed since index
" [ MARC]     D    deleted in work tree
" -------------------------------------------------
" D           D    unmerged, both deleted
" A           U    unmerged, added by us
" U           D    unmerged, deleted by them
" U           A    unmerged, added by them
" D           U    unmerged, deleted by us
" A           A    unmerged, both added
" U           U    unmerged, both modified
" -------------------------------------------------
" ?           ?    untracked
" !           !    ignored
" -------------------------------------------------
function! s:getStatusKey(x, y)
    let l:xy = a:x . a:y
    if get(s:unmerged_status, l:xy, 0)
        return 'Unmerged'
    elseif l:xy ==# '??'
        return 'Untracked'
    elseif l:xy ==# '!!'
        return 'Ignored'
    elseif a:y ==# 'M'
        return 'Modified'
    elseif a:y ==# 'D'
        return 'Deleted'
    elseif a:y =~# '[RC]'
        return 'Renamed'
    elseif a:x ==# 'D'
        return 'Deleted'
    elseif a:x =~# '[MA]'
        return 'Staged'
    elseif a:x =~# '[RC]'
        return 'Renamed'
    else
        return 'Unknown'
    endif
endfunction

function! s:dictEqual(c1, c2) abort
    if len(a:c1) != len(a:c2)
        return 0
    endif
    for [key, value] in items(a:c1)
        if !has_key(a:c2, key) || a:c2[key] !=# value
            return 0
        endif
    endfor
    return 1
endfunction

function! s:tryUpdateNERDTreeUI(cache) abort
    if s:dictEqual(g:NERDTreeGitStatusCache, a:cache)
        " nothing to update
        return
    endif

    let g:NERDTreeGitStatusCache = a:cache

    if !g:NERDTree.IsOpen()
        return
    endif

    let l:winnr = winnr()
    let l:altwinnr = winnr('#')

    try
        call g:NERDTree.CursorToTreeWin()
        call b:NERDTree.root.refreshFlags()
        call NERDTreeRender()
    finally
        exec l:altwinnr . 'wincmd w'
        exec l:winnr . 'wincmd w'
    endtry
endfunction

function! s:refreshGitStatus(name, workdir) abort
    let opts =  {
                \ 'on_failed_cb': function('s:onGitStatusFailedCB'),
                \ 'on_success_cb': function('s:onGitStatusSuccessCB'),
                \ 'cwd': a:workdir
                \ }
    let job = gitstatus#job#Spawn(a:name, s:buildGitStatusCommand(a:workdir), opts)
    return job
endfunction

function! s:onGitStatusSuccessCB(job) abort
    if !exists('g:NTGitWorkdir') || g:NTGitWorkdir !=# a:job.opts.cwd
        call s:logger.debug(printf("git workdir has changed: '%s' -> '%s'", a:job.opts.cwd, get(g:, 'NTGitWorkdir', '')))
        return
    endif
    let l:output = join(a:job.chunks, '')
    let l:lines = split(l:output, "\n")
    let l:cache = s:parseGitStatusLines(a:job.opts.cwd, l:lines)

    call s:tryUpdateNERDTreeUI(l:cache)
endfunction

function! s:onGitStatusFailedCB(job) abort
    let errormsg = join(a:job.err_chunks, '')
    if errormsg =~# "error: option `porcelain' takes no value"
        call s:logger.error(printf("'git status' command failed, please upgrade your git binary('v2.11.0' or higher) or set option 'g:NERDTreeGitStatusPorcelainVersion' to 1 in vimrc"))
        call s:disableLiveUpdate()
        unlet! g:NTGitWorkdir
    else
        call s:logger.error(printf('job[%s] failed: %s', a:job.name, errormsg))
    endif
endfunction

function! s:hasPrefix(text, prefix) abort
    return len(a:text) > len(a:prefix) && a:text[:len(a:prefix)-1] ==# a:prefix
endfunction

" FUNCTION: s:onCursorHold(fname) {{{2
function! s:onCursorHold(fname)
    " Do not update when a special buffer is selected
    if !empty(&l:buftype)
        return
    endif
    let l:fname = s:is_win ?
                \ substitute(a:fname, '\', '/', 'g') :
                \ a:fname

    if !exists('g:NTGitWorkdir') || !s:hasPrefix(l:fname, g:NTGitWorkdir)
        return
    endif

    let job = s:refreshGitStatus('cursor-hold', g:NTGitWorkdir)
    call s:logger.debug('run cursor-hold job: ' . job.id)
endfunction

" FUNCTION: s:onFileUpdate(fname) {{{2
function! s:onFileUpdate(fname)
    let l:fname = s:is_win ?
                \ substitute(a:fname, '\', '/', 'g') :
                \ a:fname
    if !exists('g:NTGitWorkdir') || !s:hasPrefix(l:fname, g:NTGitWorkdir)
        return
    endif
    let job = s:refreshGitStatus('file-update', g:NTGitWorkdir)
    call s:logger.debug('run file-update job: ' . job.id)
endfunction

function! NERDTreeGitStatusRefreshListener(event) abort
    let l:path = a:event.subject
    let l:indicator = s:getIndicatorByPath(l:path)
    call l:path.flagSet.clearFlags('git')
    if l:indicator !=# ''
        let l:indicator = s:formatIndicator(l:indicator)
        call l:path.flagSet.addFlag('git', l:indicator)
    endif
endfunction

function! s:setupNERDTreeListeners() abort
    call g:NERDTreePathNotifier.AddListener('init', 'NERDTreeGitStatusRefreshListener')
    call g:NERDTreePathNotifier.AddListener('refresh', 'NERDTreeGitStatusRefreshListener')
    call g:NERDTreePathNotifier.AddListener('refreshFlags', 'NERDTreeGitStatusRefreshListener')
endfunction

" FUNCTION: s:findHunk(node, direction)
" Args:
" node: the current node
" direction: next(>0) or prev(<0)
"
" Returns:
" lineNum if the hunk found, -1 otherwise
function! s:findHunk(node, direction) abort
    let ui = b:NERDTree.ui
    let rootLn = ui.getRootLineNum()
    let totalLn = line('$')
    let currLn = line('.') <= rootLn ? rootLn + 1 : line('.')
    let step = a:direction > 0 ? 1 : -1
    let lines = a:direction > 0 ?
                \ range(currLn+1, totalLn, step) + range(rootLn+1, currLn-1, step) :
                \ range(currLn-1, rootLn+1, step) + range(totalLn, currLn+1, step)
    for ln in lines
        let path = s:path2str(ui.getPath(ln))
        if has_key(g:NERDTreeGitStatusCache, path)
            return ln
        endif
    endfor
    return -1
endfunction

" FUNCTION: s:jumpToNextHunk(node) {{{2
function! s:jumpToNextHunk(node)
    let ln = s:findHunk(a:node, 1)
    if ln > 0
        exec '' . ln
        call s:logger.info('Jump to next hunk')
    endif
endfunction

" FUNCTION: s:jumpToPrevHunk(node) {{{2
function! s:jumpToPrevHunk(node)
    let ln = s:findHunk(a:node, -1)
    if ln > 0
        exec '' . ln
        call s:logger.info('Jump to prev hunk')
    endif
endfunction

" Function: s:SID()   {{{2
function s:SID()
    if !exists('s:sid')
        let s:sid = matchstr(expand('<sfile>'), '<SNR>\zs\d\+\ze_SID$')
    endif
    return s:sid
endfun

" FUNCTION: s:setupNERDTreeKeyMappings {{{2
function! s:setupNERDTreeKeyMappings()
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

function! s:onNERDTreeDirChanged(path) abort
    call s:getGitWorkdir(a:path)
endfunction

function! s:onNERDTreeInit(path) abort
    call s:getGitWorkdir(a:path)
endfunction

function! s:enableLiveUpdate() abort
    augroup nerdtreegitplugin_liveupdate
        autocmd!
        if g:NERDTreeGitStatusUpdateOnWrite
            autocmd BufWritePost * silent! call s:onFileUpdate(expand('%:p'))
        endif

        if g:NERDTreeGitStatusUpdateOnCursorHold
            autocmd CursorHold * silent! call s:onCursorHold(expand('%:p'))
        endif
    augroup end
endfunction

function! s:disableLiveUpdate() abort
    augroup nerdtreegitplugin_liveupdate
        autocmd!
    augroup end
endfunction

augroup nerdtreegitplugin
    autocmd!
    autocmd User NERDTreeInit call s:onNERDTreeInit(s:path2str(b:NERDTree.root.path))
    autocmd User NERDTreeNewRoot call s:onNERDTreeDirChanged(s:path2str(b:NERDTree.root.path))
augroup end

call s:setupNERDTreeKeyMappings()
call s:setupNERDTreeListeners()
