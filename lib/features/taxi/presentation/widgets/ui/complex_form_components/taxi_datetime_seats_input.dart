import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class TaxiDateTimeSeatsInputWidget extends StatelessWidget {
  final bool hasDateError;
  final bool hasTimeError;
  final String dateText;
  final String timeText;
  final VoidCallback onDateTimeTap;
  final int passCnt;
  final VoidCallback onPassTap;

  const TaxiDateTimeSeatsInputWidget({
    super.key,
    required this.hasDateError,
    required this.hasTimeError,
    required this.dateText,
    required this.timeText,
    required this.onDateTimeTap,
    required this.passCnt,
    required this.onPassTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onDateTimeTap();
            },
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: (hasDateError || hasTimeError) ? const Color(0xFFFFF1F2) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: (hasDateError || hasTimeError)
                      ? const Color(0xFFFDA4AF)
                      : const Color(0xFFE2E8F0),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    color: (hasDateError || hasTimeError) ? const Color(0xFFE11D48) : const Color(0xFF4A80F0),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'ДАТА И ВРЕМЯ',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            color: (hasDateError || hasTimeError) ? const Color(0xFFE11D48) : const Color(0xFF64748B),
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 1),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            (dateText.isEmpty || dateText == 'date')
                                ? 'Выбрать...'
                                : '${dateText == 'today' ? 'Сегодня' : dateText == 'tomorrow' ? 'Завтра' : dateText}${timeText == 'time' ? '' : ', ' + timeText}',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: (dateText.isEmpty || dateText == 'date')
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF1E293B),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onPassTap();
            },
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.group_rounded,
                    color: Color(0xFF4A80F0),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'МЕСТА',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '$passCnt',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFF1E293B),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
