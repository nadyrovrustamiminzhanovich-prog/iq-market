import 'dart:io';
void main() {
  final lines = File('lib/screens/taxi/taxi_service_screen.dart').readAsLinesSync();
  for(var i=0; i<lines.length; i++) {
    if (lines[i].contains('_showEditCarDialog')) print('${i+1}: ${lines[i]}');
  }
}
