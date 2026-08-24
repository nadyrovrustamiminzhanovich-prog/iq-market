import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:iqmarket/models/message_model.dart';
import 'package:iqmarket/providers/app_config_provider.dart';
import 'package:iqmarket/services/translation_service.dart';
import 'package:iqmarket/services/user_service.dart';
import 'package:iqmarket/services/chat_service.dart';

class ChatContextMenu {
  static const Color _sheetColor = Color(0xFF1C2B3A);

  static void show({
    required BuildContext context,
    required MessageModel msg,
    required String otherUserId,
    VoidCallback? onDeleted,
  }) {
    HapticFeedback.heavyImpact();
    final lang = Provider.of<AppConfigProvider>(context, listen: false).language;
    final bool isMyMessage = msg.senderId == UserService.currentUid;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: const BoxDecoration(
          color: _sheetColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              if (msg.type == 'text')
                ListTile(
                  leading: const Icon(Icons.copy_rounded, color: Colors.white70),
                  title: Text(
                    TranslationService.t('copy_text', lang),
                    style: const TextStyle(color: Colors.white),
                  ),
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
              // «Удалить у меня» доступно для ЛЮБОГО сообщения, включая чужое:
              // до этого получатель не мог убрать из своей переписки вообще
              // ничего — оскорбление или мерзкое фото оставались навсегда,
              // единственным выходом была блокировка собеседника.
              ListTile(
                leading: const Icon(Icons.visibility_off_rounded, color: Colors.white70),
                title: Text(
                  TranslationService.t('delete_for_me', lang),
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final confirmed = await _confirm(
                    context: context,
                    lang: lang,
                    body: TranslationService.t('delete_for_me_confirm', lang),
                    destructive: false,
                  );
                  if (!confirmed) return;
                  final count =
                      await ChatService.hideMessagesForMe(otherUserId, [msg.id]);
                  if (count == 0) {
                    _showError(context, TranslationService.t('errDeleteMsg', lang));
                  } else {
                    onDeleted?.call();
                  }
                },
              ),
              if (isMyMessage)
                ListTile(
                  leading: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
                  title: Text(
                    TranslationService.t('delete_for_all', lang),
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    // Удаление у всех необратимо, поэтому одного нажатия по
                    // пункту меню для него недостаточно.
                    final confirmed = await _confirm(
                      context: context,
                      lang: lang,
                      body: TranslationService.t('delete_for_all_confirm', lang),
                      destructive: true,
                    );
                    if (!confirmed) return;
                    final count =
                        await ChatService.deleteMessages(otherUserId, [msg.id]);
                    if (count == 0) {
                      _showError(context, TranslationService.t('errDeleteMsg', lang));
                    } else {
                      onDeleted?.call();
                    }
                  },
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
  }) async {
    if (!context.mounted) return false;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _sheetColor,
        title: Text(
          TranslationService.t('delete_msg_title', lang),
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(body, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              TranslationService.t('cancel', lang),
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              TranslationService.t('delete_confirm_action', lang),
              style: TextStyle(
                color: destructive ? Colors.redAccent : Colors.white,
                fontWeight: FontWeight.bold,
              ),
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
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
