#!/usr/bin/env python3
"""Grammar check a file via the public LanguageTool API.

Prints one JSON object per issue on stdout; diagnostics go to stderr. Vim's
errorformat could not carry this data: it has no end-column field (%e is the
error *number*), so every span collapsed to a single character.
"""
import json
import sys

import requests

API_URL = "https://api.languagetool.org/v2/check"
LANGUAGE = "en-US"        # en-GB, fr, de-DE, es, ...
MAX_CHARS = 18000
TIMEOUT = 30


def report(text, offset, length):
    """Return (line_number, byte_column, byte_length) clamped to the line."""
    line = text.count("\n", 0, offset) + 1
    start = text.rfind("\n", 0, offset) + 1
    line_text = text[start:].split("\n", 1)[0]

    line_bytes = line_text.encode("utf-8")
    col = len(line_text[:offset - start].encode("utf-8")) + 1
    # matchadd() clips nothing: an out-of-range column is a hard error in Vim.
    col = min(col, max(len(line_bytes), 1))
    span = len(text[offset:offset + length].encode("utf-8"))
    span = max(min(span, len(line_bytes) - col + 1), 1)
    return line, col, span


def main():
    if len(sys.argv) != 2:
        print("Usage: grammar_checker.py <filename>", file=sys.stderr)
        return 1

    filename = sys.argv[1]
    try:
        with open(filename, "r", encoding="utf-8") as f:
            text = f.read()
    except OSError as e:
        print(f"Error: cannot read {filename}: {e}", file=sys.stderr)
        return 1

    if not text.strip():
        return 0

    if len(text) > MAX_CHARS:
        print(f"Note: truncated to {MAX_CHARS} characters.", file=sys.stderr)
        text = text[:MAX_CHARS]

    headers = {
        "User-Agent": "Mozilla/5.0 (compatible; grammar-checker/1.0)",
        "Accept": "application/json",
    }

    try:
        resp = requests.post(API_URL, data={"text": text, "language": LANGUAGE},
                             headers=headers, timeout=TIMEOUT)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1

    if resp.status_code == 429:
        print("Error: LanguageTool public API rate limit hit (429). Wait a "
              "minute and run :GrammarCheck again.", file=sys.stderr)
        return 2

    try:
        resp.raise_for_status()
        result = resp.json()
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1

    for match in result.get("matches", []):
        rule = match.get("rule") or {}
        line, col, span = report(text, match["offset"], match.get("length", 1))
        print(json.dumps({
            "lnum": line,
            "col": col,
            "len": span,
            "kind": rule.get("issueType") or match.get("category", {}).get("id", ""),
            "rule": rule.get("id", "?"),
            "message": match["message"].replace("\n", " "),
            "suggestions": [r["value"] for r in match.get("replacements", [])[:3]],
        }, ensure_ascii=False))

    return 0


if __name__ == "__main__":
    sys.exit(main())
