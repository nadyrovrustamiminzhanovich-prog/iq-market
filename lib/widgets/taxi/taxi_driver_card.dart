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
    final String rating  = driver['rating']?.toString() ?? '4.9';
    final String reviews = driver['reviews']?.toString() ?? '128';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        children: [
          Row(
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

                        const SizedBox(width: 8),
                        const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '$rating ($reviews)',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFF94A3B8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      car,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
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
                      color: const Color(0xFF1E293B),
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
          const SizedBox(height: 12),
          Row(
            children: [
              GestureDetector(
                onTap: onNegotiate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF4A80F0), Color(0xFF1E40AF)]),

                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF84CC16).withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.bolt_rounded, color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'ТОРГОВАТЬСЯ',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              _actionBtn(Icons.chat_bubble_outline_rounded, onChat),
              const SizedBox(width: 8),
              _actionBtn(Icons.phone_rounded, onCall),
            ],
          ),

        ],
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


