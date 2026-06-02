import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:line_icons/line_icons.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:iqmarket/providers/taxi_provider.dart';
import 'package:iqmarket/screens/taxi/taxi_history_screen.dart';

class TaxiSettingsScreen extends StatelessWidget {
  const TaxiSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final taxiProvider = Provider.of<TaxiProvider>(context);
    final t = taxiProvider.theme;

    final uid = FirebaseAuth.instance.currentUser?.uid ?? "";
    final reviewCount = taxiProvider.getUserReviewCount(uid);
    final rating = taxiProvider.getUserRating(uid);
    final String ratingStr = reviewCount < 5 ? 'Новичок' : '${rating.toStringAsFixed(1)} ★';

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
          style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionHeader(t, 'Мой профиль'),
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: t.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: t.border.withValues(alpha: 0.6)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))
              ],
            ),
            child: Row(
              children: [
                // Taxi Rating
                Expanded(
                  child: Column(
                    children: [
                      const Icon(Icons.star_rounded, color: Colors.amber, size: 28),
                      const SizedBox(height: 6),
                      Text(ratingStr, style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.w900, fontSize: 14)),
                      const SizedBox(height: 2),
                      if (reviewCount < 5)
                        Tooltip(
                          message: 'Рейтинг формируется после 5 оценок от других пользователей',
                          child: Text(
                            'Рейтинг после 5 оценок',
                            style: GoogleFonts.inter(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.w500),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      Text(
                        reviewCount < 5 ? 'Оценок: $reviewCount/5' : '$reviewCount отзывов',
                        style: GoogleFonts.inter(color: t.sub, fontSize: 10, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                Container(height: 50, width: 1, color: t.border.withValues(alpha: 0.4)),
                // History shortcut
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      Navigator.push(context, MaterialPageRoute(builder: (_) => TaxiHistoryScreen(t: t)));
                    },
                    child: Column(
                      children: [
                        Icon(LineIcons.history, color: t.accent, size: 28),
                        const SizedBox(height: 6),
                        Text('ИСТОРИЯ', style: GoogleFonts.inter(color: t.accent, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5)),
                        const SizedBox(height: 2),
                        Text('Все поездки', style: GoogleFonts.inter(color: t.sub, fontSize: 10, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 8),

          // App settings section
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
    padding: const EdgeInsets.only(left: 4, bottom: 10, top: 12),
    child: Text(title.toUpperCase(), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: t.sub, letterSpacing: 1)),
  );

  Widget _tile(dynamic t, IconData i, String title, Widget a) => ListTile(
    leading: Icon(i, color: t.lime),
    title: Text(title, style: GoogleFonts.inter(color: t.text)),
    trailing: a,
  );

  Widget _notif(TaxiProvider provider) => Switch(
    value: provider.notifEnabled,
    activeThumbColor: provider.theme.lime,
    activeTrackColor: provider.theme.lime.withValues(alpha: 0.5),
    onChanged: (v) => provider.setNotifEnabled(v),
  );

  Widget _l(dynamic t, String l, String c, TaxiProvider provider) => ListTile(
    title: Text(l, style: GoogleFonts.inter(color: t.text)),
    trailing: provider.curLang == c ? Icon(Icons.check, color: t.lime) : null,
    onTap: () => provider.setLanguage(c),
  );
}
