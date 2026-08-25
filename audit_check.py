# -*- coding: utf-8 -*-
import os, sys, re

sys.stdout.reconfigure(encoding='utf-8')

print("=== CHECKING FOR OVERFLOW RISKS IN MODALS AND SHEETS ===")

unscrollable_sheets = []

for root, dirs, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart'):
            path = os.path.join(root, file)
            with open(path, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
            
            # Look for showModalBottomSheet with Column and without SingleChildScrollView
            sheets = re.finditer(r'showModalBottomSheet\s*\([^;]+?;', content, re.DOTALL)
            for s in sheets:
                body = s.group(0)
                if 'Column(' in body and 'SingleChildScrollView' not in body and 'ListView' not in body:
                    # check how many children or lines
                    line_cnt = len(body.splitlines())
                    if line_cnt > 20:
                        unscrollable_sheets.append((path, line_cnt, body[:80]))

print(f"Total potential modal sheets to verify: {len(unscrollable_sheets)}")
for p, l, snip in unscrollable_sheets:
    print(f"  - {p} (lines: {l})")
