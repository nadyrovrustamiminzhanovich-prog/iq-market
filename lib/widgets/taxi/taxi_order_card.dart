import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
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
  bool _isExpanded = false;

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

  String _formatSeats(int seats) {
    if (seats == 1) return '1 место';
    if (seats >= 2 && seats <= 4) return '$seats места';
    return '$seats мест';
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    final t = widget.t;
    final name = widget.name.isNotEmpty ? widget.name : 'Пассажир';
    final from = widget.from.isNotEmpty ? widget.from : 'Чунджа';
    final to = widget.to.isNotEmpty ? widget.to : 'Алматы';
    final price = widget.price;
    final seats = widget.seats;
    final comment = widget.comment;
    final created = widget.created;
    final img = widget.img;
    final passengerId = widget.passengerId;

    final double realRating = provider.getUserRatingAsPassenger(passengerId);
    final int realReviewCount = provider.getUserReviewCountAsPassenger(passengerId);

    // Passenger Verification Badge logic:
    // For passengers, blue checkmark is granted if registered/logged in via Telegram!
    final bool isPassengerTelegramVerified = passengerId.startsWith('telegram_') ||
        provider.allPassengerOrders.any((o) =>
            (o['passengerId'] == passengerId || o['userId'] == passengerId) &&
            (o['isTelegramVerified'] == true ||
                o['isTelegramAuth'] == true ||
                o['authProvider'] == 'telegram' ||
                o['telegramChatId'] != null ||
                o['telegramId'] != null));

    const Color primaryBlue = Color(0xFF2563EB);
    final Color darkText = t.isDark ? Colors.white : const Color(0xFF1E293B);
    final Color subText = t.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final Color cardBg = t.isDark ? t.card : Colors.white;
    final Color borderColor = t.isDark ? t.border : const Color(0xFFF1F5F9);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: t.isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── TOP ROW: Avatar, Name + Verified Badge, Rating/Time, Price ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: widget.onShowProfile,
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: primaryBlue.withValues(alpha: 0.1),
                    backgroundImage: (img.isNotEmpty && img.startsWith('http'))
                        ? CachedNetworkImageProvider(img)
                        : null,
                    child: (img.isEmpty || !img.startsWith('http'))
                        ? const Icon(Icons.person_rounded, color: primaryBlue, size: 24)
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: GestureDetector(
                              onTap: widget.onShowProfile,
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: darkText,
                                ),
                              ),
                            ),
                          ),
                          if (isPassengerTelegramVerified) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.verified,
                              color: primaryBlue,
                              size: 18,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 14),
                          const SizedBox(width: 3),
                          Text(
                            realReviewCount < 5 ? 'Новичок' : '$realRating ($realReviewCount)',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: primaryBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text('•', style: TextStyle(color: subText, fontSize: 12)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              created,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: subText,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '$price ₸',
                  style: GoogleFonts.inter(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: primaryBlue,
                  ),
                ),
              ],
            ),
          ),

          // ── ROUTE LINE (Clickable to Expand/Collapse Order Info) ──
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, color: primaryBlue, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$from ➔ $to',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: darkText,
                          ),
                        ),
                      ),
                      Icon(
                        _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.chevron_right_rounded,
                        color: subText,
                        size: 22,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // ── SUB-LINE: Seats & User Comment (Luggage indicator is removed!) ──
                  Row(
                    children: [
                      const SizedBox(width: 26),
                      Icon(Icons.people_alt_outlined, color: subText, size: 15),
                      const SizedBox(width: 5),
                      Text(
                        _formatSeats(seats),
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          color: subText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('•', style: TextStyle(color: subText, fontSize: 12)),
                      const SizedBox(width: 8),
                      const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF94A3B8), size: 13),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          comment.isNotEmpty ? comment : 'Без комментария',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: subText,
                            fontWeight: FontWeight.w500,
                            fontStyle: comment.isNotEmpty ? FontStyle.italic : FontStyle.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── EXPANDED FULL DETAILS & BARGAIN SECTION ──
          if (_isExpanded) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(color: borderColor, height: 1),
                  const SizedBox(height: 12),
                  if (comment.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: t.isDark ? Colors.black26 : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: borderColor),
                      ),
                      child: Text(
                        'Комментарий от пассажира: $comment',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: darkText,
                          height: 1.35,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  // Price offer section when order details are opened
                  _buildBargainSection(context, primaryBlue),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // ── BOTTOM ACTION BUTTONS: Call & Message ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                // Outlined "Позвонить" Button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.onCall,
                    icon: const Icon(Icons.phone_outlined, color: primaryBlue, size: 18),
                    label: Text(
                      'Позвонить',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: primaryBlue,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
                      backgroundColor: t.isDark ? Colors.transparent : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Filled "Написать" Button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: widget.onChat,
                    icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 18),
                    label: Text(
                      'Написать',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: primaryBlue,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBargainSection(BuildContext context, Color primaryBlue) {
    final t = widget.t;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: primaryBlue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: primaryBlue.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ПРЕДЛОЖИТЬ СВОЮ ЦЕНУ',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: primaryBlue,
                    letterSpacing: 0.5,
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
                            if (_bidPrice < 100) _bidPrice = 100;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: primaryBlue.withValues(alpha: 0.3), width: 1.5),
                          color: Colors.white,
                        ),
                        child: Icon(Icons.remove_rounded, size: 16, color: primaryBlue),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '$_bidPrice ₸',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: t.isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(width: 10),
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
                          border: Border.all(color: primaryBlue.withValues(alpha: 0.3), width: 1.5),
                          color: Colors.white,
                        ),
                        child: Icon(Icons.add_rounded, size: 16, color: primaryBlue),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => widget.onNegotiate(_bidPrice),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Предложить',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

