import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_compress/video_compress.dart';
import 'package:iqmarket/models/ad_model.dart';
import 'package:iqmarket/services/file_service.dart';
import 'package:iqmarket/services/notification_service.dart';
import 'package:iqmarket/services/gemini_service.dart';
import 'package:iqmarket/services/user_service.dart';
import 'package:iqmarket/services/network_service.dart';
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
    File? video,
    String? condition,
    bool bargain = false,
    bool exchange = false,
    bool delivery = false,
    Map<String, dynamic>? extraFields,
    String? initialAdId,
    Function(String)? onStatusUpdate,
    required String lang,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Пользователь не авторизован');

    // 1. ИИ Модерация
    if (onStatusUpdate != null) onStatusUpdate('Проверка модерации ИИ...');
    String moderationVerdict = 'MANUAL_REVIEW';
    try {
      final gemini = GeminiService();
      gemini.init(lang);
      final result = await gemini.checkContent(title, description, images);
      if (result.contains('APPROVED')) moderationVerdict = 'APPROVED';
      else if (result.contains('REJECTED')) moderationVerdict = 'REJECTED';
    } catch (e) {
      debugPrint('[AdService] Gemini failed: $e');
      // If AI fails, we allow manual review instead of blocking
    }

    if (moderationVerdict.startsWith('REJECTED')) {
      final reason = moderationVerdict.replaceFirst('REJECTED:', '').trim();
      throw Exception('Объявление отклонено ИИ за нарушение правил.\nПричина: ${reason.isEmpty ? "Нарушение политики контента" : reason}');
    }

    // 2. Загрузка фото со сжатием
    List<String> imageUrls = [];
    final tempDir = await getTemporaryDirectory();
    for (int i = 0; i < images.length; i++) {
      if (onStatusUpdate != null) onStatusUpdate('Сжатие фото ${i + 1}/${images.length}...');
      final file = images[i];
      final targetPath = p.join(tempDir.path, 'comp_${DateTime.now().millisecondsSinceEpoch}_$i.jpg');
      
      try {
        final compressed = await FlutterImageCompress.compressAndGetFile(
          file.absolute.path, targetPath, quality: 85, minWidth: 1280, minHeight: 1280
        );
        
        final url = await FileService.uploadFile(File(compressed?.path ?? file.path), 'ads/images');
        if (url != null) {
          imageUrls.add(url);
        } else {
          throw Exception('Не удалось загрузить фото ${i+1}');
        }
      } catch (e) {
        throw Exception('Ошибка при обработке фото: $e');
      }
    }

    // 3. Загрузка видео со сжатием
    String? videoUrl;
    if (video != null) {
      if (onStatusUpdate != null) onStatusUpdate('Оптимизация видео...');
      final mediaInfo = await VideoCompress.compressVideo(
        video.path, quality: VideoQuality.MediumQuality, deleteOrigin: false
      );
      final fileToUpload = (mediaInfo != null && mediaInfo.path != null) ? File(mediaInfo.path!) : video;
      videoUrl = await FileService.uploadFile(fileToUpload, 'ads/videos');
    }

    // 4. Подготовка данных
    final userData = await UserService.getUserById(user.uid);
    final isAdmin = userData?.accountType == 'admin';
    final isApproved = moderationVerdict == 'APPROVED' || isAdmin;

    final adModel = AdModel(
      id: initialAdId ?? '',
      title: title,
      description: description,
      price: double.tryParse(price.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0,
      category: category,
      images: imageUrls,
      videoUrl: videoUrl,
      userId: user.uid,
      userName: user.displayName ?? 'Пользователь',
      userEmail: user.email ?? '',
      userPhone: user.phoneNumber ?? '',
      timestamp: DateTime.now(),
      location: location,
      condition: condition,
      isBargainAllowed: bargain,
      canExchange: exchange,
      hasDelivery: delivery,
      active: isApproved,
      status: isApproved ? 'active' : 'pending',
      extraFields: extraFields,
      expiresAt: DateTime.now().add(const Duration(days: 30)),
    );

    // 5. Сохранение
    if (onStatusUpdate != null) onStatusUpdate('Сохранение...');
    if (initialAdId != null) {
      await updateAd(initialAdId, adModel.toMap());
      return initialAdId;
    } else {
      final id = await createAd(adModel);
      return id ?? '';
    }
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


  /// Create a new advertisement in Firestore
  static Future<String?> createAd(AdModel ad) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final docRef = await _adsCollection.add(ad.toMap());
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
      // Чтобы не требовать сложные составные индексы в Firestore, делаем простой orderBy и фильтруем на клиенте!
      Query query = _adsCollection.orderBy('timestamp', descending: sortBy != 'oldest');

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final isOffline = await NetworkService.isOffline();
      final snapshot = await query.limit(limit * 4).get( // Увеличиваем запас для надежной локальной фильтрации
        GetOptions(source: isOffline ? Source.cache : Source.serverAndCache),
      );
      
      List<AdModel> ads = snapshot.docs
          .map((doc) => AdModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .where((ad) => ad.active && ad.status == 'active')
          .toList();

      if (category != null && category != 'Все') {
        ads = ads.where((ad) => ad.category == category).toList();
      }
      
      if (city != null && city != 'Все') {
        ads = ads.where((ad) => ad.location == city).toList();
      }

      if (searchQuery != null && searchQuery.isNotEmpty) {
        ads = ads.where((ad) => 
          ad.title.toLowerCase().contains(searchQuery.toLowerCase()) || 
          ad.description.toLowerCase().contains(searchQuery.toLowerCase())
        ).toList();
      }

      if (condition != null && condition != 'Все') {
        ads = ads.where((ad) => ad.condition == condition).toList();
      }

      if (minPrice != null) {
        ads = ads.where((ad) => ad.price >= minPrice).toList();
      }

      if (maxPrice != null) {
        ads = ads.where((ad) => ad.price <= maxPrice).toList();
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


  /// Get pending ads stream for admin review
  static Stream<List<AdModel>> getPendingAdsStream() {
    return _adsCollection
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AdModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .where((ad) => ad.status == 'pending')
            .toList());
  }

  /// Get ads for a specific user
  static Stream<List<AdModel>> getAdsByUserStream(String userId) {
    return _adsCollection
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AdModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .where((ad) => ad.userId == userId && ad.active)
            .toList());
  }

  /// Get current user ads
  static Stream<List<AdModel>> getMyAdsStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);
    return getAdsByUserStream(user.uid);
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
        await NotificationService.saveNotificationToFirestore(
          uid: userId,
          title: 'Цена снижена! 🔥',
          body: 'Товар "$title" теперь стоит $newPrice. Самое время забрать его!',
          type: 'price_drop',
          data: {'adId': adId},
        );
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
        if (ad.images.isNotEmpty) await FileService.deleteMultipleFiles(ad.images);
        if (ad.videoUrl != null && ad.videoUrl!.isNotEmpty) await FileService.deleteFile(ad.videoUrl!);
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
      await NotificationService.saveNotificationToFirestore(
        uid: ad.userId,
        title: 'Объявление одобрено! ✅',
        body: 'Ваше объявление "${ad.title}" прошло модерацию и теперь доступно всем пользователям.',
        type: 'ad_approved',
        data: {'adId': adId},
      );
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
      await NotificationService.saveNotificationToFirestore(
        uid: ad.userId,
        title: 'Объявление отклонено ❌',
        body: 'Ваше объявление "${ad.title}" было отклонено модератором. Причина: $reason',
        type: 'ad_rejected',
        data: {'adId': adId, 'reason': reason},
      );

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
        await NotificationService.saveNotificationToFirestore(
          uid: uid,
          title: 'Срок объявления истекает! ⏳',
          body: 'Ваше объявление "${ad.title}" скоро будет перенесено в архив. Продлите его, чтобы не потерять просмотры.',
          type: 'price_drop',
          data: {'adId': ad.id},
        );
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
        .where((ad) => ad.title.toLowerCase().contains(query.toLowerCase()) || 
                       ad.description.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  /// Get similar ads by category
  static Stream<List<AdModel>> getSimilarAdsStream(String category, String currentAdId) {
    return _adsCollection
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AdModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .where((ad) => ad.category == category && ad.active && ad.id != currentAdId)
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
      for (var doc in snapshot.docs) {
        await deleteAd(doc.id);
      }
      debugPrint('All ads for user $userId deleted ✅');
    } catch (e) {
      debugPrint('Error deleting user ads: $e');
    }
  }
}
