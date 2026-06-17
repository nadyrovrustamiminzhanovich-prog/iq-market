import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iqmarket/theme/taxi_theme.dart';
import 'package:iqmarket/providers/taxi_provider.dart';

void showTaxiHistoryRatingSheet(
  BuildContext context,
  TaxiProvider provider,
  String targetUserId,
  String targetUserName,
  TaxiTheme t,
  String targetRole,
) {
  double selectedRating = 5.0;
  final List<String> tags = ['Чистое авто 🚗', 'Вежливый 😊', 'Быстро ⚡', 'Комфортно 🛋️', 'Безопасно 🛡️'];
  final List<String> selectedTags = [];
  final TextEditingController commentController = TextEditingController();

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
          bottom: MediaQuery.of(c).viewInsets.bottom + 24,
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
              style: GoogleFonts.inter(fontSize: 14, color: t.sub, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Text(
              targetUserName,
              style: GoogleFonts.inter(fontSize: 22, color: t.text, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 24),
            // Star rating
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final double starVal = index + 1.0;
                final bool isSelected = starVal <= selectedRating;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    ss(() => selectedRating = starVal);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: isSelected ? Colors.amber : t.border,
                      size: 48,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),
            Text(
              'Что вам понравилось?',
              style: GoogleFonts.inter(fontSize: 13, color: t.sub, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            // Tag chips with premium gradient
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: tags.map((tag) {
                final bool isChipSelected = selectedTags.contains(tag);
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    ss(() {
                      if (isChipSelected) {
                        selectedTags.remove(tag);
                      } else {
                        selectedTags.add(tag);
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    decoration: BoxDecoration(
                      gradient: isChipSelected
                          ? const LinearGradient(
                              colors: [Color(0xFF4A80F0), Color(0xFF6366F1)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: isChipSelected ? null : t.card,
                      borderRadius: BorderRadius.circular(20),
                      border: isChipSelected ? null : Border.all(color: t.border),
                      boxShadow: isChipSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFF4A80F0).withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      tag,
                      style: GoogleFonts.inter(
                        color: isChipSelected ? Colors.white : t.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            // Comment field
            TextField(
              controller: commentController,
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
                  borderSide: const BorderSide(color: Color(0xFF4A80F0)),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Submit button
            GestureDetector(
              onTap: () async {
                Navigator.pop(ctx);
                HapticFeedback.heavyImpact();

                final String reviewComment = [
                  if (selectedTags.isNotEmpty) '[${selectedTags.join(", ")}]',
                  commentController.text.trim()
                ].join(' ').trim();

                await provider.submitReview(
                  targetUserId: targetUserId,
                  rating: selectedRating,
                  comment: reviewComment.isEmpty ? 'Без комментариев' : reviewComment,
                  targetRole: targetRole,
                );

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Отзыв отправлен! Спасибо за вашу оценку ⭐',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                      backgroundColor: const Color(0xFF10B981),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  );
                }
              },
              child: Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.35),
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
            const SizedBox(height: 16),
          ],
        ),
      ),
    ),
  );
}
