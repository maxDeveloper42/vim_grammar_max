Here's a complete README for the project. Save it as `README.md` in `~/workGao/workInOct2026/vimGrammarPython/`.

### 📄 `README.md`

```markdown
# vimGrammarPython

Grammar checking directly inside **pure Vim**, powered by a small Python
script that talks to the public [LanguageTool](https://languagetool.org/)
HTTP API.

No Java. No local LanguageTool server. No GitHub downloads at runtime.
Just Vim, Python, and one HTTPS endpoint.

---

## ✨ What it does

Open any text file in Vim, run `:GrammarCheck`, and:

- The **wrong words are underlined in red** right in the buffer.
- A **`>>` sign** appears in the sign column on the affected lines.
- The issues are also loaded into Vim's **quickfix list**, so you can jump
  between them with `:cnext` / `:cprev`.
- `:GrammarClear` removes all markers.
- `:GrammarList` opens the quickfix list manually if you want to see the
  full messages and suggestions.

Under the hood, a Python script sends the file's text to
`https://api.languagetool.org/v2/check` and prints each match in a
`file:line:col:endcol: message` format that Vim's `errorformat` can parse.

---

## 📁 Project layout

```
vimGrammarPython/
├── grammar_checker.py     # Python script: reads a file, queries LanguageTool,
│                          # prints issues in Vim's errorformat
├── grammar_checker.vim    # Vim plugin: defines :GrammarCheck / :GrammarClear /
│                          # :GrammarList and draws highlights + signs
├── install_plugin.sh      # Copies grammar_checker.vim into ~/.vim/plugin/
│                          # (with backup + "already up to date" detection)
├── error_grammar_example.md
├── README.md              # This file
└── .venv/                 # uv-managed virtualenv with `requests` installed
```

The two files that matter are `grammar_checker.py` and `grammar_checker.vim`.
The rest is convenience.

---

## 🧰 Requirements

| Component | Notes |
|---|---|
| **Vim**   | Any reasonably modern Vim 8+ or Neovim. `matchaddpos()`, `sign_place()`, and `:make` are used. |
| **Python** | 3.9+ (the venv in this repo uses 3.12). |
| **uv**    | Used to create the venv. Plain `python -m venv` works too. |
| **`requests`** | Installed in the venv. That's the only Python dependency. |
| **Internet access** | Only to `api.languagetool.org`. Nothing else is fetched. |

> ⚠️ **Privacy:** the public API sends your text to a third-party server.
> Do not run `:GrammarCheck` on confidential documents.
>
> ⚠️ **Rate limits:** ~20 requests/minute, ~20 KB per request. Large files
> are truncated to 18 KB by the script. If your VM's IP is shared (e.g. a
> cloud host), you may occasionally get HTTP 429 even when idle.

---

## 🚀 Setup

### 1. Clone / copy the project

```bash
cd ~/workGao/workInOct2026/vimGrammarPython
```

### 2. Create the venv and install the one dependency

```bash
uv venv
uv pip install requests
```

(If you don't use `uv`: `python3 -m venv .venv && .venv/bin/pip install requests`.)

### 3. Install the Vim plugin

```bash
./install_plugin.sh
```

This copies `grammar_checker.vim` into `~/.vim/plugin/`, creating the
directory if needed and saving a timestamped `.bak` of any previous
version. Re-run it any time you edit the plugin in this directory.

### 4. (Optional) Point the plugin at your paths

The plugin defaults to the paths used by this project. If you move the
repo elsewhere, add these to your `~/.vimrc` **before** the plugin loads:

```vim
let g:grammar_python = '/abs/path/to/.venv/bin/python'
let g:grammar_script = '/abs/path/to/grammar_checker.py'
```

To also make the quickfix window pop open on every check:

```vim
let g:grammar_open_quickfix = 1
```

---

## 🎮 Usage

In Vim, with the file you want to check open:

| Command | What it does |
|---|---|
| `:GrammarCheck` | Runs the checker, draws highlights and signs. |
| `:GrammarClear` | Removes all highlights and signs from the buffer. |
| `:GrammarList`  | Opens the quickfix window with the last results. |
| `:cnext` / `:cprev` | Jump to the next / previous issue. |
| `:copen` / `:cclose` | Toggle the quickfix window. |

### Suggested key mappings (add to `~/.vimrc`)

```vim
nnoremap <leader>g  :GrammarCheck<CR>
nnoremap <leader>gc :GrammarClear<CR>
nnoremap <leader>gl :GrammarList<CR>
```

Then `<Space>g` checks, `<Space>gc` clears, `<Space>gl` lists.

---

## ⚙️ How it works

```
┌────────────┐   :GrammarCheck    ┌──────────────────────┐
│   Vim      │ ─────────────────► │ grammar_checker.vim  │
│  (buffer)  │                    │  - writes the buffer │
└────────────┘                    │  - :make             │
                                  └──────────┬───────────┘
                                             │ runs
                                             ▼
                          .venv/bin/python  grammar_checker.py <file>
                                             │
                                             │ HTTPS POST
                                             ▼
                              api.languagetool.org/v2/check
                                             │
                                             │ JSON
                                             ▼
                     file:line:col:endcol: [RULE] message -> fixes
                                             │
                                             │ parsed by
                                             ▼
                             Vim errorformat → quickfix list
                                             │
                                             ├─► matchaddpos() → red underline
                                             └─► sign_place()  → `>>` in gutter
```

1. **`grammar_checker.vim`** sets a buffer-local `makeprg` pointing at the
   venv Python plus the script, and a buffer-local `errorformat` of
   `%f:%l:%c:%e: %m`.
2. It runs `:make <current file>`, which spawns the Python script with the
   filename as the only argument.
3. **`grammar_checker.py`** reads the file, POSTs the text to the public
   LanguageTool API, and prints one line per match in the format above.
   Line/column are computed from LanguageTool's character offsets.
4. Vim parses those lines into the quickfix list.
5. The plugin walks the quickfix list and, for each entry in the current
   buffer, calls `matchaddpos()` (red underline) and `sign_place()` (gutter
   sign).
6. `:GrammarClear` deletes those matches and signs.

All Vim-side state is buffer-local and restored after each run, so
`:mksession` / `vim -S` won't replay a stale `makeprg`.

---

## 🔧 Customising

### Language

Edit `grammar_checker.py`:

```python
LANGUAGE = "en-US"     # try "en-GB", "fr", "de-DE", "es", ...
```

Full list: `curl https://api.languagetool.org/v2/languages | jq`.

### Highlight colour / style

The plugin links its `GrammarError` highlight group to `SpellBad` (red
underline). To change it, override in your `~/.vimrc` **after** the plugin
loads:

```vim
highlight GrammarError cterm=undercurl gui=undercurl ctermfg=red guifg=#ff5555
```

### File size limit

`MAX_CHARS` in `grammar_checker.py` (default 18000). Larger files are
truncated. To support bigger documents, chunk the text in the script and
merge the JSON results — LanguageTool returns offsets relative to each
chunk, so you'd add the chunk's starting offset back.

---

## 🐛 Troubleshooting

| Symptom | Fix |
|---|---|
| `grammar_checker.py: command not found` | `makeprg` was set to the script alone. Use the venv Python as the interpreter (as the current plugin does). |
| `Permission denied` | Same cause — Python can't execute the script directly. Calling it as `python script.py` avoids the issue entirely. |
| `ModuleNotFoundError: No module named 'requests'` | Install into the venv: `uv pip install requests`. |
| `RateLimitError` / HTTP 429 | Wait a minute. Public API is shared, so a cloud VM's IP may occasionally be throttled. |
| Nothing is highlighted | Check `:echo g:grammar_python` and `:echo g:grammar_script` inside Vim; confirm both paths exist. Also run the script from the shell once to see its raw output. |
| Quickfix opens unexpectedly | Set `let g:grammar_open_quickfix = 0` in `~/.vimrc`. |
| `vim -S` replays an old failure | Delete the stale `Session.vim` (`rm Session.vim`) and re-save with `:mksession!` if you still want sessions. |

---

## 🗺️ Possible improvements

- **Chunking** for files larger than 20 KB.
- **Asynchronous** execution (`job_start()` in Vim 8+) so the editor isn't
  blocked while waiting for HTTP.
- **Prefer a fully local engine** if privacy matters — [Harper](https://writewithharper.com/)
  (Rust, no Java) can be plugged in as an LSP server instead of this HTTP
  approach.
- **Filter by rule category** — LanguageTool classifies matches (grammar,
  style, typography); you could skip style warnings if you only want
  hard grammar errors.

---

## 📜 License

Whatever you want. `grammar_checker.py` uses the public LanguageTool API
and is subject to [LanguageTool's terms](https://languagetool.org/legal/).
```

### 📌 A couple of notes about this README

- **Placeholders to tweak**: the repo path appears in a few places (`~/workGao/workInOct2026/vimGrammarPython`). If you ever move the project, do a find-and-replace.
- **License section**: I left it open since I don't know your intent. If you want to make it MIT, replace with the standard MIT boilerplate.
- **Adding it to the project**: save it as `README.md` in the project root (you already have one there, so this will overwrite it):

```bash
cd ~/workGao/workInOct2026/vimGrammarPython
vim README.md      # paste the content above, save
```
