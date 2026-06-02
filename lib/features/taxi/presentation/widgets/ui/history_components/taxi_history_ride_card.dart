import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:line_icons/line_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:iqmarket/theme/taxi_theme.dart';
import 'package:iqmarket/providers/taxi_provider.dart';
import 'taxi_history_details_sheet.dart';

class TaxiHistoryRideCard extends StatelessWidget {
  final BuildContext context;
  final String dateStr;
  final String from;
  final String to;
  final String price;
  final String status;
  final String phone;
  final String comment;
  final TaxiProvider provider;
  final Map<String, dynamic> trip;
  final TaxiTheme t;

  const TaxiHistoryRideCard({
    super.key,
    required this.context,
    required this.dateStr,
    required this.from,
    required this.to,
    required this.price,
    required this.status,
    required this.phone,
    required this.comment,
    required this.provider,
    required this.trip,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          showTaxiHistoryDetailsSheet(context, trip, provider, t);
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: t.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: t.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(dateStr, style: GoogleFonts.inter(color: t.sub, fontSize: 12))),
                  const SizedBox(width: 8),
                  Text(status, style: GoogleFonts.inter(color: t.lime, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded, color: t.sub.withValues(alpha: 0.4), size: 18),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(LineIcons.mapMarker, color: t.lime, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text('$from → $to', style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.bold))),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(provider.translate('cost'), style: GoogleFonts.inter(color: t.sub)),
                  Text(price, style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.w900)),
                ],
              ),
              if (comment.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 8),
                Text(
                  'Комментарий: $comment',
                  style: GoogleFonts.inter(color: t.sub, fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ],
              if (phone.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final url = Uri.parse('tel:$phone');
                    if (await canLaunchUrl(url)) await launchUrl(url);
                  },
                  child: Row(
                    children: [
                      Icon(Icons.phone_rounded, color: t.lime, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        phone,
                        style: GoogleFonts.inter(
                          color: t.lime,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '(Позвонить)',
                        style: GoogleFonts.inter(color: t.sub, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
