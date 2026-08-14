import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MaxLengthEnforcement;
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:iqmarket/services/translation_service.dart';

class ReportAdSheetContent extends StatefulWidget {
  final String adId;
  final String adTitle;
  final String reportedUserId;
  final String lang;

  const ReportAdSheetContent({
    super.key,
    required this.adId,
    required this.adTitle,
    required this.reportedUserId,
    required this.lang,
  });

  @override
  State<ReportAdSheetContent> createState() => _ReportAdSheetContentState();
}

class _ReportAdSheetContentState extends State<ReportAdSheetContent> {
  static const int _maxCommentLength = 300;

  late final TextEditingController _commentCtrl;
  String? _selectedType;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _commentCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Widget _reportChip(String title, String type) {
    final isSelected = _selectedType == type;
    return ChoiceChip(
      label: Text(title),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedType = type),
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
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
              TranslationService.t('report_ad', widget.lang),
              style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              TranslationService.t('report_ad_select_reason', widget.lang),
              style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 20),
            AbsorbPointer(
              absorbing: _isLoading,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _reportChip(TranslationService.t('report_reason_fraud', widget.lang), 'fraud'),
                  _reportChip(TranslationService.t('report_reason_price', widget.lang), 'wrong_price'),
                  _reportChip(TranslationService.t('report_reason_sold', widget.lang), 'sold'),
                  _reportChip(TranslationService.t('report_reason_prohibited', widget.lang), 'prohibited'),
                  _reportChip(TranslationService.t('report_reason_other', widget.lang), 'other'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _commentCtrl,
              maxLines: 3,
              maxLength: _maxCommentLength,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              enabled: !_isLoading,
              decoration: InputDecoration(
                hintText: TranslationService.t('report_comment_hint', widget.lang),
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
                onPressed: _selectedType == null || _isLoading
                    ? null
                    : () async {
                        setState(() => _isLoading = true);
                        try {
                          final reporterId = FirebaseAuth.instance.currentUser?.uid;
                          final docId = '${reporterId ?? 'anonymous'}_${widget.adId}';
                          await FirebaseFirestore.instance.collection('reports').doc(docId).set({
                            'adId': widget.adId,
                            'adTitle': widget.adTitle,
                            'reportedUserId': widget.reportedUserId,
                            'reporterUserId': reporterId ?? 'anonymous',
                            'userId': reporterId ?? 'anonymous',
                            'type': _selectedType,
                            'comment': _commentCtrl.text.trim(),
                            'isRead': false,
                            'timestamp': FieldValue.serverTimestamp(),
                          });

                          if (mounted) {
                            Navigator.of(context).pop(true);
                          }
                        } catch (e) {
                          debugPrint('[Report] Submit error: $e');
                          setState(() => _isLoading = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  TranslationService.t('errSendReport', widget.lang)
                                      .replaceAll('{error}', e.toString()),
                                ),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        TranslationService.t('report_submit_btn', widget.lang),
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
