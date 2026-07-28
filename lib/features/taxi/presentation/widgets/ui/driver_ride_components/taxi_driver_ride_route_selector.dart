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
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: (sFromError || sToError) ? const Color(0xFFFDA4AF) : const Color(0xFFE2E8F0),
          width: (sFromError || sToError) ? 2.0 : 1.5,
        ),
      ),
      child: Column(
        children: [
          // FROM
          InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              onFromTap();
            },
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: sFromError ? const Color(0xFFFFF1F2) : const Color(0xFFECFDF5),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: sFromError ? const Color(0xFFE11D48) : const Color(0xFF10B981),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.my_location_rounded,
                      color: sFromError ? const Color(0xFFE11D48) : const Color(0xFF10B981),
                      size: 18,
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
                            fontSize: 10,
                            color: sFromError ? const Color(0xFFE11D48) : const Color(0xFF64748B),
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          localFrom.isEmpty ? provider.translate('from_hint') : localFrom,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: localFrom.isEmpty ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                ],
              ),
            ),
          ),
          Divider(height: 1, thickness: 1, color: const Color(0xFFE2E8F0), indent: 64),
          // TO
          InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              onToTap();
            },
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: sToError ? const Color(0xFFFFF1F2) : const Color(0xFFEFF6FF),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: sToError ? const Color(0xFFE11D48) : const Color(0xFF2563EB),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.location_on_rounded,
                      color: sToError ? const Color(0xFFE11D48) : const Color(0xFF2563EB),
                      size: 18,
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
                            fontSize: 10,
                            color: sToError ? const Color(0xFFE11D48) : const Color(0xFF64748B),
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          localTo.isEmpty ? provider.translate('to_hint') : localTo,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: localTo.isEmpty ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
