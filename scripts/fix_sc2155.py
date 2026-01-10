#!/usr/bin/env python3
"""
SC2155 ShellCheck Fixer

Automatically splits local/declare/export variable assignments from declarations
to avoid masking return values (SC2155).

Usage:
    # Dry-run (show diff only):
    python3 scripts/fix_sc2155.py main.sh lib/*.sh

    # Apply fixes:
    python3 scripts/fix_sc2155.py --apply main.sh lib/*.sh

Based on research from multiple ShellCheck fixer implementations.
"""
import re
import sys
import difflib
import argparse

# Pattern matches: local VAR=$(cmd), declare VAR=$(cmd), export VAR=$(cmd)
# Excludes readonly (cannot be split)
pattern = re.compile(
    r'^(\s*)'                          # indent
    r'(?P<kw>local|declare|export)?'   # optional keyword (skip readonly/typeset)
    r'(?P<opts>(?:\s+-[-\w]+)*)'       # zero or more options like -x -i
    r'\s+'
    r'(?P<var>[A-Za-z_][A-Za-z0-9_]*)' # var name (basic, no arrays/idx)
    r'\s*=\s*'
    r'(?P<val>.*)$'                    # value + trailing
)

def has_command_sub(val):
    """Check if value contains command substitution $(...) or `...`"""
    return bool(re.search(r'\$\([^)]*\)|`[^`]*`', val))

def fix_line(line):
    """
    Returns list of lines (without trailing newlines).
    Splits declaration from assignment for SC2155 compliance.
    """
    match = pattern.match(line)
    if not match:
        return [line]
    
    indent = match.group(1)
    kw = match.group('kw') or ''
    opts = (match.group('opts') or '').strip()
    var = match.group('var')
    val = match.group('val')
    
    # Skip if readonly (-r in opts) - cannot be split
    if 'readonly' in kw.lower() or '-r' in opts:
        return [line]
    
    # Only fix if command substitution present
    if not has_command_sub(val):
        return [line]
    
    if kw == 'export':
        # Safe: assign first, then export
        return [
            f"{indent}{var}={val}",
            f"{indent}export {var}"
        ]
    elif kw in ('local', 'declare'):
        # Declare first (with opts), then assign
        if opts:
            declare = f"{kw} {opts} {var}"
        else:
            declare = f"{kw} {var}"
        return [
            f"{indent}{declare}",
            f"{indent}{var}={val}"
        ]
    else:
        return [line]

def process_file(filepath, apply=False):
    """Process a single file, optionally applying fixes."""
    with open(filepath, 'r') as f:
        original = f.readlines()
    
    new_lines = []
    modified = False
    for line in original:
        stripped = line.rstrip('\n')
        fixed = fix_line(stripped)
        if len(fixed) > 1 or fixed[0] != stripped:
            modified = True
        for l in fixed:
            new_lines.append(l + '\n')
    
    if modified:
        diff = ''.join(difflib.unified_diff(
            original, new_lines,
            fromfile=f'a/{filepath}', tofile=f'b/{filepath}'
        ))
        print(diff)
        
        if apply:
            with open(filepath, 'w') as f:
                f.writelines(new_lines)
            print(f"✓ Applied fixes to {filepath}")
    else:
        print(f"✓ No SC2155 fixes needed in {filepath}")

if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description='Fix SC2155 ShellCheck warnings by separating declarations from assignments'
    )
    parser.add_argument('files', nargs='+', help='Shell files to process')
    parser.add_argument('--apply', action='store_true', 
                        help='Apply fixes (default: dry-run showing diff)')
    args = parser.parse_args()
    
    for fp in args.files:
        process_file(fp, args.apply)
