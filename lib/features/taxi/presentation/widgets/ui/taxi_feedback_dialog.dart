import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iqmarket/providers/taxi_provider.dart';
import 'package:iqmarket/services/notification_service.dart';
import 'package:iqmarket/theme/taxi_theme.dart';

/// Боттомшит для оценки пользователя после завершения поездки.
void showTaxiFeedbackDialog(
  BuildContext context,
  TaxiProvider provider,
  TaxiTheme t,
  String targetUserId,
  String targetUserName,
) {
  double selectedRating = 5.0;
  final tags = [
    'Быстро ⚡',
    'Вежливый 😊',
    'Чистое авто 🚗',
    'Безопасно 🛡️',
    'Комфортно 🛋️',
  ];
  final selectedTags = <String>[];
  final commentController = TextEditingController();

  bool isSubmitting = false;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: t.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (c, ss) => SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(c).viewInsets.bottom,
          top: 24,
          left: 24,
          right: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: t.border,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Как прошла поездка с',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: t.sub,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              targetUserName,
              style: GoogleFonts.inter(
                fontSize: 22,
                color: t.text,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 24),
            // Звёзды
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starVal = index + 1.0;
                final isSelected = starVal <= selectedRating;
                return GestureDetector(
                  onTap: () {
                    if (isSubmitting) return;
                    HapticFeedback.mediumImpact();
                    ss(() => selectedRating = starVal);
                  },
                  child: Icon(
                    isSelected
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: isSelected ? Colors.amber : t.border,
                    size: 48,
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),
            Text(
              'Что вам понравилось?',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: t.sub,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: tags.map((tag) {
                final isSelected = selectedTags.contains(tag);
                return GestureDetector(
                  onTap: () {
                    if (isSubmitting) return;
                    HapticFeedback.lightImpact();
                    ss(() {
                      if (isSelected) {
                        selectedTags.remove(tag);
                      } else {
                        selectedTags.add(tag);
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 9),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(
                              colors: [
                                Color(0xFF4A80F0),
                                Color(0xFF6366F1),
                              ],
                            )
                          : null,
                      color: isSelected ? null : t.card,
                      borderRadius: BorderRadius.circular(20),
                      border:
                          isSelected ? null : Border.all(color: t.border),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFF4A80F0)
                                    .withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      tag,
                      style: GoogleFonts.inter(
                        color: isSelected ? Colors.white : t.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: commentController,
              enabled: !isSubmitting,
              maxLines: 3,
              style: GoogleFonts.inter(color: t.text),
              decoration: InputDecoration(
                hintText: 'Напишите ваш комментарий...',
                hintStyle: GoogleFonts.inter(color: t.sub),
                filled: true,
                fillColor: t.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: t.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: t.accent),
                ),
              ),
            ),
            const SizedBox(height: 30),
            isSubmitting
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : GestureDetector(
                    onTap: () async {
                      if (isSubmitting) return;
                      HapticFeedback.heavyImpact();
                      ss(() => isSubmitting = true);
                      try {
                        final reviewComment = [
                          if (selectedTags.isNotEmpty)
                            '[${selectedTags.join(', ')}]',
                          commentController.text.trim(),
                        ].join(' ').trim();

                        await provider.submitReview(
                          targetUserId: targetUserId,
                          rating: selectedRating,
                          comment: reviewComment.isEmpty
                              ? 'Без комментариев'
                              : reviewComment,
                        );
                        if (c.mounted) {
                          NotificationService.notify(
                            c,
                            'Отзыв отправлен',
                            'Спасибо за вашу оценку!',
                            isSuccess: true,
                          );
                          Navigator.pop(c);
                        }
                      } catch (e) {
                        if (c.mounted) {
                          NotificationService.notify(
                            c,
                            provider.translate('error_label'),
                            provider.translate('general_error_desc'),
                            isSuccess: false,
                          );
                        }
                      } finally {
                        if (c.mounted) {
                          ss(() => isSubmitting = false);
                        }
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF84CC16), Color(0xFF4D7C0F)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFF84CC16).withValues(alpha: 0.4),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          'ОТПРАВИТЬ ОТЗЫВ',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    ),
  ).whenComplete(() => commentController.dispose());
}
