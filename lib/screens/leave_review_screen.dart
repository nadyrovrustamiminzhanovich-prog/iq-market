import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MaxLengthEnforcement;
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:iqmarket/models/ad_model.dart';
import 'package:iqmarket/models/review_model.dart';
import 'package:iqmarket/providers/app_config_provider.dart';
import 'package:iqmarket/services/review_service.dart';
import 'package:iqmarket/services/file_service.dart';
import 'package:iqmarket/services/translation_service.dart';
import 'package:iqmarket/widgets/secure_image_viewer.dart';

class LeaveReviewScreen extends StatefulWidget {
  final AdModel ad;
  static dynamic mockUser;
  const LeaveReviewScreen({super.key, required this.ad});

  @override
  State<LeaveReviewScreen> createState() => _LeaveReviewScreenState();
}

class _LeaveReviewScreenState extends State<LeaveReviewScreen> {
  double _rating = 5.0;
  final TextEditingController _commentCtrl = TextEditingController();
  final List<File> _images = [];
  bool _isUploading = false;

  // Upload progress: value from 0.0 to 1.0, null = not uploading
  double? _uploadProgress;

  static const int _maxImages = 5;
  static const int _maxCommentLength = 300;

  // ─── Pick images (multi-select) ───────────────────────────────────────────
  Future<void> _pickImages() async {
    final lang = Provider.of<AppConfigProvider>(context, listen: false).language;

    final remaining = _maxImages - _images.length;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(TranslationService.t('err_max_photos', lang)
              .replaceAll('{max}', '$_maxImages')),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // limit не даёт отметить в галерее больше, чем осталось свободных слотов —
      // как в размещении объявления. Раньше лимита здесь не было вовсе: юзер мог
      // выбрать хоть 20 фото, а лишние молча отрезались уже после возврата.
      //
      // limit допустим только >= 2: pickMultiImage валидирует его и на значении
      // 1 бросает ArgumentError. Поэтому на последнем свободном слоте берём
      // одиночный pickImage — галерея откроется в режиме выбора одного фото.
      final List<XFile> picked;
      if (remaining == 1) {
        final XFile? single = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
        );
        picked = single == null ? <XFile>[] : <XFile>[single];
      } else {
        picked = await ImagePicker().pickMultiImage(
          imageQuality: 85,
          limit: remaining,
        );
      }
      if (picked.isEmpty || !mounted) return;

      final limited = picked.take(remaining).toList();
      setState(() {
        for (final xFile in limited) {
          _images.add(File(xFile.path));
        }
      });

      if (picked.length > remaining) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(TranslationService.t('err_max_photos', lang)
                  .replaceAll('{max}', '$_maxImages')),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              TranslationService.t('errChoosePhoto', lang)
                  .replaceAll('{error}', e.toString()),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // ─── Remove a selected image before upload ────────────────────────────────
  void _removeImage(int index) {
    setState(() => _images.removeAt(index));
  }

  // ─── Submit review ────────────────────────────────────────────────────────
  Future<void> _submit(String lang) async {
    if (_isUploading) return;

    if (_commentCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(TranslationService.t('err_enter_comment', lang))),
      );
      return;
    }

    // Подстраховка сверх maxLength у TextField — тот блокирует ручной ввод
    // и вставку, но не защищает от текста, попавшего в контроллер в обход
    // (программно/будущий рефакторинг). Firestore rules — последний рубеж.
    if (_commentCtrl.text.trim().length > _maxCommentLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(TranslationService.t('err_comment_too_long', lang))),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = _images.isEmpty ? null : 0.0;
    });

    try {
      final user = LeaveReviewScreen.mockUser ?? FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(TranslationService.t('err_login_to_review', lang))),
          );
        }
        return;
      }

      // Дубликат-проверка
      final hasReviewed = await ReviewService.hasUserReviewedAd(user.uid, widget.ad.id);
      if (hasReviewed) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(TranslationService.t('err_already_reviewed', lang))),
          );
        }
        return;
      }

      // Загрузка фото с прогрессом и сжатием
      List<String> imageUrls = [];
      if (_images.isNotEmpty) {
        imageUrls = await _uploadImagesWithProgress(_images, user.uid);
      }

      if (!mounted) return;

      // Частичная ошибка загрузки
      if (imageUrls.length != _images.length) {
        final bool? proceed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogCtx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(TranslationService.t('photo_upload_partial_failed_title', lang)),
            content: Text(TranslationService.t('photo_upload_partial_failed_msg', lang)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: Text(TranslationService.t('cancel', lang)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogCtx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A80F0),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(TranslationService.t('publish_without_photos', lang)),
              ),
            ],
          ),
        );

        if (proceed != true) {
          if (mounted) {
            setState(() {
              _isUploading = false;
              _uploadProgress = null;
            });
          }
          return;
        }
      }

      final review = ReviewModel(
        id: '',
        adId: widget.ad.id,
        adTitle: widget.ad.title,
        fromUserId: user.uid,
        fromUserName: user.displayName ?? 'Пользователь',
        toUserId: widget.ad.userId,
        rating: _rating,
        comment: _commentCtrl.text.trim(),
        images: imageUrls,
        timestamp: DateTime.now(),
      );

      await ReviewService.addReview(review);

      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger.showSnackBar(
          SnackBar(content: Text(TranslationService.t('review_published_success', lang))),
        );
      }
    } catch (e) {
      debugPrint('Error publishing review: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              TranslationService.t('errPublish', lang).replaceAll('{error}', e.toString()),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = null;
        });
      }
    }
  }

  /// Загружает фото последовательно, обновляя прогресс
  Future<List<String>> _uploadImagesWithProgress(List<File> images, String uid) async {
    final List<String> urls = [];

    for (int i = 0; i < images.length; i++) {
      // Сжатие перед отправкой. Фото отзыва пользователь разглядывает так же,
      // как фото объявления, поэтому и качество то же (galleryPhotoQuality).
      // По умолчанию compressImage жмёт заметно сильнее — 45/1024, это нормально
      // для чата и аватарки, но на фото отзыва давало видимые JPEG-артефакты.
      File fileToUpload = images[i];
      final compressed = await FileService.compressImage(
        images[i],
        quality: FileService.galleryPhotoQuality,
        minWidth: FileService.galleryPhotoMinSize,
        minHeight: FileService.galleryPhotoMinSize,
      );
      if (compressed != null) fileToUpload = compressed;

      final url = await FileService.uploadFile(
        fileToUpload,
        'reviews/$uid',
        onProgress: (progress, attempt) {
          if (mounted) {
            setState(() {
              // Общий прогресс = (завершённые + текущий) / всего
              _uploadProgress = (i + progress) / images.length;
            });
          }
        },
      );
      if (url != null) urls.add(url);
    }

    return urls;
  }

  /// Показывает выбранное локальное фото на весь экран с возможностью масштабирования
  void _showFullScreenImage(File file) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SecureImageViewerScreen(
          file: file,
          heroTag: 'review_file_${file.path}',
        ),
      ),
    );
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = Provider.of<AppConfigProvider>(context);
    final lang = config.language;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          TranslationService.t('leave_review', lang),
          style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.ad.title,
              style: GoogleFonts.inter(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 24),

            // ─── Звёзды ─────────────────────────────────────────────────────
            Center(
              child: Column(
                children: [
                  Text(
                    TranslationService.t('your_rating', lang),
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      5,
                      (index) => IconButton(
                        onPressed: () => setState(() => _rating = index + 1.0),
                        icon: Icon(
                          index < _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: Colors.amber,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            Text(
              TranslationService.t('your_comment', lang),
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _commentCtrl,
              maxLines: 5,
              maxLength: _maxCommentLength,
              // По умолчанию enforcement платформозависим (на некоторых iOS-сборках
              // не блокирует ввод/вставку сверх лимита, только подсвечивает
              // счётчик) — задаём явно, чтобы 300 символов было жёстким пределом
              // везде одинаково.
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              decoration: InputDecoration(
                hintText: TranslationService.t('comment_placeholder', lang),
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),

            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    TranslationService.t('photos_optional', lang),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                if (_images.isNotEmpty)
                  Text(
                    '${_images.length}/$_maxImages',
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // ─── Фото-список с крестиками ────────────────────────────────────
            SizedBox(
              height: 120,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  // Кнопка добавить фото
                  if (_images.length < _maxImages)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: GestureDetector(
                        onTap: _isUploading ? null : _pickImages,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFF4A80F0).withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.add_a_photo_rounded, color: Color(0xFF4A80F0), size: 28),
                              const SizedBox(height: 4),
                              Text(
                                'Добавить',
                                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF4A80F0)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Выбранные фото с крестиком удаления
                  ..._images.asMap().entries.map((entry) {
                    final index = entry.key;
                    final file = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: SizedBox(
                        width: 112,
                        height: 112,
                        child: Stack(
                          children: [
                            // Превью фото с просмотром на весь экран
                            Positioned(
                              left: 0,
                              bottom: 0,
                              child: GestureDetector(
                                onTap: () => _showFullScreenImage(file),
                                child: Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    image: DecorationImage(
                                      image: FileImage(file),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // ✕ Кнопка удаления — сверху-справа (в границах SizedBox, что гарантирует hit-test)
                            if (!_isUploading)
                              Positioned(
                                top: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: () => _removeImage(index),
                                  behavior: HitTestBehavior.opaque,
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.2),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(Icons.close, color: Colors.white, size: 14),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),

            // ─── Прогресс-бар загрузки ───────────────────────────────────────
            if (_isUploading && _uploadProgress != null) ...[
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        TranslationService.t('uploading_photo', lang),
                        style: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
                      ),
                      Text(
                        '${(_uploadProgress! * 100).toInt()}%',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: const Color(0xFF4A80F0),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _uploadProgress,
                      backgroundColor: const Color(0xFFF1F5F9),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4A80F0)),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 48),

            // ─── Кнопка публикации ───────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isUploading ? null : () => _submit(lang),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A80F0),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFF4A80F0).withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isUploading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : Text(
                        TranslationService.t('publish_review_btn', lang),
                        style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
