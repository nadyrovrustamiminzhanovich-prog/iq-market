import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:iqmarket/models/ad_model.dart';
import 'package:iqmarket/models/review_model.dart';
import 'package:iqmarket/services/review_service.dart';
import 'package:iqmarket/services/file_service.dart';

class LeaveReviewScreen extends StatefulWidget {
  final AdModel ad;
  const LeaveReviewScreen({super.key, required this.ad});

  @override
  State<LeaveReviewScreen> createState() => _LeaveReviewScreenState();
}

class _LeaveReviewScreenState extends State<LeaveReviewScreen> {
  double _rating = 5.0;
  final TextEditingController _commentCtrl = TextEditingController();
  final List<File> _images = [];
  bool _isUploading = false;

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked != null) {
      setState(() => _images.add(File(picked.path)));
    }
  }

  Future<void> _submit() async {
    if (_commentCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Напишите текст отзыва')));
      return;
    }

    setState(() => _isUploading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Войдите в аккаунт, чтобы оставить отзыв')));
        }
        return;
      }

      // Проверка на дубликат отзыва
      final hasReviewed = await ReviewService.hasUserReviewedAd(user.uid, widget.ad.id);
      if (hasReviewed) {
        if (mounted) {
          setState(() => _isUploading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Вы уже оставляли отзыв на это объявление'))
          );
        }
        return;
      }


      // Upload images if any
      List<String> imageUrls = [];
      if (_images.isNotEmpty) {
        imageUrls = await FileService.uploadMultipleFiles(_images, 'reviews');
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
        messenger.showSnackBar(const SnackBar(content: Text('Спасибо! Отзыв опубликован.')));
      }
    } catch (e) {
      debugPrint('Error publishing review: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка при публикации: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Оставить отзыв', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18)),
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
            Text(widget.ad.title, style: GoogleFonts.inter(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500)),
            const SizedBox(height: 24),
            
            // Звезды
            Center(
              child: Column(
                children: [
                  Text('Ваша оценка', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) => IconButton(
                      onPressed: () => setState(() => _rating = index + 1.0),
                      icon: Icon(
                        index < _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: Colors.amber,
                        size: 40,
                      ),
                    )),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            Text('Ваш комментарий', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextField(
              controller: _commentCtrl,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Поделитесь впечатлениями о сделке...',
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            
            const SizedBox(height: 24),
            Text('Фотографии (необязательно)', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            SizedBox(
              height: 100,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(16)),
                      child: const Icon(Icons.add_a_photo_rounded, color: Color(0xFF94A3B8)),
                    ),
                  ),
                  ..._images.map((file) => Container(
                    width: 100,
                    height: 100,
                    margin: const EdgeInsets.only(left: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      image: DecorationImage(image: FileImage(file), fit: BoxFit.cover),
                    ),
                  )),
                ],
              ),
            ),
            
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isUploading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A80F0),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isUploading 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text('Опубликовать отзыв', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
