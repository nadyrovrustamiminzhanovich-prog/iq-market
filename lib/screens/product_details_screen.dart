import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:iqmarket/data/category_data.dart';
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
import 'package:iqmarket/widgets/secure_image_viewer.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:share_plus/share_plus.dart';
import 'package:iqmarket/screens/post_ad_screen.dart';
import 'package:iqmarket/services/chat_service.dart';
import 'package:iqmarket/widgets/auth_gate_bottom_sheet.dart';
import 'package:iqmarket/services/translation_service.dart';




class ProductDetailsScreen extends StatefulWidget {
  final AdModel ad;
  final Function(String adId) onReport;
  final String lang;
  final String? heroPrefix;
  final bool isPreview;

  const ProductDetailsScreen({
    super.key,
    required this.ad,
    required this.onReport,
    required this.lang,
    this.heroPrefix,
    this.isPreview = false,
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

    if (!widget.isPreview) {
      _fetchSeller();
      AnalyticsService.logAdView(widget.ad.id, widget.ad.title);
      _incrementViewCount();
    }
  }

  void _incrementViewCount() async {
    if (FirebaseAuth.instance.currentUser == null) return;
    try {
      await FirebaseFunctions.instance
          .httpsCallable('incrementViewCount')
          .call({'listingId': widget.ad.id});
    } catch (e) {
      debugPrint('Error incrementing view count: $e');
    }
  }

  void _incrementCallCount() async {
    if (FirebaseAuth.instance.currentUser == null) return;
    try {
      await FirebaseFunctions.instance
          .httpsCallable('incrementCallCount')
          .call({'listingId': widget.ad.id});
    } catch (e) {
      debugPrint('Error incrementing call count: $e');
    }
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
          } catch (e) { debugPrint('[ProductDetails] Video pause error: $e'); }
          try {
            await _videoController!.dispose();
          } catch (e) { debugPrint('[ProductDetails] Video dispose error: $e'); }
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

  void _handleReport() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      await AuthGateBottomSheet.show(
        context,
        message: TranslationService.t('auth_report_prompt', widget.lang),
      );
      return;
    }

    // Проверяем, отправлял ли пользователь уже жалобу на это объявление
    try {
      final docId = '${currentUser.uid}_${widget.ad.id}';
      final existingDoc = await FirebaseFirestore.instance.collection('reports').doc(docId).get();
      if (existingDoc.exists) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(TranslationService.t('report_already_sent', widget.lang)),
              backgroundColor: Colors.orangeAccent,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          );
        }
        return;
      }
    } catch (e) {
      debugPrint('Error checking existing report: $e');
    }

    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (modalContext) => _ReportAdSheetContent(
        adId: widget.ad.id,
        adTitle: widget.ad.title,
        reportedUserId: widget.ad.userId,
        lang: widget.lang,
      ),
    );

    if (result == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(TranslationService.t('report_sent_success', widget.lang)),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    }
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
    
    // Воспроизводим видео при переходе на полный экран
    _videoController!.play();
    setState(() { _isVideoPlaying = true; });

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

  Widget _buildImage(String url, {BoxFit fit = BoxFit.cover, Color? backgroundColor}) {
    Widget img;
    if (url.isEmpty || !url.startsWith('http')) {
      if (url.startsWith('/') || url.startsWith('file')) {
        img = Image.file(File(url), fit: fit);
      } else {
        img = Container(color: const Color(0xFFF1F5F9), child: const Center(child: Icon(Icons.image_not_supported_rounded, color: Colors.grey)));
      }
    } else {
      img = CachedNetworkImage(
        imageUrl: url, 
        fit: fit, 
        memCacheWidth: 800,
        placeholder: (context, url) => Container(color: const Color(0xFFF1F5F9), child: const Center(child: CircularProgressIndicator())),
        errorWidget: (context, url, error) => const Icon(Icons.image_not_supported_rounded, color: Colors.grey),
      );
    }

    if (backgroundColor != null) {
      return Container(
        color: backgroundColor,
        child: Center(child: img),
      );
    }
    return img;
  }


  @override
  void dispose() {
    _pageController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  void _shareAd() {
    final String text = widget.lang == 'Уйғурчә' 
      ? 'IQ-Market: ${widget.ad.title}\nБаһаси: ${_formatPrice(widget.ad.price)}\nШәһәр: ${widget.ad.location}\n\nБу еланни IQ-Market программисида көрүң! 🔥'
      : (widget.lang == 'Қазақша' 
        ? 'IQ-Market: ${widget.ad.title}\nБағасы: ${_formatPrice(widget.ad.price)}\nҚала: ${widget.ad.location}\n\nБұл хабарландыруды IQ-Market қосымшасында көріңіз! 🔥'
        : 'IQ-Market: ${widget.ad.title}\nЦена: ${_formatPrice(widget.ad.price)}\nГород: ${widget.ad.location}\n\nПосмотри это объявление в приложении IQ-Market! 🔥');
    SharePlus.instance.share(ShareParams(text: text));
  }


  @override
  Widget build(BuildContext context) {
    final ad = _updatedAd ?? widget.ad;
    final images = ad.images;
    final hasVideo = ad.videoUrl != null && ad.videoUrl!.startsWith('http');

    final int itemCount = images.length + (hasVideo ? 1 : 0);
    final isFree = ad.price == 0.0 || ad.category == 'Отдам даром';

    // Объявление считается архивным, если status != 'active' или active == false
    final bool isArchived = ad.status != 'active' || !ad.active;

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
              AbsorbPointer(
                absorbing: widget.isPreview,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _circleButton(Icons.share_rounded, _shareAd),
                    if (_currentUser?.uid != ad.userId) ...[
                      const SizedBox(width: 8),
                      _favoriteButton(),
                    ],
                    if (_currentUser?.accountType == 'admin' || ad.userId == _currentUser?.uid) ...[
                      const SizedBox(width: 8),
                      _circleButton(Icons.edit_outlined, () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (ctx) => PostAdScreen(lang: widget.lang, initialAd: ad)));
                        await _refreshAd();
                      }),
                      const SizedBox(width: 8),
                      _circleButton(Icons.delete_outline_rounded, () => _handleDeleteAd()),
                    ],
                  ],
                ),
              ),
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
                        onTap: widget.isPreview
                            ? null
                            : () {
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
                                    onTap: widget.isPreview
                                        ? null
                                        : () {
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
                                          SizedBox.expand(
                                            child: FittedBox(
                                              fit: BoxFit.cover,
                                              clipBehavior: Clip.hardEdge,
                                              child: SizedBox(
                                                width: _videoController!.value.size.width,
                                                height: _videoController!.value.size.height,
                                                child: VideoPlayer(_videoController!),
                                              ),
                                            ),
                                          )
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
                                  // Кнопка развертывания на весь экран в правом нижнем углу видео
                                  if (_isVideoInitialized)
                                    Positioned(
                                      bottom: 16, right: 16,
                                      child: GestureDetector(
                                        onTap: widget.isPreview ? null : _openFullscreenVideo,
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
                            final imageWidget = _buildImage(images[index], fit: BoxFit.contain, backgroundColor: const Color(0xFFF1F5F9));
                            
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
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        bottom: 16,
                        right: (hasVideo && _currentPage == images.length) ? 72 : 16,
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
            child: AbsorbPointer(
              absorbing: widget.isPreview,
              child: Column(
                children: [
                  // ── Архивный баннер (показывается сверху, если объявление в архиве) ──
                  if (isArchived) _buildArchivedBanner(),
                  _buildMainInfo(isFree),
                  if (_currentUser?.uid != ad.userId && !isArchived) _buildBargainSection(),
                  _buildTags(),
                  const SizedBox(height: 10),
                  if (widget.ad.extraFields != null && widget.ad.extraFields!.isNotEmpty) _buildSpecsSection(),
                  const SizedBox(height: 10),
                  _buildDescription(),
                  const SizedBox(height: 10),
                  _buildSellerCard(),
                  const SizedBox(height: 10),
                  _buildReviewsSection(isArchived: isArchived),
                  const SizedBox(height: 10),
                  // Кнопка «Пожаловаться» — только для активных объявлений
                  if (_currentUser?.uid != ad.userId && !isArchived) _buildReportButton(),
                  const SizedBox(height: 70),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: AbsorbPointer(
        absorbing: widget.isPreview,
        child: _buildBottomBar(),
      ),
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
                      TranslationService.t('bargain_propose', widget.lang),
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
                    children: [
                      const Icon(Icons.sell_rounded, color: Color(0xFF4A80F0)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          TranslationService.t('bargain_dialog_title', widget.lang),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  content: Text(
                    TranslationService.t('bargain_dialog_desc', widget.lang),
                    style: const TextStyle(height: 1.5, fontSize: 14),
                  ),
                  actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(TranslationService.t('understood', widget.lang)))],
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
      Text(isFree ? TranslationService.t('free', widget.lang) : _formatPrice(widget.ad.price), style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w900, color: isFree ? const Color(0xFF10B981) : const Color(0xFF4A80F0))),
      const SizedBox(height: 8),
      Text(widget.ad.title, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A), height: 1.2)),
      const SizedBox(height: 16),
      Row(children: [
        const Icon(Icons.location_on_rounded, size: 16, color: Color(0xFF4A80F0)),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            widget.ad.location,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF1E293B), fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 8),
        Text(_formatFullDate(widget.ad.timestamp), style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF94A3B8))),
      ]),
    ]),
  );

  String _getCategoryTranslation(String categoryId) {
    try {
      final cat = CategoryData.categories.firstWhere((c) => c.id == categoryId);
      if (widget.lang == 'Уйғурчә') return cat.ug.isNotEmpty ? cat.ug : cat.ru;
      if (widget.lang == 'Қазақша') return cat.kz.isNotEmpty ? cat.kz : cat.ru;
      return cat.ru;
    } catch (_) {
      return TranslationService.t(categoryId, widget.lang);
    }
  }

  Widget _buildTags() => Container(
    width: double.infinity, color: Colors.white, padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
    child: Wrap(spacing: 8, runSpacing: 8, children: [
      _tagChip(label: _getCategoryTranslation(widget.ad.category)),
      if (widget.ad.condition != null && widget.ad.condition!.isNotEmpty) 
        _tagChip(label: widget.ad.condition == 'Новый' 
          ? TranslationService.t('cond_new', widget.lang) 
          : (widget.ad.condition == 'Б/у' 
            ? TranslationService.t('cond_used', widget.lang) 
            : widget.ad.condition!)),
      if (widget.ad.isBargainAllowed) _tagChip(label: TranslationService.t('bargain_title', widget.lang)),
    ]),
  );

  Widget _buildDescription() => Container(
    width: double.infinity, color: Colors.white, padding: const EdgeInsets.all(20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(TranslationService.t('description_label', widget.lang), style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800)),
      const SizedBox(height: 12),
      Text(widget.ad.description.isEmpty ? TranslationService.t('no_description', widget.lang) : widget.ad.description, style: GoogleFonts.inter(fontSize: 15, color: const Color(0xFF334155), height: 1.6)),
    ]),
  );

  Widget _buildReviewsSection({bool isArchived = false}) {
    return Container(
      width: double.infinity, color: Colors.white, padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(TranslationService.t('reviews', widget.lang), style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800)),
          if (_seller != null && _seller!.rating > 0) Row(children: [const Icon(Icons.star_rounded, color: Colors.orange, size: 20), const SizedBox(width: 4), Text(_seller!.rating.toStringAsFixed(1), style: GoogleFonts.inter(fontWeight: FontWeight.w900))]),
        ]),
        const SizedBox(height: 16),
        StreamBuilder<List<ReviewModel>>(
          stream: widget.isPreview
              ? Stream.value(<ReviewModel>[])
              : ReviewService.getAdReviewsStream(widget.ad.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            final reviews = snapshot.data ?? [];

            final bool isMyAd = _currentUser?.uid == widget.ad.userId;
            final bool hasReviewedThisAd = _currentUser != null && reviews.any((r) => r.fromUserId == _currentUser!.uid && r.adId == widget.ad.id);
            // Для архивных объявлений кнопка «Оставить отзыв» недоступна
            final bool canLeaveReview = !isMyAd && !hasReviewedThisAd && !isArchived;

            if (reviews.isEmpty) {
              return Column(children: [
                Center(child: Text(TranslationService.t('reviews_empty', widget.lang))),
                const SizedBox(height: 20),
                if (canLeaveReview) _buildLeaveReviewButton(),
              ]);
            }
            return Column(children: [
              ...reviews.take(3).map((r) => _buildReviewItem(r)),
              if (reviews.length > 3)
                TextButton(
                  onPressed: () => _showAllReviewsSheet(reviews),
                  child: Text(
                    TranslationService.t('see_all_reviews', widget.lang).replaceAll('{count}', reviews.length.toString()),
                    style: const TextStyle(color: Color(0xFF4A80F0), fontWeight: FontWeight.bold),
                  ),
                ),
              const SizedBox(height: 16),
              if (canLeaveReview) _buildLeaveReviewButton(),
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
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  review.fromUserName,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _formatRelativeDate(review.timestamp),
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (_currentUser?.accountType == 'admin') ...[
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
              onPressed: () => _confirmDeleteReview(review),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
          ],
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(5, (i) => Icon(Icons.star_rounded, size: 14, color: i < review.rating ? Colors.orange : Colors.grey[300])),
          ),
        ],
      ),
      const SizedBox(height: 6),
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
    if (url.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SecureImageViewerScreen(
          imageUrl: url,
          heroTag: 'product_image_$url',
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
                  Text(TranslationService.t('all_reviews_title', widget.lang).replaceAll('{count}', reviews.length.toString()), style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900)),
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

  Widget _buildLeaveReviewButton() => SizedBox(width: double.infinity, height: 54, child: OutlinedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => LeaveReviewScreen(ad: widget.ad))), icon: const Icon(Icons.rate_review_rounded), label: Text(TranslationService.t('leave_review', widget.lang)), style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF4A80F0), side: const BorderSide(color: Color(0xFF4A80F0)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)))));

  /// Баннер «Объявление в архиве» — показывается вместо кнопок действий
  Widget _buildArchivedBanner() {
    final text = widget.lang == 'Қазақша'
        ? 'Хабарландыру мұрағатта. Байланысу мүмкін емес.'
        : widget.lang == 'Уйғурчә'
            ? 'Елан архивта. Мурасиет қилиш мүмкин әмәс.'
            : 'Объявление в архиве. Связаться с продавцом нельзя.';
    return Container(
      width: double.infinity,
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xFFFFF7ED),
        border: Border(
          bottom: BorderSide(color: Color(0xFFFED7AA), width: 1),
          top: BorderSide(color: Color(0xFFFED7AA), width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFFB923C).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.archive_rounded, color: Color(0xFFF97316), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF9A3412),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildSellerCard() => InkWell(
    onTap: () { if (_seller != null) Navigator.push(context, MaterialPageRoute(builder: (context) => SellerProfileScreen(seller: widget.ad, lang: widget.lang, sellerAds: const []))); },
    child: Container(
      width: double.infinity, color: Colors.white, padding: const EdgeInsets.all(20),
      child: Row(children: [
        CircleAvatar(
          radius: 28, 
          backgroundColor: const Color(0xFFF1F5F9), 
          backgroundImage: (_seller != null && _seller!.photoUrl.isNotEmpty && _seller!.photoUrl.startsWith('http')) 
            ? CachedNetworkImageProvider(_seller!.photoUrl) 
            : null, 
          child: (_seller == null || _seller!.photoUrl.isEmpty || !_seller!.photoUrl.startsWith('http')) 
            ? const Icon(Icons.person) 
            : null
        ),

        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_seller?.name ?? widget.ad.userName, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800)),
          Text(
            _seller != null
              ? (() {
                  final date = _seller!.registrationDate;
                  final dateStr = "${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}";
                  if (widget.lang == 'Қазақша') {
                    return '$dateStr жылдан бастап IQ-Market-те';
                  } else if (widget.lang == 'Уйғурчә') {
                    return '$dateStr-жилдин башлап IQ-Market-тә';
                  } else {
                    return 'На IQ-Market с $dateStr года';
                  }
                })()
              : TranslationService.t('iq_seller', widget.lang),
            style: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
          ),
        ])),
        const Icon(Icons.chevron_right_rounded),
      ]),
    ),
  );

  Widget _buildReportButton() => Container(width: double.infinity, color: Colors.white, child: TextButton.icon(onPressed: _handleReport, icon: const Icon(Icons.report_gmailerrorred_rounded, color: Colors.red), label: Text(TranslationService.t('report_ad', widget.lang), style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.w700)), style: TextButton.styleFrom(padding: const EdgeInsets.all(20))));




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
        Text(TranslationService.t('specs_label', widget.lang), style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        ...displayFields.map((e) {
          String key = e.key;
          if (key == 'carBrand') key = TranslationService.t('car_brand', widget.lang);
          else if (key == 'carModel') key = TranslationService.t('car_model', widget.lang);
          else if (key == 'carYear') key = TranslationService.t('car_year', widget.lang);
          else if (key == 'carBody') key = TranslationService.t('car_body', widget.lang);
          else if (key == 'carTransmission') key = TranslationService.t('car_transmission', widget.lang);
          else if (key == 'carDrive') key = TranslationService.t('car_drive', widget.lang);
          else if (key == 'carFuel') key = TranslationService.t('car_fuel', widget.lang);
          else if (key == 'carColor') key = TranslationService.t('car_color', widget.lang);
          else if (key == 'carEngine') key = TranslationService.t('car_engine', widget.lang);
          else if (key == 'carMileage') key = TranslationService.t('car_mileage', widget.lang);
          else if (key == 'reRooms') key = TranslationService.t('re_rooms', widget.lang);
          else if (key == 'reFloor') key = TranslationService.t('re_floor', widget.lang);
          else if (key == 'reArea') key = TranslationService.t('re_area', widget.lang);
          else if (key == 'malAge') key = TranslationService.t('livestock_age', widget.lang);
          else if (key == 'malWeight') key = TranslationService.t('livestock_weight', widget.lang);
          else if (key == 'malBreed') key = TranslationService.t('livestock_breed', widget.lang);

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [Text(key, style: TextStyle(color: Colors.grey[600], fontSize: 14)), const Spacer(), Text(TranslationService.translateSpecValue(e.value.toString(), widget.lang), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))]),
          );
        }),
      ]),
    );
  }

  Widget _tagChip({required String label}) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)), child: Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF475569))));
  Widget _buildBottomBar() {
    final ad = _updatedAd ?? widget.ad;

    // Своё объявление — без панели
    if (_currentUser?.uid == ad.userId) return const SizedBox.shrink();

    // Архивное объявление — показываем информационную плашку вместо кнопок
    final bool isArchived = ad.status != 'active' || !ad.active;
    if (isArchived) {
      final archivedLabel = widget.lang == 'Қазақша'
          ? 'Мұрағатта'
          : widget.lang == 'Уйғурчә'
              ? 'Архивта'
              : 'В архиве';
      final archivedDesc = widget.lang == 'Қазақша'
          ? 'Байланысу мүмкін емес'
          : widget.lang == 'Уйғурчә'
              ? 'Мурасиет қилиш мүмкин әмәс'
              : 'Объявление недоступно';
      return Container(
        padding: EdgeInsets.fromLTRB(
          16, 12, 16,
          MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom : 12,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFFFFF7ED),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -5))],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFFB923C).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.archive_rounded, color: Color(0xFFF97316), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    archivedLabel,
                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF9A3412)),
                  ),
                  Text(
                    archivedDesc,
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFFC2410C)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Активное объявление — обычные кнопки
    return Container(
      padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom : 8),
      decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -5))]),
      child: Row(children: [
        Expanded(
          child: InkWell(
            onTap: () async {
              if (FirebaseAuth.instance.currentUser == null) {
                await AuthGateBottomSheet.show(
                  context,
                  message: TranslationService.t('auth_call_prompt', widget.lang),
                );
                return;
              }
              _incrementCallCount();
              final uri = Uri.parse('tel:${widget.ad.userPhone}');
              try {
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(TranslationService.t('errNoPhoneCallApp', widget.lang)), backgroundColor: Colors.redAccent),
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(TranslationService.t('errCall', widget.lang).replaceAll('{error}', e.toString())), backgroundColor: Colors.redAccent),
                  );
                }
              }
            },
            child: Container(
              height: 56,
              decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(16)),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.phone_rounded, color: Colors.white),
                    const SizedBox(width: 10),
                    Text(TranslationService.t('call_btn', widget.lang), style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16))
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () async {
              if (FirebaseAuth.instance.currentUser == null) {
                await AuthGateBottomSheet.show(
                  context,
                  message: TranslationService.t('auth_chat_prompt', widget.lang),
                );
                return;
              }
              Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(ad: widget.ad)));
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A80F0), foregroundColor: Colors.white, minimumSize: const Size(0, 56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
            child: Text(TranslationService.t('write_btn', widget.lang), style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16)),
          ),
        ),
      ]),
    );
  }

  void _showBargainDialog() async {
    if (FirebaseAuth.instance.currentUser == null) {
      await AuthGateBottomSheet.show(
        context,
        message: TranslationService.t('auth_bargain_prompt', widget.lang),
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
      builder: (sheetContext) {
        bool isSending = false;
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Container(
              padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(TranslationService.t('bargain_propose', widget.lang), style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
                  const SizedBox(height: 12),
                  Text(TranslationService.t('bargain_enter_sum', widget.lang), 
                    style: TextStyle(color: Colors.grey[600], fontSize: 14, height: 1.5)),
                  const SizedBox(height: 24),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    enabled: !isSending,
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
                      Text('${TranslationService.t('min_price', widget.lang)} ${_formatPrice(currentPrice * 0.7)}', 
                        style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSending ? null : () async {
                        final cleanStr = controller.text.replaceAll(RegExp(r'[^0-9]'), '');
                        final offeredPrice = double.tryParse(cleanStr) ?? 0;

                        if (offeredPrice <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(TranslationService.t('price_too_low', widget.lang))));
                          return;
                        }

                        setModalState(() => isSending = true);
                        try {
                          // FIX: Re-fetch the current ad price from Firestore to
                          // prevent the stale-price bypass (price may change after dialog open).
                          // Firestore rule also enforces this server-side.
                          double livePrice = currentPrice;
                          try {
                            final adDoc = await FirebaseFirestore.instance
                                .collection('ads')
                                .doc(widget.ad.id)
                                .get();
                            if (adDoc.exists) {
                              livePrice = (adDoc.data()?['price'] as num?)?.toDouble() ?? currentPrice;
                            }
                          } catch (_) {
                            // Fallback to local price — Firestore rule will catch bypass
                          }

                          if (offeredPrice < livePrice * 0.7) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(TranslationService.t('price_too_low', widget.lang))));
                            }
                            return;
                          }

                          await ChatService.sendOffer(ad: widget.ad, price: offeredPrice);
                          if (modalContext.mounted) {
                            Navigator.pop(modalContext);
                          }
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(TranslationService.t('offer_sent_check_chat', widget.lang))));
                            Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(ad: widget.ad)));
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.redAccent));
                          }
                        } finally {
                          if (modalContext.mounted) {
                            setModalState(() => isSending = false);
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A80F0), foregroundColor: Colors.white, minimumSize: const Size(0, 64), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), elevation: 0),
                      child: isSending
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(TranslationService.t('send_to_seller', widget.lang), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            );
          }
        );
      }
    );
  }
  Widget _backButton() => Padding(padding: const EdgeInsets.all(8.0), child: _circleButton(Icons.arrow_back_ios_new_rounded, () => Navigator.of(context).maybePop()));
  Widget _circleButton(IconData icon, VoidCallback onTap) => CircleAvatar(backgroundColor: Colors.black.withValues(alpha: 0.4), radius: 20, child: IconButton(icon: Icon(icon, size: 18, color: Colors.white), onPressed: onTap, padding: EdgeInsets.zero));
  Widget _favoriteButton() => Consumer<AppConfigProvider>(builder: (context, config, _) => CircleAvatar(backgroundColor: Colors.black.withValues(alpha: 0.4), radius: 20, child: IconButton(icon: Icon(config.isFavorite(widget.ad.id) ? Icons.favorite_rounded : Icons.favorite_border_rounded, size: 20, color: config.isFavorite(widget.ad.id) ? const Color(0xFFEF4444) : Colors.white), onPressed: () async {
    if (FirebaseAuth.instance.currentUser == null) {
      await AuthGateBottomSheet.show(
        context,
        message: TranslationService.t('auth_favorites_prompt', widget.lang),
      );
    } else {
      config.toggleFavorite(widget.ad.id);
    }
  }, padding: EdgeInsets.zero)));
  String _formatPrice(double price) { 
    return price > 0 ? '${NumberFormat.decimalPattern('ru').format(price.toInt())} ₸' : TranslationService.t('by_agreement', widget.lang); 
  }
  String _formatFullDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatRelativeDate(DateTime dt) {
    final now = DateTime.now();
    if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
      return TranslationService.t('today_with_time', widget.lang).replaceAll('{time}', '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}');
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (dt.day == yesterday.day && dt.month == yesterday.month && dt.year == yesterday.year) {
      return TranslationService.t('yesterday_with_time', widget.lang).replaceAll('{time}', '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}');
    }
    
    final Map<String, List<String>> months = {
      'Русский': ['','янв','фев','мар','апр','мая','июн','июл','авг','сен','окт','ноя','дек'],
      'Қазақша': ['','қаң','ақп','мау','сәу','мам','мау','шіл','там','қыр','қаз','қара','жел'],
      'Уйғурчә': ['','янв','фев','мар','апр','май','июн','июл','авг','сен','окт','ноя','дек'],
    };
    final monthList = months[widget.lang] ?? months['Русский']!;
    return '${dt.day} ${monthList[dt.month]}';
  }

  void _confirmDeleteReview(ReviewModel review) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(TranslationService.t('delete_review_title', widget.lang)),
        content: Text(TranslationService.t('delete_review_desc', widget.lang)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(TranslationService.t('cancel', widget.lang).toUpperCase())),
          TextButton(onPressed: () async {
            await ReviewService.deleteReview(review.id, widget.ad.userId);
            if (mounted) Navigator.pop(context);
          }, child: Text(TranslationService.t('delete_btn', widget.lang).toUpperCase(), style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  void _handleDeleteAd() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(TranslationService.t('delete_ad_title', widget.lang)),
        content: Text(TranslationService.t('delete_ad_desc', widget.lang)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(TranslationService.t('cancel', widget.lang).toUpperCase())),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(TranslationService.t('delete_btn', widget.lang).toUpperCase(), style: const TextStyle(color: Colors.red))),
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
  bool _showControls = true;
  Timer? _controlsTimer;

  @override
  void initState() {
    super.initState();
    _isPlaying = widget.controller.value.isPlaying;
    widget.controller.addListener(_videoListener);
    
    // Скрытие системного интерфейса для полного погружения (fullscreen)
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _startControlsTimer();
  }

  void _videoListener() {
    if (mounted) {
      final isPlayingNow = widget.controller.value.isPlaying;
      if (_isPlaying != isPlayingNow) {
        setState(() {
          _isPlaying = isPlayingNow;
        });
        if (_isPlaying) {
          _startControlsTimer();
        } else {
          _cancelControlsTimer();
          setState(() {
            _showControls = true;
          });
        }
      }
    }
  }

  void _startControlsTimer() {
    _cancelControlsTimer();
    if (_isPlaying) {
      _controlsTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _showControls = false;
          });
        }
      });
    }
  }

  void _cancelControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = null;
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _startControlsTimer();
    } else {
      _cancelControlsTimer();
    }
  }

  @override
  void dispose() {
    _cancelControlsTimer();
    widget.controller.removeListener(_videoListener);
    // Восстанавливаем системный интерфейс
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Плеер по центру
            Center(
              child: AspectRatio(
                aspectRatio: widget.controller.value.aspectRatio,
                child: VideoPlayer(widget.controller),
              ),
            ),
            
            // Кнопка закрытия (сверху слева)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 16,
              child: IgnorePointer(
                ignoring: !_showControls,
                child: AnimatedOpacity(
                  opacity: _showControls ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  child: CircleAvatar(
                    backgroundColor: Colors.black.withValues(alpha: 0.5),
                    radius: 22,
                    child: IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
              ),
            ),
            
            // Кнопка Play/Pause по центру экрана
            IgnorePointer(
              ignoring: !_showControls,
              child: AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                child: Center(
                  child: GestureDetector(
                    onTap: () {
                      if (_isPlaying) {
                        widget.controller.pause();
                      } else {
                        widget.controller.play();
                      }
                    },
                    child: Container(
                      width: 75, height: 75,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24, width: 1.5),
                      ),
                      child: Icon(
                        _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 45,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Нижний прогресс-бар и кнопки
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 20,
              left: 20, right: 20,
              child: IgnorePointer(
                ignoring: !_showControls,
                child: AnimatedOpacity(
                  opacity: _showControls ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black38,
                          blurRadius: 10,
                          offset: Offset(0, 5),
                        )
                      ],
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 26),
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
                              bufferedColor: Colors.white30,
                              backgroundColor: Colors.white12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportAdSheetContent extends StatefulWidget {
  final String adId;
  final String adTitle;
  final String reportedUserId;
  final String lang;

  const _ReportAdSheetContent({
    required this.adId,
    required this.adTitle,
    required this.reportedUserId,
    required this.lang,
  });

  @override
  State<_ReportAdSheetContent> createState() => _ReportAdSheetContentState();
}

class _ReportAdSheetContentState extends State<_ReportAdSheetContent> {
  late final TextEditingController _commentCtrl;
  String? _selectedType;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _commentCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Widget _reportChip(String title, String type) {
    final isSelected = _selectedType == type;
    return ChoiceChip(
      label: Text(title),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedType = type),
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              TranslationService.t('report_ad', widget.lang),
              style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              TranslationService.t('report_ad_select_reason', widget.lang),
              style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 20),
            AbsorbPointer(
              absorbing: _isLoading,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _reportChip(TranslationService.t('report_reason_fraud', widget.lang), 'fraud'),
                  _reportChip(TranslationService.t('report_reason_price', widget.lang), 'wrong_price'),
                  _reportChip(TranslationService.t('report_reason_sold', widget.lang), 'sold'),
                  _reportChip(TranslationService.t('report_reason_prohibited', widget.lang), 'prohibited'),
                  _reportChip(TranslationService.t('report_reason_other', widget.lang), 'other'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _commentCtrl,
              maxLines: 3,
              enabled: !_isLoading,
              decoration: InputDecoration(
                hintText: TranslationService.t('report_comment_hint', widget.lang),
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedType == null || _isLoading
                    ? null
                    : () async {
                        setState(() => _isLoading = true);
                        try {
                          final reporterId = FirebaseAuth.instance.currentUser?.uid;
                          final docId = '${reporterId ?? 'anonymous'}_${widget.adId}';
                          await FirebaseFirestore.instance.collection('reports').doc(docId).set({
                            'adId': widget.adId,
                            'adTitle': widget.adTitle,
                            'reportedUserId': widget.reportedUserId,
                            'reporterUserId': reporterId ?? 'anonymous',
                            'type': _selectedType,
                            'comment': _commentCtrl.text.trim(),
                            'isRead': false,
                            'timestamp': FieldValue.serverTimestamp(),
                          });

                          if (mounted) {
                            Navigator.of(context).pop(true);
                          }
                        } catch (e) {
                          debugPrint('[Report] Submit error: $e');
                          setState(() => _isLoading = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  TranslationService.t('errSendReport', widget.lang)
                                      .replaceAll('{error}', e.toString()),
                                ),
                                backgroundColor: Colors.redAccent,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A80F0),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[300],
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        TranslationService.t('report_submit_btn', widget.lang),
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

