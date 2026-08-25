# -*- coding: utf-8 -*-
import os, sys, re

sys.stdout.reconfigure(encoding='utf-8')

with open('lib/services/translation_service.dart', 'r', encoding='utf-8') as f:
    tr = f.read()

entries = re.findall(r"'([a-zA-Z0-9_\-]+)':\s*\{([^}]+)\}", tr)

for key, body in entries:
    has_ru = 'Русский' in body
    has_kk = 'Қазақша' in body
    has_ug = 'Уйғурчә' in body
    if not (has_ru and has_kk and has_ug):
        print(f"KEY: {key}")
        print(f"  BODY: {body.strip()}")
        print("-" * 40)
