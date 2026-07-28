import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:iqmarket/theme/taxi_theme.dart';
import 'package:iqmarket/providers/taxi_provider.dart';
import 'package:iqmarket/features/taxi/presentation/widgets/ui/kazakhstan_license_plate.dart';

class TaxiDriverCard extends StatefulWidget {
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
  State<TaxiDriverCard> createState() => _TaxiDriverCardState();
}

class _TaxiDriverCardState extends State<TaxiDriverCard> {
  bool _isExpanded = false;
  int _bidPrice = 0;

  @override
  void initState() {
    super.initState();
    final rawPrice = widget.driver['price'];
    if (rawPrice is int) {
      _bidPrice = rawPrice;
    } else if (rawPrice != null) {
      _bidPrice = int.tryParse(rawPrice.toString()) ?? 4500;
    } else {
      _bidPrice = 4500;
    }
  }

  @override
  void didUpdateWidget(TaxiDriverCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final rawPrice = widget.driver['price'];
    if (rawPrice != oldWidget.driver['price']) {
      if (rawPrice is int) {
        _bidPrice = rawPrice;
      } else if (rawPrice != null) {
        _bidPrice = int.tryParse(rawPrice.toString()) ?? 4500;
      }
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
    final driver = widget.driver;

    final String name = driver['name'] ?? 'Водитель';
    final String img = driver['img'] ?? '';
    final String car = driver['car'] ?? 'Toyota Camry';
    final String price = driver['price']?.toString() ?? '4 500';
    final String driverPlate = driver['driverPlate']?.toString() ?? '';
    final String driverColor = driver['driverColor']?.toString() ?? '';
    final String comment = driver['comment']?.toString() ?? '';
    final String from = driver['from']?.toString() ?? provider.from;
    final String to = driver['to']?.toString() ?? provider.to;
    final String displayFrom = from.isNotEmpty ? from : 'Чунджа';
    final String displayTo = to.isNotEmpty ? to : 'Алматы';

    final int seats = driver['seats'] is int
        ? driver['seats']
        : (int.tryParse(driver['seats']?.toString() ?? '1') ?? 1);

    final String driverId = driver['driverId']?.toString() ?? '';
    final double realRating = provider.getUserRatingAsDriver(driverId);
    final int realReviewCount = provider.getUserReviewCountAsDriver(driverId);

    // Driver Verification Badge logic:
    // For drivers, Telegram login alone is NOT enough!
    // Badge is ONLY granted if full document/photo verification passed.
    final bool isDocVerified = driver['isVehicleVerified'] == true ||
        driver['driverVerified'] == true ||
        driver['driverVerified'] == 'true' ||
        driver['isDriverVerified'] == true ||
        driver['docVerified'] == true;

    final String displayDate = (driver['created'] != null && driver['created'].toString().isNotEmpty)
        ? driver['created'].toString()
        : '${TaxiProvider.formatTaxiDisplayDate(driver, provider.curLang)}${driver['time'] == null || driver['time'] == 'time' || driver['time'].toString().isEmpty ? '' : ', ' + driver['time'].toString()}';

    const Color primaryBlue = Color(0xFF2563EB);
    final Color darkText = t.isDark ? Colors.white : const Color(0xFF1E293B);
    final Color subText = t.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final Color cardBg = t.isDark ? t.card : Colors.white;
    final Color borderColor = t.isDark ? t.border : const Color(0xFFF1F5F9);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: t.isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── TOP ROW: Avatar, Name + Verified Badge, Rating/Time, Price ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: widget.onShowProfile,
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: primaryBlue.withValues(alpha: 0.1),
                    backgroundImage: (img.isNotEmpty && img.startsWith('http'))
                        ? CachedNetworkImageProvider(img)
                        : null,
                    child: (img.isEmpty || !img.startsWith('http'))
                        ? const Icon(Icons.person_rounded, color: primaryBlue, size: 20)
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
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
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: darkText,
                                ),
                              ),
                            ),
                          ),
                          if (isDocVerified) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.verified,
                              color: primaryBlue,
                              size: 16,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 13),
                          const SizedBox(width: 3),
                          Text(
                            realReviewCount < 5 ? 'Новичок' : '$realRating ($realReviewCount)',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: primaryBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text('•', style: TextStyle(color: subText, fontSize: 11)),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              displayDate,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
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
                const SizedBox(width: 10),
                Text(
                  '$price ₸',
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: primaryBlue,
                  ),
                ),
              ],
            ),
          ),

          // ── ROUTE LINE (Clickable to Expand/Collapse Trip Info) ──
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, color: primaryBlue, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '$displayFrom ➔ $displayTo',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: darkText,
                          ),
                        ),
                      ),
                      Icon(
                        _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.chevron_right_rounded,
                        color: subText,
                        size: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // ── SUB-LINE: Seats & User Comment ──
                  Row(
                    children: [
                      const SizedBox(width: 22),
                      Icon(Icons.people_alt_outlined, color: subText, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        _formatSeats(seats),
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: subText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text('•', style: TextStyle(color: subText, fontSize: 11)),
                      const SizedBox(width: 6),
                      const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF94A3B8), size: 12),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          comment.isNotEmpty ? comment : 'Без комментария',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
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

          // ── EXPANDED FULL DETAILS & OFFER PRICE SECTION ──
          if (_isExpanded) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(color: borderColor, height: 1),
                  const SizedBox(height: 8),
                  if (car.isNotEmpty || driverPlate.isNotEmpty || driverColor.isNotEmpty) ...[
                    Row(
                      children: [
                        const Icon(Icons.directions_car_rounded, color: primaryBlue, size: 15),
                        const SizedBox(width: 6),
                        Text(
                          car,
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: darkText,
                          ),
                        ),
                        if (driverPlate.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          KazakhstanLicensePlate(plate: driverPlate, fontSize: 10),
                        ],
                        if (driverColor.isNotEmpty) ...[
                          const SizedBox(width: 5),
                          Text(
                            '($driverColor)',
                            style: GoogleFonts.inter(fontSize: 11.5, color: subText),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (comment.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: t.isDark ? Colors.black26 : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: borderColor),
                      ),
                      child: Text(
                        'Комментарий от водителя: $comment',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: darkText,
                          height: 1.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  _buildBargainSection(context, primaryBlue),
                ],
              ),
            ),
          ],

          const SizedBox(height: 8),

          // ── BOTTOM ACTION BUTTONS: Call & Message ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Row(
              children: [
                // Outlined "Позвонить" Button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.onCall,
                    icon: const Icon(Icons.phone_outlined, color: primaryBlue, size: 16),
                    label: Text(
                      'Позвонить',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: primaryBlue,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.1),
                      backgroundColor: t.isDark ? Colors.transparent : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Filled "Написать" Button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: widget.onChat,
                    icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 16),
                    label: Text(
                      'Написать',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      backgroundColor: primaryBlue,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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
            onPressed: widget.onNegotiate,
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

