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
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: sFromError ? const Color(0xFFFDA4AF) : const Color(0xFFE2E8F0),
                width: sFromError ? 2.0 : 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: sFromError ? const Color(0xFFFFF1F2) : const Color(0xFFEFF6FF),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.north_rounded,
                      color: sFromError ? const Color(0xFFE11D48) : const Color(0xFF2563EB),
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        provider.translate('from').toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: sFromError ? const Color(0xFFE11D48) : const Color(0xFF1E293B),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        localFrom.isEmpty ? provider.translate('from_hint') : localFrom,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: localFrom.isEmpty ? const Color(0xFF64748B) : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF334155),
                  size: 20,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 6),

        // КУДА (TO) CARD
        InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onToTap();
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: sToError ? const Color(0xFFFDA4AF) : const Color(0xFFE2E8F0),
                width: sToError ? 2.0 : 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: sToError ? const Color(0xFFFFF1F2) : const Color(0xFFEFF6FF),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.south_rounded,
                      color: sToError ? const Color(0xFFE11D48) : const Color(0xFF2563EB),
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        provider.translate('to').toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: sToError ? const Color(0xFFE11D48) : const Color(0xFF1E293B),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        localTo.isEmpty ? provider.translate('to_hint') : localTo,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: localTo.isEmpty ? const Color(0xFF64748B) : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF334155),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
