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
          _sectionHeader(t, 'Аккаунт'),
          _telegramTile(taxiProvider, t),
          const SizedBox(height: 24),
          _sectionHeader(t, 'Приложение'),
          _tile(t, Icons.notifications_none, taxiProvider.translate('notif'), _notif(taxiProvider)),
          const Divider(height: 32),
          _sectionHeader(t, 'Язык / Тіл'),
          _l(t, 'Русский', 'ru', taxiProvider),
          _l(t, 'Қазақша', 'kz', taxiProvider),
          _l(t, 'Уйғурчә', 'uyg', taxiProvider),
        ],
      ),
    );
  }

  Widget _sectionHeader(dynamic t, String title) => Padding(
    padding: const EdgeInsets.only(left: 16, bottom: 8, top: 8),
    child: Text(title.toUpperCase(), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: t.sub, letterSpacing: 1)),
  );

  Widget _telegramTile(TaxiProvider p, dynamic t) {
    final isLinked = p.isTelegramVerified;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isLinked ? Colors.blue.withValues(alpha: 0.2) : t.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFF24A1DE).withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.telegram, color: Color(0xFF24A1DE)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Telegram', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: t.text)),
                Text(isLinked ? 'Аккаунт привязан' : 'Не привязано', style: GoogleFonts.inter(fontSize: 12, color: t.sub)),
              ],
            ),
          ),
          if (!isLinked)
            TextButton(
              onPressed: () {}, // Triggered via auth dialog in main screen
              child: const Text('ПРИВЯЗАТЬ'),
            )
          else
            const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
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
    activeTrackColor: provider.theme.lime.withValues(alpha: 0.5),
    onChanged: (v) => provider.setNotifEnabled(v),
  );

  Widget _l(dynamic t, String l, String c, TaxiProvider provider) => ListTile(
    title: Text(l, style: GoogleFonts.inter(color: t.text)),
    trailing: provider.curLang == c ? Icon(Icons.check, color: t.lime) : null,
    onTap: () => provider.setLanguage(c),
  );
}
