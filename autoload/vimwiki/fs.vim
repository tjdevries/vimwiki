""
" Filesystem (fs) functions
" Many formerly existed in "base", but I'm changing them out of there

""
" Helper function to get the root directory
function! s:get_root_directory(wiki_nr) abort
  if a:wiki_nr >= 0
    return VimwikiGet('path', a:wiki_nr)
  else
    return VimwikiGet('path') . VimwikiGet('diary_rel_path')
  endif
endfunction

""
" Helper function to get the wiki number
function! s:get_wiki_nr(wiki_nr) abort
  return a:wiki_nr >= 0 ?
        \ a:wiki_nr
        \ : g:vimwiki_current_idx
endfunction

""
" find_files
"
" @param wiki_nr (number): The wiki to be searching for the files in
"       if negative, the diary of the current wiki is used
function! vimwiki#fs#find_files(wiki_nr) abort
  let root_directory = s:get_root_directory(a:wiki_nr)
  let wiki_nr = s:get_wiki_nr(a:wiki_nr)

  let ext = VimwikiGet('ext', wiki_nr)
  let temp = VimwikiGet('temp', wiki_nr)
  let pattern = temp ?
        \ '*' . ext
        \ : '**' . std#path#separator() . '*' . ext

  return split(globpath(root_directory, pattern), '\n')
endfunction

""
" find_directories
"
" @param wiki_nr (number): The wiki to be searching for the files in
"       if negative, the diary of the current wiki is used
function! vimwiki#fs#find_directories(wiki_nr) abort
  let root_directory = s:get_root_directory(a:wiki_nr)
  let wiki_nr = s:get_wiki_nr(a:wiki_nr)

  let ext = std#path#separator()
  let temp = VimwikiGet('temp', wiki_nr)
  let pattern = temp ?
        \ '*' . ext
        \ : '**' . std#path#separator() . '*' . ext

  return filter(split(globpath(root_directory, pattern), '\n'), { idx, val -> isdirectory(val) })
endfunction
