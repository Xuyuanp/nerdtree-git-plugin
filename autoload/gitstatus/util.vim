" ============================================================================
" File:        autoload/git_status/util.vim
" Description: utils
" Maintainer:  Xuyuan Pang <xuyuanp at gmail dot com>
" License:     This program is free software. It comes without any warranty,
"              to the extent permitted by applicable law. You can redistribute
"              it and/or modify it under the terms of the Do What The Fuck You
"              Want To Public License, Version 2, as published by Sam Hocevar.
"              See http://sam.zoy.org/wtfpl/COPYING for more details.
" ============================================================================
if exists('g:loaded_nerdtree_git_status_util')
    finish
endif
let g:loaded_nerdtree_git_status_util = 1

" FUNCTION: gitstatus#utilFormatPath
" This function is used to format nerdtree.Path.
" For Windows, returns in format 'C:/path/to/file'
"
" ARGS:
" path: nerdtree.Path
"
" RETURNS:
" absolute path
if gitstatus#isWin()
    if exists('+shellslash')
        function! gitstatus#util#FormatPath(path) abort
            let l:sslbak = &shellslash
            try
                set shellslash
                return a:path.str()
            finally
                let &shellslash = l:sslbak
            endtry
        endfunction
    else
        function! gitstatus#util#FormatPath(path) abort
            let l:pathStr = a:path.str()
            let l:pathStr = a:path.WinToUnixPath(l:pathStr)
            let l:pathStr = a:path.drive . l:pathStr
            return l:pathStr
        endfunction
    endif
else
    function! gitstatus#util#FormatPath(path) abort
        return a:path.str()
    endfunction
endif

function! gitstatus#util#BuildGitWorkdirCommand(root, opts) abort
    return [
                \ get(a:opts, 'NERDTreeGitStatusGitBinPath', 'git'),
                \ '-C', a:root,
                \ 'rev-parse',
                \ '--show-toplevel',
                \ ]
endfunction

function! gitstatus#util#BuildGitStatusCommand(root, opts) abort
    let l:cmd = [
                \ get(a:opts, 'NERDTreeGitStatusGitBinPath', 'git'),
                \ '-C', a:root,
                \ 'status',
                \ '--porcelain' . (get(a:opts, 'NERDTreeGitStatusPorcelainVersion', 2) ==# 2 ? '=v2' : ''),
                \ '-z'
                \ ]
    if has_key(a:opts, 'NERDTreeGitStatusUntrackedFilesMode')
        let l:cmd += ['--untracked-files=' . a:opts['NERDTreeGitStatusUntrackedFilesMode']]
    endif

    if get(a:opts, 'NERDTreeGitStatusShowIgnored', 0)
        let l:cmd += ['--ignored=traditional']
    endif

    if has_key(a:opts, 'NERDTreeGitStatusIgnoreSubmodules')
        let l:cmd += ['--ignore-submodules=' . a:opts['NERDTreeGitStatusIgnoreSubModules']]
    endif

    return l:cmd
endfunction
