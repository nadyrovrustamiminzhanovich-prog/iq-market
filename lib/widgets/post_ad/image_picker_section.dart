import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iqmarket/widgets/post_ad/post_ad_image_item.dart';

class ImagePickerSection extends StatelessWidget {
  final List<File> imageFiles;
  final File? videoFile;
  final VoidCallback onPickImages;
  final VoidCallback onPickVideo;
  final Function(int index) onRemoveImage;
  final VoidCallback onRemoveVideo;

  const ImagePickerSection({
    super.key,
    required this.imageFiles,
    this.videoFile,
    required this.onPickImages,
    required this.onPickVideo,
    required this.onRemoveImage,
    required this.onRemoveVideo,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _mediaBtn(Icons.add_photo_alternate_rounded, 'ФОТО', onPickImages, color: const Color(0xFF4A80F0))),
            const SizedBox(width: 12),
            Expanded(child: _mediaBtn(Icons.videocam_rounded, 'ВИДЕО', onPickVideo, color: const Color(0xFF6366F1))),
          ],
        ),
        if (imageFiles.isNotEmpty || videoFile != null) ...[
          const SizedBox(height: 20),
          SizedBox(
            height: 110,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: [
                if (videoFile != null)
                  _videoPreview(),
                ...imageFiles.asMap().entries.map<Widget>((entry) => PostAdImageItem(
                  file: entry.value,
                  isFirst: entry.key == 0,
                  onRemove: () => onRemoveImage(entry.key),
                )),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFF4A80F0).withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF4A80F0)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Видео: до 20 секунд. Первое фото будет на обложке.',
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF4A80F0), fontWeight: FontWeight.w600),
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
        color: const Color(0xFF6366F1).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
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

  Widget _mediaBtn(IconData icon, String label, VoidCallback onTap, {Color? color}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: (color ?? const Color(0xFF64748B)).withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: (color ?? const Color(0xFF64748B)).withOpacity(0.2), width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color ?? const Color(0xFF64748B), size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: color ?? const Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }
}
