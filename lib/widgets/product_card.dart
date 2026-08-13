import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';
import 'package:iqmarket/models/ad_model.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:iqmarket/widgets/auth_gate_bottom_sheet.dart';
import 'package:provider/provider.dart';
import 'package:iqmarket/providers/app_config_provider.dart';
import 'package:iqmarket/services/translation_service.dart';

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
    final lang = Provider.of<AppConfigProvider>(context, listen: false).language;
    final images = ad.images;
    final hasMultiple = images.length > 1;
    final isFree = ad.price == 0.0 || ad.category == 'Отдам даром';
    final isArchived = ad.status != 'active' || !ad.active;
    final hasVideo = ad.videoUrl != null && ad.videoUrl!.isNotEmpty;

    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Единый шаблон карточки: превью 4:5 (портрет) + инфо-блок под ним.
          // Высота превью считается от реальной ширины ячейки грида, а не
          // фиксируется во всём Column — так карточка не переполняется, даже
          // если childAspectRatio/mainAxisExtent грида чуть разойдётся с этим
          // расчётом на другом экране.
          final cardWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : (widget.width ?? 180);
          final photoHeight = cardWidth * 5 / 4;

          return Container(
            width: widget.width,
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.15), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: photoHeight,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      GestureDetector(
                        onTap: widget.onTap,
                        behavior: HitTestBehavior.opaque,
                        child: images.isEmpty
                            ? (hasVideo ? _videoOnlyFallback() : _noImage())
                            : (hasMultiple
                                ? PageView.builder(
                                    controller: _pageCtrl,
                                    itemCount: images.length,
                                    physics: const BouncingScrollPhysics(),
                                    onPageChanged: (p) => setState(() => _currentPage = p),
                                    itemBuilder: (_, i) {
                                      final img = _CoverPhoto(url: images[i]);
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
                                    child: _CoverPhoto(url: images.first),
                                  )),
                      ),

                      // Компактный бейдж видео (плей + длительность) — один
                      // элемент вместо прежних двух (крупная кнопка по центру
                      // + широкий цветной лейбл "ВИДЕО"). IgnorePointer: чисто
                      // декоративный, тап должен уходить на GestureDetector выше.
                      if (hasVideo && images.isNotEmpty && _currentPage == 0)
                        Positioned(
                          bottom: 8,
                          left: 8,
                          child: IgnorePointer(child: _videoBadge(ad.videoDurationSeconds)),
                        ),

                      // Градиент сверху для читаемости верхних бейджей
                      Positioned(
                        top: 0, left: 0, right: 0,
                        height: 50,
                        child: IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.black.withValues(alpha: 0.18), Colors.transparent],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Затемнение архивных объявлений — GestureDetector остаётся
                      // кликабельным, поэтому декорация тоже в IgnorePointer.
                      if (isArchived)
                        Positioned.fill(
                          child: IgnorePointer(child: Container(
                            color: Colors.black.withValues(alpha: 0.35),
                          )),
                        ),

                      // Бейдж "В АРХИВЕ" / "НОВОЕ" — компактнее, меньше паддинг
                      if (isArchived)
                        Positioned(
                          top: 8, left: 8,
                          child: IgnorePointer(child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFF97316), Color(0xFFEA580C)],
                              ),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.archive_rounded, color: Colors.white, size: 10),
                                const SizedBox(width: 3),
                                Text(
                                  TranslationService.t('in_archive', lang),
                                  style: GoogleFonts.inter(color: Colors.white, fontSize: 7, fontWeight: FontWeight.w900, letterSpacing: 0.4),
                                ),
                              ],
                            ),
                          )),
                        )
                      else if (DateTime.now().difference(ad.timestamp).inDays.abs() < 3)
                        Positioned(
                          top: 8, left: 8,
                          child: IgnorePointer(child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4A80F0),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Text(
                              TranslationService.t('new_badge', lang).toUpperCase(),
                              style: GoogleFonts.inter(color: Colors.white, fontSize: 7, fontWeight: FontWeight.w900, letterSpacing: 0.4),
                            ),
                          )),
                        ),

                      // Точки-пагинация — единственный постоянный индикатор
                      // нескольких медиа. Стрелки листания убраны намеренно:
                      // свайп по PageView работает и без них, а видимые кнопки
                      // спорили с фото за внимание (см. задачу на упрощение
                      // ленты). Сами точки — мельче и прозрачнее, чем раньше.
                      if (hasMultiple)
                        Positioned(
                          bottom: 8,
                          left: 0,
                          right: 0,
                          child: IgnorePointer(child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(images.length, (index) {
                              final isSelected = _currentPage == index;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: isSelected ? 8 : 4,
                                height: 4,
                                margin: const EdgeInsets.symmetric(horizontal: 2),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(2),
                                  color: isSelected
                                      ? Colors.white.withValues(alpha: 0.85)
                                      : Colors.white.withValues(alpha: 0.4),
                                ),
                              );
                            }),
                          )),
                        ),

                      Positioned(
                        top: 6, right: 6,
                        child: GestureDetector(
                          onTap: () async {
                            HapticFeedback.mediumImpact();
                            if (FirebaseAuth.instance.currentUser == null) {
                              await AuthGateBottomSheet.show(
                                context,
                                message: 'Чтобы сохранить это объявление в избранное, необходимо войти в свой профиль. Это займет всего пару секунд!',
                              );
                            } else {
                              widget.onToggleFavorite();
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(5),
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

                // ── Инфо-блок: один общий шаблон для всех карточек ──
                // Высота ячейки фиксирована гридом (mainAxisExtent в
                // home_screen.dart/favorites_screen.dart), поэтому этот блок
                // обязан укладываться в свой бюджет всегда. Раньше 2 из 3 Text
                // не задавали style.height — реальная высота строки бралась из
                // метрик самого файла шрифта Inter, а она заметно больше
                // fontSize, и по факту не совпадала с тем, что заложили в
                // константу infoBlockHeight — отсюда RenderFlex overflow снизу
                // блока. Явный height:1.2 у всех трёх строк делает высоту
                // предсказуемой (и совпадающей с тем, что уже стояло у title).
                // Клампим textScaler сверху: без этого системная настройка
                // "крупный шрифт" всё равно способна раздуть даже
                // предсказуемую высоту за бюджет ячейки — при этом сами строки
                // и так обрублены maxLines:1 + ellipsis, так что доступности
                // это не вредит, просто не даёт кегль расти дальше 1.2×.
                Expanded(
                  child: MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.2),
                    ),
                    child: GestureDetector(
                      onTap: widget.onTap,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        color: Colors.white,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isFree ? 'Бесплатно' : _formatPrice(ad.price),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                height: 1.2,
                                color: isFree ? const Color(0xFF10B981) : const Color(0xFF4A80F0),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              ad.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B), height: 1.2),
                            ),
                            const SizedBox(height: 4),
                            // Время идёт первым намеренно: если строка не влезает,
                            // Text с ellipsis обрезает КОНЕЦ строки — обрежется
                            // длинное название города, а не время (сигнал
                            // свежести объявления, он важнее и не должен пропадать).
                            Text(
                              '${_formatDateTimeShort(ad.timestamp, lang)} · ${ad.location.isEmpty || ad.location == 'Шонжы' ? 'Чунджа' : ad.location}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B), fontWeight: FontWeight.w600, height: 1.2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _videoOnlyFallback() => Stack(
    fit: StackFit.expand,
    children: [
      Container(color: const Color(0xFF0F172A)),
      const Positioned(
        bottom: 8, left: 8,
        child: IgnorePointer(child: _StaticPlayChip()),
      ),
    ],
  );

  Widget _videoBadge(int? durationSeconds) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 14),
        if (durationSeconds != null && durationSeconds > 0) ...[
          const SizedBox(width: 2),
          Text(
            _formatDuration(durationSeconds),
            style: GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
          ),
        ],
      ],
    ),
  );

  String _formatDuration(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String _formatPrice(double price) {
    return price > 0 ? '${NumberFormat.decimalPattern('ru').format(price.toInt())} ₸' : 'Договорная';
  }

  String _formatDateTimeShort(DateTime dt, String lang) {
    final now = DateTime.now();
    final timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return timeStr;
    }

    final yesterday = now.subtract(const Duration(days: 1));
    if (dt.year == yesterday.year && dt.month == yesterday.month && dt.day == yesterday.day) {
      return '${TranslationService.t('yesterday', lang)}, $timeStr';
    }

    const months = ['', 'янв', 'фев', 'мар', 'апр', 'мая', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
    final monthStr = months[dt.month];
    if (dt.year == now.year) {
      return '${dt.day} $monthStr';
    }
    return '${dt.day} $monthStr ${dt.year}';
  }

  Widget _noImage() => Container(color: const Color(0xFFF8FAFC), child: const Center(child: Icon(Icons.image_outlined, color: Colors.grey, size: 24)));
}

/// Компактный play-бейдж без известной длительности — используется, когда у
/// объявления есть только видео и не удалось сгенерировать обложку.
class _StaticPlayChip extends StatelessWidget {
  const _StaticPlayChip();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(6),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.15),
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
    ),
    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 16),
  );
}

/// Фото/обложка карточки с "умным" кропом: как только реальные размеры
/// исходника известны, сильно вертикальные кадры (source_ratio < 0.75 —
/// типично для видео 9:16 с телефона/Telegram) смещают точку фокуса cover-кропа
/// вверх (~30% от верха, где обычно лицо/объект) вместо центра по умолчанию.
/// Обычные фото (почти квадратные/альбомные) остаются с центральным кропом.
class _CoverPhoto extends StatefulWidget {
  final String url;
  const _CoverPhoto({required this.url});

  @override
  State<_CoverPhoto> createState() => _CoverPhotoState();
}

class _CoverPhotoState extends State<_CoverPhoto> {
  static const Alignment _topBiasAlignment = Alignment(0, -0.4);

  Alignment _alignment = Alignment.center;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  ImageProvider? get _provider {
    final url = widget.url;
    if (url.isEmpty) return null;
    if (url.startsWith('/') || url.startsWith('file')) return FileImage(File(url));
    if (url.startsWith('http')) return CachedNetworkImageProvider(url, maxWidth: 400);
    return null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant _CoverPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _alignment = Alignment.center;
      _resolve();
    }
  }

  void _resolve() {
    final provider = _provider;
    if (provider == null) return;
    final newStream = provider.resolve(createLocalImageConfiguration(context));
    if (_stream?.key == newStream.key) return;
    if (_stream != null && _listener != null) _stream!.removeListener(_listener!);
    _listener = ImageStreamListener((info, _) {
      final w = info.image.width;
      final h = info.image.height;
      if (h == 0) return;
      final ratio = w / h;
      final target = ratio < 0.75 ? _topBiasAlignment : Alignment.center;
      if (mounted && target != _alignment) setState(() => _alignment = target);
    }, onError: (_, __) {});
    _stream = newStream;
    _stream!.addListener(_listener!);
  }

  @override
  void dispose() {
    if (_stream != null && _listener != null) _stream!.removeListener(_listener!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = _provider;
    return Container(
      color: const Color(0xFFF1F5F9),
      width: double.infinity,
      height: double.infinity,
      child: provider == null
          ? Container(color: const Color(0xFFF8FAFC), child: const Center(child: Icon(Icons.image_outlined, color: Colors.grey, size: 24)))
          : Image(
              image: provider,
              fit: BoxFit.cover,
              alignment: _alignment,
              errorBuilder: (context, error, stack) => Container(
                color: const Color(0xFFF8FAFC),
                child: const Center(child: Icon(Icons.image_outlined, color: Colors.grey, size: 24)),
              ),
            ),
    );
  }
}

class ProductCardSkeleton extends StatelessWidget {
  final double? width;
  const ProductCardSkeleton({super.key, this.width});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final cardWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : (width ?? 180);
      final photoHeight = cardWidth * 5 / 4;
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
              Container(
                height: photoHeight,
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(width: 80, height: 16, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                      const SizedBox(height: 6),
                      Container(width: double.infinity, height: 12, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                      const SizedBox(height: 8),
                      Container(width: 90, height: 10, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
