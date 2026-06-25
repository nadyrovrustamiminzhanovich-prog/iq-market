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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (sFromError || sToError)
              ? const Color(0xFFFDA4AF)
              : const Color(0xFFE2E8F0),
          width: (sFromError || sToError) ? 1.5 : 1.0,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 21,
            top: 30,
            bottom: 30,
            child: Container(
              width: 1.5,
              decoration: BoxDecoration(
                color: const Color(0xFF4A80F0).withValues(alpha: 0.3),
              ),
            ),
          ),
          Column(
            children: [
              // From
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onFromTap();
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                  color: Colors.transparent,
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: sFromError
                              ? const Color(0xFFE11D48)
                              : const Color(0xFF4A80F0),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: sFromError
                                ? const Color(0xFFFDA4AF)
                                : const Color(0xFF4A80F0),
                            width: 2,
                          ),
                        ),
                        child: const Center(
                          child: Icon(Icons.circle,
                              color: Colors.white, size: 6),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: localFrom.isEmpty
                            ? Text(
                                provider.translate('from_hint'),
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: sFromError
                                      ? const Color(0xFFE11D48)
                                      : const Color(0xFF94A3B8),
                                  letterSpacing: -0.3,
                                ),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    provider.translate('from'),
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      color: sFromError
                                          ? const Color(0xFFE11D48)
                                          : const Color(0xFF94A3B8),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    localFrom,
                                    style: GoogleFonts.inter(
                                      color: t.text,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16.5,
                                      letterSpacing: -0.4,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 50, right: 10),
                child: Divider(height: 1, color: Color(0xFFE2E8F0)),
              ),
              // To
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onToTap();
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                  color: Colors.transparent,
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: sToError
                                ? const Color(0xFFFDA4AF)
                                : const Color(0xFF4A80F0),
                            width: 2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: localTo.isEmpty
                            ? Text(
                                provider.translate('to_hint'),
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: sToError
                                      ? const Color(0xFFE11D48)
                                      : const Color(0xFF94A3B8),
                                  letterSpacing: -0.3,
                                ),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    provider.translate('to'),
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      color: sToError
                                          ? const Color(0xFFE11D48)
                                          : const Color(0xFF94A3B8),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    localTo,
                                    style: GoogleFonts.inter(
                                      color: t.text,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16.5,
                                      letterSpacing: -0.4,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
