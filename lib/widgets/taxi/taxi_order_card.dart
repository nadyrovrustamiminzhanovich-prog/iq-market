import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:line_icons/line_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:iqmarket/theme/taxi_theme.dart';
import 'package:iqmarket/providers/taxi_provider.dart';

class TaxiOrderCard extends StatelessWidget {
  final TaxiProvider provider;
  final TaxiTheme t;
  final String name;
  final String from;
  final String to;
  final int price;
  final int seats;
  final String comment;
  final bool isNegotiated;
  final String created;
  final String img;
  final String phone;
  final String passengerId;
  final VoidCallback onShowProfile;
  final VoidCallback onNegotiate;
  final VoidCallback onCall;
  final VoidCallback onChat;

  const TaxiOrderCard({
    super.key,
    required this.provider,
    required this.t,
    required this.name,
    required this.from,
    required this.to,
    required this.price,
    required this.seats,
    required this.comment,
    required this.isNegotiated,
    required this.created,
    required this.img,
    required this.phone,
    required this.passengerId,
    required this.onShowProfile,
    required this.onNegotiate,
    required this.onCall,
    required this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    final double realRating = provider.getUserRating(passengerId);
    final int realReviewCount = provider.getUserReviewCount(passengerId);

    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: t.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ],
        ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: onShowProfile,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: t.accent.withValues(alpha: 0.2), width: 2),
                        ),
                        child: CircleAvatar(
                          backgroundColor: t.accent.withValues(alpha: 0.1),
                          radius: 26,
                          backgroundImage: img.isNotEmpty ? CachedNetworkImageProvider(img) : null,
                          child: img.isEmpty
                              ? Text(name.isNotEmpty ? name[0] : '?',
                                  style: GoogleFonts.inter(
                                      color: t.accent, fontWeight: FontWeight.bold, fontSize: 20))
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                  color: t.text, fontWeight: FontWeight.w900, fontSize: 16)),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 13),
                              const SizedBox(width: 3),
                              Text(
                                realReviewCount < 5 ? 'Новичок' : '$realRating ($realReviewCount)',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: const Color(0xFF3B82F6),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(LineIcons.clock, color: t.sub.withValues(alpha: 0.5), size: 12),
                              const SizedBox(width: 4),
                              Text(created,
                                  style: GoogleFonts.inter(
                                      color: t.sub, fontSize: 10, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('$price ₸',
                            style: GoogleFonts.inter(
                                color: t.accent, fontWeight: FontWeight.w900, fontSize: 20)),
                        const SizedBox(height: 6),
                        if (isNegotiated)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                                color: t.accent.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8)),
                            child: Text(provider.translate('offer').toUpperCase(),
                                style: GoogleFonts.inter(
                                    color: t.accent,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5)),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: t.bg.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: t.border.withValues(alpha: 0.5))),
                  child: Row(
                    children: [
                      Icon(Icons.location_on_rounded, color: t.accent, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text('$from → $to',
                              style: GoogleFonts.inter(
                                  color: t.text, fontSize: 13, fontWeight: FontWeight.w700))),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _badge(t, '$seats ${provider.translate('seats')}', LineIcons.users),
                    const SizedBox(width: 8),
                    if (comment.isNotEmpty)
                      Expanded(
                        child: Text(comment,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                                color: t.sub,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                fontStyle: FontStyle.italic)),
                      ),
                  ],
                ),
              ],
            ),
          ),
          _actionStrip(),
        ],
      ),
    ),
  );
}

  Widget _badge(TaxiTheme t, String l, IconData i) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: t.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.border)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(i, size: 14, color: t.accent),
            const SizedBox(width: 6),
            Text(l,
                style: GoogleFonts.inter(
                    fontSize: 10, fontWeight: FontWeight.w800, color: t.text)),
          ],
        ),
      );

  Widget _actionStrip() => Container(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: _stripBtn(provider.translate('bargain'), LineIcons.coins, const Color(0xFF0052FF), onNegotiate,
                  isFilled: true, fontSize: 13),
            ),
            const SizedBox(width: 10),
            _iconBtn(LineIcons.phone, const Color(0xFF0052FF), onCall),
            const SizedBox(width: 10),
            _iconBtn(LineIcons.comment, const Color(0xFF0052FF), onChat),
          ],
        ),
      );

  Widget _iconBtn(IconData i, Color c, VoidCallback onTap) => Material(
        color: c,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            child: Icon(i, size: 20, color: Colors.white),
          ),
        ),
      );

  Widget _stripBtn(String l, IconData i, Color c, VoidCallback onTap, {bool isFilled = false, double fontSize = 10}) =>
      Material(
        color: isFilled ? c : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: isFilled ? null : Border.all(color: c.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(i, size: 18, color: isFilled ? Colors.white : c),
                const SizedBox(width: 8),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(l,
                        style: GoogleFonts.inter(
                            fontSize: fontSize,
                            fontWeight: FontWeight.w900,
                            color: isFilled ? Colors.white : c)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
