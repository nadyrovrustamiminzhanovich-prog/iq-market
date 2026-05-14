import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iqmarket/models/ad_model.dart';
import 'dart:io';

class ProductCard extends StatefulWidget {
  final AdModel ad;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;
  final bool isFavorite;
  final double? width;
  final String? heroPrefix;

  const ProductCard({
    super.key,
    required this.ad,
    required this.onTap,
    required this.onToggleFavorite,
    required this.isFavorite,
    this.width,
    this.heroPrefix,
  });

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> with SingleTickerProviderStateMixin {
  late PageController _pageCtrl;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = widget.ad;
    final images = ad.images;
    final hasMultiple = images.length > 1;
    final isFree = ad.price == 0.0 || ad.category == 'Отдам даром';

    return Container(
      width: widget.width,
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Фото Блок (Свайп работает здесь) ──
          Expanded(
            flex: 62,
            child: Stack(
              fit: StackFit.expand,
              children: [
                GestureDetector(
                  onTap: widget.onTap,
                  behavior: HitTestBehavior.opaque,
                  child: images.isEmpty
                      ? (ad.videoUrl != null && ad.videoUrl!.startsWith('http')
                          // Video-only ad: show black background with play icon
                          ? Stack(
                              fit: StackFit.expand,
                              children: [
                                Container(color: const Color(0xFF0F172A)),
                                Center(
                                  child: Container(
                                    width: 50, height: 50,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
                                    ),
                                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30),
                                  ),
                                ),
                                Positioned(
                                  bottom: 10, left: 10,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF4A80F0),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.videocam_rounded, color: Colors.white, size: 12),
                                        SizedBox(width: 4),
                                        Text('ВИДЕО', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : _noImage())
                      : (hasMultiple
                          ? PageView.builder(
                              controller: _pageCtrl,
                              itemCount: images.length,
                              physics: const BouncingScrollPhysics(),
                              onPageChanged: (p) => setState(() => _currentPage = p),
                              itemBuilder: (_, i) {
                                final img = _buildImage(images[i]);
                                if (i == 0) {
                                  return Hero(
                                    tag: '${widget.heroPrefix ?? ''}ad-image-${ad.id}',
                                    child: img,
                                  );
                                }
                                return img;
                              },
                            )
                          : Hero(
                              tag: '${widget.heroPrefix ?? ''}ad-image-${ad.id}',
                              child: _buildImage(images.first),
                            )),
                ),

                // Градиент сверху для значков
                Positioned(
                  top: 0, left: 0, right: 0,
                  height: 60,
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.black.withValues(alpha: 0.2), Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                ),

                // Бейдж "Новый"
                if (DateTime.now().difference(ad.timestamp).inDays < 3)
                  Positioned(
                    top: 10, left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4A80F0),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('НОВОЕ', style: GoogleFonts.inter(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)),
                    ),
                  ),

                // Индикаторы страниц (точки)
                if (hasMultiple)
                  Positioned(
                    bottom: 10, left: 10,
                    child: Row(
                      children: List.generate(images.length, (index) => Container(
                        width: 5, height: 5,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _currentPage == index ? Colors.white : Colors.white.withValues(alpha: 0.4),
                        ),
                      )),
                    ),
                  ),

                // Кнопка избранного (Сердечко) - ВЕРХНИЙ ПРАВЫЙ УГОЛ
                Positioned(
                  top: 8, right: 8,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      widget.onToggleFavorite();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)],
                      ),
                      child: Icon(
                        widget.isFavorite ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                        color: widget.isFavorite ? const Color(0xFFEF4444) : const Color(0xFF0F172A),
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Инфо Блок ──────────────────
          GestureDetector(
            onTap: widget.onTap,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(color: Colors.white),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isFree ? 'Бесплатно' : _formatPrice(ad.price),
                    style: GoogleFonts.inter(
                      fontSize: 17, 
                      fontWeight: FontWeight.w900, 
                      color: isFree ? const Color(0xFF10B981) : const Color(0xFF4A80F0),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ad.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B), height: 1.2),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _metaInfo(ad.location.isEmpty || ad.location == 'Шонжы' ? 'Чунджа' : ad.location, Icons.location_on_rounded, color: const Color(0xFF4A80F0))),
                      const SizedBox(width: 4),
                      Expanded(child: _metaInfo(_formatRelativeDate(ad.timestamp), Icons.access_time_filled_rounded)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, curve: Curves.easeOut).slideY(begin: 0.05, end: 0, duration: 400.ms, curve: Curves.easeOut);
  }

  Widget _metaInfo(String text, IconData icon, {Color? color}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(
      color: (color ?? const Color(0xFF64748B)).withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 8, color: color ?? const Color(0xFF94A3B8)),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontSize: 9, color: color?.withValues(alpha: 0.8) ?? const Color(0xFF64748B), fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );

  String _formatPrice(double price) {
    return price > 0 ? '${NumberFormat.decimalPattern('ru').format(price.toInt())} ₸' : 'Договорная';
  }

  String _formatRelativeDate(DateTime dt) {
    final now = DateTime.now();
    if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
      return 'Сегодня ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (dt.day == yesterday.day && dt.month == yesterday.month && dt.year == yesterday.year) {
      return 'Вчера ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day} ${['','янв','фев','мар','апр','мая','июн','июл','авг','сен','окт','ноя','дек'][dt.month]}';
  }

  Widget _buildImage(String url) {
    if (url.isEmpty) return _noImage();
    if (url.startsWith('/') || url.startsWith('file')) {
      return Image.file(File(url), fit: BoxFit.cover);
    }
    if (!url.startsWith('http')) return _noImage();
    return CachedNetworkImage(
      imageUrl: url, 
      fit: BoxFit.cover, 
      memCacheWidth: 400, // Оптимизация памяти (не грузим оригинал в RAM)
      maxWidthDiskCache: 800, // Оптимизация диска
      placeholder: (context, url) => Container(color: const Color(0xFFF1F5F9)), 
      errorWidget: (context, url, error) => _noImage(),
    );
  }

  Widget _noImage() => Container(color: const Color(0xFFF8FAFC), child: const Center(child: Icon(Icons.image_outlined, color: Colors.grey, size: 24)));
}

class ProductCardSkeleton extends StatelessWidget {
  final double? width;
  const ProductCardSkeleton({super.key, this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Shimmer.fromColors(
        baseColor: const Color(0xFFF1F5F9),
        highlightColor: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 60,
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
              ),
            ),
            Expanded(
              flex: 40,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 80, height: 18, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 8),
                    Container(width: double.infinity, height: 14, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                    const Spacer(),
                    Row(
                      children: [
                        Container(width: 50, height: 10, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                        const SizedBox(width: 8),
                        Container(width: 40, height: 10, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
