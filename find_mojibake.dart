import 'dart:io';

void main() async {
  final file = File('lib/screens/taxi/taxi_service_screen.dart');
  final lines = await file.readAsLines();

  for (int i = 0; i < lines.length; i++) {
    // Search for Cyrillic 'Р' which indicates Mojibake
    if (lines[i].contains('Р')) {
      print('Line ${i+1}: ${lines[i]}');
    }
  }
}
