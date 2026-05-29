import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

import 'package:iqmarket/screens/chat_screen.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:iqmarket/services/analytics_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iqmarket/models/ad_model.dart';
import 'package:iqmarket/models/user_model.dart';
import 'package:iqmarket/models/review_model.dart';
import 'package:iqmarket/services/user_service.dart';
import 'package:iqmarket/services/review_service.dart';
import 'package:iqmarket/services/ad_service.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:iqmarket/providers/app_config_provider.dart';
import 'package:iqmarket/screens/seller_profile_screen.dart';
import 'package:iqmarket/screens/leave_review_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:iqmarket/screens/post_ad_screen.dart';
import 'package:iqmarket/services/ai_limit_service.dart';
import 'package:iqmarket/services/chat_service.dart';
import 'package:iqmarket/widgets/auth_gate_bottom_sheet.dart';




class ProductDetailsScreen extends StatefulWidget {
  final AdModel ad;
  final Function(String adId) onReport;
  final String lang;
  final String? heroPrefix;

  const ProductDetailsScreen({
    super.key,
    required this.ad,
    required this.onReport,
    required this.lang,
    this.heroPrefix,
  });

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  late PageController _pageController;
  int _currentPage = 0;
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _isVideoPlaying = false;
  UserModel? _seller;
  UserModel? _currentUser;
  AdModel? _updatedAd;


  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    if (widget.ad.videoUrl != null && widget.ad.videoUrl!.startsWith('http')) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        try {
          _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.ad.videoUrl!))
            ..initialize().then((_) {
              if (!mounted) return;
              setState(() { _isVideoInitialized = true; });
              _videoController!.setLooping(true);
            });
        } catch (e) {
          debugPrint('Video init error: $e');
        }
      });
    }

    _fetchSeller();
    AnalyticsService.logAdView(widget.ad.id, widget.ad.title);
  }

  Future<void> _fetchSeller() async {
    final seller = await UserService.getUserById(widget.ad.userId);
    final current = await UserService.getUserById(FirebaseAuth.instance.currentUser?.uid ?? '');
    if (mounted) {
      setState(() {
        _seller = seller;
        _currentUser = current;
      });
    }
  }

  Future<void> _refreshAd() async {
    final freshAd = await AdService.getAdById(_updatedAd?.id ?? widget.ad.id);
    if (freshAd != null && mounted) {
      final oldVideoUrl = _updatedAd?.videoUrl ?? widget.ad.videoUrl;
      if (freshAd.videoUrl != oldVideoUrl) {
        if (_videoController != null) {
          try {
            await _videoController!.pause();
          } catch (_) {}
          try {
            await _videoController!.dispose();
          } catch (_) {}
          _videoController = null;
          _isVideoInitialized = false;
          _isVideoPlaying = false;
        }
        if (freshAd.videoUrl != null && freshAd.videoUrl!.startsWith('http')) {
          try {
            _videoController = VideoPlayerController.networkUrl(Uri.parse(freshAd.videoUrl!))
              ..initialize().then((_) {
                if (!mounted) return;
                setState(() { _isVideoInitialized = true; });
                _videoController!.setLooping(true);
              });
          } catch (e) {
            debugPrint('Video init error: $e');
          }
        }
      }
      setState(() {
        _updatedAd = freshAd;
      });
    }
  }

  void _handleReport() {
    String? selectedType;
    final TextEditingController commentCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
                const SizedBox(height: 24),
                Text('Пожаловаться', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text('Выберите причину и опишите проблему', style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 14)),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: [
                    _reportChip('Мошенничество', 'fraud', selectedType, (v) => setModalState(() => selectedType = v)),
                    _reportChip('Неверная цена', 'wrong_price', selectedType, (v) => setModalState(() => selectedType = v)),
                    _reportChip('Товар продан', 'sold', selectedType, (v) => setModalState(() => selectedType = v)),
                    _reportChip('Запрещенный товар', 'prohibited', selectedType, (v) => setModalState(() => selectedType = v)),
                    _reportChip('Другое', 'other', selectedType, (v) => setModalState(() => selectedType = v)),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: commentCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Опишите подробнее (необязательно)...',
                    filled: true, fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: selectedType == null ? null : () async {
                      final reporterId = FirebaseAuth.instance.currentUser?.uid;
                      await FirebaseFirestore.instance.collection('reports').add({
                        'adId': widget.ad.id,
                        'adTitle': widget.ad.title,
                        'reportedUserId': widget.ad.userId,
                        'reporterUserId': reporterId ?? 'anonymous',
                        'type': selectedType,
                        'comment': commentCtrl.text.trim(),
                        'timestamp': FieldValue.serverTimestamp(),
                      });
                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Жалоба отправлена. Спасибо за помощь!')));
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A80F0), foregroundColor: Colors.white, disabledBackgroundColor: Colors.grey[300], padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                    child: Text('Отправить жалобу', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                ),
              ],
            ),
          );
        }
      ),
    ).then((_) {
      // ✅ Освобождаем контроллер ПОСЛЕ закрытия шторки — предотвращает утечку памяти
      commentCtrl.dispose();
    });
  }

  Widget _reportChip(String title, String type, String? selectedType, Function(String) onSelect) {
    final isSelected = selectedType == type;
    return ChoiceChip(
      label: Text(title),
      selected: isSelected,
      onSelected: (_) => onSelect(type),
      backgroundColor: const Color(0xFFF1F5F9),
      selectedColor: const Color(0xFF4A80F0).withValues(alpha: 0.1),
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF4A80F0) : const Color(0xFF1E293B),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      showCheckmark: false,
    );
  }


  void _openFullscreenGallery(int initialIndex) {
    final images = widget.ad.images;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              PageView.builder(
                itemCount: images.length,
                controller: PageController(initialPage: initialIndex),
                itemBuilder: (context, index) => InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Center(child: _buildImage(images[index], fit: BoxFit.contain)),
                ),
              ),
              // Prominent Back Button
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                left: 16,
                child: _circleButton(Icons.arrow_back_ios_new_rounded, () => Navigator.pop(context)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openFullscreenVideo() {
    if (_videoController == null || !_isVideoInitialized) return;
    
    final wasPlaying = _videoController!.value.isPlaying;
    if (wasPlaying) {
      _videoController!.pause();
      setState(() { _isVideoPlaying = false; });
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullscreenVideoPlayer(controller: _videoController!),
      ),
    ).then((_) {
      if (mounted) {
        setState(() {
          _isVideoPlaying = _videoController!.value.isPlaying;
        });
      }
    });
  }

  Widget _buildImage(String url, {BoxFit fit = BoxFit.cover}) {
    if (url.isEmpty || !url.startsWith('http')) {
      if (url.startsWith('/') || url.startsWith('file')) {
        return Image.file(File(url), fit: fit);
      }
      return Container(color: const Color(0xFFF1F5F9), child: const Center(child: Icon(Icons.image_not_supported_rounded, color: Colors.grey)));
    }
    return CachedNetworkImage(
      imageUrl: url, 
      fit: fit, 
      placeholder: (context, url) => Container(color: const Color(0xFFF1F5F9), child: const Center(child: CircularProgressIndicator())),
      errorWidget: (context, url, error) => const Icon(Icons.image_not_supported_rounded, color: Colors.grey),
    );
  }


  @override
  void dispose() {
    _pageController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  void _shareAd() {
    final String text = 'IQ-Market: ${widget.ad.title}\n'
        'Цена: ${_formatPrice(widget.ad.price)}\n'
        'Город: ${widget.ad.location}\n\n'
        'Посмотри это объявление в приложении IQ-Market! 🔥';
    Share.share(text);
  }


  @override
  Widget build(BuildContext context) {
    final ad = _updatedAd ?? widget.ad;
    final images = ad.images;
    final hasVideo = ad.videoUrl != null && ad.videoUrl!.startsWith('http');

    final int itemCount = images.length + (hasVideo ? 1 : 0);
    final isFree = ad.price == 0.0 || ad.category == 'Отдам даром';

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).maybePop();
      },
      child: Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: MediaQuery.of(context).size.height * 0.45,
            pinned: true,
            backgroundColor: Colors.white,
            elevation: 0,
            leading: _backButton(),
            actions: [
              _circleButton(Icons.share_rounded, _shareAd),
              const SizedBox(width: 8),
              _favoriteButton(),
              if (_currentUser?.accountType == 'admin' || ad.userId == _currentUser?.uid) ...[

                const SizedBox(width: 8),
                _circleButton(Icons.edit_outlined, () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (ctx) => PostAdScreen(lang: widget.lang, initialAd: ad)));
                  await _refreshAd();
                }),
                const SizedBox(width: 8),
                _circleButton(Icons.delete_outline_rounded, () => _handleDeleteAd()),
              ],

              const SizedBox(width: 12),
            ],


            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                padding: const EdgeInsets.all(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: GestureDetector(
                        onTap: () {
                          // Video is always last, so it's at index images.length
                          final isVideoSlide = hasVideo && _currentPage == images.length;
                          if (!isVideoSlide) {
                            _openFullscreenGallery(_currentPage);
                          }
                        },
                        child: PageView.builder(
                          controller: _pageController,
                          onPageChanged: (i) => setState(() => _currentPage = i),
                          itemCount: itemCount,
                          itemBuilder: (context, index) {
                            // Photos first, video LAST
                            if (hasVideo && index == images.length) {
                              // Video slide with play icon overlay
                              return Stack(
                                fit: StackFit.expand,
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      if (_isVideoInitialized) {
                                        setState(() {
                                          _isVideoPlaying = !_isVideoPlaying;
                                          _isVideoPlaying ? _videoController!.play() : _videoController!.pause();
                                        });
                                      }
                                    },
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        if (_isVideoInitialized)
                                          VideoPlayer(_videoController!)
                                        else
                                          Container(color: Colors.black, child: const Center(child: CircularProgressIndicator(color: Color(0xFF4A80F0)))),
                                        // Play icon overlay (hide when playing)
                                        if (!_isVideoPlaying)
                                          Center(
                                            child: Container(
                                              width: 70, height: 70,
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(alpha: 0.5),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 40),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  // Кнопка развертывания на весь экран в правом верхнем углу видео
                                  if (_isVideoInitialized)
                                    Positioned(
                                      top: 12, right: 12,
                                      child: GestureDetector(
                                        onTap: _openFullscreenVideo,
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.6),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.2),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.2),
                                                blurRadius: 8,
                                                offset: const Offset(0, 3),
                                              )
                                            ],
                                          ),
                                          child: const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 24),
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            }
                            
                            // Image slides (photos first)
                            final imageWidget = _buildImage(images[index]);
                            
                            if (index == 0) {
                              return Hero(
                                tag: '${widget.heroPrefix ?? ''}ad-image-${widget.ad.id}',
                                child: imageWidget,
                              );
                            }
                            
                            return imageWidget;
                          },
                        ),
                      ),
                    ),
                    if (itemCount > 1)
                      Positioned(
                        bottom: 16, right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(12)),
                          child: Text('${_currentPage + 1}/$itemCount', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildMainInfo(isFree),
                if (_currentUser?.uid != widget.ad.userId) _buildBargainSection(),
                _buildTags(),
                const SizedBox(height: 10),
                if (widget.ad.extraFields != null && widget.ad.extraFields!.isNotEmpty) _buildSpecsSection(),
                const SizedBox(height: 10),
                _buildDescription(),
                const SizedBox(height: 10),
                _buildSellerCard(),
                const SizedBox(height: 10),
                _buildReviewsSection(), 
                const SizedBox(height: 10),
                _buildReportButton(),
                const SizedBox(height: 120),
              ],
            ),
          ),
        ],
      ),
      bottomSheet: _buildBottomBar(),
      ),
    );
  }

  Widget _buildBargainSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: _showBargainDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A80F0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.sell_rounded, size: 18),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Предложить цену',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  title: Row(
                    children: const [
                      Icon(Icons.sell_rounded, color: Color(0xFF4A80F0)),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Как предложить свою цену?',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  content: const Text(
                    '«Предложить цену» — это возможность предложить продавцу свою цену и договориться о скидке (не более 30% от начальной стоимости)!\n\n'
                    '1. Нажмите кнопку «Предложить цену».\n'
                    '2. Напишите цену, за которую хотите купить товар.\n'
                    '3. Продавцу сразу придет сообщение в чат с вашим предложением.\n'
                    '4. Продавец может нажать «Принять» или «Отклонить».\n'
                    '5. Если продавец согласится, вы сможете купить товар по вашей выгодной цене!',
                    style: TextStyle(height: 1.5, fontSize: 14),
                  ),
                  actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Понятно'))],
                ),
              );
            },
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF4A80F0).withValues(alpha: 0.2)),
              ),
              child: const Icon(Icons.help_outline_rounded, color: Color(0xFF4A80F0), size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainInfo(bool isFree) => Container(
    width: double.infinity, color: Colors.white, padding: const EdgeInsets.all(20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(isFree ? 'Бесплатно' : _formatPrice(widget.ad.price), style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w900, color: isFree ? const Color(0xFF10B981) : const Color(0xFF4A80F0))),
      const SizedBox(height: 8),
      Text(widget.ad.title, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A), height: 1.2)),
      const SizedBox(height: 16),
      Row(children: [
        const Icon(Icons.location_on_rounded, size: 16, color: Color(0xFF4A80F0)),
        const SizedBox(width: 4),
        Text(widget.ad.location, style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF1E293B), fontWeight: FontWeight.w700)),
        const Spacer(),
        Text(_formatFullDate(widget.ad.timestamp), style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF94A3B8))),
      ]),
    ]),
  );

  Widget _buildTags() => Container(
    width: double.infinity, color: Colors.white, padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
    child: Wrap(spacing: 8, runSpacing: 8, children: [
      _tagChip(label: widget.ad.category),
      if (widget.ad.condition != null && widget.ad.condition!.isNotEmpty) _tagChip(label: widget.ad.condition!),
      if (widget.ad.isBargainAllowed) _tagChip(label: 'Торг'),
    ]),
  );

  Widget _buildDescription() => Container(
    width: double.infinity, color: Colors.white, padding: const EdgeInsets.all(20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Описание', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800)),
      const SizedBox(height: 12),
      Text(widget.ad.description.isEmpty ? 'Нет описания' : widget.ad.description, style: GoogleFonts.inter(fontSize: 15, color: const Color(0xFF334155), height: 1.6)),
    ]),
  );

  Widget _buildReviewsSection() {
    return Container(
      width: double.infinity, color: Colors.white, padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Отзывы', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800)),
          if (_seller?.rating != null) Row(children: [const Icon(Icons.star_rounded, color: Colors.orange, size: 20), const SizedBox(width: 4), Text(_seller!.rating!.toStringAsFixed(1), style: GoogleFonts.inter(fontWeight: FontWeight.w900))]),
        ]),
        const SizedBox(height: 16),
        StreamBuilder<List<ReviewModel>>(
          stream: ReviewService.getUserReviewsStream(widget.ad.userId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            final reviews = snapshot.data ?? [];
            
            final bool isMyAd = _currentUser?.uid == widget.ad.userId;
            final bool hasReviewedThisAd = _currentUser != null && reviews.any((r) => r.fromUserId == _currentUser!.uid && r.adId == widget.ad.id);
            
            if (reviews.isEmpty) return Column(children: [const Center(child: Text('Отзывов пока нет. Будьте первым!')), const SizedBox(height: 20), if (!isMyAd && !hasReviewedThisAd) _buildLeaveReviewButton()]);
            return Column(children: [
              ...reviews.take(3).map((r) => _buildReviewItem(r)),
              if (reviews.length > 3)
                // ✅ Работающая кнопка — открывает шторку со всеми отзывами
                TextButton(
                  onPressed: () => _showAllReviewsSheet(reviews),
                  child: Text(
                    'Смотреть все ${reviews.length} отзывов',
                    style: const TextStyle(color: Color(0xFF4A80F0), fontWeight: FontWeight.bold),
                  ),
                ),
              const SizedBox(height: 16),
              if (!isMyAd && !hasReviewedThisAd) _buildLeaveReviewButton(),
            ]);
          },
        ),
      ],
      ),
    );
  }

  Widget _buildReviewItem(ReviewModel review) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(review.fromUserName, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14)), 
        const Spacer(), 
        if (_currentUser?.accountType == 'admin') 
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
            onPressed: () => _confirmDeleteReview(review),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        const SizedBox(width: 8),
        Row(children: List.generate(5, (i) => Icon(Icons.star_rounded, size: 14, color: i < review.rating ? Colors.orange : Colors.grey[300]))),
      ]),
      const SizedBox(height: 4),
      Text(review.comment, style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[700])),

      if (review.images.isNotEmpty) ...[ 
        const SizedBox(height: 8), 
        SizedBox(
          height: 80, 
          child: ListView.builder(
            scrollDirection: Axis.horizontal, 
            itemCount: review.images.length, 
            itemBuilder: (context, i) => GestureDetector(
              onTap: () {
                final url = review.images[i];
                if (url.isNotEmpty && url.startsWith('http')) {
                  _showFullScreenImage(url);
                }
              },
              child: Container(
                width: 80, 
                margin: const EdgeInsets.only(right: 8), 
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12), 
                  image: (review.images[i].isNotEmpty && review.images[i].startsWith('http')) 
                    ? DecorationImage(image: CachedNetworkImageProvider(review.images[i]), fit: BoxFit.cover)
                    : null,
                  color: Colors.grey[200],
                ),
                child: (review.images[i].isEmpty || !review.images[i].startsWith('http'))
                    ? const Icon(Icons.broken_image_rounded, size: 20, color: Colors.grey)
                    : null,
              ),
            )

          )
        ), 
      ],
      const Divider(height: 24),
    ]),
  );

  void _showFullScreenImage(String url) {
    showDialog(
      context: context,
      builder: (context) => Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: (url.isNotEmpty && url.startsWith('http'))
                  ? CachedNetworkImage(
                      imageUrl: url,
                      placeholder: (context, url) => const CircularProgressIndicator(),
                      errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.white),
                    )
                  : const Icon(Icons.broken_image_rounded, color: Colors.white, size: 50),
              ),
            ),
            // Prominent Back Button
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 16,
              child: _circleButton(Icons.arrow_back_ios_new_rounded, () => Navigator.pop(context)),
            ),
          ],
        ),
      ),
    );
  }


  // ✅ Полноценная шторка со всеми отзывами (вместо пустого onPressed: () {})
  void _showAllReviewsSheet(List<ReviewModel> reviews) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text('Все отзывы (${reviews.length})', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: reviews.length,
                itemBuilder: (context, index) => _buildReviewItem(reviews[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaveReviewButton() => SizedBox(width: double.infinity, height: 54, child: OutlinedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => LeaveReviewScreen(ad: widget.ad))), icon: const Icon(Icons.rate_review_rounded), label: const Text('Оставить отзыв'), style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF4A80F0), side: const BorderSide(color: Color(0xFF4A80F0)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)))));


  Widget _buildSellerCard() => InkWell(
    onTap: () { if (_seller != null) Navigator.push(context, MaterialPageRoute(builder: (context) => SellerProfileScreen(seller: widget.ad, lang: widget.lang, sellerAds: const []))); },
    child: Container(
      width: double.infinity, color: Colors.white, padding: const EdgeInsets.all(20),
      child: Row(children: [
        CircleAvatar(
          radius: 28, 
          backgroundColor: const Color(0xFFF1F5F9), 
          backgroundImage: (_seller?.photoUrl != null && _seller!.photoUrl!.startsWith('http')) 
            ? CachedNetworkImageProvider(_seller!.photoUrl!) 
            : null, 
          child: (_seller?.photoUrl == null || !_seller!.photoUrl!.startsWith('http')) 
            ? const Icon(Icons.person) 
            : null
        ),

        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_seller?.name ?? widget.ad.userName, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800)),
          // ✅ Динамическая дата регистрации из Firestore
          Text(
            _seller?.registrationDate != null
              ? 'На рынке с ${_seller!.registrationDate!.year}'
              : 'Продавец IQ Market',
            style: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
          ),
        ])),
        const Icon(Icons.chevron_right_rounded),
      ]),
    ),
  );

  Widget _buildReportButton() => Container(width: double.infinity, color: Colors.white, child: TextButton.icon(onPressed: _handleReport, icon: const Icon(Icons.report_gmailerrorred_rounded, color: Colors.red), label: Text('Пожаловаться на объявление', style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.w700)), style: TextButton.styleFrom(padding: const EdgeInsets.all(20))));




  Widget _buildSpecsSection() {
    final fields = widget.ad.extraFields ?? {};
    final displayFields = fields.entries.where((e) {
      final val = e.value?.toString() ?? '';
      // Фильтруем пустые значения, null и технические ключи типа subCategory
      if (val.isEmpty || val == 'null') return false;
      if (e.key == 'subCategory') return false;
      return true;
    }).toList();

    if (displayFields.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity, color: Colors.white, padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Характеристики', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        ...displayFields.map((e) {
          String key = e.key;
          // Если ключ технический (например carBrand), можно его поправить, 
          // но лучше чтобы они уже были на русском из PostAdScreen
          if (key == 'carBrand') key = 'Марка';
          else if (key == 'carModel') key = 'Модель';
          else if (key == 'carYear') key = 'Год';
          else if (key == 'reRooms') key = 'Комнаты';
          else if (key == 'reArea') key = 'Площадь';
          else if (key == 'malAge') key = 'Возраст';

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [Text(key, style: TextStyle(color: Colors.grey[600], fontSize: 14)), const Spacer(), Text(e.value.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))]),
          );
        }),
      ]),
    );
  }

  Widget _tagChip({required String label}) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)), child: Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF475569))));
  Widget _buildBottomBar() {
    if (_currentUser?.uid == widget.ad.userId) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
      decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -5))]),
      child: Row(children: [
        Expanded(child: InkWell(onTap: () async { final uri = Uri.parse('tel:${widget.ad.userPhone}'); if (await canLaunchUrl(uri)) await launchUrl(uri); }, child: Container(height: 56, decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(16)), child: Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.phone_rounded, color: Colors.white), const SizedBox(width: 10), Text('Позвонить', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16))]))))),
        const SizedBox(width: 12),
        Expanded(child: ElevatedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(ad: widget.ad))), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A80F0), foregroundColor: Colors.white, minimumSize: const Size(0, 56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0), child: Text('Написать', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16)))),
      ]),
    );
  }

  void _showBargainDialog() async {
    if (FirebaseAuth.instance.currentUser == null) {
      await AuthGateBottomSheet.show(
        context,
        message: 'Чтобы предложить свою цену продавцу, необходимо войти в свой профиль. Это займет всего пару секунд!',
      );
      return;
    }
    final currentPrice = widget.ad.price;
    final initialPrice = currentPrice > 0 ? (currentPrice * 0.9).toInt() : 0;
    final controller = TextEditingController(
      text: initialPrice > 0 
          ? NumberFormat.decimalPattern('ru').format(initialPrice).replaceAll(',', ' ') 
          : ''
    );
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Предложить свою цену', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
            const SizedBox(height: 12),
            Text('Введите сумму, которую вы готовы заплатить. Продавец получит уведомление и сможет принять ваше предложение или продолжить диалог.', 
              style: TextStyle(color: Colors.grey[600], fontSize: 14, height: 1.5)),
            const SizedBox(height: 24),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w900, color: const Color(0xFF4A80F0)),
              inputFormatters: [
                TextInputFormatter.withFunction((oldValue, newValue) {
                  if (newValue.text.isEmpty) return newValue;
                  final cleanText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
                  if (cleanText.isEmpty) return newValue.copyWith(text: '');
                  final double price = double.tryParse(cleanText) ?? 0;
                  final String formattedText = NumberFormat.decimalPattern('ru').format(price.toInt()).replaceAll(',', ' ');
                  return newValue.copyWith(
                    text: formattedText,
                    selection: TextSelection.collapsed(offset: formattedText.length),
                  );
                }),
              ],
              decoration: InputDecoration(
                prefixText: '₸ ',
                hintText: '0',
                filled: true, fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 14, color: Colors.grey[400]),
                const SizedBox(width: 6),
                Text('Минимальная цена: ${_formatPrice(currentPrice * 0.7)}', 
                  style: TextStyle(color: Colors.grey[400], fontSize: 12)),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final cleanStr = controller.text.replaceAll(RegExp(r'[^0-9]'), '');
                  final offeredPrice = double.tryParse(cleanStr) ?? 0;
                  if (offeredPrice < currentPrice * 0.7) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Цена слишком низкая. Скидка не может быть больше 30%.')));
                    return;
                  }
                  
                  Navigator.pop(context);
                  await ChatService.sendOffer(ad: widget.ad, price: offeredPrice);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Предложение отправлено! Проверьте чат.')));
                    Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(ad: widget.ad)));
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A80F0), foregroundColor: Colors.white, minimumSize: const Size(0, 64), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), elevation: 0),
                child: const Text('Отправить продавцу', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _backButton() => Padding(padding: const EdgeInsets.all(8.0), child: _circleButton(Icons.arrow_back_ios_new_rounded, () => Navigator.of(context).maybePop()));
  Widget _circleButton(IconData icon, VoidCallback onTap) => CircleAvatar(backgroundColor: Colors.black.withValues(alpha: 0.4), radius: 20, child: IconButton(icon: Icon(icon, size: 18, color: Colors.white), onPressed: onTap, padding: EdgeInsets.zero));
  Widget _favoriteButton() => Consumer<AppConfigProvider>(builder: (context, config, _) => CircleAvatar(backgroundColor: Colors.black.withValues(alpha: 0.4), radius: 20, child: IconButton(icon: Icon(config.isFavorite(widget.ad.id) ? Icons.favorite_rounded : Icons.favorite_border_rounded, size: 20, color: config.isFavorite(widget.ad.id) ? const Color(0xFFEF4444) : Colors.white), onPressed: () async {
    if (FirebaseAuth.instance.currentUser == null) {
      await AuthGateBottomSheet.show(
        context,
        message: 'Чтобы сохранить это объявление в избранное, необходимо войти в свой профиль. Это займет всего пару секунд!',
      );
    } else {
      config.toggleFavorite(widget.ad.id);
    }
  }, padding: EdgeInsets.zero)));
  String _formatPrice(double price) { 
    return price > 0 ? '${NumberFormat.decimalPattern('ru').format(price.toInt())} ₸' : 'Договорная'; 
  }
  String _formatFullDate(DateTime dt) {
    final now = DateTime.now();
    final timeStr = '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    
    if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
      return 'Сегодня $timeStr';
    }
    
    final yesterday = now.subtract(const Duration(days: 1));
    if (dt.day == yesterday.day && dt.month == yesterday.month && dt.year == yesterday.year) {
      return 'Вчера $timeStr';
    }
    
    return '${dt.day} ${['','янв','фев','мар','апр','мая','июн','июл','авг','сен','окт','ноя','дек'][dt.month]}';
  }

  void _confirmDeleteReview(ReviewModel review) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить отзыв?'),
        content: const Text('Это действие нельзя отменить.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ОТМЕНА')),
          TextButton(onPressed: () async {
            await ReviewService.deleteReview(review.id, widget.ad.userId);
            if (mounted) Navigator.pop(context);
          }, child: const Text('УДАЛИТЬ', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  void _handleDeleteAd() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить объявление?'),
        content: const Text('Оно будет удалено безвозвратно.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ОТМЕНА')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('УДАЛИТЬ', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseFirestore.instance.collection('ads').doc(widget.ad.id).delete();
      if (mounted) Navigator.pop(context);
    }
  }
}

class FullscreenVideoPlayer extends StatefulWidget {
  final VideoPlayerController controller;
  const FullscreenVideoPlayer({super.key, required this.controller});

  @override
  State<FullscreenVideoPlayer> createState() => _FullscreenVideoPlayerState();
}

class _FullscreenVideoPlayerState extends State<FullscreenVideoPlayer> {
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _isPlaying = widget.controller.value.isPlaying;
    widget.controller.addListener(_videoListener);
  }

  void _videoListener() {
    if (mounted) {
      setState(() {
        _isPlaying = widget.controller.value.isPlaying;
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_videoListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: widget.controller.value.aspectRatio,
              child: VideoPlayer(widget.controller),
            ),
          ),
          
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            child: CircleAvatar(
              backgroundColor: Colors.black.withValues(alpha: 0.5),
              radius: 20,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          
          GestureDetector(
            onTap: () {
              if (_isPlaying) {
                widget.controller.pause();
              } else {
                widget.controller.play();
              }
            },
            behavior: HitTestBehavior.opaque,
            child: Center(
              child: AnimatedOpacity(
                opacity: _isPlaying ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  width: 70, height: 70,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 40),
                ),
              ),
            ),
          ),

          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 20,
            left: 20, right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 24),
                    onPressed: () {
                      if (_isPlaying) {
                        widget.controller.pause();
                      } else {
                        widget.controller.play();
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: VideoProgressIndicator(
                      widget.controller,
                      allowScrubbing: true,
                      colors: const VideoProgressColors(
                        playedColor: Color(0xFF4A80F0),
                        bufferedColor: Colors.white24,
                        backgroundColor: Colors.white10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

