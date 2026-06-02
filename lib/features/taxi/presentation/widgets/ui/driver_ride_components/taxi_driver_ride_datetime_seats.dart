import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iqmarket/theme/taxi_theme.dart';

class TaxiDriverRideDatetimeSeats extends StatelessWidget {
  final TaxiTheme t;
  final String localDate;
  final String localTime;
  final int seats;
  final bool sDateError;
  final bool sTimeError;
  final VoidCallback onDateTimeTap;
  final VoidCallback onSeatsTap;

  const TaxiDriverRideDatetimeSeats({
    super.key,
    required this.t,
    required this.localDate,
    required this.localTime,
    required this.seats,
    required this.sDateError,
    required this.sTimeError,
    required this.onDateTimeTap,
    required this.onSeatsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: GestureDetector(
            onTap: onDateTimeTap,
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: (sDateError || sTimeError)
                    ? const Color(0xFFFFF1F2)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: (sDateError || sTimeError)
                      ? const Color(0xFFFDA4AF)
                      : const Color(0xFFE2E8F0),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    color: (sDateError || sTimeError)
                        ? const Color(0xFFE11D48)
                        : const Color(0xFF4A80F0),
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
                            color: (sDateError || sTimeError)
                                ? const Color(0xFFE11D48)
                                : const Color(0xFF64748B),
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 1),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            (localDate.isEmpty || localDate == 'date')
                                ? 'Выбрать...'
                                : '${localDate == 'today' ? 'Сегодня' : localDate == 'tomorrow' ? 'Завтра' : localDate}${localTime.isEmpty || localTime == 'time' ? '' : ', ' + localTime}',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: (localDate.isEmpty || localDate == 'date')
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
            onTap: onSeatsTap,
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
                          '$seats',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: const Color(0xFF1E293B),
                            fontWeight: FontWeight.w900,
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
