import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:iqmarket/providers/taxi_provider.dart';
import 'package:iqmarket/theme/taxi_theme.dart';

class TaxiDriverRideRouteSelector extends StatelessWidget {
  final TaxiTheme t;
  final String localFrom;
  final String localTo;
  final bool sFromError;
  final bool sToError;
  final VoidCallback onFromTap;
  final VoidCallback onToTap;

  const TaxiDriverRideRouteSelector({
    super.key,
    required this.t,
    required this.localFrom,
    required this.localTo,
    required this.sFromError,
    required this.sToError,
    required this.onFromTap,
    required this.onToTap,
  });

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TaxiProvider>(context);

    return Column(
      children: [
        // ОТКУДА (FROM) CARD
        InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onFromTap();
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: sFromError ? const Color(0xFFFDA4AF) : const Color(0xFFF1F5F9),
                width: sFromError ? 2.0 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: sFromError ? const Color(0xFFFFF1F2) : const Color(0xFFEFF6FF),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.north_rounded,
                      color: sFromError ? const Color(0xFFE11D48) : const Color(0xFF2563EB),
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        provider.translate('from').toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: sFromError ? const Color(0xFFE11D48) : const Color(0xFF94A3B8),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        localFrom.isEmpty ? provider.translate('from_hint') : localFrom,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: localFrom.isEmpty ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF64748B),
                  size: 24,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // КУДА (TO) CARD
        InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onToTap();
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: sToError ? const Color(0xFFFDA4AF) : const Color(0xFFF1F5F9),
                width: sToError ? 2.0 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: sToError ? const Color(0xFFFFF1F2) : const Color(0xFFEFF6FF),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.south_rounded,
                      color: sToError ? const Color(0xFFE11D48) : const Color(0xFF2563EB),
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        provider.translate('to').toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: sToError ? const Color(0xFFE11D48) : const Color(0xFF94A3B8),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        localTo.isEmpty ? provider.translate('to_hint') : localTo,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: localTo.isEmpty ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF64748B),
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
