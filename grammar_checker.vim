" ~/.vim/plugin/grammar_checker.vim
" Inline grammar checking via the public LanguageTool API.

if exists('g:loaded_grammar_checker')
    finish
endif
let g:loaded_grammar_checker = 1

" --- Configurable paths -------------------------------------------------
" Find the script: beside this plugin, one directory up, then the repo default.
let s:here = expand('<sfile>:p:h')
let s:repo = filereadable(s:here . '/grammar_checker.py') ? s:here
    \ : filereadable(s:here . '/../grammar_checker.py') ? simplify(s:here . '/..')
    \ : '/home/ubuntu/workGao/workInOct2026/vim_grammar_max'

if !exists('g:grammar_script')
    let g:grammar_script = s:repo . '/grammar_checker.py'
endif
if !exists('g:grammar_python')
    let g:grammar_python = executable(s:repo . '/.venv/bin/python')
        \ ? s:repo . '/.venv/bin/python' : 'python3'
endif

" Open quickfix after a check? 0 = no (inline marks only), 1 = yes.
let g:grammar_open_quickfix = get(g:, 'grammar_open_quickfix', 0)

" --- Highlights ---------------------------------------------------------
" Colour is user-overridable: set g:grammar_colors in your vimrc before the
" plugin loads. Defaults follow the common red/magenta/yellow convention.
if !exists('g:grammar_colors')
    let g:grammar_colors = {
        \ 'Error':    {'cterm': 1, 'gui': '#ff5555'},
        \ 'Spelling': {'cterm': 5, 'gui': '#d700ff'},
        \ 'Style':    {'cterm': 3, 'gui': '#d7d700'},
        \ }
endif

" undercurl needs termguicolors plus a terminal that understands t_us; with
" either missing it silently degrades, so fall back to a visible style.
let s:squiggle = has('gui_running') || (&termguicolors && &t_us !=# '')
let s:cterm_style = s:squiggle ? 'undercurl' : 'reverse'
let s:gui_style = 'undercurl'

for s:name in ['Error', 'Spelling', 'Style']
    let s:c = g:grammar_colors[s:name]
    execute 'highlight default Grammar' . s:name
        \ . ' cterm=' . s:cterm_style . ' gui=' . s:gui_style
        \ . ' ctermfg=' . s:c.cterm . ' guifg=' . s:c.gui . ' guisp=' . s:c.gui
    execute 'highlight default Grammar' . s:name . 'Sign ctermfg=' . s:c.cterm
        \ . ' guifg=' . s:c.gui
endfor
unlet s:name s:c
unlet s:squiggle s:cterm_style s:gui_style

for s:name in ['Error', 'Spelling', 'Style']
    execute 'sign define GrammarSign' . s:name . ' text=>> texthl=Grammar' . s:name . 'Sign'
endfor
unlet s:name

" --- State --------------------------------------------------------------
" Marks are window-local, signs are buffer-local; both keyed off the buffer
" that was checked so a re-run never depends on which window has focus.
let s:last_buf = -1
let s:pending = []

function! s:SeverityFor(kind) abort
    if a:kind ==# 'misspelling' || a:kind ==# 'typographical'
        return 'Spelling'
    endif
    if a:kind ==# 'grammar'
        return 'Error'
    endif
    return 'Style'
endfunction

function! s:ClearWindow() abort
    for l:id in get(w:, 'grammar_match_ids', [])
        silent! call matchdelete(l:id)
    endfor
    let w:grammar_match_ids = []
endfunction

function! s:ApplyPending() abort
    call s:ClearWindow()
    let l:ids = []
    for l:item in s:pending
        let l:add = matchaddpos('Grammar' . s:SeverityFor(get(l:item, 'kind', '')),
            \ [[l:item.lnum, l:item.col, l:item.len]], 10)
        call add(l:ids, l:add)
    endfor
    let w:grammar_match_ids = l:ids
endfunction

function! s:Clear() abort
    let l:buf = s:TargetBuf()
    if l:buf < 0
        return
    endif
    for l:win in win_findbuf(l:buf)
        call win_execute(l:win, 'call s:ClearWindow()')
    endfor
    silent! call sign_unplace('grammar_checker', {'buffer': l:buf})
    call setqflist([])
    echomsg 'GrammarCheck: markers cleared'
endfunction

" The quickfix window has no file of its own, so when it has focus fall back to
" the buffer that was last checked instead of erroring out.
function! s:TargetBuf() abort
    let l:buf = bufnr('%')
    if filereadable(bufname(l:buf))
        return l:buf
    endif
    if s:last_buf > 0 && bufexists(s:last_buf) && buflisted(s:last_buf)
        return s:last_buf
    endif
    return -1
endfunction

function! s:Check() abort
    let l:buf = s:TargetBuf()
    if l:buf < 0
        echohl WarningMsg
        echomsg 'GrammarCheck: no readable file to check'
        echohl None
        return
    endif
    let l:file = fnamemodify(bufname(l:buf), ':p')
    if !filereadable(g:grammar_script)
        echohl ErrorMsg
        echomsg 'GrammarCheck: script not found: ' . g:grammar_script
        echohl None
        return
    endif

    " Only save when we are actually editing that buffer: the file on disk is
    " what gets sent, and a buffer we are not in cannot be written safely here.
    if l:buf == bufnr('%') && getbufvar(l:buf, '&modified')
        if !&l:modifiable
            echohl WarningMsg
            echomsg 'GrammarCheck: buffer is not modifiable, checking saved contents'
            echohl None
        else
            try
                lockmarks silent write
            catch
                echohl WarningMsg
                echomsg 'GrammarCheck: could not save, checking the file on disk'
                echohl None
            endtry
        endif
    endif

    " stderr to its own file: merging it into stdout (2>&1) can interleave a
    " warning into the middle of a JSON line.
    let l:errfile = tempname()
    let l:cmd = shellescape(g:grammar_python) . ' ' . shellescape(g:grammar_script)
        \ . ' ' . shellescape(l:file) . ' 2>' . shellescape(l:errfile)

    " system() instead of :make - :make runs :cc on the first entry, which is
    " what dragged the cursor to the top of the file on every check.
    let l:raw = system(l:cmd)
    let l:rc = v:shell_error
    let l:problems = filter(readfile(l:errfile), '!empty(v:val)')
    call delete(l:errfile)

    let l:items = []
    for l:line in split(l:raw, "\n")
        if l:line =~# '^{.\+}$'
            let l:item = json_decode(l:line)
            if has_key(l:item, 'message')
                call add(l:items, l:item)
            endif
        endif
    endfor

    if l:rc != 0 || (empty(l:items) && !empty(l:problems))
        echohl ErrorMsg
        echomsg 'GrammarCheck: failed: ' . join(l:problems, ' ')
        echohl None
        return
    endif

    if !empty(l:problems)
        echomsg 'GrammarCheck: ' . join(l:problems, ' ')
    endif

    let s:last_buf = l:buf
    let s:pending = l:items
    call s:Draw(l:buf, l:file)
endfunction

function! s:Draw(buf, file) abort
    call sign_unplace('grammar_checker', {'buffer': a:buf})

    let l:entries = []
    for l:item in s:pending
        let l:sev = s:SeverityFor(get(l:item, 'kind', ''))
        let l:sugg = get(l:item, 'suggestions', [])
        let l:text = '[' . l:sev . '] ' . l:item.message
            \ . (empty(l:sugg) ? '' : ' -> ' . join(l:sugg, ', '))
        call add(l:entries, {
            \ 'bufnr': a:buf,
            \ 'lnum': l:item.lnum,
            \ 'col': l:item.col,
            \ 'end_col': l:item.col + l:item.len,
            \ 'text': l:text,
            \ })
        call sign_place(0, 'grammar_checker', 'GrammarSign' . l:sev, a:buf,
            \ {'lnum': l:item.lnum, 'priority': 10})
    endfor

    " Two calls: this Vim rejects a list and a "what" dict in one call (E475),
    " and the "action" must be "r" - " " with a "what" dict wipes the items.
    call setqflist(l:entries, 'r')
    call setqflist([], 'r', {'title': 'Grammar: ' . fnamemodify(a:file, ':t')})

    for l:win in win_findbuf(a:buf)
        call win_execute(l:win, 'call s:ApplyPending()')
    endfor

    if empty(l:entries)
        echomsg 'GrammarCheck: no issues found'
    else
        if g:grammar_open_quickfix
            copen
        endif
        echomsg printf('GrammarCheck: %d issue(s) marked', len(l:entries))
    endif
endfunction

" --- Commands -----------------------------------------------------------
command! GrammarCheck call s:Check()
command! GrammarClear call s:Clear()
command! GrammarList  copen

augroup grammar_checker
    autocmd!
    " A closed window's matches die with it; drop the signs with it.
    autocmd BufWipeout * silent! call sign_unplace('grammar_checker', {'buffer': expand('<abuf>')})
augroup END
