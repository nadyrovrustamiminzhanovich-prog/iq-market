import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:line_icons/line_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:iqmarket/theme/taxi_theme.dart';
import 'package:iqmarket/providers/taxi_provider.dart';

class TaxiOrderCard extends StatefulWidget {
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
  final void Function(int price) onNegotiate;
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
  State<TaxiOrderCard> createState() => _TaxiOrderCardState();
}

class _TaxiOrderCardState extends State<TaxiOrderCard> {
  int _bidPrice = 0;

  @override
  void initState() {
    super.initState();
    _bidPrice = widget.price;
  }

  @override
  void didUpdateWidget(TaxiOrderCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.price != widget.price) {
      _bidPrice = widget.price;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    final t = widget.t;
    final name = widget.name;
    final from = widget.from;
    final to = widget.to;
    final price = widget.price;
    final seats = widget.seats;
    final comment = widget.comment;
    final isNegotiated = widget.isNegotiated;
    final created = widget.created;
    final img = widget.img;
    final passengerId = widget.passengerId;
    final onShowProfile = widget.onShowProfile;

    final double realRating = provider.getUserRatingAsPassenger(passengerId);
    final int realReviewCount = provider.getUserReviewCountAsPassenger(passengerId);

    final Color borderCol = t.isDark
        ? const Color(0xFF6366F1).withValues(alpha: 0.35)
        : const Color(0xFF4F46E5).withValues(alpha: 0.2);

    final Gradient bgGrad = t.isDark
        ? const LinearGradient(
            colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [Color(0xFFEFF6FF), Color(0xFFF5F3FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    final List<BoxShadow> shadows = [
      BoxShadow(
        color: t.isDark 
            ? const Color(0xFF6366F1).withValues(alpha: 0.12)
            : const Color(0xFF4F46E5).withValues(alpha: 0.08),
        blurRadius: 20,
        offset: const Offset(0, 8),
      )
    ];

    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          gradient: bgGrad,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: borderCol,
            width: 1.5,
          ),
          boxShadow: shadows,
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
                                color: const Color(0xFF4F46E5), fontWeight: FontWeight.w900, fontSize: 18)),
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
                      color: t.isDark 
                          ? Colors.black.withValues(alpha: 0.2) 
                          : Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderCol.withValues(alpha: 0.15))),
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
                              color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.15)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.person_rounded, size: 14, color: Color(0xFF4F46E5)),
                                const SizedBox(width: 4),
                                Text('$seats',
                                    style: GoogleFonts.inter(
                                        fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF4F46E5))),
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
          _buildBargainSection(context),
          _actionStrip(context),
        ],
      ),
    ),
  );
}

  Widget _buildBargainSection(BuildContext context) {
    final t = widget.t;
    final Color borderCol = t.isDark
        ? const Color(0xFF6366F1).withValues(alpha: 0.35)
        : const Color(0xFF4F46E5).withValues(alpha: 0.2);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: t.isDark 
              ? const Color(0xFF1E1B4B).withValues(alpha: 0.3) 
              : const Color(0xFFEFF6FF).withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderCol,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      widget.provider.translate('suggest_price').toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF4F46E5),
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          if (_bidPrice > 100) {
                            setState(() {
                              _bidPrice -= 100;
                              if (_bidPrice < 100) {
                                _bidPrice = 100;
                              }
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.remove_rounded,
                            size: 14,
                            color: Color(0xFF4F46E5),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '$_bidPrice ₸',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: t.isDark ? Colors.white : const Color(0xFF1E1B4B),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() {
                            _bidPrice += 100;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.add_rounded,
                            size: 14,
                            color: Color(0xFF4F46E5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () => widget.onNegotiate(_bidPrice),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                elevation: 0,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  widget.provider.translate('send').toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionStrip(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
        child: Row(
          children: [
            Expanded(
              child: _stripBtn(
                widget.provider.translate('call'),
                LineIcons.phone,
                const Color(0xFF4F46E5),
                widget.onCall,
                isFilled: false,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _stripBtn(
                widget.provider.translate('message'),
                LineIcons.comment,
                const Color(0xFF4F46E5),
                widget.onChat,
                isFilled: true,
                fontSize: 13,
              ),
            ),
          ],
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
