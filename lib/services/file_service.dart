import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:iqmarket/services/analytics_service.dart';

class FileService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  
  /// Test hook to override file upload behavior in widget/unit tests
  static UploadTask Function(File file, String folder, {String? customFileName})? uploadFileWithTaskOverride;

  // 🔒 X10: Max file size before aggressive recompression (5 MB)
  static const int _maxFileSizeBytes = 5 * 1024 * 1024;

  /// Upload a file to Firebase Storage and return the Task for cancellation support
  static UploadTask uploadFileWithTask(File file, String folder, {String? customFileName}) {
    if (uploadFileWithTaskOverride != null) {
      return uploadFileWithTaskOverride!(file, folder, customFileName: customFileName);
    }
    final String extension = p.extension(file.path).toLowerCase();
    final String fileName = customFileName ?? '${DateTime.now().millisecondsSinceEpoch}$extension';
    final Reference ref = _storage.ref().child(folder).child(fileName);
    
    // 🔒 Set content-type metadata to prevent "application/octet-stream" playback failures
    String? contentType;
    if (extension == '.m4a') {
      contentType = 'audio/mp4';
    } else if (extension == '.mp4') {
      contentType = 'video/mp4';
    } else if (extension == '.mp3') {
      contentType = 'audio/mpeg';
    } else if (extension == '.wav') {
      contentType = 'audio/wav';
    } else if (extension == '.jpg' || extension == '.jpeg') {
      contentType = 'image/jpeg';
    } else if (extension == '.png') {
      contentType = 'image/png';
    } else if (extension == '.gif') {
      contentType = 'image/gif';
    }

    final metadata = contentType != null ? SettableMetadata(contentType: contentType) : null;
    return ref.putFile(file, metadata);
  }

  /// Upload a file and get URL — with retry logic (3 attempts, exponential backoff)
  /// Works reliably on 3G/4G and weak Wi-Fi connections.
  static Future<String?> uploadFile(
    File file,
    String folder, {
    int maxRetries = 3,
    void Function(double progress, int attempt)? onProgress,
  }) async {
    // 🔒 X10: If file is oversized, try aggressive recompression before upload.
    // Only for images — FlutterImageCompress can't process video files, so
    // running it on an oversized video just fails silently and wastes time.
    File fileToUpload = file;
    final fileSize = await file.length();
    const imageExtensions = {'.jpg', '.jpeg', '.png', '.gif', '.webp'};
    final isImage = imageExtensions.contains(p.extension(file.path).toLowerCase());
    if (fileSize > _maxFileSizeBytes && isImage) {
      debugPrint('FileService: File too large (${fileSize ~/ 1024}KB), applying emergency compression...');
      final emergency = await compressImageAggressive(file);
      if (emergency != null) fileToUpload = emergency;
    }

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint('FileService: Uploading ${p.basename(fileToUpload.path)} (attempt $attempt/$maxRetries)...');
        final task = uploadFileWithTask(fileToUpload, folder);

        // Track upload progress per attempt
        task.snapshotEvents.listen((snapshot) {
          if (snapshot.totalBytes > 0 && onProgress != null) {
            final progress = snapshot.bytesTransferred / snapshot.totalBytes;
            onProgress(progress, attempt);
          }
        });

        final snapshot = await task.timeout(
          const Duration(seconds: 90),
          onTimeout: () => throw Exception('Upload timeout after 90s'),
        );
        final url = await snapshot.ref.getDownloadURL();
        debugPrint('FileService: Upload success (attempt $attempt): $url');
        return url;
      } catch (e, stack) {
        debugPrint('FileService: Upload attempt $attempt failed: $e');
        AnalyticsService.logStoragePermissionError(e, stack, folder);
        if (attempt < maxRetries) {
          // Exponential backoff: 2s, 4s, 8s
          final delay = Duration(seconds: 2 * attempt);
          debugPrint('FileService: Retrying in ${delay.inSeconds}s...');
          await Future.delayed(delay);
        }
      }
    }
    debugPrint('FileService: All $maxRetries upload attempts failed.');
    return null;
  }

  /// Upload a file for chat
  static Future<String?> uploadChatFile(File file) async {
    return uploadFile(file, 'chats');
  }

  /// Image compression — standard quality (~100-200 KB)
  static Future<File?> compressImage(File file) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final String targetPath = p.join(tempDir.path, '${DateTime.now().millisecondsSinceEpoch}_compressed.jpg');

      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        minWidth: 1024,
        minHeight: 1024,
        quality: 45,
        format: CompressFormat.jpeg,
      );

      return result != null ? File(result.path) : null;
    } catch (e) {
      debugPrint('FileService: Error compressing image: $e');
      return null;
    }
  }

  /// Emergency aggressive compression for oversized files (quality 20, 512px)
  static Future<File?> compressImageAggressive(File file) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final String targetPath = p.join(tempDir.path, '${DateTime.now().millisecondsSinceEpoch}_emergency.jpg');

      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        minWidth: 512,
        minHeight: 512,
        quality: 20,
        format: CompressFormat.jpeg,
      );

      return result != null ? File(result.path) : null;
    } catch (e) {
      debugPrint('FileService: Error in aggressive compression: $e');
      return null;
    }
  }

  /// Delete a file from Firebase Storage
  static Future<void> deleteFile(String url) async {
    try {
      final Reference ref = _storage.refFromURL(url);
      await ref.delete();
    } catch (e) {
      debugPrint('FileService: Error deleting file: $e');
    }
  }

  /// Bulk delete files
  static Future<void> deleteMultipleFiles(List<String> urls) async {
    for (final url in urls) {
      await deleteFile(url);
    }
  }

  // Test hook to override upload results
  static Future<List<String>> Function(List<File> files, String folder)? mockUploadMultipleFiles;

  /// Upload multiple files and return URLs
  static Future<List<String>> uploadMultipleFiles(List<File> files, String folder) async {
    if (mockUploadMultipleFiles != null) {
      return mockUploadMultipleFiles!(files, folder);
    }
    List<String> urls = [];
    for (var file in files) {
      final url = await uploadFile(file, folder);
      if (url != null) urls.add(url);
    }
    return urls;
  }
}
