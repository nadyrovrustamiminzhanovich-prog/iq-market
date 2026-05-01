import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:line_icons/line_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:iqmarket/theme/taxi_theme.dart';
import 'package:iqmarket/providers/taxi_provider.dart';

class TaxiDriverCard extends StatelessWidget {
  final TaxiProvider provider;
  final TaxiTheme t;
  final Map<String, dynamic> driver;
  final VoidCallback onShowProfile;
  final VoidCallback onCall;
  final VoidCallback onChat;
  final VoidCallback onNegotiate;

  const TaxiDriverCard({
    super.key,
    required this.provider,
    required this.t,
    required this.driver,
    required this.onShowProfile,
    required this.onCall,
    required this.onChat,
    required this.onNegotiate,
  });

  @override
  Widget build(BuildContext context) {
    final String name    = driver['name']    ?? 'Водитель';
    final String img     = driver['img']     ?? '';
    final String car     = driver['car']     ?? '';
    final String price   = driver['price']?.toString() ?? '0';
    final String rating  = driver['rating']?.toString() ?? '5.0';
    final String reviews = driver['reviews']?.toString() ?? '0';
    final String from    = driver['from']    ?? '';
    final String to      = driver['to']      ?? '';
    final String date    = driver['date']    ?? '';

    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(TaxiTheme.radiusCard),
          border: Border.all(color: t.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: onShowProfile,
                        child: Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: t.accent.withValues(alpha: 0.25), width: 2),
                              ),
                              child: CircleAvatar(
                                radius: 28,
                                backgroundColor: t.accent.withValues(alpha: 0.06),
                                backgroundImage: img.isNotEmpty ? CachedNetworkImageProvider(img) : null,
                                child: img.isEmpty
                                    ? Icon(LineIcons.user, color: t.accent, size: 24)
                                    : null,
                              ),
                            ),
                            Positioned(
                              right: 1, bottom: 1,
                              child: Container(
                                width: 13, height: 13,
                                decoration: BoxDecoration(
                                  color: t.lime,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: t.card, width: 2),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: onShowProfile,
                              child: Text(
                                name,
                                style: GoogleFonts.inter(
                                  color: t.accent,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  decoration: TextDecoration.underline,
                                  decorationColor: t.accent.withValues(alpha: 0.35),
                                ),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Icon(Icons.star_rounded, color: const Color(0xFFF59E0B), size: 14),
                                const SizedBox(width: 3),
                                Text(
                                  rating,
                                  style: GoogleFonts.inter(
                                    color: t.text,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '($reviews)',
                                  style: GoogleFonts.inter(
                                    color: t.sub,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: t.lime.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(TaxiTheme.radiusButton),
                          border: Border.all(color: t.lime.withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          '$price ₸',
                          style: GoogleFonts.inter(
                            color: t.lime,
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _infoRow(LineIcons.car, car, t),
                  const SizedBox(height: 8),
                  _infoRow(LineIcons.mapMarker, '$from → $to', t, isBold: true),
                  const SizedBox(height: 8),
                  _infoRow(LineIcons.calendar, provider.translate(date), t),
                ],
              ),
            ),
            _actionArea(),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData i, String label, TaxiTheme t, {bool isBold = false}) => Row(
    children: [
      Icon(i, size: 15, color: t.sub.withValues(alpha: 0.5)),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: t.text,
            fontSize: 13,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    ],
  );

  Widget _actionArea() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
    child: Row(
      children: [
        Expanded(flex: 3, child: _btn(provider.translate('bargain'), Icons.bolt_rounded, const Color(0xFF84CC16), onNegotiate, isFilled: true)),
        const SizedBox(width: 8),
        Expanded(flex: 3, child: _btn(provider.translate('call'), LineIcons.phone, t.sub, onCall)),
        const SizedBox(width: 8),
        Expanded(flex: 4, child: _btn(provider.translate('chat'), LineIcons.comments, t.accent, onChat, isFilled: true)),
      ],
    ),
  );

  Widget _btn(String label, IconData icon, Color c, VoidCallback onTap, {bool isFilled = false}) =>
    Material(
      color: isFilled ? c : Colors.transparent,
      borderRadius: BorderRadius.circular(TaxiTheme.radiusButton),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(TaxiTheme.radiusButton),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(TaxiTheme.radiusButton),
            border: isFilled ? null : Border.all(color: t.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isFilled ? Colors.white : t.sub),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isFilled ? Colors.white : t.text,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
}

