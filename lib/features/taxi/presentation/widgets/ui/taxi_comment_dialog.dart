import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iqmarket/providers/taxi_provider.dart';
import 'package:iqmarket/theme/taxi_theme.dart';

void showTaxiCommentDialog(
  BuildContext context,
  TaxiProvider provider,
  TaxiTheme t,
) {
  final ctrl = TextEditingController(text: provider.comment);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: t.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(ctx).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: t.border,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Комментарий к заказу',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w900,
              color: t.text,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Напишите пожелания (например, чемодан, детское кресло)',
            style: GoogleFonts.inter(color: t.sub, fontSize: 13),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: ctrl,
            maxLength: 300,
            maxLines: 4,
            autofocus: true,
            style: GoogleFonts.inter(color: t.text),
            decoration: InputDecoration(
              filled: true,
              fillColor: t.card,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              hintText: 'Введите текст...',
              hintStyle: GoogleFonts.inter(
                  color: t.sub.withValues(alpha: 0.5)),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: () {
                provider.setComment(ctrl.text);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A80F0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Text(
                'СОХРАНИТЬ',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    ),
  ).whenComplete(() => ctrl.dispose());
}
