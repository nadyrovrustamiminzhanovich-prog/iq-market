import 'dart:convert';
import 'dart:io';

void main() async {
  final transcriptPath = r'C:\Users\AaA\.gemini\antigravity\brain\7c5de8d0-e263-4614-bf7e-07403a54248e\.system_generated\logs\transcript.jsonl';
  final filePath = r'd:\iqmarket\lib\screens\taxi\taxi_service_screen.dart';
  
  var content = await File(filePath).readAsString();
  content = content.replaceAll('\r\n', '\n');
  
  final lines = await File(transcriptPath).readAsLines();
  
  for (final line in lines) {
    try {
      final data = jsonDecode(line);
      if (data.containsKey('tool_calls')) {
        for (final tc in data['tool_calls']) {
          if (tc['name'] == 'multi_replace_file_content') {
            final args = tc['args'] ?? tc['arguments'];
            // In the transcript, string values in 'args' might be JSON strings or regular strings containing escaped quotes, wait, the transcript output showed: "TargetFile":"\"d:\\\\iqmarket\\\\lib\\\\screens\\\\taxi\\\\taxi_service_screen.dart\""
            // Wait, the strings are JSON-encoded strings! So we need to jsonDecode the strings!
            String targetFile = jsonDecode(args['TargetFile']);
            if (targetFile.toLowerCase() == filePath.toLowerCase()) {
              final chunks = jsonDecode(args['ReplacementChunks']);
              for (final chunk in chunks) {
                String target = chunk['TargetContent'];
                String replacement = chunk['ReplacementContent'];
                target = target.replaceAll('\r\n', '\n');
                replacement = replacement.replaceAll('\r\n', '\n');
                
                if (content.contains(target)) {
                  content = content.replaceFirst(target, replacement);
                  print('Applied multi_replace chunk successfully.');
                } else {
                  print('Failed to apply multi_replace chunk.');
                }
              }
            }
          } else if (tc['name'] == 'replace_file_content') {
            final args = tc['args'] ?? tc['arguments'];
            String targetFile = jsonDecode(args['TargetFile']);
            if (targetFile.toLowerCase() == filePath.toLowerCase()) {
              String target = jsonDecode(args['TargetContent']);
              String replacement = jsonDecode(args['ReplacementContent']);
              target = target.replaceAll('\r\n', '\n');
              replacement = replacement.replaceAll('\r\n', '\n');
              
              if (content.contains(target)) {
                content = content.replaceFirst(target, replacement);
                print('Applied replace_file_content successfully.');
              } else {
                print('Failed to apply replace_file_content.');
              }
            }
          }
        }
      }
    } catch (e) {
      // ignore
    }
  }
  
  await File(filePath).writeAsString(content); // Overwrite the original file
  print('Recovery complete. File saved to $filePath');
}
