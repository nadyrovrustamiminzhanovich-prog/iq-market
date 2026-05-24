import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:line_icons/line_icons.dart';
import 'package:iqmarket/theme/taxi_theme.dart';

import 'package:provider/provider.dart';
import 'package:iqmarket/providers/taxi_provider.dart';

class TaxiHistoryScreen extends StatelessWidget {
  final TaxiTheme t;
  const TaxiHistoryScreen({super.key, required this.t});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TaxiProvider>(context);
    
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.card,
        elevation: 0,
        title: Text(provider.translate('history_full'), style: GoogleFonts.inter(color: t.text)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: t.text),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _buildBody(provider),
    );
  }

  Widget _buildBody(TaxiProvider provider) {
    final trips = provider.historyTrips;

    if (trips.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LineIcons.history, size: 72, color: t.sub.withValues(alpha: 0.3)),
            const SizedBox(height: 24),
            Text(
              provider.translate('no_history'),
              style: GoogleFonts.inter(color: t.sub, fontSize: 16, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'История ваших поездок пуста',
              style: GoogleFonts.inter(color: t.sub.withValues(alpha: 0.6), fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: trips.map((trip) {
        final String from = trip['from'] ?? '';
        final String to = trip['to'] ?? '';
        final String priceStr = '${trip['price'] ?? 0} ₸';
        final String date = trip['date'] == 'today' 
            ? 'Сегодня' 
            : (trip['date'] == 'tomorrow' ? 'Завтра' : (trip['date'] ?? ''));
        final String role = trip['role'] == 'driver' ? 'Водитель' : 'Пассажир';
        return _hItem(
          '$date ($role)', 
          from, 
          to, 
          priceStr, 
          provider.translate('completed'), 
          provider
        );
      }).toList(),
    );
  }

  Widget _hItem(String d, String f, String to, String p, String s, TaxiProvider provider) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: t.card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: t.border),
    ),
    child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(d, style: GoogleFonts.inter(color: t.sub, fontSize: 12)),
            Text(s, style: GoogleFonts.inter(color: t.lime, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(LineIcons.mapMarker, color: t.lime, size: 16),
            const SizedBox(width: 8),
            Text('$f → $to', style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(provider.translate('cost'), style: GoogleFonts.inter(color: t.sub)),
            Text(p, style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.w900)),
          ],
        ),
      ],
    ),
  );
}
