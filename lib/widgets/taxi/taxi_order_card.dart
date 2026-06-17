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
    final double realRating = provider.getUserRatingAsPassenger(passengerId);
    final int realReviewCount = provider.getUserReviewCountAsPassenger(passengerId);

    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: t.border),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4A80F0).withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                    // Issue #1 msg2: Use Flexible to prevent name clipping
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: onShowProfile,
                            child: Text(name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                    color: t.text, fontWeight: FontWeight.w900, fontSize: 15)),
                          ),
                          const SizedBox(height: 3),
                          // Issue #1 msg2: Rating shown below name, not competing with price
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
                              if (realReviewCount < 5) ...[
                                const SizedBox(width: 3),
                                Tooltip(
                                  message: 'Рейтинг формируется после 5 оценок от других пользователей',
                                  child: Icon(Icons.info_outline_rounded, size: 11, color: const Color(0xFF94A3B8)),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(LineIcons.clock, color: t.sub.withValues(alpha: 0.5), size: 12),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(created,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                        color: t.sub, fontSize: 10, fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Price on the right - no longer competed by novice badge
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('$price ₸',
                            style: GoogleFonts.inter(
                                color: const Color(0xFF4A80F0), fontWeight: FontWeight.w900, fontSize: 18)),
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
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: t.bg.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: t.border.withValues(alpha: 0.5))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.location_on_rounded, color: t.accent, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text('$from → $to',
                                style: GoogleFonts.inter(
                                    color: t.text, fontSize: 15, fontWeight: FontWeight.w700))),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4A80F0).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF4A80F0).withValues(alpha: 0.15)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.person_rounded, size: 14, color: Color(0xFF4A80F0)),
                                const SizedBox(width: 4),
                                Text('$seats',
                                    style: GoogleFonts.inter(
                                        fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF4A80F0))),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (comment.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(left: 28),
                          child: Text(comment,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                  color: t.sub,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  fontStyle: FontStyle.italic)),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          _actionStrip(context),
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

  void _showBargainHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFF4A80F0), size: 24),
            const SizedBox(width: 8),
            Text('Как это работает? 💡', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16, color: const Color(0xFF1E293B))),
          ],
        ),
        content: Text(
          'Вы можете предложить пассажиру свою стоимость поездки! Пассажир получит моментальное пуш-уведомление с вашей ценой и сможет согласиться или отказать.',
          style: GoogleFonts.inter(fontSize: 13, height: 1.45, fontWeight: FontWeight.w500, color: const Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('ПОНЯТНО', style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: const Color(0xFF4A80F0), fontSize: 13)),
          )
        ],
      ),
    );
  }

  Widget _actionStrip(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: _stripBtn(
                provider.translate('bargain'), 
                LineIcons.coins, 
                const Color(0xFF4A80F0), 
                onNegotiate,
                isFilled: true, 
                fontSize: 14
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _showBargainHelpDialog(context),
              child: Container(
                width: 32,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFF4A80F0).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF4A80F0).withValues(alpha: 0.15)),
                ),
                child: const Icon(Icons.help_outline_rounded, color: Color(0xFF4A80F0), size: 18),
              ),
            ),
            const SizedBox(width: 8),
            _iconBtn(LineIcons.phone, const Color(0xFF4A80F0), onCall),
            const SizedBox(width: 8),
            _iconBtn(LineIcons.comment, const Color(0xFF4A80F0), onChat),
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
