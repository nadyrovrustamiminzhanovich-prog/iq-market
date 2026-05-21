import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_compress/video_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ad_model.dart';
import '../services/ad_service.dart';
import '../services/file_service.dart';
import '../services/gemini_service.dart';

class PostAdProvider extends ChangeNotifier {
  bool _isLoading = false;
  String _uploadStatus = '';
  
  bool get isLoading => _isLoading;
  String get uploadStatus => _uploadStatus;

  Future<bool> publishAd({
    required BuildContext context,
    required String title,
    required String description,
    required String price,
    required String category,
    required List<File> imageFiles,
    required File? videoFile,
    required String location,
    required String condition,
    required bool bargainAvailable,
    required bool canExchange,
    required bool hasDelivery,
    required Map<String, dynamic> extraFields,
    required String lang,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showError(context, 'Пожалуйста, войдите в систему');
      return false;
    }

    final List<ConnectivityResult> connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      _showError(context, 'Нет подключения к интернету. Проверьте сеть и повторите.');
      return false;
    }

    _setLoading(true, 'Проверка модерации ИИ...');

    try {
      // 0. AI Moderation Check
      final gemini = GeminiService();
      gemini.init(lang);
      final moderationResult = await gemini.checkContent(title, description, imageFiles);

      if (moderationResult.startsWith('REJECTED')) {
        final reason = moderationResult.replaceFirst('REJECTED:', '').trim();
        _setLoading(false, '');
        _showModerationError(context, reason);
        return false;
      }

      // 1. Image Upload
      List<String> imageUrls = [];
      final tempDir = await getTemporaryDirectory();

      for (int i = 0; i < imageFiles.length; i++) {
        _setLoading(true, 'Сжатие и загрузка фото ${i + 1} из ${imageFiles.length}...');
        final file = imageFiles[i];
        final targetPath = p.join(tempDir.path, '${DateTime.now().millisecondsSinceEpoch}_$i.jpg');
        
        final compressedFile = await FlutterImageCompress.compressAndGetFile(
          file.absolute.path, 
          targetPath,
          quality: 70,
          minWidth: 1080,
          minHeight: 1080,
        );

        final uploadFuture = FileService.uploadFile(File(compressedFile?.path ?? file.path), 'ads/images');
        final url = await uploadFuture.timeout(const Duration(seconds: 15), onTimeout: () => throw TimeoutException('Слишком медленный интернет для фото'));
        if (url != null) imageUrls.add(url);
      }

      // 2. Video Upload
      String? videoUrl;
      if (videoFile != null) {
        _setLoading(true, 'Сжатие и загрузка видео...');
        
        final MediaInfo? mediaInfo = await VideoCompress.compressVideo(
          videoFile.path,
          quality: VideoQuality.MediumQuality,
          deleteOrigin: false,
          includeAudio: true,
        );
        
        final fileToUpload = (mediaInfo != null && mediaInfo.path != null) ? File(mediaInfo.path!) : videoFile;
        final uploadVideoFuture = FileService.uploadFile(fileToUpload, 'ads/videos');
        videoUrl = await uploadVideoFuture.timeout(const Duration(seconds: 60), onTimeout: () => throw TimeoutException('Слишком медленный интернет для видео'));
      }

      _setLoading(true, 'Создание объявления...');

      // 3. Create Model
      final ad = AdModel(
        id: '', 
        title: title,
        description: description,
        price: category == 'Отдам даром' ? 0.0 : (double.tryParse(price.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0),
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
        isBargainAllowed: bargainAvailable,
        canExchange: canExchange,
        hasDelivery: hasDelivery,
        active: true,
        status: 'active',
        extraFields: extraFields,
        expiresAt: DateTime.now().add(const Duration(days: 30)),
        notifiedExpiry: false,
      );

      // 4. Save to Firestore
      await AdService.createAd(ad);
      
      // Clear draft
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('ad_draft');

      _setLoading(false, '');
      return true;

    } on TimeoutException catch (e) {
      _setLoading(false, '');
      _showTimeoutError(context, e.message ?? 'Ошибка таймаута');
      return false;
    } catch (e) {
      _setLoading(false, '');
      _showError(context, 'Ошибка при публикации: $e');
      return false;
    }
  }

  void _setLoading(bool value, String status) {
    _isLoading = value;
    _uploadStatus = status;
    notifyListeners();
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  void _showModerationError(BuildContext context, String reason) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [Icon(Icons.shield_outlined, color: Colors.red), SizedBox(width: 10), Text('Ошибка модерации')]),
        content: Text('Ваше объявление отклонено автоматической системой.\n\nПричина: $reason'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Понятно'))],
      ),
    );
  }

  void _showTimeoutError(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [Icon(Icons.wifi_off, color: Colors.orange), SizedBox(width: 10), Text('Проблема с сетью')]),
        content: Text('$message\nПопробуйте переключиться между Wi-Fi и мобильным интернетом.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Понятно'))]
      )
    );
  }
}
