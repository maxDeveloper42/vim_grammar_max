" ~/.vim/plugin/grammar_checker.vim
" Inline grammar checking via language_tool_python (public LanguageTool API).

if exists('g:loaded_grammar_checker')
    finish
endif
let g:loaded_grammar_checker = 1

" --- Configurable paths -------------------------------------------------
let g:grammar_python = get(g:, 'grammar_python',
    \ '/home/ubuntu/workGao/workInOct2026/vimGrammarPython/.venv/bin/python')
let g:grammar_script = get(g:, 'grammar_script',
    \ '/home/ubuntu/workGao/workInOct2026/vimGrammarPython/grammar_checker.py')

" Open quickfix after check? 0 = no (just inline marks), 1 = yes.
let g:grammar_open_quickfix = get(g:, 'grammar_open_quickfix', 0)

" Sign + highlight definitions
sign define GrammarErrorSign text=>> texthl=GrammarError
highlight default link GrammarError SpellBad

" --- Commands -----------------------------------------------------------
command! GrammarCheck call s:GrammarCheck()
command! GrammarClear call s:GrammarClear()
command! GrammarList  copen

" --- Implementation -----------------------------------------------------
function! s:GrammarClear() abort
    " Clear highlight matches added by this plugin (group 'GrammarError').
    for m in getmatches()
        if m.group ==# 'GrammarError'
            call matchdelete(m.id)
        endif
    endfor
    " Remove our signs from the current buffer.
    call sign_unplace('grammar_checker', {'buffer': bufnr('%')})
endfunction

function! s:GrammarCheck() abort
    let l:file = expand('%:p')

    if empty(l:file) || !filereadable(l:file)
        echohl WarningMsg
        echomsg 'GrammarCheck: no readable file in the current buffer'
        echohl None
        return
    endif
    if !filereadable(g:grammar_script)
        echohl ErrorMsg
        echomsg 'GrammarCheck: script not found: ' . g:grammar_script
        echohl None
        return
    endif

    " Wipe previous markers before re-checking.
    call s:GrammarClear()

    " Save the buffer so the script reads the latest on-disk content.
    silent! write

    " Buffer-local makeprg / errorformat so nothing leaks into sessions.
    let l:save_makeprg = &l:makeprg
    let l:save_efm     = &l:errorformat

    let &l:makeprg     = shellescape(g:grammar_python)
    \                   . ' ' . shellescape(g:grammar_script)
    " file:line:col:endcol: message   -> %f:%l:%c:%e: %m
    let &l:errorformat = '%f:%l:%c:%e: %m'

    execute 'silent make ' . shellescape(l:file)

    let &l:makeprg     = l:save_makeprg
    let &l:errorformat = l:save_efm

    let l:qflist = getqflist()
    let l:bufnr  = bufnr('%')
    let l:count  = 0

    for item in l:qflist
        if get(item, 'bufnr', l:bufnr) != l:bufnr
            continue
        endif

        let l:line    = item.lnum
        let l:col     = item.col                          " 0-based from script
        let l:end_col = get(item, 'end_col', l:col + 1)
        let l:len     = max([l:end_col - l:col, 1])

        " Inline highlight (matchaddpos: col is 1-based, len in chars/bytes).
        call matchaddpos('GrammarError', [[l:line, l:col + 1, l:len]], 10)

        " Sign in the gutter.
        call sign_place(0, 'grammar_checker', 'GrammarErrorSign',
            \ l:bufnr, {'lnum': l:line, 'priority': 10})

        let l:count += 1
    endfor

    if l:count == 0
        echomsg 'GrammarCheck: no issues found'
    else
        if g:grammar_open_quickfix
            copen
        endif
        echomsg printf('GrammarCheck: %d issue(s) marked', l:count)
    endif
endfunction




" ==== something new, just try
