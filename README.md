# vim_grammar_max

Grammar checking inside **plain Vim**, using a small Python script that talks to
the public [LanguageTool](https://languagetool.org/) HTTP API.

No Java, no local LanguageTool server, no LSP. Just Vim, Python, `requests`, and
one HTTPS endpoint.

## Quick start

```bash
python3 -m venv .venv && .venv/bin/pip install requests   # or: uv venv && uv pip install requests
./install_plugin.sh                                       # copies the .vim file into ~/.vim/plugin/
```

Then open a text file in Vim and run `:GrammarCheck`. Try it on
`error_grammar_example.md`.

## Commands

| Command | What it does |
|---|---|
| `:GrammarCheck` | Saves the buffer, queries LanguageTool, marks every issue in place. |
| `:GrammarClear` | Removes all highlights, signs and quickfix entries. |
| `:GrammarList`  | Opens the quickfix window with the last results. |
| `:cnext` / `:cprev` | Jump between issues. |

Handy mappings for your `~/.vimrc`:

```vim
nnoremap <leader>g  :GrammarCheck<CR>
nnoremap <leader>gc :GrammarClear<CR>
```

## What you see

Issues are marked by severity, each with its own colour and a `>>` gutter sign:

- **Error** (grammar) — red squiggle
- **Spelling** (misspelling / typography) — magenta squiggle
- **Style** — yellow squiggle

Full messages and up to three suggestions per issue go to the quickfix list.
The cursor does **not** move when you check, and you can run `:GrammarCheck` as
many times as you like — old marks are replaced, never stacked.

## Configuration

Set these in `~/.vimrc` **before** the plugin loads:

```vim
let g:grammar_python        = '/abs/path/.venv/bin/python'  " default: repo .venv, else python3
let g:grammar_script        = '/abs/path/grammar_checker.py' " default: auto-found next to plugin
let g:grammar_open_quickfix = 1                             " default: 0 (inline marks only)

" Colours. Keys are Error / Spelling / Style.
let g:grammar_colors = {'Error':    {'cterm': 1, 'gui': '#ff5555'},
                      \ 'Spelling': {'cterm': 5, 'gui': '#d700ff'},
                      \ 'Style':    {'cterm': 3, 'gui': '#d7d700'}}
```

The squiggle needs `set termguicolors` plus a terminal that supports undercurl.
Without them the plugin falls back to a `reverse` video highlight so issues stay
visible.

Language and size limits live at the top of `grammar_checker.py`:
`LANGUAGE = "en-US"`, `MAX_CHARS = 18000`.

## How it works

```
:GrammarCheck
   └─> grammar_checker.vim ──system()──> python grammar_checker.py <file>
                                              └──POST──> api.languagetool.org/v2/check
        Vim highlights, signs and              <── one JSON object per line ──┘
        quickfix list are filled from that JSON
```

The script prints one JSON object per issue (`lnum`, `col`, `len`, `kind`,
`rule`, `message`, `suggestions`) and diagnostics on stderr. The plugin reads
stdout line by line and decodes it.

Two design notes worth knowing before you edit this code:

- **JSON, not `errorformat`.** Vim's errorformat has no end-column field (`%e`
  is the error *number*), so every span would collapse to a single character.
- **`system()`, not `:make`.** `:make` runs `:cc` on the first entry, which is
  what used to drag the cursor to the top of the file on every check.

Columns and lengths are **byte** offsets, because that is what `matchaddpos()`
expects. `report()` in the Python script does that conversion and clamps the
result to the line — an out-of-range column is a hard error in Vim.

## Caveats

- **Privacy.** Your text is sent to a third-party server. Never check
  confidential documents.
- **Rate limits.** Roughly 20 requests/minute on the public API; files over
  `MAX_CHARS` are truncated. A shared cloud IP can hit HTTP 429 even when idle.
- **Blocking.** The check is synchronous; the editor pauses for the HTTP round
  trip (up to 30s).
- The script checks the file **on disk**, so unsaved edits are not covered.

## Troubleshooting

| Symptom | Check |
|---|---|
| Nothing marked | `:echo g:grammar_python` and `:echo g:grammar_script`; run the script by hand on a file. |
| `No module named 'requests'` | Install it into the venv that `g:grammar_python` points at. |
| HTTP 429 | Wait a minute, then re-run. |
| Colours look wrong | `set termguicolors`, or override `g:grammar_colors`. |
| `Session.vim` replays an old state | Delete it and re-save with `:mksession!`. |

## Files

| File | Purpose |
|---|---|
| `grammar_checker.py` | LanguageTool client; emits one JSON line per issue. |
| `grammar_checker.vim` | The plugin: commands, highlights, signs, quickfix. |
| `install_plugin.sh` | Copies the plugin to `~/.vim/plugin/` with a timestamped backup. |
| `error_grammar_example.md` | Sample file with deliberate errors, for testing. |
| `CHANGES.md` | Work log: what has been fixed and what is still open. |
| `README_for_MACHINE_TO_READE.md` | **Outdated** — describes the old `:make`/errorformat design. |
| `Session.vim` | A saved Vim session; safe to ignore or delete. |
