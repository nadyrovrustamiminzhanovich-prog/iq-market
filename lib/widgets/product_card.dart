import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

// Единый цвет цены для всех карточек
const _kPriceColor = Color(0xFF4A80F0);

class ProductCard extends StatefulWidget {
  final Map<String, dynamic> ad;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback onTap;
  final String lang;
  final double? width;

  const ProductCard({
    super.key,
    required this.ad,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onTap,
    required this.lang,
    this.width,
  });

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  final PageController _pageCtrl = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  String _formatAdDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final adDate = DateTime(date.year, date.month, date.day);
    final String time = DateFormat('HH:mm').format(date);

    if (adDate == today) {
      return widget.lang == 'Қазақша'
          ? 'Бүгін, $time'
          : widget.lang == 'Уйғурчә'
              ? 'Бүгүн, $time'
              : 'Сегодня, $time';
    } else if (adDate == yesterday) {
      return widget.lang == 'Қазақша'
          ? 'Кеше, $time'
          : widget.lang == 'Уйғурчә'
              ? 'Түнүгүн, $time'
              : 'Вчера, $time';
    } else {
      return DateFormat('dd.MM.yyyy, HH:mm').format(date);
    }
  }

  List<String> _getImageList() {
    final ad = widget.ad;
    final List<String> result = [];

    // Собираем все изображения: images[], image_url, image
    if (ad['images'] is List) {
      for (final img in ad['images'] as List) {
        if (img != null && img.toString().isNotEmpty) result.add(img.toString());
      }
    }
    final single = ad['image_url'] ?? ad['image'];
    if (single != null && single.toString().isNotEmpty && !result.contains(single.toString())) {
      result.add(single.toString());
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final ad = widget.ad;
    final DateTime? timestamp = ad['timestamp'] as DateTime?;
    final images = _getImageList();
    final hasVideo = ad['video_url'] != null;
    final hasMultiple = images.length > 1;

    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: widget.width,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Фото ─────────────────────────────────────────
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: SizedBox(
                    height: widget.width != null ? widget.width! * 0.8 : 140,
                    width: double.infinity,
                    child: images.isEmpty
                        ? _buildImageFile(ad)
                        : (hasMultiple
                            ? PageView.builder(
                                controller: _pageCtrl,
                                itemCount: images.length,
                                onPageChanged: (p) => setState(() => _currentPage = p),
                                itemBuilder: (_, i) => _buildNetworkImage(images[i]),
                              )
                            : _buildNetworkImage(images.first)),
                  ),
                ),

                // Кнопка избранного (в белом круге)
                Positioned(
                  top: 8, right: 8,
                  child: GestureDetector(
                    onTap: widget.onToggleFavorite,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_outline_rounded,
                        color: widget.isFavorite ? const Color(0xFFEF4444) : const Color(0xFF1E293B),
                        size: 18,
                      ),
                    ),
                  ),
                ),

                // Бейдж видео
                if (hasVideo)
                  Positioned(
                    top: 8, left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.play_circle_outline_rounded, color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            widget.lang == 'Русский' ? 'Видео' : 'Видео',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),

            // ── Контент ───────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (ad['title'] ?? '').toString(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        height: 1.2,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const Spacer(),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        (ad['price'] ?? '').toString(),
                        style: GoogleFonts.inter(
                          color: const Color(0xFF4A80F0),
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded, size: 10, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            (ad['location'] ?? '').toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: const Color(0xFF64748B),
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (timestamp != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        _formatAdDate(timestamp),
                        style: GoogleFonts.inter(
                          color: const Color(0xFF94A3B8),
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkImage(String url) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      width: double.infinity,
      placeholder: (_, __) => Shimmer.fromColors(
        baseColor: Colors.grey[200]!,
        highlightColor: Colors.grey[100]!,
        child: Container(color: Colors.white, height: 140),
      ),
      errorWidget: (_, __, ___) => _noImage(),
    );
  }

  Widget _buildImageFile(Map<String, dynamic> ad) {
    if (ad['image_file'] != null) {
      return Image.file(
        ad['image_file'] as File,
        fit: BoxFit.cover,
        width: double.infinity,
      );
    }
    return _noImage();
  }

  Widget _noImage() => Container(
    width: double.infinity,
    color: const Color(0xFFF1F5F9),
    child: Center(
      child: Icon(Icons.image_not_supported_outlined, size: 32, color: Colors.grey[300]),
    ),
  );
}
