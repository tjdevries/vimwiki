" vim:tabstop=2:shiftwidth=2:expandtab:foldmethod=marker:textwidth=79
" Vimwiki autoload plugin file


let s:TAGS_METADATA_FILE_NAME = '.tags'

" Tags metadata in-memory format:
" metadata := { 'pagename': [entries, ...] }
" entry := { 'tagname':..., 'lineno':..., 'link':... }

" Tags metadata in-file format:
"
" Is based on CTags format (see |tags-file-format|).
"
" {tagaddress} is set to lineno.  We'll let vim search by exact line number; we
" can afford that, we assume metadata file is always updated before use.
"
" Pagename and link are not saved in standard ctags fields, so we'll add
" an optional field, "vimwiki:".  In this field, we encode tab-separated values
" of missing parameters -- "pagename" and "link".

" vimwiki#tags#update_tags
"   Update tags metadata.
"   a:full_rebuild == 1: re-scan entire wiki
"   a:full_rebuild == 0: only re-scan current page
"   a:all_files == '':   only if the file is newer than .tags
function! vimwiki#tags#update_tags(full_rebuild, all_files) "{{{
  let all_files = a:all_files != ''

  if a:full_rebuild
    let file_list = vimwiki#fs#find_files(g:vimwiki_current_idx)
  else
    let file_list = [expand('%:p')]
  endif

  let tags_file_last_modification = getftime(vimwiki#tags#metadata_file_path())
  let wiki_base_dir = VimwikiGet('path', g:vimwiki_current_idx)

  let metadata = s:load_tags_metadata()

  for file in file_list
    if all_files || getftime(file) >= tags_file_last_modification
        let page_name = vimwiki#base#subdir(wiki_base_dir, file) . fnamemodify(file, ':t:r')
        let tags = s:scan_tags(readfile(file), page_name)
        let metadata = s:remove_page_from_tags(metadata, page_name)
        let metadata = s:merge_tags(metadata, page_name, tags)
    endif
  endfor

  call s:write_tags_metadata(metadata)
endfunction " }}}

" s:scan_tags
"   Scans the list of text lines (argument) and produces tags metadata as a
"   list of tag entries.
function! s:scan_tags(lines, page_name) "{{{
  let entries = []

  " Code wireframe to scan for headers -- borrowed from
  " vimwiki#base#get_anchors(), with minor modifications.

  " TODO(tjdevries): Switch to a more reasonable dictionary approach
  let rxheader = g:vimwiki_{VimwikiGet('syntax')}_header_search
  let rxtag = g:vimwiki_{VimwikiGet('syntax')}_tag_search

  let anchor_level = ['', '', '', '', '', '', '']
  let current_complete_anchor = ''

  let PROXIMITY_LINES_NR = vimwiki#conf#get('tags', 'header_proximity')
  let header_line_nr = - (2 * PROXIMITY_LINES_NR)

  for line_nr in range(1, len(a:lines))
    let line = a:lines[line_nr - 1]

    " process headers
    let h_match = matchlist(line, rxheader)
    if !empty(h_match) " got a header
      let header_line_nr = line_nr
      let header = vimwiki#u#trim(h_match[2])
      let level = len(h_match[1])
      let anchor_level[level-1] = header
      for l in range(level, 6)
        let anchor_level[l] = ''
      endfor
      if level == 1
        let current_complete_anchor = header
      else
        let current_complete_anchor = ''
        for l in range(level-1)
          if anchor_level[l] != ''
            let current_complete_anchor .= anchor_level[l].'#'
          endif
        endfor
        let current_complete_anchor .= header
      endif
      continue " tags are not allowed in headers
    endif

    " TODO ignore verbatim blocks

    " Scan line for tags.  There can be many of them.
    let str = line
    while 1
      let tag_group = matchstr(str, rxtag)
      if tag_group == ''
        break
      endif
      let tagend = matchend(str, rxtag)
      let str = str[(tagend):]
      for tag in split(tag_group, ':')
        " Create metadata entry
        if line_nr <= PROXIMITY_LINES_NR && header_line_nr < 0
          " Tag appeared at the top of the file
          let link   = a:page_name
        elseif line_nr <= (header_line_nr + PROXIMITY_LINES_NR)
          " Tag appeared right below a header
          let link   = a:page_name . '#' . current_complete_anchor
        else
          " Tag stands on its own
          let link   = a:page_name . '#' . tag
        endif

        let priority = -1
        if match(line, '^' . rxtag) > -1
          let priority = 1
        endif

        let entry = s:tag_factory(tag, line_nr, link, a:page_name, priority)
        call add(entries, entry)
      endfor
    endwhile

  endfor " loop over lines
  return entries
endfunction " }}}

" vimwiki#tags#metadata_file_path
"   Returns tags metadata file path
function! vimwiki#tags#metadata_file_path() abort "{{{
  return fnamemodify(vimwiki#path#join_path(VimwikiGet('path'), s:TAGS_METADATA_FILE_NAME), ':p')
endfunction " }}}

" s:load_tags_metadata
"   Loads tags metadata from file, returns a dictionary
function! s:load_tags_metadata() abort "{{{
  let metadata_path = vimwiki#tags#metadata_file_path()
  if !filereadable(metadata_path)
    return {}
  endif
  let metadata = {}
  for line in readfile(metadata_path)
    if line =~ '^!_TAG_FILE_'
      continue
    endif

    let entry = s:tag_parse_string(line)

    if !has_key(metadata, entry.pagename)
      let metadata[entry.pagename] = []
    endif
    call add(metadata[entry.pagename], entry)
  endfor

  return metadata
endfunction " }}}

" s:remove_page_from_tags
"   Removes all entries for given page from metadata in-place.  Returns updated
"   metadata (just in case).
function! s:remove_page_from_tags(metadata, page_name) "{{{
  let meta = a:metadata

  if has_key(meta, a:page_name)
    call remove(meta, a:page_name)
  endif

  return meta
endfunction " }}}

" s:merge_tags
"   Merges metadata of one file into a:metadata
function! s:merge_tags(metadata, pagename, file_metadata) "{{{
  let metadata = a:metadata
  let metadata[a:pagename] = a:file_metadata
  return metadata
endfunction " }}}

" s:tags_entry_cmp
"   Compares two actual lines from tags file.  Return value is in strcmp style.
"   See help on sort() -- that's what this function is going to be used for.
"   See also s:write_tags_metadata below -- that's where we compose these tags
"   file lines.
"
"   This function is needed for tags sorting, since plain sort() compares line
"   numbers as strings, not integers, and so, for example, tag at line 14
"   preceeds the same tag on the same page at line 9.  (Because string "14" is
"   alphabetically 'less than' string "9".)
function! s:tags_entry_cmp(i1, i2) "{{{
  let entry_1 = s:tag_parse_string(a:i1)
  let entry_2 = s:tag_parse_string(a:i2)

  if entry_1.name ># entry_2.name
    return 1
  elseif entry_1.name <# entry_2.name
    return -1

  " We want a bigger number to sort first
  elseif entry_1.priority > entry_2.priority
    return -1
  elseif entry_1.priority < entry_2.priority
    return 1


  elseif entry_1.pagename > entry_2.pagename
    return 1
  elseif entry_1.pagename < entry_2.pagename
    return -1
  elseif entry_1.line_number > entry_2.line_number
    return 1
  elseif entry_1.line_number < entry_2.line_number
    return -1
  else
    return 0
  endif
endfunction " }}}

" s:write_tags_metadata
"   Saves metadata object into a file. Throws exceptions in case of problems.
function! s:write_tags_metadata(metadata) "{{{
  let metadata_path = vimwiki#tags#metadata_file_path()
  let tags = []
  for pagename in keys(a:metadata)
    for entry in a:metadata[pagename]
      call add(tags, entry.result())
    endfor
  endfor
  call sort(tags, "s:tags_entry_cmp")
  call insert(tags, "!_TAG_FILE_SORTED\t1\t")
  call writefile(tags, metadata_path)
endfunction " }}}

" vimwiki#tags#get_tags
"   Returns list of unique tags found in the .tags file
function! vimwiki#tags#get_tags() "{{{
  let metadata = s:load_tags_metadata()
  let tags = {}
  for entries in values(metadata)
    for entry in entries
      let tags[entry.name] = 1
    endfor
  endfor
  return keys(tags)
endfunction " }}}

" vimwiki#tags#generate_tags
"   Similar to vimwiki#base#generate_links.  In the current buffer, appends
"   tags and references to all their instances.  If no arguments (tags) are
"   specified, outputs all tags.
function! vimwiki#tags#generate_tags(...) abort "{{{
  let need_all_tags = (a:0 == 0)
  let specific_tags = a:000

  let metadata = s:load_tags_metadata()

  " make a dictionary { tag_name: [tag_links, ...] }
  let tags_entries = {}
  for entries in values(metadata)
    for entry in entries
      if has_key(tags_entries, entry.name)
        call add(tags_entries[entry.name], entry.link)
      else
        let tags_entries[entry.name] = [entry.link]
      endif
    endfor
  endfor

  let lines = []
  let bullet = repeat(' ', vimwiki#lst#get_list_margin()).
        \ vimwiki#lst#default_symbol().' '
  for tagname in sort(keys(tags_entries))
    if need_all_tags || index(specific_tags, tagname) != -1
      call extend(lines, [
            \ '',
            \ substitute(g:vimwiki_rxH2_Template, '__Header__', tagname, ''),
            \ '' ])
      for taglink in sort(tags_entries[tagname])
        call add(lines, bullet .
              \ substitute(g:vimwiki_WikiLinkTemplate1, '__LinkUrl__', taglink, ''))
      endfor
    endif
  endfor

  let links_rx = '\m\%(^\s*$\)\|\%('.g:vimwiki_rxH2.'\)\|\%(^\s*'
        \ .vimwiki#u#escape(vimwiki#lst#default_symbol()).' '
        \ .g:vimwiki_rxWikiLink.'$\)'

  call vimwiki#base#update_listing_in_buffer(lines, 'Generated Tags', links_rx,
        \ line('$')+1, 1)
endfunction " }}}

" vimwiki#tags#complete_tags
function! vimwiki#tags#complete_tags(ArgLead, CmdLine, CursorPos) abort " {{{
  " We can safely ignore args if we use -custom=complete option, Vim engine
  " will do the job of filtering.
  let taglist = vimwiki#tags#get_tags()
  return join(taglist, "\n")
endfunction " }}}


function! s:tag_parse_string(s) abort
  let parts = matchlist(a:s, '^\(.\{-}\);"\(.*\)$')

  if len(parts) == 0
    throw 'VimwikiTags1: Metadata file corrupted'
  endif
  if parts[0] == '' || parts[1] == '' || parts[2] == ''
    throw 'VimwikiTags1: Metadata file corrupted'
  endif

  let std_fields = split(parts[1], '\t')
  if len(std_fields) != 3
    throw 'VimwikiTags2: Metadata file corrupted'
  endif

  let vw_part = parts[2]
  if vw_part[0] != "\t"
    throw 'VimwikiTags3: Metadata file corrupted'
  endif

  let vw_fields = split(vw_part[1:], "\t")
  if len(vw_fields) != 1 || vw_fields[0] !~ '^vimwiki:'
    throw 'VimwikiTags4: Metadata file corrupted'
  endif
  let vw_data = substitute(vw_fields[0], '^vimwiki:', '', '')
  try
    let vw_data = json_decode(vw_data)
  catch
    throw 'VimwikiTags5: Metadata file corrupted'
  endtry

  if !has_key(vw_data, 'pagename') || !has_key(vw_data, 'priority') || !has_key(vw_data, 'link')
    throw 'VimwikiTags6: Metadata file corrupted'
  endif

  let pagename = vw_data.pagename
  return s:tag_factory(std_fields[0], std_fields[2], vw_data.link, pagename, vw_data.priority)
endfunction

function! s:tag_factory(name, line, link, pagename, ...) abort
  let tag = {}
  let tag.name = a:name
  let tag.line_number = a:line
  let tag.link = a:link
  let tag.pagename = a:pagename
  let tag.priority = get(a:, 1, -1)

  let tag.vimwiki_data = function('s:tag_vimwiki_data', tag)
  let tag.result = function('s:tag_entry', tag)

  return tag
endfunction

function! s:tag_vimwiki_data() dict abort
  return json_encode({
        \ 'pagename': self.pagename,
        \ 'link': self.link,
        \ 'priority': self.priority,
        \ })
endfunction

function! s:tag_entry() dict abort
  return join([
        \ self.name,
        \ self.pagename . VimwikiGet('ext'),
        \ self.line_number . ';"',
        \ "vimwiki:" . self.vimwiki_data(),
        \ ], "\t")
endfunction

