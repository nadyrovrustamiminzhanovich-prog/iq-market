import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:iqmarket/providers/taxi_provider.dart';

class TaxiCommentInputWidget extends StatelessWidget {
  final TextEditingController commentController;
  final Function(String) onCommentChanged;
  final VoidCallback onCommentClear;
  final bool showCommentClear;

  const TaxiCommentInputWidget({
    super.key,
    required this.commentController,
    required this.onCommentChanged,
    required this.onCommentClear,
    required this.showCommentClear,
  });

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TaxiProvider>(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              color: Color(0xFF1E5EE6),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: commentController,
              style: GoogleFonts.inter(color: const Color(0xFF1E293B), fontWeight: FontWeight.w700, fontSize: 14),
              maxLength: 200,
              onChanged: onCommentChanged,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: provider.translate('comment_hint'),
                hintStyle: GoogleFonts.inter(color: const Color(0xFF475569), fontSize: 13, fontWeight: FontWeight.w500),
                counterText: '',
              ),
            ),
          ),
          if (showCommentClear)
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                onCommentClear();
              },
              child: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 18),
            ),
        ],
      ),
    );
  }
}
