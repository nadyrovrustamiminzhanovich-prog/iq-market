import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  static final FirebaseAnalyticsObserver observer = FirebaseAnalyticsObserver(analytics: _analytics);

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
}
