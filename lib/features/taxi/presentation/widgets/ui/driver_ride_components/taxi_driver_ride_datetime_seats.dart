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
    final hasDate = localDate.isNotEmpty && localDate != 'date';
    final dateDisplay = !hasDate
        ? provider.translate('select_dot')
        : '${localDate == 'today' ? provider.translate('today') : localDate == 'tomorrow' ? provider.translate('tomorrow') : localDate}${localTime.isEmpty || localTime == 'time' ? '' : ', ' + localTime}';

    return Row(
      children: [
        // ДАТА И ВРЕМЯ CARD
        Expanded(
          flex: 1,
          child: InkWell(
            onTap: onDateTimeTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: (sDateError || sTimeError) ? const Color(0xFFFDA4AF) : const Color(0xFFE2E8F0),
                  width: (sDateError || sTimeError) ? 2.0 : 1.2,
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
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: (sDateError || sTimeError) ? const Color(0xFFFFF1F2) : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.calendar_today_outlined,
                        color: (sDateError || sTimeError) ? const Color(0xFFE11D48) : const Color(0xFF2563EB),
                        size: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          provider.translate('date_time_label').toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: (sDateError || sTimeError) ? const Color(0xFFE11D48) : const Color(0xFF1E293B),
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dateDisplay,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: !hasDate ? const Color(0xFF64748B) : const Color(0xFF0F172A),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF334155),
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(width: 8),

        // МЕСТА CARD
        Expanded(
          flex: 1,
          child: InkWell(
            onTap: onSeatsTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  width: 1.2,
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
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.airline_seat_recline_normal_rounded,
                        color: Color(0xFF2563EB),
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          provider.translate('seats_label').toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: const Color(0xFF1E293B),
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$seats мес.',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: const Color(0xFF0F172A),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF334155),
                    size: 18,
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
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.chair_outlined,
                        color: Color(0xFF2563EB),
                        size: 20,
                      ),
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
                            fontSize: 10,
                            color: const Color(0xFF94A3B8),
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '$seats ${seats == 1 ? 'место' : seats < 5 ? 'места' : 'мест'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            color: const Color(0xFF0F172A),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF64748B),
                    size: 20,
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

