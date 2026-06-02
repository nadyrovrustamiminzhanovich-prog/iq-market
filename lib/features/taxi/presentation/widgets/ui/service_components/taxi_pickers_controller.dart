import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iqmarket/theme/taxi_theme.dart';
import 'package:iqmarket/providers/taxi_provider.dart';

class TaxiPickersController {
  static Future<void> pickDateTimeSequential({
    required BuildContext context,
    required TaxiProvider provider,
    required TaxiTheme t,
    required VoidCallback onDatePicked,
    required VoidCallback onTimePicked,
  }) async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (ctx, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.dark(
            primary: const Color(0xFF4A80F0),
            onPrimary: Colors.white,
            surface: t.card,
            onSurface: t.text,
          ),
        ),
        child: child!,
      ),
    );
    if (d == null || !context.mounted) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(d.year, d.month, d.day);

    String dateStr;
    if (selected == today) {
      dateStr = 'today';
    } else if (selected == today.add(const Duration(days: 1))) {
      dateStr = 'tomorrow';
    } else {
      final months = [
        provider.translate('jan'), provider.translate('feb'),
        provider.translate('mar'), provider.translate('apr'),
        provider.translate('may'), provider.translate('jun'),
        provider.translate('jul'), provider.translate('aug'),
        provider.translate('sep'), provider.translate('oct'),
        provider.translate('nov'), provider.translate('dec'),
      ];
      dateStr = '${d.day} ${months[d.month - 1]}';
    }
    provider.setDate(dateStr);
    onDatePicked();

    if (!context.mounted) return;
    final tVal = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.dark(
            primary: const Color(0xFF4A80F0),
            onPrimary: Colors.white,
            surface: t.card,
            onSurface: t.text,
          ),
        ),
        child: child!,
      ),
    );
    if (tVal != null) {
      provider.setTime('${tVal.hour}:${tVal.minute.toString().padLeft(2, '0')}');
      onTimePicked();
    }
  }

  static Future<void> pickDate({
    required BuildContext context,
    required TaxiProvider provider,
    required TaxiTheme t,
  }) async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (ctx, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.dark(
            primary: t.accent,
            onPrimary: Colors.white,
            surface: t.card,
            onSurface: t.text,
          ),
        ),
        child: child!,
      ),
    );
    if (d == null || !context.mounted) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(d.year, d.month, d.day);

    if (selected == today) {
      provider.setDate('today');
    } else if (selected == today.add(const Duration(days: 1))) {
      provider.setDate('tomorrow');
    } else {
      final months = [
        provider.translate('jan'), provider.translate('feb'),
        provider.translate('mar'), provider.translate('apr'),
        provider.translate('may'), provider.translate('jun'),
        provider.translate('jul'), provider.translate('aug'),
        provider.translate('sep'), provider.translate('oct'),
        provider.translate('nov'), provider.translate('dec'),
      ];
      provider.setDate('${d.day} ${months[d.month - 1]}');
    }
  }

  static void pickPass({
    required BuildContext context,
    required TaxiProvider provider,
    required TaxiTheme t,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: t.bg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 20),
        Text(provider.translate('sel_seats'),
            style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: List.generate(
              7,
              (i) => GestureDetector(
                onTap: () {
                  provider.setPassCnt(i + 1);
                  Navigator.pop(context);
                },
                child: Container(
                  width: 50,
                  height: 50,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: provider.passCnt == i + 1
                        ? const Color(0xFF4A80F0)
                        : t.card,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                        color: provider.passCnt == i + 1
                            ? const Color(0xFF4A80F0)
                            : t.border),
                  ),
                  child: Center(
                    child: Text('${i + 1}',
                        style: GoogleFonts.inter(
                            color: provider.passCnt == i + 1
                                ? Colors.white
                                : t.text,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 40),
      ]),
    );
  }
}
