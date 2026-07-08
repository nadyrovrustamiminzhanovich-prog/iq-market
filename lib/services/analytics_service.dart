import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  static final FirebaseAnalyticsObserver observer = FirebaseAnalyticsObserver(analytics: _analytics);

  static Future<void> init() async {
    // В режиме отладки можно отключить сбор данных
    if (kDebugMode) {
      await _analytics.setAnalyticsCollectionEnabled(false);
    }
  }

  static Future<void> logAppOpen() async {
    await _analytics.logAppOpen();
  }

  static Future<void> logLogin(String method) async {
    await _analytics.logLogin(loginMethod: method);
  }

  static Future<void> logAdView(String adId, String title) async {
    await _analytics.logEvent(
      name: 'ad_view',
      parameters: {
        'ad_id': adId,
        'ad_title': title,
      },
    );
  }

  static Future<void> logSearch(String query) async {
    await _analytics.logSearch(searchTerm: query);
  }

  static Future<void> logCategoryView(String category) async {
    await _analytics.logEvent(
      name: 'category_view',
      parameters: {
        'category_name': category,
      },
    );
  }

  static Future<void> logAdPost() async {
    await _analytics.logEvent(name: 'ad_post');
  }

  static Future<void> logTaxiOrder(String type) async {
    await _analytics.logEvent(
      name: 'taxi_order_start',
      parameters: {'type': type},
    );
  }

  static Future<void> setUserProperties(String userId, String accountType) async {
    await _analytics.setUserId(id: userId);
    await _analytics.setUserProperty(name: 'account_type', value: accountType);
  }

  static Future<void> logEvent({required String name, Map<String, Object>? parameters}) async {
    await _analytics.logEvent(name: name, parameters: parameters);
  }

  static Future<void> logPermissionDenied({
    required String chatId,
    required String operation,
    required String type,
  }) async {
    final String hashedChatId = chatId.length > 8 ? chatId.substring(0, 8) : chatId;
    await logEvent(
      name: 'chat_permission_denied',
      parameters: {
        'chat_id_hash': hashedChatId,
        'operation': operation,
        'type': type,
      },
    );
  }

  static Future<void> logPushNavigation(String step, {Map<String, Object>? extra}) async {
    final Map<String, Object> params = {'step': step};
    if (extra != null) {
      params.addAll(extra);
    }
    await logEvent(name: 'push_navigation', parameters: params);
  }

  static void logFirestorePermissionError(Object e, StackTrace stack, String chatId, String operation, String type) {
    if (e is FirebaseException && e.code == 'permission-denied') {
      logPermissionDenied(
        chatId: chatId,
        operation: operation,
        type: type,
      );
      FirebaseCrashlytics.instance.recordError(
        e,
        stack,
        reason: 'Firebase Firestore Permission Denied ($operation $type)',
        information: ['chatId: $chatId'],
      );
    }
  }

  static void logStoragePermissionError(Object e, StackTrace stack, String folder) {
    if (e is FirebaseException && e.code == 'permission-denied') {
      final String operation = 'write';
      String type = 'other';
      String chatId = '';
      
      if (folder.startsWith('avatars/')) {
        type = 'avatar';
      } else if (folder.startsWith('chat_media/') || folder.startsWith('voice_messages/') || folder.startsWith('chats/')) {
        type = 'attachment';
        final parts = folder.split('/');
        if (parts.length > 1) {
          chatId = parts[1];
        }
      }
      
      logPermissionDenied(
        chatId: chatId,
        operation: operation,
        type: type,
      );
      
      FirebaseCrashlytics.instance.recordError(
        e,
        stack,
        reason: 'Firebase Storage Permission Denied ($operation $type)',
        information: ['folder: $folder', 'chatId: $chatId'],
      );
    }
  }

  // ─── MODERATION MONITORING ────────────────────────────────────────────────

  /// Non-fatal Crashlytics + Analytics event при сбое ИИ-модератора.
  /// Параметры намеренно совпадают с chat/push-контекстом: ad_id, user_id, timestamp.
  static void logModerationAiFailure({
    required Object error,
    required StackTrace stack,
    required String errorType,   // 'timeout' | 'network' | 'parse' | 'quota' | 'unknown'
    required String adId,        // ID объявления (может быть '' до сохранения)
    required String userId,
    required String verdict,     // итоговый вердикт после обработки
    required bool retrySucceeded, // признак успешного ретрая
  }) {
    // 1. Non-fatal в Crashlytics с контекстом
    FirebaseCrashlytics.instance.recordError(
      error,
      stack,
      reason: 'moderation_ai_failure [$errorType] (retry_succeeded: $retrySucceeded)',
      fatal: false,
      information: [
        'error_type: $errorType',
        'ad_id: $adId',
        'user_id: $userId',
        'verdict_applied: $verdict',
        'retry_succeeded: $retrySucceeded',
        'timestamp: ${DateTime.now().toUtc().toIso8601String()}',
      ],
    );

    // 2. Analytics-событие для дашборда
    logEvent(
      name: 'moderation_ai_failure',
      parameters: {
        'error_type': errorType,
        'ad_id': adId.isNotEmpty ? adId : 'unknown',
        'user_id': userId.isNotEmpty ? userId : 'anonymous',
        'verdict_applied': verdict,
        'retry_succeeded': retrySucceeded ? 'true' : 'false',
        'timestamp_utc': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  /// Analytics-событие при полном отказе сервиса Gemini (квота, 5xx).
  /// Позволяет настроить алерт в Firebase Console → Analytics → BigQuery.
  static void logModerationServiceDown({
    required String reason,   // 'quota_exceeded' | 'service_unavailable' | 'auth_error'
    required String adId,
    required String userId,
  }) {
    logEvent(
      name: 'moderation_service_down',
      parameters: {
        'reason': reason,
        'ad_id': adId.isNotEmpty ? adId : 'unknown',
        'user_id': userId.isNotEmpty ? userId : 'anonymous',
        'timestamp_utc': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  /// Log duplicate check failures (non-fatal Crashlytics and Analytics event)
  static void logFingerprintCheckFailure({
    required Object error,
    required StackTrace stack,
    required String adId,
    required String userId,
    String? errorCode,
  }) {
    FirebaseCrashlytics.instance.recordError(
      error,
      stack,
      reason: 'fingerprint_check_failed',
      fatal: false,
      information: [
        'ad_id: $adId',
        'user_id: $userId',
        'error_code: ${errorCode ?? 'unknown'}',
        'timestamp: ${DateTime.now().toUtc().toIso8601String()}',
      ],
    );

    logEvent(
      name: 'fingerprint_check_failed',
      parameters: {
        'ad_id': adId.isNotEmpty ? adId : 'unknown',
        'user_id': userId.isNotEmpty ? userId : 'anonymous',
        'error_code': errorCode ?? 'unknown',
        'timestamp_utc': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }
}
