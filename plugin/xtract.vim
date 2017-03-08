if exists('g:loaded_xtract') || &cp || v:version < 700
  finish
endif
let g:loaded_xtract = 1

" Extracts the current selection into a new file.
"
"     :6,8Xtract newfile
"
command -range -bang -nargs=1 -complete=dir Xtract :<line1>,<line2>call s:Xtract(<bang>0,<f-args>)

" Convert CamelCase to kebab-case
" MyString -> my-string
function! s:ToKebabCase(string)
  return substitute(a:string, '\(\<\u\l\+\|\l\+\)\(\u\)', '\l\1-\l\2', 'g')
endfunction

" Convert string to tag name
" string -> <string></string>
function! s:ConvertToTag(string)
   return '<' . a:string . '></' . a:string . '>'
endfunction

function! s:fileContainsString(string)
  if match(readfile(expand("%:p")), a:string) != -1
    return 1
  endif
endfunction

function! s:Xtract(bang,target) range abort
  let first = a:firstline
  let last = a:lastline
  let range = first.",".last

  let isVue = &filetype == 'vue.html.javascript.css'

  let ext = expand("%:e")        " js
  let path = expand("%:h")       " /path/to
  let fname = a:target.".".ext   " target.js
  let fullpath = path."/".fname  " /path/to/target.js
  let spaces = matchstr(getline(first),"^ *")
  let fileNameWithoutExtension = expand("%:r")

  " Raise an error if invoked without a bang
  if filereadable(fullpath) && !a:bang
    return s:error('E13: File exists (add ! to override): '.fullpath)
  endif

  " Copy it
  silent exe range."yank"
  " Replace it
  let placeholder = substitute(&commentstring, "%s", fname, "")
  silent exe "norm! :".first.",".last."change\<CR>".spaces.placeholder."\<CR>.\<CR>"

  if (isVue)
    let kebabFileName = s:ToKebabCase(fileNameWithoutExtension)
    let tagName = s:ConvertToTag(kebabFileName)
    " Replace selection with tag name
    silent exe "norm! :".first.",".last."change\<CR>".spaces.tagName."\<CR>.\<CR>"
    " Fix indentation
    silent exe "norm! =="
    if (s:fileContainsString('components'))
      execute('%s/components:\s{\zs/\r' . fileNameWithoutExtension . ',/g | normal j=``')
    endif
  else
    " Replace it
    let placeholder = substitute(&commentstring, "%s", fname, "")
    silent exe "norm! :".first.",".last."change\<CR>".spaces.placeholder."\<CR>.\<CR>"
  endif

  " Open a new window and paste it in
  silent execute "split ".fullpath

  if (isVue)
    " Trigger vue snippet and insert the selected lines
    silent exe "normal! iv" . "\<C-r>=UltiSnips#ExpandSnippet()\<CR>"
    silent exe "normal! {{"
    silent put
    silent exe "normal! kdd"
  else
    silent put
    silent 1
    silent normal '"_dd'
  endif

  " mkdir -p
  if !isdirectory(fnamemodify(fullpath, ':h'))
    call mkdir(fnamemodify(fullpath, ':h'), 'p')
  endif

  " Remove extra lines at the end of the file
  silent! '%s#\($\n\s*\)\+\%$##'
  silent 1
endfunction

"
" Shows an error message.
"
function! s:error(str)
  echohl ErrorMsg
  echomsg a:str
  echohl None
  let v:errmsg = a:str
  return ''
endfunction
