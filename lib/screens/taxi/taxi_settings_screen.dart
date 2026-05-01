import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:iqmarket/providers/taxi_provider.dart';

class TaxiSettingsScreen extends StatelessWidget {
  const TaxiSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final taxiProvider = Provider.of<TaxiProvider>(context);
    final t = taxiProvider.theme;

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.card,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: t.text),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          taxiProvider.translate('settings'),
          style: GoogleFonts.inter(color: t.text),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _tile(t, Icons.notifications_none, taxiProvider.translate('notif'), _notif(taxiProvider)),
          _tile(t, Icons.dark_mode_outlined, taxiProvider.translate('theme'), _themeS(taxiProvider)),
          const Divider(),
          _l(t, 'Русский', 'ru', taxiProvider),
          _l(t, 'Қазақша', 'kz', taxiProvider),
          _l(t, 'Уйғурчә', 'uyg', taxiProvider),
        ],
      ),
    );
  }

  Widget _tile(dynamic t, IconData i, String title, Widget a) => ListTile(
    leading: Icon(i, color: t.lime),
    title: Text(title, style: GoogleFonts.inter(color: t.text)),
    trailing: a,
  );

  Widget _notif(TaxiProvider provider) => Switch(
    value: provider.notifEnabled,
    activeColor: provider.theme.lime,
    onChanged: (v) => provider.setNotifEnabled(v),
  );

  Widget _themeS(TaxiProvider provider) => Switch(
    value: provider.isDarkGlobal,
    activeColor: provider.theme.accent,
    onChanged: (v) => provider.toggleTheme(),
  );

  Widget _l(dynamic t, String l, String c, TaxiProvider provider) => ListTile(
    title: Text(l, style: GoogleFonts.inter(color: t.text)),
    trailing: provider.curLang == c ? Icon(Icons.check, color: t.lime) : null,
    onTap: () => provider.setLanguage(c),
  );
}
