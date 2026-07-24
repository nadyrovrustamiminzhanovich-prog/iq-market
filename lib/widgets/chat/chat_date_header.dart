import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:iqmarket/providers/app_config_provider.dart';
import 'package:iqmarket/services/translation_service.dart';

class ChatDateHeader extends StatelessWidget {
  final DateTime date;

  const ChatDateHeader({
    super.key,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<AppConfigProvider>(context, listen: false).language;
    final now = DateTime.now();
    String text;
    if (now.day == date.day && now.month == date.month && now.year == date.year) {
      text = TranslationService.t('today', lang);
    } else if (now.day - 1 == date.day && now.month == date.month && now.year == date.year) {
      text = TranslationService.t('yesterday', lang);
    } else {
      final locale = lang == 'Қазақша' ? 'kk' : (lang == 'Уйғурчә' ? 'ug' : 'ru');
      text = DateFormat('d MMMM', locale).format(date);
    }
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF17212D).withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
