import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iqmarket/theme/taxi_theme.dart';
import 'package:iqmarket/providers/taxi_provider.dart';
import 'package:iqmarket/features/taxi/presentation/widgets/ui/taxi_location_picker_sheet.dart';

class TaxiRouteBuilder extends StatelessWidget {
  final BuildContext context;
  final TaxiTheme t;
  final TaxiProvider provider;
  final bool isFrom;
  final bool isDriver;
  final bool hasError;
  final VoidCallback onClearError;

  const TaxiRouteBuilder({
    super.key,
    required this.context,
    required this.t,
    required this.provider,
    required this.isFrom,
    this.isDriver = false,
    this.hasError = false,
    required this.onClearError,
  });

  @override
  Widget build(BuildContext context) {
    final val = isDriver
        ? (isFrom ? provider.driverFrom : provider.driverTo)
        : (isFrom ? provider.from : provider.to);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        showTaxiLocationPickerSheet(
          context: context,
          t: t,
          isFrom: isFrom,
          provider: provider,
          isDriver: isDriver,
        );
        if (!isDriver) {
          onClearError();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        color: Colors.transparent,
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: hasError
                    ? const Color(0xFFFFF1F2)
                    : isFrom
                        ? const Color(0xFFEFF6FF)
                        : const Color(0xFFF0FDF4),
                shape: BoxShape.circle,
                border: Border.all(
                  color: hasError
                      ? const Color(0xFFFDA4AF)
                      : isFrom
                          ? const Color(0xFF3B82F6)
                          : const Color(0xFF22C55E),
                  width: 2.2,
                ),
              ),
              child: Center(
                child: isFrom
                    ? Icon(Icons.circle,
                        color: hasError
                            ? const Color(0xFFE11D48)
                            : const Color(0xFF3B82F6),
                        size: 6.5)
                    : Icon(Icons.location_on_rounded,
                        color: hasError
                            ? const Color(0xFFE11D48)
                            : const Color(0xFF22C55E),
                        size: 10),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: val.isEmpty
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isFrom ? 'Откуда' : 'Куда',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: hasError
                                ? const Color(0xFFE11D48)
                                : const Color(0xFF94A3B8),
                            letterSpacing: -0.3,
                          ),
                        ),
                        if (hasError)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF1F2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: const Color(0xFFFDA4AF), width: 0.8),
                            ),
                            child: Text(
                              'укажите',
                              style: GoogleFonts.inter(
                                color: const Color(0xFFE11D48),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isFrom ? 'ОТКУДА' : 'КУДА',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF94A3B8),
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          val,
                          style: GoogleFonts.inter(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1E293B),
                            letterSpacing: -0.4,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
