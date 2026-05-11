import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

class FileService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload a file to Firebase Storage and return the Task for cancellation support
  static UploadTask uploadFileWithTask(File file, String folder) {
    final String extension = p.extension(file.path).toLowerCase();
    final String fileName = '${DateTime.now().millisecondsSinceEpoch}$extension';
    final Reference ref = _storage.ref().child(folder).child(fileName);
    return ref.putFile(file);
  }

  /// Upload a file and get URL (Legacy/Simple version)
  static Future<String?> uploadFile(File file, String folder) async {
    try {
      final task = uploadFileWithTask(file, folder);
      final snapshot = await task;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading file: $e');
      return null;
    }
  }

  /// Upload a file for chat
  static Future<String?> uploadChatFile(File file) async {
    return uploadFile(file, 'chats');
  }

  /// Image compression logic
  static Future<File?> compressImage(File file) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final String targetPath = p.join(tempDir.path, '${DateTime.now().millisecondsSinceEpoch}_compressed.jpg');

      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 70, // Оптимально для мобильных приложений
        format: CompressFormat.jpeg,
      );

      return result != null ? File(result.path) : null;
    } catch (e) {
      debugPrint('Error compressing image: $e');
      return null;
    }
  }

  /// Delete a file from Firebase Storage
  static Future<void> deleteFile(String url) async {
    try {
      final Reference ref = _storage.refFromURL(url);
      await ref.delete();
    } catch (e) {
      debugPrint('Error deleting file: $e');
    }
  }

  /// Bulk delete files
  static Future<void> deleteMultipleFiles(List<String> urls) async {
    for (final url in urls) {
      await deleteFile(url);
    }
  }

  /// Upload multiple files and return URLs
  static Future<List<String>> uploadMultipleFiles(List<File> files, String folder) async {
    List<String> urls = [];
    for (var file in files) {
      final url = await uploadFile(file, folder);
      if (url != null) urls.add(url);
    }
    return urls;
  }
}
