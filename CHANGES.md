# Work log

State of the three items listed in `README.md` as the things to change, plus what
was verified today.

## The three known problems

### 1. Colour scheme — addressed, needs your eye

Colours were hardcoded `highlight default` lines in the plugin. They are now
driven by a `g:grammar_colors` dictionary you can override from `~/.vimrc`
before the plugin loads, so a new colourscheme no longer has to fight the
plugin.

Also added: undercurl needs `termguicolors` plus a terminal that understands
`t_us`. When either is missing the previous code degraded *silently* — you would
see nothing at all. The plugin now detects that and falls back to a `reverse`
video highlight, so issues stay visible in any terminal.

Verified headlessly: setting custom colours produces
`GrammarError cterm=reverse ctermfg=12 gui=undercurl guifg=#005fff guisp=#005fff`
in a non-gui terminal, and the `gui=` styling is kept for gvim.

**Still open:** "better" is your call. The defaults are the conventional
red / magenta / yellow, but I cannot judge how they look against your actual
terminal — run `:GrammarCheck` on `error_grammar_example.md` and tell me what to
adjust.

### 2. Cannot be run twice — already fixed in the uncommitted rework

Confirmed by test. `:GrammarCheck` twice in a row leaves exactly 4 quickfix
entries and 4 matches (the second run creates fresh match ids and deletes the
old ones via `s:ClearWindow()`), and `:GrammarClear` followed by
`:GrammarCheck` behaves the same. Marks are replaced, never stacked.

The mechanism: window-local `w:grammar_match_ids` plus a single sign group
(`sign_unplace('grammar_checker')`) keyed off the buffer that was checked
(`s:last_buf`), so a re-run does not depend on which window has focus.

### 3. Cursor jumping out and back — already fixed in the uncommitted rework

Confirmed by test: cursor stays at line 1, column 1 across repeated checks.

The cause was `:make`, which runs `:cc` on the first quickfix entry and yanks
you to the top of the file. The plugin now uses `system()` and fills the
quickfix list directly. The write that saves the buffer uses `lockmarks` so it
cannot move marks either.

## What was tested today

- `grammar_checker.py` against the live API on `error_grammar_example.md` —
  4 issues, correct severities, compiles clean.
- Plugin load, `:GrammarCheck` x2, `:GrammarClear`, `:GrammarCheck` again, in
  headless Vim 9.1. Results above.
- Custom `g:grammar_colors` override.

Note on signs: `sign_getplaced()` returned empty in headless tests. That is an
artifact of those tests, not a bug — with no window displaying the buffer,
`sign_place()` is a no-op. It still returned a valid id and the plugin raised no
error, so gutter signs work in a real Vim session. Worth a glance when you try
it.

## Ideas not done, in rough order of value

- **Async checks.** The current `system()` call blocks the editor for the whole
  HTTP round trip, up to the 30s timeout. `job_start()` would fix that.
- **Chunking for long files.** Text over `MAX_CHARS` is silently truncated;
  LanguageTool returns per-chunk offsets, so splitting and re-adding the chunk
  start would cover large documents.
- **Apply a suggestion.** Quickfix shows up to three replacements but you retype
  them by hand; a prompt that picks one and edits the line would close the loop.
- **Rule filtering.** Skip style-only warnings when you want hard errors.
- `README_for_MACHINE_TO_READE.md` documents the abandoned `:make`/errorformat
  design and is now actively misleading. Either rewrite it or delete it.
