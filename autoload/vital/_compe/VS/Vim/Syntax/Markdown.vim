" ___vital___
" NOTE: lines between '" ___vital___' is generated by :Vitalize.
" Do not modify the code nor insert new lines before '" ___vital___'
function! s:_SID() abort
  return matchstr(expand('<sfile>'), '<SNR>\zs\d\+\ze__SID$')
endfunction
execute join(['function! vital#_compe#VS#Vim#Syntax#Markdown#import() abort', printf("return map({'apply': ''}, \"vital#_compe#function('<SNR>%s_' . v:key)\")", s:_SID()), 'endfunction'], "\n")
delfunction s:_SID
" ___vital___
"
" apply
"
function! s:apply(...) abort
  let l:args = get(a:000, 0, {})

  if !exists('b:___VS_Vim_Syntax_Markdown')
    call s:_execute('runtime! syntax/markdown.vim')

    " Remove markdownCodeBlock because we support it manually.
    call s:_clear('markdownCodeBlock') " tpope/vim-markdown
    call s:_clear('mkdCode') " plasticboy/vim-markdown

    " Modify markdownCode (`codes...`)
    call s:_clear('markdownCode')
    syntax region markdownCode matchgroup=Conceal start=/\%(``\)\@!`/ matchgroup=Conceal end=/\%(``\)\@!`/ containedin=TOP keepend concealends

    " Modify markdownEscape (_bold\_text_)
    call s:_clear('markdownEscape')
    let l:name = 0
    for l:char in split('!"#$%&()*+,-.g:;<=>?@[]^_`{|}~' . "'", '\zs')
      let l:name += 1
      execute printf('syntax match vital_vs_vim_syntax_markdown_escape_%s /[^\\]\?\zs\\\V%s/ conceal cchar=%s containedin=ALL',
      \   l:name,
      \   l:char,
      \   l:char,
      \ )
    endfor
    syntax match vital_vs_vim_syntax_markdown_escape_escape /[^\\]\?\zs\\\\/ conceal cchar=\ containedin=ALL

    " Add syntax for basic html entities.
    syntax match vital_vs_vim_syntax_markdown_entities_lt /&lt;/ containedin=ALL conceal cchar=<
    syntax match vital_vs_vim_syntax_markdown_entities_gt /&gt;/ containedin=ALL conceal cchar=>
    syntax match vital_vs_vim_syntax_markdown_entities_amp /&amp;/ containedin=ALL conceal cchar=&
    syntax match vital_vs_vim_syntax_markdown_entities_quot /&quot;/ containedin=ALL conceal cchar="
    syntax match vital_vs_vim_syntax_markdown_entities_nbsp /&nbsp;/ containedin=ALL conceal cchar= 

    let b:___VS_Vim_Syntax_Markdown = {}
  endif

  let l:text = has_key(l:args, 'text') ? l:args.text : getbufline('%', 1, '$')
  let l:text = type(l:text) == v:t_list ? join(l:text, "\n") : l:text
  try
    for [l:mark, l:filetype] in items(s:_get_filetype_map(l:text))
      let l:group = substitute(toupper(l:mark), '\.', '_', 'g')
      if has_key(b:___VS_Vim_Syntax_Markdown, l:group)
        continue
      endif
      let b:___VS_Vim_Syntax_Markdown[l:group] = v:true

      try
        call s:_execute('syntax include @%s syntax/%s.vim', l:group, l:filetype)
        call s:_execute('syntax region %s matchgroup=Conceal start=/%s/rs=e matchgroup=Conceal end=/%s/re=s contains=@%s containedin=TOP keepend concealends',
        \   l:group,
        \   printf('```\s*%s\s*', l:mark),
        \   '```\s*\%(\s\|' . "\n" . '\|$\)',
        \   l:group
        \ )
      catch /.*/
        unsilent echomsg printf('[VS.Vim.Syntax.Markdown] The `%s` is not valid filetype! You can add `"let g:markdown_fenced_languages = ["FILETYPE=%s"]`.', l:mark, l:mark)
      endtry
    endfor
  catch /.*/
    unsilent echomsg string({ 'exception': v:exception, 'throwpoint': v:throwpoint })
  endtry
endfunction

"
" _clear
"
function! s:_clear(group) abort
  try
    execute printf('silent! syntax clear %s', a:group)
  catch /.*/
  endtry
endfunction

"
"  _execute
"
function! s:_execute(command, ...) abort
  let b:current_syntax = ''
  unlet b:current_syntax

  let g:main_syntax = ''
  unlet g:main_syntax

  execute call('printf', [a:command] + a:000)
endfunction

"
" _get_filetype_map
"
function! s:_get_filetype_map(text) abort
  let l:filetype_map = {}
  for l:mark in s:_find_marks(a:text)
    let l:filetype_map[l:mark] = s:_get_filetype_from_mark(l:mark)
  endfor
  return l:filetype_map
endfunction

"
" _find_marks
"
function! s:_find_marks(text) abort
  let l:marks = {}

  " find from buffer contents.
  let l:text = a:text
  let l:pos = 0
  while 1
    let l:match = matchstrpos(l:text, '```\s*\zs\w\+', l:pos, 1)
    if empty(l:match[0])
      break
    endif
    let l:marks[l:match[0]] = v:true
    let l:pos = l:match[2]
  endwhile

  return keys(l:marks)
endfunction

"
" _get_filetype_from_mark
"
function! s:_get_filetype_from_mark(mark) abort
  for l:config in get(g:, 'markdown_fenced_languages', [])
    if l:config !~# '='
      if l:config ==# a:mark
        return a:mark
      endif
    else
      let l:config = split(l:config, '=')
      if l:config[1] ==# a:mark
        return l:config[0]
      endif
    endif
  endfor
  return a:mark
endfunction

