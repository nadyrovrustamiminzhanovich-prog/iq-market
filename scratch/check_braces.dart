import 'dart:io';

void main() {
  final file = File('lib/screens/taxi/taxi_service_screen.dart');
  final lines = file.readAsLinesSync();
  int depth = 0;
  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];
    for (int j = 0; j < line.length; j++) {
      if (line[j] == '{') depth++;
      if (line[j] == '}') depth--;
    }
    if (depth == 0 && i > 50) {
      print('Class might have closed at line ${i + 1}');
    }
  }
}
