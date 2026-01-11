#!/usr/bin/env python3
"""
Unicode safety scan.

Policy:
- Bidi control characters are ALWAYS forbidden (all files).
- "Hidden" format characters and sneaky whitespace are forbidden in STRICT files
  (shell/config/allowlist/etc.), but allowed in DOCS (e.g. .md).

Exit code:
- 1 if forbidden characters are found
- 0 otherwise

Usage:
  python3 scripts/unicode_safety_scan.py
  python3 scripts/unicode_safety_scan.py --warn-docs
  python3 scripts/unicode_safety_scan.py path/to/file
"""

from __future__ import annotations

import argparse
import subprocess
import sys
import unicodedata
from pathlib import Path
from typing import Iterable, List, Tuple

# ---- Forbidden everywhere: Trojan Source style bidi controls ----
BIDI_CODEPOINTS = {
    0x061C,  # ARABIC LETTER MARK
    0x200E,  # LEFT-TO-RIGHT MARK
    0x200F,  # RIGHT-TO-LEFT MARK
    *range(0x202A, 0x202F),  # LRE/RLE/PDF/LRO/RLO + others in that block
    *range(0x2066, 0x206A),  # LRI/RLI/FSI/PDI
}

# ---- Forbidden in STRICT files (but allowed in docs by default) ----
HIDDEN_FORMAT_CODEPOINTS = {
    0x00AD,  # SOFT HYPHEN
    0x034F,  # COMBINING GRAPHEME JOINER
    0x200B,  # ZERO WIDTH SPACE
    0x200C,  # ZERO WIDTH NON-JOINER
    0x200D,  # ZERO WIDTH JOINER (ZWJ)  <-- emoji joiner
    0x2060,  # WORD JOINER
    0xFEFF,  # ZERO WIDTH NO-BREAK SPACE / BOM
}

SNEAKY_WHITESPACE = {
    0x00A0,  # NO-BREAK SPACE
    0x1680,  # OGHAM SPACE MARK
    0x2000, 0x2001, 0x2002, 0x2003, 0x2004, 0x2005, 0x2006, 0x2007,
    0x2008, 0x2009, 0x200A,
    0x202F,  # NARROW NO-BREAK SPACE
    0x205F,  # MEDIUM MATHEMATICAL SPACE
    0x3000,  # IDEOGRAPHIC SPACE
}

STRICT_CODEPOINTS = HIDDEN_FORMAT_CODEPOINTS | SNEAKY_WHITESPACE

# File classification
DOCS_EXTS = {".md", ".txt", ".rst"}
STRICT_EXTS = {
    ".sh", ".bash", ".zsh",
    ".ini", ".conf", ".cfg", ".env",
    ".yml", ".yaml", ".json", ".toml",
    ".dockerfile",
}

STRICT_PATHS = {
    Path("build/allowlist"),
}

def git_ls_files() -> List[Path]:
    out = subprocess.check_output(["git", "ls-files"], text=True)
    return [Path(line.strip()) for line in out.splitlines() if line.strip()]

def is_docs_file(p: Path) -> bool:
    return p.suffix.lower() in DOCS_EXTS

def is_strict_file(p: Path) -> bool:
    if p.name == "Dockerfile":
        return True
    if p in STRICT_PATHS:
        return True
    return p.suffix.lower() in STRICT_EXTS

def describe_cp(cp: int) -> str:
    ch = chr(cp)
    name = unicodedata.name(ch, "UNKNOWN")
    cat = unicodedata.category(ch)
    return f"U+{cp:04X} {name} (category {cat})"

def scan_text(text: str, path: Path) -> List[Tuple[str, int, int, int, str]]:
    """
    Returns list of (severity, line_no, col_no, codepoint, snippet)
    severity: 'ERROR' or 'WARN'
    """
    issues = []
    lines = text.splitlines(keepends=True)

    strict = is_strict_file(path)
    docs = is_docs_file(path)

    for i, line in enumerate(lines, start=1):
        for j, ch in enumerate(line, start=1):
            cp = ord(ch)

            if cp in BIDI_CODEPOINTS:
                issues.append(("ERROR", i, j, cp, line.rstrip("\n")))
                continue

            if cp in STRICT_CODEPOINTS:
                if strict:
                    issues.append(("ERROR", i, j, cp, line.rstrip("\n")))
                elif docs:
                    issues.append(("WARN", i, j, cp, line.rstrip("\n")))
                else:
                    # default: treat unknown extensions as strict-ish
                    issues.append(("ERROR", i, j, cp, line.rstrip("\n")))

    return issues

def read_text(path: Path) -> str | None:
    try:
        data = path.read_bytes()
    except Exception as e:
        print(f"[warn] Could not read {path}: {e}", file=sys.stderr)
        return None
    if b"\x00" in data:
        return None
    try:
        return data.decode("utf-8")
    except UnicodeDecodeError:
        return data.decode("utf-8", errors="surrogateescape")

def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--warn-docs", action="store_true",
                    help="Print warnings for docs files; otherwise docs warnings are suppressed.")
    ap.add_argument("paths", nargs="*", help="Optional paths to scan; default scans git ls-files.")
    args = ap.parse_args()

    targets = [Path(p) for p in args.paths] if args.paths else git_ls_files()

    any_error = False
    any_warn = False

    for path in targets:
        if not path.exists() or path.is_dir():
            continue

        text = read_text(path)
        if text is None:
            continue

        issues = scan_text(text, path)
        if not issues:
            continue

        for severity, line_no, col_no, cp, snippet in issues:
            if severity == "WARN" and not args.warn_docs:
                continue

            if severity == "ERROR":
                any_error = True
            else:
                any_warn = True

            safe = snippet
            if len(safe) > 220:
                safe = safe[:220] + "…"
            print(f"{severity}: {path}:{line_no}:{col_no}: {describe_cp(cp)}")
            print(f"  ↳ {safe}")

    if any_error:
        print("\nUnicode safety scan: FAILED (forbidden characters found).", file=sys.stderr)
        return 1

    if any_warn and args.warn_docs:
        print("\nUnicode safety scan: warnings only (docs).", file=sys.stderr)

    print("Unicode safety scan: OK.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
