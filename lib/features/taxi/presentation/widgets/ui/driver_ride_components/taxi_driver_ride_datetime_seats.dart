import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iqmarket/theme/taxi_theme.dart';
import 'package:provider/provider.dart';
import 'package:iqmarket/providers/taxi_provider.dart';

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
    final provider = Provider.of<TaxiProvider>(context);
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: InkWell(
            onTap: onDateTimeTap,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: (sDateError || sTimeError) ? const Color(0xFFFFF1F2) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: (sDateError || sTimeError) ? const Color(0xFFFDA4AF) : const Color(0xFFE2E8F0),
                  width: (sDateError || sTimeError) ? 2.0 : 1.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: (sDateError || sTimeError) ? const Color(0xFFE11D48).withValues(alpha: 0.1) : const Color(0xFF2563EB).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.calendar_today_rounded,
                      color: (sDateError || sTimeError) ? const Color(0xFFE11D48) : const Color(0xFF2563EB),
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          provider.translate('date_time_label').toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            color: (sDateError || sTimeError) ? const Color(0xFFE11D48) : const Color(0xFF64748B),
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            (localDate.isEmpty || localDate == 'date')
                                ? provider.translate('select_dot')
                                : '${localDate == 'today' ? provider.translate('today') : localDate == 'tomorrow' ? provider.translate('tomorrow') : localDate}${localTime.isEmpty || localTime == 'time' ? '' : ', ' + localTime}',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: (localDate.isEmpty || localDate == 'date') ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                              fontWeight: FontWeight.w800,
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
          child: InkWell(
            onTap: onSeatsTap,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.event_seat_rounded,
                      color: Color(0xFF10B981),
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          provider.translate('seats_label').toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$seats ${seats == 1 ? 'место' : seats < 5 ? 'места' : 'мест'}',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFF0F172A),
                            fontWeight: FontWeight.w800,
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
