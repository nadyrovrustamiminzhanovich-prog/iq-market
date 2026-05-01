import json
import os

log_file = r'C:\Users\AaA\.gemini\antigravity\brain\1aa0ef0e-37d1-4ea8-86ba-390b1d95013f\.system_generated\logs\overview.txt'
output_file = r'd:\iqmarket\full_main.dart'

with open(log_file, 'r', encoding='utf-8') as f:
    for line in f:
        if '_globalAds' in line and 'multi_replace_file_content' in line:
            try:
                data = json.loads(line)
                for call in data.get('tool_calls', []):
                    if call['name'] == 'multi_replace_file_content' and call['args'].get('TargetFile') == 'd:\\iqmarket\\lib\\main.dart':
                        # This might not be the FULL file, but it contains the chunks.
                        # Wait, I need the FULL file before I broke it.
                        pass
            except:
                continue

# Actually, I'll just look for the last VIEW_FILE of main.dart
with open(log_file, 'r', encoding='utf-8') as f:
    last_content = None
    for line in f:
        if 'lib/main.dart' in line and 'content' in line:
             try:
                 data = json.loads(line)
                 if 'content' in data:
                     last_content = data['content']
             except:
                 continue
    
    if last_content:
        with open(output_file, 'w', encoding='utf-8') as out:
            out.write(last_content)
        print(f"Recovered to {output_file}")
    else:
        print("Not found")
