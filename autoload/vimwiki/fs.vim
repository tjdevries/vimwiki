""
" Filesystem (fs) functions
" Many formerly existed in "base", but I'm changing them out of there

""
" find_files
"
" @param wiki_nr (number): The wiki to be searching for the files in
"       if negative, the diary of the current wiki is used
function! vimwiki#fs#find_files(wiki_nr) abort
  let wiki_nr = a:wiki_nr
  if wiki_nr >= 0
    let root_directory = VimwikiGet('path', wiki_nr)
  else
    let root_directory = VimwikiGet('path') . VimwikiGet('diary_rel_path')
    let wiki_nr = g:vimwiki_current_idx
  endif

  let ext = VimwikiGet('ext', wiki_nr)
  let temp = VimwikiGet('temp', wiki_nr)
  let pattern = temp ?
        \ '*' . ext
        \ : '**' . std#path#separator() . '*' . ext

  echo 'fs' pattern

  return split(globpath(root_directory, pattern), '\n')
endfunction

""
" find_directories
function! vimwiki#fs#find_directories(wiki_nr) abort
  echo 'TODO'
endfunction
