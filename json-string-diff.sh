#!/usr/bin/env bash
# Word-level inline diff for JSON files with large single-line string values.
# Parses the JSON, splits string fields by \n into paragraphs, and diffs them.
#
# Usage:
#   ./scripts/json-string-diff.sh <file>                  # diff against HEAD
#   ./scripts/json-string-diff.sh <file> <git-ref>        # diff against a specific ref

set -euo pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <json-file> [git-ref]"
    echo "  json-file  Path to the JSON file (relative to repo root)"
    echo "  git-ref    Git ref to compare against (default: HEAD)"
    exit 1
fi

FILE="$1"
REF="${2:-HEAD}"

if [[ ! -f "$FILE" ]]; then
    echo "Error: file '$FILE' not found"
    exit 1
fi

python3 -c "
import json, subprocess, difflib, sys

filepath = sys.argv[1]
ref = sys.argv[2]

old_raw = subprocess.run(
    ['git', 'show', ref + ':' + filepath],
    capture_output=True, text=True
)
if old_raw.returncode != 0:
    print(f'Error: cannot read {filepath} from ref {ref}')
    sys.exit(1)

old = json.loads(old_raw.stdout)
with open(filepath) as f:
    new = json.load(f)

# Find actual line numbers in the raw file
line_map = {}
with open(filepath) as f:
    for lineno, line in enumerate(f, 1):
        stripped = line.strip()
        for key in old:
            if stripped.startswith('\"' + key + '\"'):
                line_map[key] = lineno

# Find string fields that changed
changed = False
for key in old:
    if not isinstance(old[key], str) or old[key] == new.get(key):
        continue

    old_paras = old[key].split('\n')
    new_paras = new[key].split('\n')

    max_len = max(len(old_paras), len(new_paras))
    old_paras += [''] * (max_len - len(old_paras))
    new_paras += [''] * (max_len - len(new_paras))

    for i, (o, n) in enumerate(zip(old_paras, new_paras)):
        if o == n:
            continue
        changed = True
        file_line = line_map.get(key, '?')
        print(f'\n{\"=\"*80}')
        print(f'{filepath}:{file_line}  ({key}, paragraph {i+1})')
        print(f'{\"=\"*80}')

        sm = difflib.SequenceMatcher(None, o.split(), n.split())
        result = []
        for op, i1, i2, j1, j2 in sm.get_opcodes():
            if op == 'equal':
                result.append(' '.join(o.split()[i1:i2]))
            elif op == 'delete':
                result.append('\033[31m' + ' '.join(o.split()[i1:i2]) + '\033[0m')
            elif op == 'insert':
                result.append('\033[32m' + ' '.join(n.split()[j1:j2]) + '\033[0m')
            elif op == 'replace':
                result.append('\033[31m' + ' '.join(o.split()[i1:i2]) + '\033[0m')
                result.append('\033[32m' + ' '.join(n.split()[j1:j2]) + '\033[0m')
        print()
        print(' '.join(result))

if not changed:
    print('No string field changes found.')
" "$FILE" "$REF"
