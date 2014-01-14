" vim600: set foldmethod=marker:
"
" Mercurial extension for VCSCommand. This extension is based on svn extension
" to VCSCommand made by Bob Hiestand <bob.hiestand@gmail.com>
"
" Version:       2
" Maintainer:    Vladimir Marek <vlmarek@volny.cz>
" License:
" Copyright (c) 2007 Vladimir Marek
"
" Permission is hereby granted, free of charge, to any person obtaining a copy
" of this software and associated documentation files (the "Software"), to
" deal in the Software without restriction, including without limitation the
" rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
" sell copies of the Software, and to permit persons to whom the Software is
" furnished to do so, subject to the following conditions:
"
" The above copyright notice and this permission notice shall be included in
" all copies or substantial portions of the Software.
"
" THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
" IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
" FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
" AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
" LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
" FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
" IN THE SOFTWARE.
"
" Section: Documentation {{{1
"
" Command documentation {{{2
"
" The following command only applies to files under SCCS source control.
"
" Those functions are NOT implemented (yet?). Their implementation would differ
" for using sccs or TeamWare. Current implementation has enough features to
" support VCSVimDiff and VCSAnnotate "
" Add
" Delete
" Lock
" Revert
" Unlock
" Update
"
" Mapping documentation: {{{2
"
" By default, a mapping is defined for each command.  User-provided mappings
" can be used instead by mapping to <Plug>CommandName, for instance:
"
" None currently
"
" The default mappings are as follow:
"
" None currently
"
" Options documentation: {{{2
"
" VCSCommandSCCSExec
"   This variable specifies path to the sccs binaries. If not set, it defaults
"   to empty string (which means use your $PATH). If set, it MUST end by slash

if v:version < 700
  finish
endif

" Section: Plugin header {{{1

if exists('VCSCommandDisableAll')
	finish
endif

if v:version < 700
	echohl WarningMsg|echomsg 'VCSCommand requires at least VIM 7.0'|echohl None
	finish
endif

if !exists('g:loaded_VCSCommand')
	runtime plugin/vcscommand.vim
endif

if !executable(VCSCommandGetOption('VCSCommandSCCSExec', 'sccs'))
	" HG is not installed
	finish
endif

let s:save_cpo=&cpo
set cpo&vim

" Section: Variable initialization {{{1

let s:sccsFunctions = {}

" Section: Utility functions {{{1

" Function: s:Executable() {{{2
" Returns the executable used to invoke sccs suitable for use in a shell
" command.
function! s:Executable()
	return shellescape(VCSCommandGetOption('VCSCommandSCCSExec', 'sccs'))
endfunction

" Function: s:DoCommand(cmd, cmdName, statusText, options) {{{2
" Wrapper to VCSCommandDoCommand to add the name of the SCCS executable to the
" command argument.
function! s:DoCommand(cmd, cmdName, statusText, options)
  if VCSCommandGetVCSType(expand('%')) == 'SCCS'
    if has_key(a:options, 'executable')
      let fullCmd = a:options['executable']. ' ' . a:cmd
    else
      let fullCmd = s:Executable() . ' ' . a:cmd
    endif
    return VCSCommandDoCommand(fullCmd, a:cmdName, a:statusText, a:options)
  else
    throw 'SCCS VCSCommand plugin called on non-SCCS item.'
  endif
endfunction

" Section: VCS function implementations {{{1

" Function: s:sccsFunctions.Identify(buffer) {{{2
function! s:sccsFunctions.Identify(buffer)
  let fileName = resolve(bufname(a:buffer))
  if isdirectory(fileName)
    let directoryName = fileName
  else
    let directoryName = fnamemodify(fileName, ':h')
  endif
  if strlen(directoryName) > 0
    let sccsDir = directoryName . '/SCCS'
  else
    let sccsDir = 'SCCS'
  endif
  if isdirectory(sccsDir)
    return 1
  else
    return 0
  endif
endfunction

" Function: s:sccsFunctions.Annotate(argList) {{{2
function! s:sccsFunctions.Annotate(argList)
    if len(a:argList) == 0
      if &filetype ==? 'SCCSAnnotate'
        " Perform annotation of the version indicated by the current line.
        let caption = matchstr(getline('.'),'\v^\s*\zs\d+\.\d+')
	let options = '-r '
      else
	let caption = ''
	let options = ''
      endif
    elseif len(a:argList) == 1 && a:argList[0] !~ '^-'
      let caption = a:argList[0]
      let options = '-r ' . caption
    else
      let caption = join(a:argList, ' ')
      let options = ' ' . caption
    endif

    return s:DoCommand('get -p -m -s ' . options, 'annotate', caption, {}) 
endfunction

" Function: s:sccsFunctions.Commit(argList) {{{2
function! s:sccsFunctions.Commit(argList)
  return s:DoCommand("deledit -y\"$(cat " . a:argList[0] .")\" <VCSCOMMANDFILE>" , 'commit', '', {})
endfunction

" 0 args - current file vs. last revision
" 1 args - current file vs. revision REV
" 2 args - current file revisions REV1 & REV2
" Function: s:sccsFunctions.Diff(argList) {{{2
function! s:sccsFunctions.Diff(argList)
  let opts = {}
  if len(a:argList) == 0
    let revOptions = 'diffs -u'
    let caption = ''
  elseif len(a:argList) == 1 && match(a:argList, '^-') == -1
    let revOptions = 'diffs -r' . a:argList[0] . ' -u'
    let caption = '(' . a:argList[0] . ' : current)'
  elseif len(a:argList) == 2
    let l:fileName = resolve(bufname(VCSCommandGetOriginalBuffer(bufnr('%'))))
    let l:fileName = fnamemodify(l:fileName, ':p:h') . '/SCCS/s.' . fnamemodify(l:fileName, ':t')
    let revOptions = ' -r' . a:argList[0] . ' -r' . a:argList[1] . ' -u <VCSCOMMANDFILE>'
    let caption = '(' . a:argList[0] . ' : ' . a:argList[1] . ')'
    let opts['executable'] = 'sccsdiff'
    let opts['fileName'] = l:fileName
  endif

  return s:DoCommand(revOptions , 'diff', caption, opts)
endfunction


" Function: s:sccsFunctions.Info(argList) {{{2
function! s:sccsFunctions.Info(argList)
  return s:DoCommand('prt -s ', 'log', join(a:argList, ' '), {})
endfunction


" Function: s:sccsFunctions.GetBufferInfo() {{{2
" Provides version control details for the current file.  Current version
" number and current repository version number are required to be returned by
" the vcscommand plugin.
" Returns: List of results:  [revision, repository, branch]
function! s:sccsFunctions.GetBufferInfo()
  let originalBuffer = VCSCommandGetOriginalBuffer(bufnr('%'))
  let fileName = bufname(originalBuffer)
  let statusText = s:VCSCommandUtility.system(s:Executable() . ' prt -y "' . fileName . '"')
  if(v:shell_error)
    return []
  endif

  " Error is returned above anyway
  if statusText =~ ' nonexistent (ut4)'
    return ['Unknown']
  endif

  " We can't have 'new', sccs create already commits the file

  let statusText=substitute(statusText, '^[^\t]*...', "", "")
  let statusText=substitute(statusText, "\t.*", "", "")

  return [statusText]
endfunction


" 0 parameters - full log
" 1 parameter - log of the given commit
" Function: s:sccsFunctions.Log() {{{2
function! s:sccsFunctions.Log(argList)
  if len(a:argList) == 0
    let versionOption = ''
    let caption = ''
  else
    let versionOption=' -y' . a:argList[0]
    let caption = a:argList[0]
  endif

  return s:DoCommand('prt ' . versionOption, 'log', caption, {})
endfunction


" Function: s:sccsFunctions.Review(argList) {{{2
function! s:sccsFunctions.Review(argList)
  if len(a:argList) == 0
    let versiontag = '(current)'
    let versionOption = ''
  else
    let versiontag = a:argList[0]
    let versionOption = ' -r ' . versiontag . ' '
  endif

  return s:DoCommand('get -p -s -k' . versionOption, 'review', versiontag, {'allowEmptyOutput': 1})
endfunction

" Function: s:sccsFunctions.Status(argList) {{{2
function! s:sccsFunctions.Status(argList)
  return s:DoCommand(join(['sact'] + a:argList, ' '), 'status', '', {}))
endfunction

" Section: Plugin Registration {{{1
let s:VCSCommandUtility = VCSCommandRegisterModule('SCCS', expand('<sfile>'), s:sccsFunctions, [])

let &cpo = s:save_cpo
