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

if !exists('g:NERDTreeGitStatusWithFlags')
  let g:NERDTreeGitStatusWithFlags = 1
endif

if !exists('g:NERDTreeGitStatusNodeColorization')
  let g:NERDTreeGitStatusNodeColorization = 0
endif

if !exists('g:NERDTreeMapNextHunk')
    let g:NERDTreeMapNextHunk = ']c'
endif

if !exists('g:NERDTreeMapPrevHunk')
    let g:NERDTreeMapPrevHunk = '[c'
endif

if !exists('g:NERDTreeUpdateOnWrite')
    let g:NERDTreeUpdateOnWrite = 1
endif

if !exists('g:NERDTreeUpdateOnCursorHold')
    let g:NERDTreeUpdateOnCursorHold = 1
endif

if !exists('g:NERDTreeGitStatusIndicatorMap')
    if g:NERDTreeGitStatusWithFlags == 1
        let g:NERDTreeGitStatusIndicatorMap = {
                \ 'Modified'  : '✹',
                \ 'Added'     : '✚',
                \ 'Renamed'   : '➜',
                \ 'Unmerged'  : '═',
                \ 'Unknown'   : '✗',
                \ 'Dirty'     : '★',
                \ 'Clean'     : '✔︎'
                \ }
    else
        let g:NERDTreeGitStatusIndicatorMap = {
                \ 'Modified'  : nr2char(8201),
                \ 'Added'     : nr2char(8239),
                \ 'Renamed'   : nr2char(8199),
                \ 'Unmerged'  : nr2char(8200),
                \ 'Unknown'   : nr2char(8195),
                \ 'Dirty'     : nr2char(8202),
                \ 'Clean'     : nr2char(8196)
                \ }
    endif
endif


function! NERDTreeGitStatusRefreshListener(event)
    if !exists('b:NOT_A_GIT_REPOSITORY')
        call g:NERDTreeGitStatusRefresh()
    endif
    let l:path = a:event.subject
    let l:flag = g:NERDTreeGetGitStatusPrefix(l:path)
    call l:path.flagSet.clearFlags('git')
    if l:flag !=# ''
        call l:path.flagSet.addFlag('git', l:flag)
    endif
endfunction

" FUNCTION: g:NERDTreeGitStatusRefresh() {{{2
" refresh cached git status
function! g:NERDTreeGitStatusRefresh()
    let b:NERDTreeCachedGitFileStatus = {}
    let b:NERDTreeCachedGitDirtyDir   = {}
    let b:NOT_A_GIT_REPOSITORY        = 1

    let l:root = b:NERDTree.root.path.str()
    let l:gitcmd = 'git -c color.status=false status -s -uall | sort -r'
    if exists('g:NERDTreeGitStatusIgnoreSubmodules')
        let l:gitcmd = l:gitcmd . ' --ignore-submodules'
        if g:NERDTreeGitStatusIgnoreSubmodules ==# 'all' || g:NERDTreeGitStatusIgnoreSubmodules ==# 'dirty' || g:NERDTreeGitStatusIgnoreSubmodules ==# 'untracked'
            let l:gitcmd = l:gitcmd . '=' . g:NERDTreeGitStatusIgnoreSubmodules
        endif
    endif
    let l:statusesStr = system('cd "' . l:root . '" && ' . l:gitcmd)
    let l:statusesSplit = split(l:statusesStr, '\n')
    if l:statusesSplit != [] && l:statusesSplit[0] =~# 'fatal:.*'
        let l:statusesSplit = []
        return
    endif
    let b:NOT_A_GIT_REPOSITORY = 0



    for l:statusLine in l:statusesSplit
        " cache git status of files
        let l:pathStr = substitute(l:statusLine, '...', '', '')
        let l:pathSplit = split(l:pathStr, ' -> ')
        let l:statusKey = s:NERDTreeGetFileGitStatusKey(l:statusLine[0], l:statusLine[1])
        if len(l:pathSplit) == 2
            call s:NERDTreeCacheDirtyDir(l:pathSplit[0], l:statusKey)
            let l:pathStr = l:pathSplit[1]
        else
            let l:pathStr = l:pathSplit[0]
        endif
        let l:pathStr = s:NERDTreeTrimDoubleQuotes(l:pathStr)
        if l:pathStr =~# '\.\./.*'
            continue
        endif
        let b:NERDTreeCachedGitFileStatus[fnameescape(l:pathStr)] = l:statusKey
        call s:NERDTreeCacheDirtyDir(l:pathStr, l:statusKey)
    endfor
endfunction

function! s:NERDTreeCacheDirtyDir(pathStr, statusKey)
    " cache dirty dir
    let l:dirtyPath = s:NERDTreeTrimDoubleQuotes(a:pathStr)
    if l:dirtyPath =~# '\.\./.*'
        return
    endif
    let l:dirtyPathInitial = substitute(l:dirtyPath, '/[^/]*$', '/', '')
    let l:dirtyPath = l:dirtyPathInitial
    while l:dirtyPath =~# '.\+/.*' && has_key(b:NERDTreeCachedGitDirtyDir, fnameescape(l:dirtyPath)) == 0
      let b:NERDTreeCachedGitDirtyDir[fnameescape(l:dirtyPath)] = a:statusKey
      let l:dirtyPath = substitute(l:dirtyPath, '/[^/]*/$', '/', '')
    endwhile
endfunction

function! s:NERDTreeTrimDoubleQuotes(pathStr)
    let l:toReturn = substitute(a:pathStr, '^"', '', '')
    let l:toReturn = substitute(l:toReturn, '"$', '', '')
    return l:toReturn
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
    let l:pathStr = a:path.str()
    let l:cwd = b:NERDTree.root.path.str() . a:path.Slash()
    if nerdtree#runningWindows()
        let l:pathStr = a:path.WinToUnixPath(l:pathStr)
        let l:cwd = a:path.WinToUnixPath(l:cwd)
    endif
    let l:pathStr = substitute(l:pathStr, fnameescape(l:cwd), '', '')
    let l:statusKey = ''
    if a:path.isDirectory
        let l:statusKey = get(b:NERDTreeCachedGitDirtyDir, fnameescape(l:pathStr . '/'), '')
    else
        let l:statusKey = get(b:NERDTreeCachedGitFileStatus, fnameescape(l:pathStr), '')
    endif
    return s:NERDTreeGetIndicator(l:statusKey)
endfunction

" FUNCTION: s:NERDTreeGetCWDGitStatus() {{{2
" return the indicator of cwd
function! g:NERDTreeGetCWDGitStatus()
    if b:NOT_A_GIT_REPOSITORY
        return ''
    elseif b:NERDTreeCachedGitDirtyDir == {} && b:NERDTreeCachedGitFileStatus == {}
        return s:NERDTreeGetIndicator('Clean')
    endif
    return s:NERDTreeGetIndicator('Dirty')
endfunction

function! s:NERDTreeGetIndicator(statusKey)
    let l:indicator = get(g:NERDTreeGitStatusIndicatorMap, a:statusKey, '')
    if l:indicator !=# ''
        return l:indicator
    endif
    return ''
endfunction

function! s:NERDTreeGetFileGitStatusKey(us, them)
    " See git-status docs for more information

    " We want to know if is modified whether it is staged or not
    if a:us ==# 'M' ||  a:them ==# 'M'
        return 'Modified'
    " Untracked to added, AU/AA will result in unmerged
    elseif get(['A', '?'], a:us, '') !=# '' && get(['?', ' '], a:them, '') !=# ''
        return 'Added'
    elseif a:us ==# 'R'
        return 'Renamed'
    elseif get(['U', 'D'], a:us, '') !=# '' || get(['U', 'D', 'A'], a:them, '') !=# ''
        return 'Unmerged'
    else
        return 'Unknown'
    endif
endfunction

" FUNCTION: s:getRegexForJump
function! s:getRegexForJump()
    let l:regex = ''
    for val in values(g:NERDTreeGitStatusIndicatorMap)
      if strwidth(val) == 1
          let l:regex = l:regex . '[\d' . char2nr(val) . ']'
      else
          let l:regex = l:regex . val
      endif
      let l:regex = l:regex . '\|'
    endfor
    let l:regex = strpart(l:regex, 0, strlen(l:regex) - 2)
    return l:regex
endfunction

" FUNCTION: s:jumpToNextHunk(node) {{{2
function! s:jumpToNextHunk(node)
    let l:position = search(s:getRegexForJump(), '')

    if l:position
        " call nerdtree#echo(s:getRegexForJump())
    endif
endfunction

" FUNCTION: s:jumpToPrevHunk(node) {{{2
function! s:jumpToPrevHunk(node)
    let l:position = search(s:getRegexForJump(), 'b')
    if l:position
        call nerdtree#echo('Jump to prev hunk ')
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
        \ 'key': g:NERDTreeMapNextHunk,
        \ 'scope': 'Node',
        \ 'callback': l:s.'jumpToNextHunk',
        \ 'quickhelpText': 'Jump to next git hunk' })

    call NERDTreeAddKeyMap({
        \ 'key': g:NERDTreeMapPrevHunk,
        \ 'scope': 'Node',
        \ 'callback': l:s.'jumpToPrevHunk',
        \ 'quickhelpText': 'Jump to prev git hunk' })

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

    let l:winnr = winnr()
    call g:NERDTree.CursorToTreeWin()
    call b:NERDTree.root.refreshFlags()
    call NERDTreeRender()
    exec l:winnr . 'wincmd w'
endfunction

augroup nerdtreegitplugin
    autocmd BufWritePost * call s:FileUpdate(expand('%:p'))
augroup END

" FUNCTION: s:FileUpdate(fname) {{{2
function! s:FileUpdate(fname)
    if g:NERDTreeUpdateOnWrite != 1
        return
    endif
    if !g:NERDTree.IsOpen()
        return
    endif

    let l:winnr = winnr()

    call g:NERDTree.CursorToTreeWin()
    let l:node = b:NERDTree.root.findNode(g:NERDTreePath.New(a:fname))
    if l:node == {}
        return
    endif
    call l:node.refreshFlags()
    let l:node = l:node.parent
    while !empty(l:node)
        call l:node.refreshDirFlags()
        let l:node = l:node.parent
    endwhile

    call NERDTreeRender()
    exec l:winnr . 'wincmd w'
endfunction

augroup AddHighlighting
    autocmd FileType nerdtree call s:AddHighlighting()
augroup END
function! s:AddHighlighting()
    let l:synmap = {
                \ 'NERDTreeGitStatusModified'    : s:NERDTreeGetIndicator('Modified'),
                \ 'NERDTreeGitStatusAdded'       : s:NERDTreeGetIndicator('Added'),
                \ 'NERDTreeGitStatusRenamed'     : s:NERDTreeGetIndicator('Renamed'),
                \ 'NERDTreeGitStatusUnmerged'     : s:NERDTreeGetIndicator('Unmerged'),
                \ 'NERDTreeGitStatusUnknown'     : s:NERDTreeGetIndicator('Unknown'),
                \ 'NERDTreeGitStatusDirDirty'    : s:NERDTreeGetIndicator('Dirty'),
                \ 'NERDTreeGitStatusDirClean'    : s:NERDTreeGetIndicator('Clean')
                \ }

    for l:name in keys(l:synmap)
      if g:NERDTreeGitStatusNodeColorization == 1
          exec 'syn match '.l:name.' "'.l:synmap[l:name].'.*" containedin=NERDTreeDir'
          exec 'syn match '.l:name.' "'.l:synmap[l:name].'.*" containedin=NERDTreeFile'
          exec 'syn match '.l:name.' "'.l:synmap[l:name].'.*" containedin=NERDTreeExecFile'
      else
        exec 'syn match ' . l:name . ' #' . escape(l:synmap[l:name], '~') . '# containedin=NERDTreeFlags'
      endif
    endfor

    hi def link NERDTreeGitStatusModified NERDTreeGitModified
    hi def link NERDTreeGitStatusAdded NERDTreeGitAdded
    hi def link NERDTreeGitStatusRenamed  NERDTreeGitRenamed
    hi def link NERDTreeGitStatusUnmerged NERDTreeGitUnmerged
    hi def link NERDTreeGitStatusUnknown NERDTreeGitUnknown
    hi def link NERDTreeGitStatusDirDirty NERDTreeGitDirDirty
    hi def link NERDTreeGitStatusDirClean NERDTreeGitDirClean
endfunction

function! s:SetupListeners()
    call g:NERDTreePathNotifier.AddListener('init', 'NERDTreeGitStatusRefreshListener')
    call g:NERDTreePathNotifier.AddListener('refresh', 'NERDTreeGitStatusRefreshListener')
    call g:NERDTreePathNotifier.AddListener('refreshFlags', 'NERDTreeGitStatusRefreshListener')
endfunction

if g:NERDTreeShowGitStatus && executable('git')
    call s:NERDTreeGitStatusKeyMapping()
    call s:SetupListeners()
endif
