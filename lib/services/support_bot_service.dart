import 'dart:async';
import '../data/support_faq_database.dart';

/// ─────────────────────────────────────────────────────────────────
///  IQ Support Bot Service — Offline FAQ database & Operator routing
/// ─────────────────────────────────────────────────────────────────
class SupportBotService {
  // ── MAIN ENTRY POINT ─────────────────────────────────────────────
  /// Returns a [BotReply] describing what to show the user.
  static Future<BotReply> processMessage({
    required String userMessage,
    required String mode,  // 'market' | 'taxi'
    required String lang,  // 'RU' | 'KZ' | 'UG'
    required List<Map<String, dynamic>> chatHistory,
  }) async {
    final text = userMessage.trim();
    if (text.isEmpty) {
      return BotReply(
        type: BotReplyType.error,
        text: _t(lang, 'empty'),
      );
    }

    // TIER 1: Instant local FAQ match
    var localMatch = SupportFaqDatabase.findExactMatch(text, mode, lang);
    if (localMatch == null && mode != 'account') {
      localMatch = SupportFaqDatabase.findExactMatch(text, 'account', lang);
    }

    if (localMatch != null) {
      return BotReply(
        type: BotReplyType.faqMatch,
        text: localMatch['a']!,
        isOffline: true,
      );
    }

    // TIER 2: Not found in database -> Directly suggest operator contact
    return BotReply(
      type: BotReplyType.offlineFallback,
      text: _buildFallback(mode, lang),
      isOffline: true,
      showContact: true,
    );
  }

  // ── Build graceful fallback ─────────────────────────────
  static String _buildFallback(String mode, String lang) {
    if (lang == 'KZ') {
      return 'Кешіріңіз, бұл сұраққа біздің базамызда жауап табылмады. 😔\n\nСұрағыңызды шешу үшін төмендегі батырмалар арқылы біздің тірі операторымызға хабарласа аласыз:';
    } else if (lang == 'UG') {
      return 'Кәчүрүң, бу соалға базимизда җавап тепилмиди. 😔\n\nСоалиңизни һәл қилиш үшін төвәндики кнопкилар арқилиқ мулазимчимызға мүрәҗиәт қилишиңиз болиду:';
    }
    return 'Извините, в нашей базе знаний пока нет ответа на этот вопрос. 😔\n\nВы можете напрямую связаться с нашим живым оператором для решения любого вопроса с помощью кнопок ниже:';
  }

  // ── Localized strings ─────────────────────────────────────────────
  static String _t(String lang, String key) {
    const map = <String, Map<String, String>>{
      'empty': {
        'RU': 'Напишите ваш вопрос 😊',
        'KZ': 'Сұрағыңызды жазыңыз 😊',
        'UG': 'Соалиңизни йезиң 😊',
      },
    };
    return map[key]?[lang] ?? map[key]?['RU'] ?? key;
  }
}

// ── Data models ───────────────────────────────────────────────────
enum BotReplyType {
  faqMatch,       // Instant match from local database
  offlineFallback,// Graceful offline template
  error,          // System error
}

class BotReply {
  final BotReplyType type;
  final String text;
  final bool isOffline;
  final bool showContact;

  const BotReply({
    required this.type,
    required this.text,
    this.isOffline = true,
    this.showContact = false,
  });
}
