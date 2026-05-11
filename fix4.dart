import 'dart:io';

void main() async {
  final file = File('lib/screens/taxi/taxi_service_screen.dart');
  final lines = await file.readAsLines();

  // Fix line 621 (index 620)
  lines[620] = '                    Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(ad: {\'seller\': \'Пассажир\', \'title\': provider.translate(\'order_accepted\'), \'price\': \'В пути\'})));';

  // Fix line 683 (index 682)
  lines[682] = '                  Expanded(child: _miniBtn(t, LineIcons.calendar, provider.selDate == \'Сегодня\' ? provider.translate(\'today\') : provider.selDate == \'Вчера\' ? provider.translate(\'yesterday\') : provider.selDate, () => _pickDate(provider, t))),';

  // Fix line 685 (index 684)  
  lines[684] = '                  Expanded(child: _miniBtn(t, LineIcons.clock, provider.selTime == \'Время\' ? provider.translate(\'time\') : provider.selTime, () => _pickTime(provider, t))),';

  await file.writeAsString(lines.join('\n'));
}
