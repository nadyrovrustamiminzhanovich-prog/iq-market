import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:iqmarket/providers/app_config_provider.dart';
import 'package:iqmarket/services/chat_service.dart';
import 'package:iqmarket/services/translation_service.dart';

class ChatListContextMenu {
  static void show({
    required BuildContext context,
    required String chatId,
    required String sellerId,
    required String sellerName,
    required String adTitle,
    required String adImage,
  }) {
    HapticFeedback.heavyImpact();
    final lang = Provider.of<AppConfigProvider>(context, listen: false).language;
    final config = Provider.of<AppConfigProvider>(context, listen: false);
    final isBlocked = config.isUserBlocked(sellerId);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pull bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Chat Header Preview
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF4A80F0), width: 1.5),
                      ),
                      child: ClipOval(
                        child: adImage.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: adImage,
                                fit: BoxFit.cover,
                                memCacheWidth: 120,
                                errorWidget: (_, __, ___) => const Icon(Icons.person_outline_rounded, color: Colors.grey),
                              )
                            : const Icon(Icons.person_outline_rounded, color: Colors.grey),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sellerName,
                            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            adTitle,
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF4A80F0)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Action: Удалить чат (WhatsApp Style)
              _buildActionTile(
                icon: Icons.delete_outline_rounded,
                iconColor: Colors.redAccent,
                title: TranslationService.t('delete_chat', lang),
                titleColor: Colors.redAccent,
                subtitle: TranslationService.t('delete_chat_title', lang),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _showDeleteChatOptions(context, chatId, sellerId, lang);
                },
              ),

              // Action: Очистить историю
              _buildActionTile(
                icon: Icons.cleaning_services_rounded,
                iconColor: const Color(0xFF64748B),
                title: TranslationService.t('clear_chat', lang),
                titleColor: const Color(0xFF1E293B),
                subtitle: TranslationService.t('clear_chat_confirm', lang),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _showClearChatConfirm(context, chatId, sellerId, lang);
                },
              ),

              // Action: Заблокировать / Разблокировать
              _buildActionTile(
                icon: isBlocked ? Icons.lock_open_rounded : Icons.block_flipped,
                iconColor: isBlocked ? const Color(0xFF10B981) : Colors.orange,
                title: isBlocked
                    ? TranslationService.t('unblock_user', lang)
                    : TranslationService.t('block_user', lang),
                titleColor: isBlocked ? const Color(0xFF10B981) : Colors.orange[800]!,
                subtitle: isBlocked ? 'Разблокировать сообщения' : 'Заблокировать входящие сообщения',
                onTap: () async {
                  Navigator.pop(sheetContext);
                  if (isBlocked) {
                    config.unblockUser(sellerId);
                  } else {
                    config.blockUser(sellerId);
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isBlocked ? 'Пользователь разблокирован' : 'Пользователь заблокирован'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: isBlocked ? const Color(0xFF10B981) : Colors.orange[800],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Color titleColor,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(
          title,
          style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15, color: titleColor),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
        onTap: onTap,
      ),
    );
  }

  static Future<void> _showDeleteChatOptions(
    BuildContext context,
    String chatId,
    String sellerId,
    String lang,
  ) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                TranslationService.t('delete_chat_title', lang),
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)),
              ),
              const SizedBox(height: 6),
              Text(
                TranslationService.t('delete_chat_confirm_desc', lang),
                style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
              ),
              const SizedBox(height: 20),

              // Кнопка: Удалить только у меня
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final success = await ChatService.deleteChatForUser(chatId: chatId, otherUserId: sellerId);
                    if (success && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(TranslationService.t('chat_deleted_success', lang)),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: const Color(0xFF10B981),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: Text(TranslationService.t('delete_chat_for_me', lang), style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A80F0),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Кнопка: Удалить для всех (удаляет отправленные сообщения)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final success = await ChatService.deleteChatForBoth(chatId: chatId, otherUserId: sellerId);
                    if (success && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(TranslationService.t('chat_deleted_success', lang)),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: const Color(0xFF10B981),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.delete_forever_rounded, size: 18, color: Colors.redAccent),
                  label: Text(TranslationService.t('delete_chat_for_both', lang), style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.redAccent)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.redAccent),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Отмена
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(TranslationService.t('cancel', lang), style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _showClearChatConfirm(
    BuildContext context,
    String chatId,
    String sellerId,
    String lang,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dlgContext) => AlertDialog(
        title: Text(TranslationService.t('clear_chat', lang), style: GoogleFonts.inter(fontWeight: FontWeight.w900)),
        content: Text(TranslationService.t('clear_chat_confirm', lang), style: GoogleFonts.inter(fontSize: 14)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgContext, false),
            child: Text(TranslationService.t('cancel', lang), style: const TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dlgContext, true),
            child: Text(TranslationService.t('delete_confirm_action', lang), style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final success = await ChatService.clearChatHistory(chatId: chatId, otherUserId: sellerId);
      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(TranslationService.t('chat_cleared_success', lang)),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    }
  }
}
