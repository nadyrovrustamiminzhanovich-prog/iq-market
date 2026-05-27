import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
    final String car     = driver['car']     ?? 'Toyota Camry 70';
    final String price   = driver['price']?.toString() ?? '4 500';
    final String driverCar   = driver['driverCar']?.toString() ?? car;
    final String driverPlate = driver['driverPlate']?.toString() ?? '';
    final String driverColor = driver['driverColor']?.toString() ?? '';
    final String comment     = driver['comment']?.toString() ?? '';
    
    // Dynamic rating and verification badge
    final String driverId = driver['driverId'] ?? '';
    final double realRating = provider.getUserRating(driverId);
    final int realReviewCount = provider.getUserReviewCount(driverId);
    final bool isVerified = driver['isVerified'] == true || driverId == 'taxi_driver';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          colors: [Color(0xFF4A80F0), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.all(1.5),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4A80F0).withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: onShowProfile,
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: (img.isNotEmpty && img.startsWith('http')) 
                        ? CachedNetworkImageProvider(img) 
                        : null,
                    child: (img.isEmpty || !img.startsWith('http')) 
                        ? const Icon(Icons.person, color: Color(0xFF94A3B8)) 
                        : null,
                  ),

                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1E293B),
                                ),
                              ),
                            ),
                            if (isVerified) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.verified_user_rounded, color: Color(0xFF4A80F0), size: 16),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (realReviewCount < 5)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4A80F0),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Новичок',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              )
                            else ...[
                              const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 16),
                              const SizedBox(width: 4),
                              Text(
                                '$realRating ($realReviewCount)',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: const Color(0xFF4A80F0),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            const SizedBox(width: 6),
                            Container(
                              width: 4,
                              height: 4,
                              decoration: const BoxDecoration(
                                color: Color(0xFF94A3B8),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                driverCar,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: const Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$price ₸',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF4A80F0),
                        ),
                      ),
                      Text(
                        'за место',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFF94A3B8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Car info row: plate & color
            if (driverPlate.isNotEmpty || driverColor.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.directions_car_rounded, color: Color(0xFF4A80F0), size: 14),
                  const SizedBox(width: 6),
                  if (driverPlate.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        driverPlate,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E293B),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  if (driverPlate.isNotEmpty && driverColor.isNotEmpty)
                    const SizedBox(width: 8),
                  if (driverColor.isNotEmpty)
                    Text(
                      driverColor,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ],

            // Comment display
            if (comment.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF94A3B8), size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        comment,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: onNegotiate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF4A80F0), Color(0xFF4A80F0)]),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFF4A80F0).withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 4))
                        ],
                      ),
                      child: Center(
                        child: Text(
                          'ТОРГОВАТЬСЯ',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _actionBtn(Icons.chat_bubble_outline_rounded, onChat),
                const SizedBox(width: 12),
                _actionBtn(Icons.phone_rounded, onCall),
              ],
            ),

          ],
        ),
      ),
    );
  }



  Widget _actionBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: const Color(0xFF4A80F0)),
      ),
    );
  }
}
