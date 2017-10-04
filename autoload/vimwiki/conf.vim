
" Prefix to use for this autoload file
let s:autoload_prefix = "vimwiki#conf"
let s:autoload_file = expand("<sfile>:p")

" Set the name of name of your plugin.
" Here is my best guess
call conf#set_name(s:, 'vimwiki')

" Set a version for your plugin.
" It should be valid semver string or ['major', 'minor', 'patch'] list
call conf#set_version(s:, [1, 0, 0])

" Try adding a configuration area to your plugin, like so
" call conf#add_area(s:, 'defaults')


" And then add some options
" call conf#add_setting(s:, 'defaults', 'map_key', {'default': '<leader>x', 'type': v:t_string})
" call conf#add_setting(s:, 'defaults', 'another_key', {'default': '<leader>a', 'type': v:t_string})


""
" vimwiki#conf#set
" Set a "value" for the "area.setting"
" See |conf.set_setting|
function! vimwiki#conf#set(area, setting, value) abort
  return conf#set_setting(s:, a:area, a:setting, a:value)
endfunction


""
" vimwiki#conf#get
" Get the "value" for the "area.setting"
" See |conf.get_setting}
function! vimwiki#conf#get(area, setting) abort
  return conf#get_setting(s:, a:area, a:setting)
endfunction


""
" vimwiki#conf#view
" View the current configuration dictionary.
" Useful for debugging
function! vimwiki#conf#view() abort
  return conf#view(s:)
endfunction


""
" vimwiki#conf#menu
" Provide the user with an automatic "quickmenu"
" See |conf.menu|
function! vimwiki#conf#menu() abort
  return conf#menu(s:)
endfunction


""
" vimwiki#conf#version
" Get the version for this plugin
" Returns a semver dict
function! vimwiki#conf#version() abort
  return conf#get_version(s:)
endfunction


""
" vimwiki#conf#require
" Require a version of this plugin.
" Returns false if not a high enough version
function! vimwiki#conf#require(semver) abort
  return conf#require_version(s:, a:semver)
endfunction


""
" vimwiki#conf#debug
" Print a debug statement containing information about the plugin
" and the versions of required plugins
function! vimwiki#conf#debug() abort
  return conf#debug(s:)
endfunction


""
" vimwiki#conf#generate_docs
" Returns a list of lines to be placed in your documentation
" Can use :call append(line("%"), func())
function! vimwiki#conf#generate_docs() abort
  return conf#docs#generate(s:, s:autoload_prefix)
endfunction

""
" vimwiki#conf#insert_docs
" Insert the generated docs under where you cursor is
function! vimwiki#conf#insert_docs() abort
  return conf#docs#insert(s:, s:autoload_prefix)
endfunction

