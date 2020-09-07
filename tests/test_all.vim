let s:suite = themis#suite('Test for nerdtree-git-plugin')
let s:assert = themis#helper('assert')

function! s:suite.BuildGitWorkdirCommand() abort
    let l:cmd = gitstatus#util#BuildGitWorkdirCommand('/workdir', {})
    call s:assert.equal(l:cmd, ['git', '-C', '/workdir', 'rev-parse', '--show-toplevel'])

    let l:cmd = gitstatus#util#BuildGitWorkdirCommand('/workdir', {'NERDTreeGitStatusGitBinPath': '/path/to/git'})
    call s:assert.equal(l:cmd, ['/path/to/git', '-C', '/workdir', 'rev-parse', '--show-toplevel'])
endfunction

function! s:suite.BuildGitStatusCommand() abort
    let l:cmd = gitstatus#util#BuildGitStatusCommand('/workdir', {})
    call s:assert.equal(l:cmd, ['git', '-C', '/workdir', 'status', '--porcelain=v2', '-z'])

    let l:cmd = gitstatus#util#BuildGitStatusCommand('/workdir', {
                \ 'NERDTreeGitStatusPorcelainVersion': 1
                \ })
    call s:assert.equal(l:cmd, ['git', '-C', '/workdir', 'status', '--porcelain', '-z'])

    let l:cmd = gitstatus#util#BuildGitStatusCommand('/workdir', {
                \ 'NERDTreeGitStatusUntrackedFilesMode': 'all'
                \ })
    call s:assert.equal(l:cmd, ['git', '-C', '/workdir', 'status', '--porcelain=v2', '-z', '--untracked-files=all'])

    let l:cmd = gitstatus#util#BuildGitStatusCommand('/workdir', {
                \ 'NERDTreeGitStatusShowIgnored': 1
                \ })
    call s:assert.equal(l:cmd, ['git', '-C', '/workdir', 'status', '--porcelain=v2', '-z', '--ignored=traditional'])

    let l:cmd = gitstatus#util#BuildGitStatusCommand('/workdir', {
                \ 'NERDTreeGitStatusShowIgnored': 0
                \ })
    call s:assert.equal(l:cmd, ['git', '-C', '/workdir', 'status', '--porcelain=v2', '-z'])

    let l:cmd = gitstatus#util#BuildGitStatusCommand('/workdir', {
                \ 'NERDTreeGitStatusIgnoreSubmodules': 'dirty'
                \ })
    call s:assert.equal(l:cmd, ['git', '-C', '/workdir', 'status', '--porcelain=v2', '-z', '--ignore-submodules=dirty'])

    let l:cmd = gitstatus#util#BuildGitStatusCommand('/workdir', {
                \ 'NERDTreeGitStatusPorcelainVersion': 1,
                \ 'NERDTreeGitStatusUntrackedFilesMode': 'all',
                \ 'NERDTreeGitStatusShowIgnored': 1,
                \ 'NERDTreeGitStatusIgnoreSubmodules': 'dirty'
                \ })
    call s:assert.equal(l:cmd, ['git', '-C', '/workdir', 'status', '--porcelain', '-z',
                \ '--untracked-files=all',
                \ '--ignored=traditional',
                \ '--ignore-submodules=dirty'])
endfunction
