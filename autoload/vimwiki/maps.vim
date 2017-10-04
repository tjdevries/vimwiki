

""
" Go to tag remap
function! vimwiki#maps#goto_tag() abort
  call execute('tag ' . substitute(expand('<cWORD>'), '^:\|:$', '', 'g'))
endfunction
