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
    final driverReviewCount = taxiProvider.getUserReviewCountAsDriver(uid);
    final driverRating = taxiProvider.getUserRatingAsDriver(uid);
    final String driverRatingStr = driverReviewCount < 5
        ? taxiProvider.translate('rating_novice')
        : '${driverRating.toStringAsFixed(1)} ★';

    final passengerReviewCount = taxiProvider.getUserReviewCountAsPassenger(uid);
    final passengerRating = taxiProvider.getUserRatingAsPassenger(uid);
    final String passengerRatingStr = passengerReviewCount < 5
        ? taxiProvider.translate('rating_novice')
        : '${passengerRating.toStringAsFixed(1)} ★';

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
          _sectionHeader(t, taxiProvider.translate('my_profile_header')),
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
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
                // Driver Rating
                Expanded(
                  child: Column(
                    children: [
                      const Icon(Icons.local_taxi_rounded, color: Colors.amber, size: 24),
                      const SizedBox(height: 6),
                      Text(
                        taxiProvider.translate('driver_role').toUpperCase(),
                        style: GoogleFonts.inter(color: t.sub, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.3),
                      ),
                      const SizedBox(height: 4),
                      Text(driverRatingStr, style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.w900, fontSize: 13)),
                      const SizedBox(height: 2),
                      Text(
                        driverReviewCount < 5
                            ? '${taxiProvider.translate('rating_count_prefix')} $driverReviewCount/5'
                            : '$driverReviewCount ${taxiProvider.translate('reviews_label')}',
                        style: GoogleFonts.inter(color: t.sub, fontSize: 9, fontWeight: FontWeight.w500),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                Container(height: 40, width: 1, color: t.border.withValues(alpha: 0.4)),
                // Passenger Rating
                Expanded(
                  child: Column(
                    children: [
                      const Icon(Icons.directions_walk_rounded, color: Color(0xFF4A80F0), size: 24),
                      const SizedBox(height: 6),
                      Text(
                        taxiProvider.translate('passenger_role').toUpperCase(),
                        style: GoogleFonts.inter(color: t.sub, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.3),
                      ),
                      const SizedBox(height: 4),
                      Text(passengerRatingStr, style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.w900, fontSize: 13)),
                      const SizedBox(height: 2),
                      Text(
                        passengerReviewCount < 5
                            ? '${taxiProvider.translate('rating_count_prefix')} $passengerReviewCount/5'
                            : '$passengerReviewCount ${taxiProvider.translate('reviews_label')}',
                        style: GoogleFonts.inter(color: t.sub, fontSize: 9, fontWeight: FontWeight.w500),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                Container(height: 40, width: 1, color: t.border.withValues(alpha: 0.4)),
                // History shortcut
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      Navigator.push(context, MaterialPageRoute(builder: (_) => TaxiHistoryScreen(t: t)));
                    },
                    child: Column(
                      children: [
                        Icon(LineIcons.history, color: t.accent, size: 24),
                        const SizedBox(height: 6),
                        Text(
                          taxiProvider.translate('history').toUpperCase(),
                          style: GoogleFonts.inter(color: t.accent, fontWeight: FontWeight.w800, fontSize: 9, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          taxiProvider.translate('all_trips'),
                          style: GoogleFonts.inter(color: t.sub, fontSize: 9, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 8),

          // App settings section
          _sectionHeader(t, taxiProvider.translate('app_settings_header')),
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
