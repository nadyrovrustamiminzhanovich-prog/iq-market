import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:iqmarket/services/translation_service.dart';
import 'package:iqmarket/widgets/auth_gate_bottom_sheet.dart';

class ReportUserSheet {
  static void show(
    BuildContext context, {
    required String reportedUserId,
    required String reportedUserName,
    required String lang,
  }) async {
    if (FirebaseAuth.instance.currentUser == null) {
      await AuthGateBottomSheet.show(
        context,
        message: TranslationService.t('auth_report_user_prompt', lang),
      );
      return;
    }

    String? selectedType;
    final TextEditingController commentCtrl = TextEditingController();
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (modalCtx) => StatefulBuilder(
        builder: (builderCtx, setModalState) {
          return Container(
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              MediaQuery.of(builderCtx).viewInsets.bottom + 24,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    TranslationService.t('report_user', lang),
                    style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    TranslationService.t('report_user_select_reason', lang),
                    style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  AbsorbPointer(
                    absorbing: isLoading,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _reportChip(
                          TranslationService.t('report_reason_spam', lang),
                          'spam',
                          selectedType,
                          (v) => setModalState(() => selectedType = v),
                        ),
                        _reportChip(
                          TranslationService.t('report_reason_insult', lang),
                          'insult',
                          selectedType,
                          (v) => setModalState(() => selectedType = v),
                        ),
                        _reportChip(
                          TranslationService.t('report_reason_fraud', lang),
                          'fraud',
                          selectedType,
                          (v) => setModalState(() => selectedType = v),
                        ),
                        _reportChip(
                          TranslationService.t('report_reason_other', lang),
                          'other',
                          selectedType,
                          (v) => setModalState(() => selectedType = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: commentCtrl,
                    maxLines: 3,
                    enabled: !isLoading,
                    style: GoogleFonts.inter(fontSize: 15),
                    decoration: InputDecoration(
                      hintText: TranslationService.t('report_comment_hint', lang),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: selectedType == null || isLoading
                          ? null
                          : () async {
                              setModalState(() {
                                isLoading = true;
                              });
                              try {
                                final reporterId = FirebaseAuth.instance.currentUser?.uid;
                                await FirebaseFirestore.instance.collection('reports').add({
                                  'reportedUserId': reportedUserId,
                                  'reportedUserName': reportedUserName,
                                  'reporterUserId': reporterId ?? 'anonymous',
                                  'type': selectedType,
                                  'comment': commentCtrl.text.trim(),
                                  'timestamp': FieldValue.serverTimestamp(),
                                });

                                if (modalCtx.mounted) {
                                  Navigator.pop(modalCtx);
                                }

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        TranslationService.t('report_sent_success', lang),
                                      ),
                                      backgroundColor: const Color(0xFF10B981),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (builderCtx.mounted) {
                                  setModalState(() {
                                    isLoading = false;
                                  });
                                }
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Ошибка отправки: $e'),
                                      backgroundColor: Colors.redAccent,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    ),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4A80F0),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey[300],
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              TranslationService.t('report_submit_btn', lang),
                              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).then((_) {
      commentCtrl.dispose();
    });
  }

  static Widget _reportChip(
    String title,
    String type,
    String? selectedType,
    Function(String) onSelect,
  ) {
    final isSelected = selectedType == type;
    return ChoiceChip(
      label: Text(title),
      selected: isSelected,
      onSelected: (_) => onSelect(type),
      backgroundColor: const Color(0xFFF1F5F9),
      selectedColor: const Color(0xFF4A80F0).withValues(alpha: 0.1),
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF4A80F0) : const Color(0xFF1E293B),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      showCheckmark: false,
    );
  }
}
