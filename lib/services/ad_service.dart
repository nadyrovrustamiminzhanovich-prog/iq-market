import 'dart:io';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_compress/video_compress.dart';
import 'package:iqmarket/models/ad_model.dart';
import 'package:iqmarket/services/analytics_service.dart';
import 'package:iqmarket/services/file_service.dart';
import 'package:iqmarket/services/notification_service.dart';
import 'package:iqmarket/services/gemini_service.dart';
import 'package:iqmarket/services/user_service.dart';
import 'package:iqmarket/services/network_service.dart';
import 'package:iqmarket/services/telegram_bot_service.dart';
import 'package:iqmarket/services/fallback_moderation_keywords.dart';
import 'package:iqmarket/utils/fuzzy_matcher.dart';
class AdService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static CollectionReference get _adsCollection => _db.collection('ads');

  /// Высокоуровневый метод для загрузки медиа и публикации объявления
  static Future<String> uploadAndPublishAd({
    required String title,
    required String description,
    required String price,
    required String category,
    required String location,
    required List<File> images,
    List<String>? existingImages,
    File? video,
    String? condition,
    bool bargain = false,
    bool exchange = false,
    bool delivery = false,
    Map<String, dynamic>? extraFields,
    String? initialAdId,
    Function(String)? onStatusUpdate,
    required String lang,
    required String userPhone,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Пользователь не авторизован');

    // 1. Сжатие фото перед проверкой ИИ и загрузкой! (Сеньор-оптимизация 10x)
    List<File> compressedImages = [];
    final tempDir = await getTemporaryDirectory();
    
    for (int i = 0; i < images.length; i++) {
      if (onStatusUpdate != null) onStatusUpdate('Сжатие фото ${i + 1}/${images.length}...');
      final file = images[i];
      final targetPath = p.join(tempDir.path, 'comp_${DateTime.now().millisecondsSinceEpoch}_$i.jpg');
      
      try {
        final compressed = await FlutterImageCompress.compressAndGetFile(
          file.absolute.path, targetPath, quality: 80, minWidth: 1080, minHeight: 1080, autoCorrectionAngle: true
        );
        if (compressed != null) {
          compressedImages.add(File(compressed.path));
        } else {
          compressedImages.add(file); // fallback to original
        }
      } catch (e) {
        debugPrint('[AdService] Image compression error: $e');
        compressedImages.add(file); // fallback
      }
    }

    // ─────────────────────────────────────────────────────────────
    // 2. ИИ-Модерация (уже на сжатых фото)
    // Архитектура обработки ошибок:
    //   • Таймаут / сеть  → retry раз → APPROVED (fail-open) + Crashlytics non-fatal
    //   • Парсинг (нестандартный ответ) → MANUAL_REVIEW + Crashlytics non-fatal
    //   • Квота / сервис недоступен    → MANUAL_REVIEW + Analytics moderation_service_down
    //   • Перед любым fail-open  → offline-фильтр стоп-слов
    // ─────────────────────────────────────────────────────────────
    if (onStatusUpdate != null) onStatusUpdate('Проверка модерации ИИ...');

    final _userId = user.uid;
    String moderationVerdict = 'APPROVED'; // дефолт fail-open

    try {
      final gemini = GeminiService();
      gemini.init(lang);

      // Первая попытка — с таймаутом 20с
      final result = await gemini
          .checkContent(title, description, compressedImages)
          .timeout(const Duration(seconds: 20));

      moderationVerdict = _parseModerationResult(result);

    } on TimeoutException catch (e, stack) {
      // ─── ТАЙМАУТ: ретрай один раз, затем fail-open ───
      debugPrint('[AdService] Gemini timeout (attempt 1), retrying...');
      try {
        final gemini2 = GeminiService();
        gemini2.init(lang);
        final retryResult = await gemini2
            .checkContent(title, description, compressedImages)
            .timeout(const Duration(seconds: 25));
        moderationVerdict = _parseModerationResult(retryResult);
        debugPrint('[AdService] Retry succeeded: $moderationVerdict');
        
        // Ретрай успешен -> логируем первую ошибку с retrySucceeded: true
        AnalyticsService.logModerationAiFailure(
          error: e,
          stack: stack,
          errorType: 'timeout',
          adId: initialAdId ?? '',
          userId: _userId,
          verdict: moderationVerdict,
          retrySucceeded: true,
        );
      } on TimeoutException catch (e2, stack2) {
        // Оба попытки истекли — offline-фильтр + fail-open
        moderationVerdict = _offlineFallbackVerdict(title, description);
        AnalyticsService.logModerationAiFailure(
          error: e2,
          stack: stack2,
          errorType: 'timeout',
          adId: initialAdId ?? '',
          userId: _userId,
          verdict: moderationVerdict,
          retrySucceeded: false,
        );
      } catch (e2, stack2) {
        // Ретрай вернул другую ошибку — обрабатываем как сетевую
        moderationVerdict = _offlineFallbackVerdict(title, description);
        AnalyticsService.logModerationAiFailure(
          error: e2,
          stack: stack2,
          errorType: _classifyNetworkError(e2),
          adId: initialAdId ?? '',
          userId: _userId,
          verdict: moderationVerdict,
          retrySucceeded: false,
        );
      }

    } catch (e, stack) {
      // ─── ОСТАЛЬНЫЕ ОШИБКИ: классифицируем ───
      final errorType = _classifyNetworkError(e);

      if (errorType == 'quota' || errorType == 'service_unavailable') {
        // Полный отказ сервиса — запрос админа в Analytics
        moderationVerdict = _offlineFallbackVerdict(title, description);
        // Если offline-фильтр не поймал — всё равно отправляем на ручную
        if (moderationVerdict == 'APPROVED') moderationVerdict = 'MANUAL_REVIEW';
        AnalyticsService.logModerationServiceDown(
          reason: errorType,
          adId: initialAdId ?? '',
          userId: _userId,
        );
      } else if (errorType == 'parse_error') {
        // Нестандартный ответ Gemini — подозрительно, может быть prompt injection
        moderationVerdict = 'MANUAL_REVIEW';
      } else {
        // Сетевая / неизвестная — offline-фильтр + fail-open
        moderationVerdict = _offlineFallbackVerdict(title, description);
      }

      AnalyticsService.logModerationAiFailure(
        error: e,
        stack: stack,
        errorType: errorType,
        adId: initialAdId ?? '',
        userId: _userId,
        verdict: moderationVerdict,
        retrySucceeded: false,
      );
    }

    if (moderationVerdict.startsWith('REJECTED')) {
      final reason = moderationVerdict.replaceFirst('REJECTED:', '').trim();
      
      // Отправляем уведомление админу в Телеграм о попытке публикации запрещенного контента
      try {
        final authorName = user.displayName ?? 'Пользователь';
        await TelegramBotService.notifyAdminNewAd(
          adId: initialAdId ?? 'rejected_by_ai',
          title: title,
          price: price,
          category: category,
          userName: authorName,
          reason: '🚫 ЗАБЛОКИРОВАНО ИИ: ${reason.isEmpty ? "Нарушение политики контента" : reason}',
          description: description,
          imageUrls: const [],
        );
      } catch (tgEx) {
        debugPrint('[AdService] Failed to notify admin of rejected ad: $tgEx');
      }

      throw Exception('Объявление отклонено ИИ за нарушение правил.\nПричина: ${reason.isEmpty ? "Нарушение политики контента" : reason}');
    }

    // 3. Загрузка pre-compressed фото в Firebase Storage
    List<String> imageUrls = [];
    for (int i = 0; i < compressedImages.length; i++) {
      if (onStatusUpdate != null) onStatusUpdate('Загрузка фото ${i + 1}/${compressedImages.length}...');
      final file = compressedImages[i];
      try {
        final url = await FileService.uploadFile(file, 'ads/images');
        if (url != null) {
          imageUrls.add(url);
        } else {
          throw Exception('Не удалось загрузить фото ${i+1}');
        }
      } catch (e) {
        throw Exception('Ошибка при загрузке фото: $e');
      }
    }

    // 3. Загрузка оптимизированного видео
    String? videoUrl;
    if (video != null) {
      if (onStatusUpdate != null) onStatusUpdate('Загрузка видео...');
      videoUrl = await FileService.uploadFile(video, 'ads/videos');

      // Если нет фотографий, сгенерируем обложку из видео
      if (imageUrls.isEmpty) {
        try {
          if (onStatusUpdate != null) onStatusUpdate('Создание обложки из видео...');
          final thumbnailFile = await VideoCompress.getFileThumbnail(
            video.path,
            quality: 75,
            position: 100, // 100ms is safer than -1 which often fails
          );
          final thumbnailUrl = await FileService.uploadFile(thumbnailFile, 'ads/images');
          if (thumbnailUrl != null) {
            imageUrls.add(thumbnailUrl);
            debugPrint('[AdService] Generated video thumbnail: $thumbnailUrl');
          }
        } catch (e) {
          debugPrint('[AdService] Failed to generate video thumbnail: $e');
        }
      }
    }

    // 4. Подготовка данных и вызов Серверной верификации отпечатков
    final String savedAdId = initialAdId ?? _adsCollection.doc().id;
    final userData = await UserService.getUserById(user.uid);
    final isAdmin = userData?.accountType == 'admin';

    // Исходная активность и статус на основе ИИ-модерации
    bool finalActive = moderationVerdict == 'APPROVED' || isAdmin;
    String finalStatus = finalActive ? 'active' : 'pending';

    // Если ИИ одобрил объявление (и пользователь не админ), проверяем на дубликаты
    if (finalActive && !isAdmin) {
      if (onStatusUpdate != null) onStatusUpdate('Проверка на дубликаты...');
      try {
        final callable = FirebaseFunctions.instance.httpsCallable('checkAdFingerprint');
        final allImages = [...(existingImages ?? []), ...imageUrls];

        final response = await callable.call({
          'title': title,
          'description': description,
          'imagePaths': allImages,
          'adId': savedAdId,
        });

        final String serverVerdict = response.data['verdict'] ?? 'CLEAN';
        if (serverVerdict == 'MANUAL_REVIEW') {
          // Если найден дубль у другого пользователя — отправляем на ручную проверку
          finalActive = false;
          finalStatus = 'pending';
          debugPrint('[AdService] Ad fingerprint marked as MANUAL_REVIEW by server.');
        }
      } on FirebaseFunctionsException catch (e, stack) {
        if (e.code == 'already-exists') {
          throw Exception('Вы уже опубликовали точно такое же объявление');
        }
        // Fail-open логирование сбоя проверки на дубликаты
        AnalyticsService.logFingerprintCheckFailure(
          error: e,
          stack: stack,
          adId: savedAdId,
          userId: _userId,
          errorCode: e.code,
        );
        debugPrint('[AdService] checkAdFingerprint error (fail-open): ${e.message}');
      } catch (e, stack) {
        if (e.toString().contains('Вы уже опубликовали точно такое же объявление')) {
          rethrow;
        }
        // Fail-open логирование общего сбоя
        AnalyticsService.logFingerprintCheckFailure(
          error: e,
          stack: stack,
          adId: savedAdId,
          userId: _userId,
          errorCode: 'unknown_exception',
        );
        debugPrint('[AdService] checkAdFingerprint general error (fail-open): $e');
      }
    }

    // Get original ad owner if editing (to prevent changing userId and failing firestore rules)
    String finalUserId = user.uid;
    String finalUserName = user.displayName ?? 'Пользователь';
    String finalUserEmail = user.email ?? '';

    if (initialAdId != null) {
      try {
        final existingAdDoc = await _adsCollection.doc(initialAdId).get();
        if (existingAdDoc.exists) {
          final existingData = existingAdDoc.data() as Map<String, dynamic>?;
          if (existingData != null && existingData.containsKey('userId')) {
            finalUserId = existingData['userId'];
            finalUserName = existingData['userName'] ?? finalUserName;
            finalUserEmail = existingData['userEmail'] ?? finalUserEmail;
          }
        }
      } catch (e) {
        debugPrint('[AdService] Error fetching original ad owner: $e');
      }
    }

    // 🔒 Auto-sync phone number to user profile in Firestore (only if creator is editing)
    if (userPhone.isNotEmpty && finalUserId == user.uid) {
      try {
        final uid = user.uid;
        final userDocRef = _db.collection('users').doc(uid);
        await userDocRef.collection('private').doc('contact').set({
          'phone': userPhone,
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        debugPrint('[AdService] Auto-synced phone to profile: $userPhone');
      } catch (e) {
        debugPrint('[AdService] Auto-sync phone to profile failed: $e');
      }
    }

    final adModel = AdModel(
      id: savedAdId,
      title: title,
      description: description,
      price: double.tryParse(price.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0,
      category: category,
      images: [...(existingImages ?? []), ...imageUrls],
      videoUrl: videoUrl,
      userId: finalUserId,
      userName: finalUserName,
      userEmail: finalUserEmail,
      userPhone: userPhone,
      timestamp: DateTime.now(),
      location: location,
      condition: condition,
      isBargainAllowed: bargain,
      canExchange: exchange,
      hasDelivery: delivery,
      active: finalActive,
      status: finalStatus,
      extraFields: extraFields,
      expiresAt: DateTime.now().add(const Duration(days: 30)),
    );

    // 5. Сохранение
    if (onStatusUpdate != null) onStatusUpdate('Сохранение...');
    if (initialAdId != null) {
      await updateAd(initialAdId, adModel.toMap());
    } else {
      await createAd(adModel, customId: savedAdId);
    }

    // 📣 X10 NOTIFICATION: Отправляем уведомление админу в Телеграм для всех новых и обновленных объявлений
    if (savedAdId.isNotEmpty) {
      try {
        final displayTitle = initialAdId != null ? '🔄 [ОБНОВЛЕНО] $title' : title;
        if (finalActive) {
          // Если одобрено ИИ — отправляем информационное уведомление с кнопкой "Отклонить"
          await TelegramBotService.notifyAdminAdAutoApproved(
            adId: savedAdId,
            title: displayTitle,
            price: price,
            category: category,
            userName: adModel.userName,
            description: description,
            imageUrls: adModel.images,
          );
        } else {
          // Если требует ручной модерации — отправляем алерт на ручную проверку (кнопки "Одобрить"/"Отклонить")
          await TelegramBotService.notifyAdminNewAd(
            adId: savedAdId,
            title: displayTitle,
            price: price,
            category: category,
            userName: adModel.userName,
            reason: '🤖 ИИ или правила запросили ручную проверку (MANUAL_REVIEW).',
            description: description,
            imageUrls: adModel.images,
          );
        }
      } catch (e) {
        debugPrint('[AdService] Failed to notify admin via Telegram: $e');
      }
    }

    return savedAdId;
  }

  /// Get a single ad by ID
  static Future<AdModel?> getAdById(String id) async {
    try {
      final isOffline = await NetworkService.isOffline();
      final doc = await _adsCollection.doc(id).get(
        GetOptions(source: isOffline ? Source.cache : Source.serverAndCache),
      );
      if (doc.exists) {
        return AdModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting ad by ID: $e');
      return null;
    }
  }


  /// Create a new advertisement in Firestore (supports optional customId)
  static Future<String?> createAd(AdModel ad, {String? customId}) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final docRef = customId != null ? _adsCollection.doc(customId) : _adsCollection.doc();
      await docRef.set(ad.toMap());
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating ad: $e');
      return null;
    }
  }

  /// Get all active ads stream (Optimized to NOT require composite indices for now)
  static Stream<List<AdModel>> getActiveAdsStream() {
    return _adsCollection
        .orderBy('timestamp', descending: true)
        .limit(100) // Берем только 100 последних для ленты, чтобы не тормозило
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AdModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .where((ad) => ad.active && ad.status == 'active')
            .toList());
  }

  static Future<Map<String, dynamic>> getActiveAdsPaginated({
    DocumentSnapshot? startAfter, 
    int limit = 20,
    String? category,
    String? city,
    String? searchQuery,
    double? minPrice,
    double? maxPrice,
    String? condition,
    String? sortBy,
  }) async {
    try {
      // Базовые фильтры статуса — выполняются на стороне Firestore.
      // Для category и city требуются составные индексы:
      //   • status ASC + timestamp DESC
      //   • status ASC + category ASC + timestamp DESC
      //   • status ASC + location ASC + timestamp DESC
      // Их можно создать в Firebase Console → Firestore → Indexes.
      Query query = _adsCollection
          .where('active', isEqualTo: true)
          .where('status', isEqualTo: 'active');

      if (category != null && category != 'Все') {
        query = query.where('category', isEqualTo: category);
      }
      
      if (city != null && city != 'Все') {
        query = query.where('location', isEqualTo: city);
      }

      // condition filter is applied client-side below, after snapshot fetch

      query = query.orderBy('timestamp', descending: sortBy != 'oldest');

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      // Буфер limit*2 нужен только для клиентских фильтров
      // (searchQuery, minPrice, maxPrice), которые пока нельзя
      // выразить составным индексом вместе с другими where.
      final bool hasClientFilters = (searchQuery != null && searchQuery.isNotEmpty) ||
          minPrice != null ||
          maxPrice != null;
      final int fetchLimit = hasClientFilters ? limit * 2 : limit;

      final isOffline = await NetworkService.isOffline();
      final snapshot = await query.limit(fetchLimit).get(
        GetOptions(source: isOffline ? Source.cache : Source.serverAndCache),
      );
      
      List<AdModel> ads = snapshot.docs
          .map((doc) => AdModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList(); // active/status уже отфильтрованы Firestore

      // Клиентские фильтры, которые пока не поддерживаются составным индексом
      if (searchQuery != null && searchQuery.isNotEmpty) {
        ads = ads.where((ad) => 
          FuzzyMatcher.isMatch(searchQuery, '${ad.title} ${ad.description}')
        ).toList();
      }

      if (minPrice != null) {
        ads = ads.where((ad) => ad.price >= minPrice).toList();
      }

      if (maxPrice != null) {
        ads = ads.where((ad) => ad.price <= maxPrice).toList();
      }

      // ✅ condition filter: client-side to avoid missing Firestore composite index
      if (condition != null && condition != 'Все') {
        ads = ads.where((ad) => ad.condition == condition).toList();
      }

      
      // Ограничиваем возвращаемый список размером limit
      if (ads.length > limit) {
        ads = ads.sublist(0, limit);
      }
      
      return {
        'ads': ads,
        'lastDocument': snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      };
    } catch (e) {
      debugPrint('Error fetching paginated ads: $e');
      rethrow;
    }
  }


  /// Get ALL ads stream for admin (Active, Pending, Archived, Rejected)
  static Stream<List<AdModel>> getAllAdsStreamAdmin() {
    return _adsCollection
        .orderBy('timestamp', descending: true)
        .limit(300)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AdModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  /// Get pending ads stream for admin review
  static Stream<List<AdModel>> getPendingAdsStream() {
    return _adsCollection
        .where('status', isEqualTo: 'pending')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AdModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  /// Get archived or inactive ads stream for admin
  static Stream<List<AdModel>> getArchivedAdsStreamAdmin() {
    return _adsCollection
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => AdModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
              .where((ad) => !ad.active || ad.status == 'archived' || ad.status == 'rejected')
              .toList();
          list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return list;
        });
  }

  /// Get ads for a specific user
  static Stream<List<AdModel>> getAdsByUserStream(String userId) {
    return _adsCollection
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => AdModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
              .where((ad) => ad.active)
              .toList();
          list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return list;
        });
  }

  /// Get current user ads (Includes active, pending, and archived ads for proper tabs population)
  static Stream<List<AdModel>> getMyAdsStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);
    return _adsCollection
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => AdModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
              .toList();
          list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return list;
        });
  }

  /// Update an existing ad
  static Future<void> updateAd(String adId, Map<String, dynamic> updates) async {
    try {
      // 1. Получаем текущее состояние объявления перед обновлением
      final doc = await _adsCollection.doc(adId).get();
      if (!doc.exists) return;
      final oldAd = AdModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);

      // 2. Выполняем обновление
      await _adsCollection.doc(adId).update(updates);

      // 3. Логика уведомления о снижении цены
      if (updates.containsKey('price')) {
        final double? oldPrice = oldAd.price;
        final double? newPrice = double.tryParse(updates['price'].toString().replaceAll(RegExp(r'[^0-9.]'), ''));

        if (oldPrice != null && newPrice != null && newPrice < oldPrice) {
          updates['oldPrice'] = oldAd.price; // Сохраняем старую цену для красоты в UI
          _notifyPriceDrop(adId, oldAd.title, updates['price'].toString());
        }

      }
    } catch (e) {
      debugPrint('Error updating ad: $e');
      rethrow;
    }
  }

  /// Внутренний метод для поиска "фанатов" товара и отправки уведомлений
  static Future<void> _notifyPriceDrop(String adId, String title, String newPrice) async {
    try {
      // Ищем всех пользователей, у которых этот adId в списке избранного
      final usersSnapshot = await _db.collection('users')
          .where('favoriteIds', arrayContains: adId)
          .get();

      for (var userDoc in usersSnapshot.docs) {
        final userId = userDoc.id;
        // Отправляем уведомление через наш NotificationService
        NotificationService.saveNotificationToFirestore(
          uid: userId,
          title: 'Цена снижена! 🔥',
          body: 'Товар "$title" теперь стоит $newPrice. Самое время забрать его!',
          type: 'price_drop',
          data: {'adId': adId},
        ).catchError((e) {
          debugPrint('[AD_SERVICE] notifyPriceDrop failed for user $userId: $e');
        });
      }
    } catch (e) {
      debugPrint('Error notifying price drop: $e');
    }
  }


  /// Delete an ad and its associated files
  static Future<void> deleteAd(String adId) async {
    try {
      final doc = await _adsCollection.doc(adId).get();
      if (doc.exists) {
        final ad = AdModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        try {
          if (ad.images.isNotEmpty) await FileService.deleteMultipleFiles(ad.images);
        } catch (e) {
          debugPrint('Error deleting ad images from storage: $e');
        }
        try {
          if (ad.videoUrl != null && ad.videoUrl!.isNotEmpty) await FileService.deleteFile(ad.videoUrl!);
        } catch (e) {
          debugPrint('Error deleting ad video from storage: $e');
        }
      }
      await _adsCollection.doc(adId).delete();
    } catch (e) {
      debugPrint('Error deleting ad: $e');
      rethrow;
    }
  }

  /// Toggle ad status (active/archived)
  static Future<void> toggleAdStatus(String adId, bool isActive) async {
    try {
      await _adsCollection.doc(adId).update({
        'active': isActive,
        'status': isActive ? 'active' : 'archived',
      });
    } catch (e) {
      debugPrint('Error toggling ad status: $e');
      rethrow;
    }
  }

  /// Extend ad duration by 30 days
  static Future<void> extendAd(String adId) async {
    try {
      await _adsCollection.doc(adId).update({
        'active': true,
        'status': 'active',
        'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
        'notifiedExpiry': false, // Reset notification flag
      });
    } catch (e) {
      debugPrint('Error extending ad: $e');
      rethrow;
    }
  }

  /// Approve an ad (for admin)
  static Future<void> approveAd(String adId) async {
    try {
      final doc = await _adsCollection.doc(adId).get();
      if (!doc.exists) return;
      final ad = AdModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);

      await _adsCollection.doc(adId).update({
        'status': 'active',
        'active': true,
      });

      // Отправляем уведомление владельцу
      NotificationService.saveNotificationToFirestore(
        uid: ad.userId,
        title: 'Объявление одобрено! ✅',
        body: 'Ваше объявление "${ad.title}" прошло модерацию и теперь доступно всем пользователям.',
        type: 'ad_approved',
        data: {'adId': adId},
      ).catchError((e) {
        debugPrint('[AD_SERVICE] approveAd notification failed: $e');
      });
    } catch (e) {
      debugPrint('Error approving ad: $e');
      rethrow;
    }
  }

  /// Reject and delete an ad (for admin)
  static Future<void> rejectAd(String adId, {String reason = 'Нарушение правил размещения'}) async {
    try {
      final doc = await _adsCollection.doc(adId).get();
      if (!doc.exists) return;
      final ad = AdModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);

      // Отправляем уведомление об отклонении
      NotificationService.saveNotificationToFirestore(
        uid: ad.userId,
        title: 'Объявление отклонено ❌',
        body: 'Ваше объявление "${ad.title}" было отклонено модератором. Причина: $reason',
        type: 'ad_rejected',
        data: {'adId': adId, 'reason': reason},
      ).catchError((e) {
        debugPrint('[AD_SERVICE] rejectAd notification failed: $e');
      });

      // Удаляем само объявление
      await deleteAd(adId);
    } catch (e) {
      debugPrint('Error rejecting ad: $e');
      rethrow;
    }
  }

  /// Get recommended ads
  static Stream<List<AdModel>> getRecommendationsStream() {
    return _adsCollection
        .where('active', isEqualTo: true)
        .where('status', isEqualTo: 'active')
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AdModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  /// === СИСТЕМА ЖИЗНЕННОГО ЦИКЛА ОБЪЯВЛЕНИЙ ===

  /// 1. Проверка и уведомление пользователей об истечении (для юзера)
  static Future<void> checkMyAdsLifecycle() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final now = DateTime.now();
    final threeDaysFromNow = now.add(const Duration(days: 3));

    // Находим активные объявления, которые скоро истекут
    final snapshot = await _adsCollection
        .where('userId', isEqualTo: uid)
        .where('status', isEqualTo: 'active')
        .where('notifiedExpiry', isEqualTo: false)
        .get();

    for (var doc in snapshot.docs) {
      final ad = AdModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      if (ad.expiresAt != null && ad.expiresAt!.isBefore(threeDaysFromNow)) {
        // Отправляем уведомление
        NotificationService.saveNotificationToFirestore(
          uid: uid,
          title: 'Срок объявления истекает! ⏳',
          body: 'Ваше объявление "${ad.title}" скоро будет перенесено в архив. Продлите его, чтобы не потерять просмотры.',
          type: 'price_drop',
          data: {'adId': ad.id},
        ).catchError((e) {
          debugPrint('[AD_SERVICE] Expiry notification failed: $e');
        });
        // Помечаем, что уведомили
        await doc.reference.update({'notifiedExpiry': true});
      }
      
      // Если уже истекло — переносим в архив автоматически
      if (ad.expiresAt != null && ad.expiresAt!.isBefore(now)) {
        await toggleAdStatus(ad.id, false);
      }
    }
  }

  /// 2. Глобальная ежемесячная чистка (запускается админом)
  static Future<void> runGlobalCleanupIfNeeded() async {
    final user = await UserService.getUserById(_auth.currentUser?.uid ?? '');
    if (user?.accountType != 'admin') return;

    final settingsDoc = _db.collection('settings').doc('lifecycle');
    final snap = await settingsDoc.get();
    
    DateTime lastCleanup = DateTime(2024);
    if (snap.exists) {
      lastCleanup = (snap.data()?['lastCleanup'] as Timestamp).toDate();
    }

    // Если прошло больше 30 дней с последней чистки
    if (DateTime.now().difference(lastCleanup).inDays >= 30) {
      debugPrint('[LIFECYCLE] Starting monthly cleanup...');
      
      // Удаляем старые архивные объявления (которым больше 30 дней в архиве)
      int deletedCount = await cleanupOldArchivedAds();
      
      await settingsDoc.set({
        'lastCleanup': FieldValue.serverTimestamp(),
        'lastDeletedCount': deletedCount,
      }, SetOptions(merge: true));
      
      debugPrint('[LIFECYCLE] Cleanup finished. Deleted: $deletedCount');
    }
  }

  /// Search ads by query
  static Future<List<AdModel>> searchAds(String query) async {
    // Ограничиваем выборку для поиска, так как Firestore не поддерживает полнотекстовый поиск напрямую
    final snapshot = await _adsCollection
        .where('active', isEqualTo: true)
        .where('status', isEqualTo: 'active')
        .orderBy('timestamp', descending: true)
        .limit(100) // Ищем среди последних 100
        .get();
        
    return snapshot.docs
        .map((doc) => AdModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .where((ad) => FuzzyMatcher.isMatch(query, '${ad.title} ${ad.description}'))
        .toList();
  }

  /// Get similar ads by category
  /// Фильтры active/status применяются на стороне Firestore, а не на клиенте,
  /// чтобы не скачивать всю коллекцию категории целиком.
  /// Составной индекс: category ASC + active ASC + status ASC + timestamp DESC
  static Stream<List<AdModel>> getSimilarAdsStream(String category, String currentAdId) {
    return _adsCollection
        .where('category', isEqualTo: category)
        .where('active', isEqualTo: true)
        .where('status', isEqualTo: 'active')
        .orderBy('timestamp', descending: true)
        .limit(20) // Берём 20 с запасом, чтобы исключить currentAdId и взять 6
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AdModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .where((ad) => ad.id != currentAdId)
            .take(6)
            .toList());
  }

  /// Get multiple ads by their IDs
  static Future<List<AdModel>> getAdsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    try {
      List<AdModel> allAds = [];
      final isOffline = await NetworkService.isOffline();
      
      for (var i = 0; i < ids.length; i += 10) {
        final end = (i + 10 < ids.length) ? i + 10 : ids.length;
        final chunk = ids.sublist(i, end);
        final snapshot = await _adsCollection.where(FieldPath.documentId, whereIn: chunk).get(
          GetOptions(source: isOffline ? Source.cache : Source.serverAndCache),
        );
        allAds.addAll(snapshot.docs.map((doc) => AdModel.fromMap(doc.data() as Map<String, dynamic>, doc.id)));
      }
      return allAds;
    } catch (e) {
      debugPrint('Error fetching ads by IDs: $e');
      return [];
    }
  }

  /// Clean up old archived ads (older than 90 days) to save space
  static Future<int> cleanupOldArchivedAds() async {
    try {
      final ninetyDaysAgo = DateTime.now().subtract(const Duration(days: 90));
      final snapshot = await _adsCollection
          .where('status', isEqualTo: 'archived')
          .where('timestamp', isLessThan: Timestamp.fromDate(ninetyDaysAgo))
          .get();

      int deletedCount = 0;
      for (var doc in snapshot.docs) {
        await deleteAd(doc.id);
        deletedCount++;
      }
      return deletedCount;
    } catch (e) {
      debugPrint('Error cleaning up archived ads: $e');
      return 0;
    }
  }
  /// Delete all ads by a specific user (for account deletion)
  static Future<void> deleteUserAds(String userId) async {
    try {
      final snapshot = await _adsCollection.where('userId', isEqualTo: userId).get();
      final deleteFutures = snapshot.docs.map((doc) => deleteAd(doc.id));
      await Future.wait(deleteFutures);
      debugPrint('All ads for user $userId deleted ✅');
    } catch (e) {
      debugPrint('Error deleting user ads: $e');
    }
  }

  // ─── MODERATION HELPERS (private, extracted for testability) ──────────────

  /// Парсит строку ответа Gemini → вердикт.
  /// Чистая функция без побочных эффектов — легко тестировать изолированно.
  ///
  /// SECURITY: использует startsWith(), а не contains(), чтобы исключить
  /// prompt injection через текст объявления, который Gemini может эхоировать
  /// в своём ответе (например, "Текст содержит 'APPROVED' в описании").
  static String _parseModerationResult(String result) {
    final trimmed = result.trim();
    final upper  = trimmed.toUpperCase();

    if (upper.startsWith('APPROVED')) return 'APPROVED';

    if (upper.startsWith('REJECTED')) {
      final afterReject = trimmed.substring('REJECTED'.length).trim();
      final reason = afterReject.startsWith(':')
          ? afterReject.substring(1).trim()
          : afterReject;
      return reason.isNotEmpty ? 'REJECTED: $reason' : 'REJECTED';
    }

    if (upper.startsWith('MANUAL_REVIEW')) return 'MANUAL_REVIEW';

    // Нераспознанный / многословный ответ — подозрительно.
    // Может означать prompt injection или нестабильность модели.
    // Не fail-open: MANUAL_REVIEW безопаснее.
    debugPrint('[AdService] Gemini unrecognised verdict (possible injection): "${trimmed.length > 80 ? trimmed.substring(0, 80) : trimmed}" → MANUAL_REVIEW');
    return 'MANUAL_REVIEW';
  }

  /// Классифицирует тип исключения для Analytics / Crashlytics.
  /// Возвращает одну из строк: 'timeout' | 'network' | 'quota' |
  ///   'service_unavailable' | 'auth_error' | 'parse_error' | 'unknown'
  static String _classifyNetworkError(Object e) {
    if (e is TimeoutException) return 'timeout';

    final msg = e.toString().toLowerCase();

    // Квота Gemini API (429 / RESOURCE_EXHAUSTED)
    if (msg.contains('429') ||
        msg.contains('quota') ||
        msg.contains('resource_exhausted') ||
        msg.contains('resourceexhausted')) {
      return 'quota';
    }
    // Сервис недоступен (500 / 503)
    if (msg.contains('503') ||
        msg.contains('502') ||
        msg.contains('500') ||
        msg.contains('service unavailable') ||
        msg.contains('internal server')) {
      return 'service_unavailable';
    }
    // Ошибка аутентификации прокси (401 / 403)
    if (msg.contains('401') ||
        msg.contains('403') ||
        msg.contains('unauthorized') ||
        msg.contains('unauthenticated')) {
      return 'auth_error';
    }
    // Сетевые ошибки (DNS, socket)
    if (msg.contains('socketexception') ||
        msg.contains('network') ||
        msg.contains('connection') ||
        msg.contains('host lookup') ||
        msg.contains('errno')) {
      return 'network';
    }
    // Ошибки парсинга JSON / неожиданный формат ответа
    if (msg.contains('formatexception') ||
        msg.contains('jsondecodeerror') ||
        msg.contains('unexpected character') ||
        msg.contains('invalid json')) {
      return 'parse_error';
    }
    return 'unknown';
  }

  /// Offline-подстраховка: проверяет заголовок + описание на список
  /// стоп-слов из [FallbackModerationKeywords.all].
  ///
  /// Перед сравнением текст нормализуется через [ModerationNormalizer.normalize]:
  ///   - leet-speak (0→о, 1→и, 3→з, 4→ч, 6→б)
  ///   - разделители между буквами ("о-р-у-ж-и-е" → "оружие")
  ///
  /// Возвращает 'MANUAL_REVIEW' при совпадении, иначе 'APPROVED'.
  /// НЕ заменяет ИИ-модерацию — только закрывает worst-case.
  static String _offlineFallbackVerdict(String title, String description) {
    // Нормализуем входной текст: leet + разделители
    final rawText = '$title $description';
    final normalizedText = ModerationNormalizer.normalize(rawText);

    for (final word in FallbackModerationKeywords.all) {
      if (normalizedText.contains(word)) {
        debugPrint(
          '[AdService] Offline stopword match: "$word" '
          '(normalized input: "${normalizedText.length > 60 ? normalizedText.substring(0, 60) : normalizedText}") '
          '→ MANUAL_REVIEW',
        );
        return 'MANUAL_REVIEW';
      }
    }
    return 'APPROVED';
  }
}
