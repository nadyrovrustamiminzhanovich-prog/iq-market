import json
import os

transcript_path = r"C:\Users\AaA\.gemini\antigravity\brain\7c5de8d0-e263-4614-bf7e-07403a54248e\.system_generated\logs\transcript.jsonl"
file_path = r"d:\iqmarket\lib\screens\taxi\taxi_service_screen.dart"

def apply_replacement(content, target, replacement):
    # exact string replace
    if target in content:
        return content.replace(target, replacement, 1)
    return content

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

with open(transcript_path, 'r', encoding='utf-8') as f:
    for line in f:
        try:
            data = json.loads(line)
            if 'tool_calls' in data:
                for tc in data['tool_calls']:
                    if tc['name'] == 'multi_replace_file_content':
                        args = tc['arguments']
                        if args.get('TargetFile') == file_path:
                            for chunk in args.get('ReplacementChunks', []):
                                target = chunk['TargetContent']
                                replacement = chunk['ReplacementContent']
                                new_content = apply_replacement(content, target, replacement)
                                if new_content != content:
                                    print("Applied chunk successfully.")
                                    content = new_content
                                else:
                                    print("Failed to apply a chunk!")
                    elif tc['name'] == 'replace_file_content':
                        args = tc['arguments']
                        if args.get('TargetFile') == file_path:
                            target = args['TargetContent']
                            replacement = args['ReplacementContent']
                            new_content = apply_replacement(content, target, replacement)
                            if new_content != content:
                                print("Applied replace successfully.")
                                content = new_content
                            else:
                                print("Failed to apply replace!")
        except Exception as e:
            pass

with open(file_path + ".recovered", 'w', encoding='utf-8') as f:
    f.write(content)

print("Recovered file written to " + file_path + ".recovered")
