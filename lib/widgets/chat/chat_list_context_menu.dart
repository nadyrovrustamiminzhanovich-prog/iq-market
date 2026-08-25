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
    HapticFeedback.mediumImpact();
    final lang = Provider.of<AppConfigProvider>(context, listen: false).language;
    final config = Provider.of<AppConfigProvider>(context, listen: false);
    final isBlocked = config.isUserBlocked(sellerId);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgSheet = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textDark = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final subText = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
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
                // Pull bar
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

                // Chat Header Preview
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: cardBorder, width: 1.2),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF3B82F6), width: 1.5),
                        ),
                        child: ClipOval(
                          child: adImage.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: adImage,
                                  fit: BoxFit.cover,
                                  memCacheWidth: 120,
                                  errorWidget: (_, __, ___) => Icon(
                                    Icons.person_outline_rounded,
                                    color: subText,
                                  ),
                                )
                              : Icon(
                                  Icons.person_outline_rounded,
                                  color: subText,
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sellerName,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: textDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              adTitle,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF3B82F6),
                              ),
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

                // Action list in unified grouped design
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
                        // Очистить историю
                        _buildMenuItem(
                          icon: Icons.cleaning_services_outlined,
                          iconColor: const Color(0xFF3B82F6),
                          title: TranslationService.t('clear_chat', lang),
                          subtitle: TranslationService.t('clear_chat_confirm', lang),
                          textDark: textDark,
                          subText: subText,
                          isDark: isDark,
                          onTap: () async {
                            Navigator.pop(sheetContext);
                            await _showClearChatConfirm(context, chatId, sellerId, lang, isDark);
                          },
                        ),
                        Divider(height: 1, thickness: 1, color: cardBorder),

                        // Заблокировать / Разблокировать
                        _buildMenuItem(
                          icon: isBlocked ? Icons.lock_open_rounded : Icons.block_outlined,
                          iconColor: isBlocked ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                          title: isBlocked
                              ? TranslationService.t('unblock_user', lang)
                              : TranslationService.t('block_user', lang),
                          subtitle: isBlocked
                              ? 'Разблокировать пользователя'
                              : 'Заблокировать входящие сообщения',
                          textDark: textDark,
                          subText: subText,
                          isDark: isDark,
                          onTap: () async {
                            Navigator.pop(sheetContext);
                            if (isBlocked) {
                              config.unblockUser(sellerId);
                            } else {
                              config.blockUser(sellerId);
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isBlocked
                                      ? 'Пользователь разблокирован'
                                      : 'Пользователь заблокирован',
                                ),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: isBlocked
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFF59E0B),
                              ),
                            );
                          },
                        ),
                        Divider(height: 1, thickness: 1, color: cardBorder),

                        // Удалить чат (Деструктивное действие с элегантным красным акцентом)
                        _buildMenuItem(
                          icon: Icons.delete_outline_rounded,
                          iconColor: const Color(0xFFEF4444),
                          title: TranslationService.t('delete_chat', lang),
                          subtitle: TranslationService.t('delete_chat_title', lang),
                          textDark: const Color(0xFFEF4444),
                          subText: subText,
                          isDark: isDark,
                          isDestructive: true,
                          onTap: () async {
                            Navigator.pop(sheetContext);
                            await _showDeleteChatOptions(context, chatId, sellerId, lang, isDark);
                          },
                        ),
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
    required String subtitle,
    required Color textDark,
    required Color subText,
    required bool isDark,
    required VoidCallback onTap,
    bool isDestructive = false,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: subText,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
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

  static Future<void> _showDeleteChatOptions(
    BuildContext context,
    String chatId,
    String sellerId,
    String lang,
    bool isDark,
  ) async {
    final bgSheet = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textDark = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final subText = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final cardBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.85,
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
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
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
                Text(
                  TranslationService.t('delete_chat_title', lang),
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: textDark,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  TranslationService.t('delete_chat_confirm_desc', lang),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: subText,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),

                // Option 1: Удалить только у меня
                _buildDeleteOptionCard(
                  icon: Icons.visibility_off_outlined,
                  iconColor: const Color(0xFF3B82F6),
                  title: TranslationService.t('delete_chat_for_me', lang),
                  subtitle: 'Чат исчезнет только из вашего списка',
                  cardBg: cardBg,
                  cardBorder: cardBorder,
                  textDark: textDark,
                  subText: subText,
                  isDark: isDark,
                  onTap: () async {
                    Navigator.pop(ctx);
                    final success = await ChatService.deleteChatForUser(
                      chatId: chatId,
                      otherUserId: sellerId,
                    );
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
                ),
                const SizedBox(height: 10),

                // Option 2: Удалить для обоих
                _buildDeleteOptionCard(
                  icon: Icons.delete_forever_rounded,
                  iconColor: const Color(0xFFEF4444),
                  title: TranslationService.t('delete_chat_for_both', lang),
                  subtitle: 'Удалит отправленные сообщения у обоих участников',
                  cardBg: cardBg,
                  cardBorder: cardBorder,
                  textDark: const Color(0xFFEF4444),
                  subText: subText,
                  isDark: isDark,
                  onTap: () async {
                    Navigator.pop(ctx);
                    final success = await ChatService.deleteChatForBoth(
                      chatId: chatId,
                      otherUserId: sellerId,
                    );
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
                ),
                const SizedBox(height: 14),

                // Кнопка Отмена
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      TranslationService.t('cancel', lang),
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: subText,
                      ),
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

  static Widget _buildDeleteOptionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Color cardBg,
    required Color cardBorder,
    required Color textDark,
    required Color subText,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cardBorder, width: 1.2),
          ),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: subText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
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

  static Future<void> _showClearChatConfirm(
    BuildContext context,
    String chatId,
    String sellerId,
    String lang,
    bool isDark,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dlgContext) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          TranslationService.t('clear_chat', lang),
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        content: Text(
          TranslationService.t('clear_chat_confirm', lang),
          style: GoogleFonts.inter(
            fontSize: 14,
            height: 1.4,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgContext, false),
            child: Text(
              TranslationService.t('cancel', lang),
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dlgContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
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

    if (confirmed == true && context.mounted) {
      final success = await ChatService.clearChatHistory(
        chatId: chatId,
        otherUserId: sellerId,
      );
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
