import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:iqmarket/providers/app_config_provider.dart';
import 'package:iqmarket/services/translation_service.dart';
import 'package:iqmarket/widgets/post_ad/post_ad_image_item.dart';

class ImagePickerSection extends StatelessWidget {
  final List<File> imageFiles;
  final List<String> existingImageUrls;
  final File? videoFile;
  final VoidCallback onPickImages;
  final VoidCallback onPickVideo;
  final Function(int index) onRemoveImage;
  final Function(int index)? onRemoveExistingImage;
  final VoidCallback onRemoveVideo;

  const ImagePickerSection({
    super.key,
    required this.imageFiles,
    this.existingImageUrls = const [],
    this.videoFile,
    required this.onPickImages,
    required this.onPickVideo,
    required this.onRemoveImage,
    this.onRemoveExistingImage,
    required this.onRemoveVideo,
  });

  @override
  Widget build(BuildContext context) {
    final config = Provider.of<AppConfigProvider>(context);
    final lang = config.language;
    final bool hasMedia = imageFiles.isNotEmpty || existingImageUrls.isNotEmpty || videoFile != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildPhotoCard(lang)),
            const SizedBox(width: 12),
            Expanded(child: _buildVideoCard(lang)),
          ],
        ),
        if (hasMedia) ...[
          const SizedBox(height: 20),
          SizedBox(
            height: 110,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: [
                if (videoFile != null)
                  _videoPreview(),
                // Existing Network Images
                ...existingImageUrls.asMap().entries.map<Widget>((entry) => Container(
                  width: 100,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    image: DecorationImage(image: CachedNetworkImageProvider(entry.value), fit: BoxFit.cover),
                  ),
                  child: Stack(
                    children: [
                      if (entry.key == 0)
                        Positioned(
                          bottom: 0, left: 0, right: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                            ),
                            child: Text(
                              TranslationService.t('cover_label', lang),
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      Positioned(
                        top: 4, right: 4,
                        child: GestureDetector(
                          onTap: () {
                            if (onRemoveExistingImage != null) {
                              onRemoveExistingImage!(entry.key);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            child: const Icon(Icons.close, size: 14, color: Colors.red),
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
                // New Local Image Files
                ...imageFiles.asMap().entries.map<Widget>((entry) => PostAdImageItem(
                  file: entry.value,
                  isFirst: existingImageUrls.isEmpty && entry.key == 0,
                  onRemove: () => onRemoveImage(entry.key),
                )),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F5FF),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(Icons.info, size: 18, color: Color(0xFF1A73E8)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  TranslationService.t('media_hint', lang),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF1E3A8A),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _videoPreview() {
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
      ),
      child: Stack(
        children: [
          const Center(child: Icon(Icons.videocam_rounded, color: Color(0xFF6366F1))),
          Positioned(
            top: 4, right: 4,
            child: GestureDetector(
              onTap: onRemoveVideo,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: const Icon(Icons.close, size: 14, color: Colors.red),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoCard(String lang) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEBF3FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD6E4FF), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onPickImages,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD2E3FC),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.image_rounded, color: Color(0xFF1A73E8), size: 24),
                  ),
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Color(0xFF1A73E8),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add, color: Colors.white, size: 10),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                TranslationService.t('photo_title', lang),
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                TranslationService.t('photo_desc', lang),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: const Color(0xFF64748B),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoCard(String lang) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF3EFFF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEDE9FE), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onPickVideo,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8E0FF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.videocam_rounded, color: Color(0xFF7C3AED), size: 24),
                  ),
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Color(0xFF7C3AED),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add, color: Colors.white, size: 10),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                TranslationService.t('video_title', lang),
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                TranslationService.t('video_desc', lang),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: const Color(0xFF64748B),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
