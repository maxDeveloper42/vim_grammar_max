#!/usr/bin/env python3
import sys
import requests

API_URL = "https://api.languagetool.org/v2/check"
LANGUAGE = "en-US"        # change to en-GB, fr, de, etc. if you like
MAX_CHARS = 18000

def main():
    if len(sys.argv) != 2:
        print("Usage: grammar_checker.py <filename>", file=sys.stderr)
        sys.exit(1)

    filename = sys.argv[1]

    with open(filename, "r", encoding="utf-8") as f:
        text = f.read()

    if not text.strip():
        return

    if len(text) > MAX_CHARS:
        text = text[:MAX_CHARS]

    headers = {
        "User-Agent": "Mozilla/5.0 (compatible; grammar-checker/1.0)",
        "Accept": "application/json",
    }
    data = {"text": text, "language": LANGUAGE}

    try:
        resp = requests.post(API_URL, data=data, headers=headers, timeout=30)
        if resp.status_code == 429:
            print("Error: LanguageTool public API rate limit hit (429).",
                  file=sys.stderr)
            sys.exit(2)
        resp.raise_for_status()
        result = resp.json()
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    for match in result.get("matches", []):
        offset = match["offset"]
        length = match.get("length", 1)          # <- new: error span length

        line = text.count("\n", 0, offset) + 1
        last_nl = text.rfind("\n", 0, offset)
        col = offset - (last_nl + 1)              # 0-based
        end_col = col + length                    # 0-based exclusive

        message = match["message"].replace("\n", " ")
        rule_id = match.get("rule", {}).get("id", "?")
        replacements = ", ".join(
            r["value"] for r in match.get("replacements", [])[:3]
        )

        # file:line:col:endcol: [rule_id] message -> replacements
        print(f"{filename}:{line}:{col}:{end_col}: [{rule_id}] {message} -> {replacements}")


if __name__ == "__main__":
    main()
