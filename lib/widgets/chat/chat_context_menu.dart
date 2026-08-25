import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:iqmarket/models/message_model.dart';
import 'package:iqmarket/providers/app_config_provider.dart';
import 'package:iqmarket/services/translation_service.dart';
import 'package:iqmarket/services/user_service.dart';
import 'package:iqmarket/services/chat_service.dart';

class ChatContextMenu {
  static void show({
    required BuildContext context,
    required MessageModel msg,
    required String otherUserId,
    VoidCallback? onDeleted,
  }) {
    HapticFeedback.mediumImpact();
    final lang = Provider.of<AppConfigProvider>(context, listen: false).language;
    final bool isMyMessage = msg.senderId == UserService.currentUid;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgSheet = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textDark = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final cardBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(sheetContext).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: bgSheet,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 25,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),

              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: cardBorder, width: 1.2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Column(
                    children: [
                      if (msg.type == 'text') ...[
                        _buildMenuItem(
                          icon: Icons.copy_rounded,
                          iconColor: const Color(0xFF3B82F6),
                          title: TranslationService.t('copy_text', lang),
                          textDark: textDark,
                          isDark: isDark,
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: msg.text));
                            Navigator.pop(sheetContext);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(TranslationService.t('copied', lang)),
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          },
                        ),
                        Divider(height: 1, thickness: 1, color: cardBorder),
                      ],
                      _buildMenuItem(
                        icon: Icons.visibility_off_outlined,
                        iconColor: const Color(0xFF64748B),
                        title: TranslationService.t('delete_for_me', lang),
                        textDark: textDark,
                        isDark: isDark,
                        onTap: () async {
                          Navigator.pop(sheetContext);
                          final confirmed = await _confirm(
                            context: context,
                            lang: lang,
                            body: TranslationService.t('delete_for_me_confirm', lang),
                            destructive: false,
                            isDark: isDark,
                          );
                          if (!confirmed) return;
                          final count = await ChatService.hideMessagesForMe(otherUserId, [msg.id]);
                          if (count == 0) {
                            _showError(context, TranslationService.t('errDeleteMsg', lang));
                          } else {
                            onDeleted?.call();
                          }
                        },
                      ),
                      if (isMyMessage) ...[
                        Divider(height: 1, thickness: 1, color: cardBorder),
                        _buildMenuItem(
                          icon: Icons.delete_forever_rounded,
                          iconColor: const Color(0xFFEF4444),
                          title: TranslationService.t('delete_for_all', lang),
                          textDark: const Color(0xFFEF4444),
                          isDark: isDark,
                          onTap: () async {
                            Navigator.pop(sheetContext);
                            final confirmed = await _confirm(
                              context: context,
                              lang: lang,
                              body: TranslationService.t('delete_for_all_confirm', lang),
                              destructive: true,
                              isDark: isDark,
                            );
                            if (!confirmed) return;
                            final count = await ChatService.deleteMessages(otherUserId, [msg.id]);
                            if (count == 0) {
                              _showError(context, TranslationService.t('errDeleteMsg', lang));
                            } else {
                              onDeleted?.call();
                            }
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  static Widget _buildMenuItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Color textDark,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: textDark,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<bool> _confirm({
    required BuildContext context,
    required String lang,
    required String body,
    required bool destructive,
    required bool isDark,
  }) async {
    if (!context.mounted) return false;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          TranslationService.t('delete_msg_title', lang),
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        content: Text(
          body,
          style: GoogleFonts.inter(
            fontSize: 14,
            height: 1.4,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              TranslationService.t('cancel', lang),
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: destructive ? const Color(0xFFEF4444) : const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              TranslationService.t('delete_confirm_action', lang),
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  static void _showError(BuildContext context, String text) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
