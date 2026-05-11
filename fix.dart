import 'dart:io';

void main() async {
  final file = File('lib/screens/taxi/taxi_service_screen.dart');
  final lines = await file.readAsLines();

  // Fix line 288 (index 287)
  lines[287] = '                              hintText: "••••",';
  
  // Fix line 291 (index 290)
  lines[290] = '                        Text(\'ОШИБКА: Неверный код ❌\',';
  
  await file.writeAsString(lines.join('\n'));
}
