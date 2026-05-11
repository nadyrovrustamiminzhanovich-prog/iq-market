import 'dart:io';

void main() async {
  final file = File('lib/screens/taxi/taxi_service_screen.dart');
  final lines = await file.readAsLines();

  // 1
  lines[533] = '      Expanded(child: _qBtn(t, LineIcons.history, \'\u0418\u0441\u0442\u043e\u0440\u0438\u044f\', () {';
  
  // 2
  lines[580] = '                  Flexible(child: Text(\'\${provider.translate(\\\'route\\\')}: \$from \u2192 \$to\', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.montserrat(color: t.sub, fontSize: 11))),';
  
  // 3
  lines[582] = '                  Text(\'\u2022 \$created\', style: GoogleFonts.montserrat(color: t.sub, fontSize: 10)),';
  
  // 4
  lines[620] = '                    Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(ad: {\'seller\': \'\u041f\u0430\u0441\u0441\u0430\u0436\u0438\u0440\', \'title\': provider.translate(\'order_accepted\'), \'price\': \'\u0412 \u043f\u0443\u0442\u0438\'})));';
  
  // 5
  lines[682] = '                  Expanded(child: _miniBtn(t, LineIcons.calendar, provider.selDate == \'\u0421\u0435\u0433\u043e\u0434\u043d\u044f\' ? provider.translate(\'today\') : provider.selDate == \'\u0412\u0447\u0435\u0440\u0430\' ? provider.translate(\'yesterday\') : provider.selDate, () => _pickDate(provider, t))),';
  
  // 6
  lines[684] = '                  Expanded(child: _miniBtn(t, LineIcons.clock, provider.selTime == \'\u0412\u0440\u0435\u043c\u044f\' ? provider.translate(\'time\') : provider.selTime, () => _pickTime(provider, t))),';
  
  // 7
  lines[831] = '                          child: Text(\' \u2022 154 \${provider.translate(\\\'trips\\\').toLowerCase()}\',';

  await file.writeAsString(lines.join('\n'));
}
