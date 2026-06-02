import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:line_icons/line_icons.dart';
import 'package:iqmarket/theme/taxi_theme.dart';
import 'package:provider/provider.dart';
import 'package:iqmarket/providers/taxi_provider.dart';
import 'package:iqmarket/features/taxi/presentation/widgets/ui/history_components/taxi_history_ride_card.dart';

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
      body: _buildBody(context, provider),
    );
  }

  Widget _buildBody(BuildContext context, TaxiProvider provider) {
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
        final String phone = (trip['role'] == 'driver' ? (trip['passengerPhone'] ?? trip['phone'] ?? '') : (trip['driverPhone'] ?? trip['phone'] ?? '')).toString();
        final String comment = (trip['comment'] ?? '').toString();

        return TaxiHistoryRideCard(
          context: context,
          dateStr: '$date ($role)',
          from: from,
          to: to,
          price: priceStr,
          status: provider.translate('completed'),
          phone: phone,
          comment: comment,
          provider: provider,
          trip: trip,
          t: t,
        );
      }).toList(),
    );
  }
}
