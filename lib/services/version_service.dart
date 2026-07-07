import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Service responsible for managing application updates and version validation.
class VersionService {
  /// Current app build version code (must be incremented on release matching pubspec.yaml)
  static const int currentVersionCode = 2;

  /// Checks if the current version meets the minimum version code requirements set in Firestore.
  /// Returns a [String] containing the store URL if update is required, or `null` if the app is up to date.
  static Future<String?> checkUpdateRequired() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('version_info')
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final minVersionCodeRaw = data['min_version_code'];
        int? minVersionCode;
        if (minVersionCodeRaw is int) {
          minVersionCode = minVersionCodeRaw;
        } else if (minVersionCodeRaw is double) {
          minVersionCode = minVersionCodeRaw.toInt();
        } else if (minVersionCodeRaw is String) {
          minVersionCode = int.tryParse(minVersionCodeRaw);
        }
        final storeUrl = data['store_url'] as String?;

        if (minVersionCode != null && currentVersionCode < minVersionCode) {
          return storeUrl ?? 'https://play.google.com/store/apps/details?id=com.iqmarket.app';
        }
      }
    } catch (e) {
      debugPrint('Error checking app version: $e');
    }
    return null;
  }
}
