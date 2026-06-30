import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:iqmarket/providers/app_config_provider.dart';
import 'package:iqmarket/services/translation_service.dart';
import 'package:iqmarket/screens/product_details_screen.dart';
import 'package:iqmarket/screens/chat_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:iqmarket/models/ad_model.dart';
import 'package:iqmarket/models/review_model.dart';
import 'package:iqmarket/services/review_service.dart';
import 'package:iqmarket/services/ad_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:iqmarket/widgets/report_user_sheet.dart';

class SellerProfileScreen extends StatefulWidget {
  final AdModel seller;
  final String lang;
  final List<AdModel> sellerAds;

  const SellerProfileScreen({
    super.key,
    required this.seller,
    required this.lang,
    required this.sellerAds,
  });

  @override
  State<SellerProfileScreen> createState() => _SellerProfileScreenState();
}

class _SellerProfileScreenState extends State<SellerProfileScreen> {
  final GlobalKey _reviewsKey = GlobalKey();

  void _scrollToReviews() {
    final context = _reviewsKey.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  String _t(String key) {
    final translations = {
      'seller_profile': { 'Русский': 'Профиль продавца', 'Қазақша': 'Сатушы профилі', 'Уйғурчә': 'Сатқучи профили' },
      'active_ads': { 'Русский': 'Активные объявления', 'Қазақша': 'Белсенді хабарландырулар', 'Уйғурчә': 'Актив еланлар' },
      'reviews': { 'Русский': 'Отзывы покупателей', 'Қазақша': 'Сатып алушылар пікірлері', 'Уйғурчә': 'Сетивалғучилар пикирлири' },
      'sales': { 'Русский': 'Продаж', 'Қазақша': 'Сатылым', 'Уйғурчә': 'Сетиш' },
      'rating': { 'Русский': 'Рейтинг', 'Қазақша': 'Рейтинг', 'Уйғурчә': 'Рейтинг' },
      'member_since': { 'Русский': 'На IQ-Market с 2023', 'Қазақша': '2023 жылдан бастап IQ-Market-те', 'Уйғурчә': '2023-жилдин башлап IQ-Market-тә' },
      'call': { 'Русский': 'Позвонить', 'Қазақша': 'Қоңырау шалу', 'Уйғурчә': 'Телефон қилиш' },
      'message': { 'Русский': 'Написать', 'Қазақша': 'Йезиш', 'Уйғурчә': 'Йезиш' },
      'leave_review': { 'Русский': 'Оставить отзыв', 'Қазақша': 'Пікір қалдыру', 'Уйғурчә': 'Пикир қалдуруш' },
    };
    return translations[key]?[widget.lang] ?? translations[key]?['Русский'] ?? key;
  }

  String _getMemberSinceText(DateTime date) {
    final dateStr = "${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}";
    if (widget.lang == 'Қазақша') {
      return '$dateStr жылдан бастап IQ-Market-те';
    } else if (widget.lang == 'Уйғурчә') {
      return '$dateStr-жилдин башлап IQ-Market-тә';
    } else {
      return 'На IQ-Market с $dateStr года';
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = Provider.of<AppConfigProvider>(context);
    final isBlocked = config.isUserBlocked(widget.seller.userId);

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(widget.seller.userId).snapshots(),
      builder: (context, snapshot) {
        String photoUrl = '';
        DateTime regDate = DateTime(2023); // fallback
        String name = widget.seller.userName;
        bool isVerified = false;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          if (data != null) {
            photoUrl = data['photoUrl'] ?? '';
            if (data['registrationDate'] != null) {
              final ts = data['registrationDate'];
              if (ts is Timestamp) {
                regDate = ts.toDate();
              }
            }
            name = data['name'] ?? widget.seller.userName;
            isVerified = data['isVerified'] ?? false;
          }
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF1F5F9),
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildSliverAppBar(photoUrl, regDate, name, isVerified, isBlocked),
              SliverToBoxAdapter(
                child: isBlocked
                  ? Container(
                      margin: const EdgeInsets.only(top: 40, left: 20, right: 20),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.block_flipped, color: Colors.redAccent, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            TranslationService.t('blocked_user_placeholder', widget.lang),
                            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.redAccent),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        _buildStatsSection(snapshot),
                        _buildAdsSection(),
                        _buildReviewsHeader(),
                        _buildReviewsList(),
                        const SizedBox(height: 120),
                      ],
                    ),
              ),
            ],
          ),
          bottomNavigationBar: _buildBottomActions(isBlocked),
        );
      }
    );
  }

  Widget _buildSliverAppBar(String photoUrl, DateTime regDate, String name, bool isVerified, bool isBlocked) => SliverAppBar(
    expandedHeight: 240,
    pinned: true,
    backgroundColor: const Color(0xFF4A80F0),
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
      onPressed: () => Navigator.pop(context),
    ),
    actions: [
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
        onSelected: (val) {
          final config = Provider.of<AppConfigProvider>(context, listen: false);
          if (val == 'block') {
            config.blockUser(widget.seller.userId);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(TranslationService.t('block_success', widget.lang))),
            );
          } else if (val == 'unblock') {
            config.unblockUser(widget.seller.userId);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(TranslationService.t('unblock_success', widget.lang))),
            );
          } else if (val == 'report') {
            ReportUserSheet.show(
              context,
              reportedUserId: widget.seller.userId,
              reportedUserName: name, // variable defined in StreamBuilder
              lang: widget.lang,
            );
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: isBlocked ? 'unblock' : 'block',
            child: Text(
              TranslationService.t(isBlocked ? 'unblock_seller' : 'block_seller', widget.lang),
            ),
          ),
          PopupMenuItem(
            value: 'report',
            child: Row(
              children: [
                const Icon(Icons.report_gmailerrorred_rounded, color: Colors.redAccent, size: 20),
                const SizedBox(width: 8),
                Text(
                  TranslationService.t('report', widget.lang),
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ],
            ),
          ),
        ],
      ),
    ],
    flexibleSpace: FlexibleSpaceBar(
      background: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4A80F0), Color(0xFF1E293B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            _buildAvatar(photoUrl),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  name,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                ),
                if (isVerified) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.verified_rounded, color: Color(0xFF229ED9), size: 20),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _getMemberSinceText(regDate),
              style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.7), fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    ),
  );

  void _showFullScreenAvatar(String url) {
    if (url.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Hero(
                tag: 'seller_avatar_fullscreen',
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const CircularProgressIndicator(color: Colors.white),
                  errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(String photoUrl) => GestureDetector(
    onTap: () => _showFullScreenAvatar(photoUrl),
    child: Hero(
      tag: 'seller_avatar_fullscreen',
      child: Container(
        width: 90, height: 90,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 4),
          image: photoUrl.isNotEmpty
              ? DecorationImage(image: CachedNetworkImageProvider(photoUrl), fit: BoxFit.cover)
              : null,
        ),
        child: photoUrl.isEmpty
            ? const Icon(Icons.person, color: Colors.white, size: 40)
            : null,
      ),
    ),
  );



  Widget _buildStatsSection(AsyncSnapshot<DocumentSnapshot> snapshot) {
    double ratingValue = 0.0;
    int reviewsCount = 0;
    
    if (snapshot.hasData && snapshot.data!.exists) {
      final data = snapshot.data!.data() as Map<String, dynamic>?;
      if (data != null) {
        ratingValue = (data['rating'] as num?)?.toDouble() ?? 0.0;
        reviewsCount = data['reviewsCount'] ?? 0;
      }
    }
    
    final hasReviews = reviewsCount > 0;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          GestureDetector(
            onTap: hasReviews ? _scrollToReviews : null,
            behavior: HitTestBehavior.opaque,
            child: _statItem(ratingValue.toStringAsFixed(1), _t('rating'), Icons.star_rounded, Colors.amber),
          ),
          Container(width: 1, height: 30, color: const Color(0xFFF1F5F9)),
          GestureDetector(
            onTap: hasReviews ? _scrollToReviews : null,
            behavior: HitTestBehavior.opaque,
            child: _statItem(reviewsCount.toString(), _t('reviews'), Icons.reviews_rounded, const Color(0xFF4A80F0)),
          ),
        ],
      ),
    );
  }

  Widget _statItem(String value, String label, IconData icon, Color color) => Column(
    children: [
      Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Text(value, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
        ],
      ),
      const SizedBox(height: 4),
      Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
    ],
  );

  Widget _buildAdsSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
        child: Text(_t('active_ads'), style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800)),
      ),
      SizedBox(
        height: 220,
        child: StreamBuilder<List<AdModel>>(
          stream: AdService.getAdsByUserStream(widget.seller.userId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final ads = snapshot.data ?? [];
            final activeAds = ads.where((ad) => ad.active && ad.status == 'active').toList();
            if (activeAds.isEmpty) {
              return Center(
                child: Text(
                  widget.lang == 'Қазақша'
                      ? 'Белсенді хабарландырулар жоқ'
                      : widget.lang == 'Уйғурчә'
                          ? 'Актив еланлар йоқ'
                          : 'Нет активных объявлений',
                  style: GoogleFonts.inter(color: Colors.grey),
                ),
              );
            }
            return ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              physics: const BouncingScrollPhysics(),
              itemCount: activeAds.length,
              itemBuilder: (context, index) => _adCard(activeAds[index]),
            );
          }
        ),
      ),
    ],
  );

  Widget _adCard(AdModel ad) => GestureDetector(
    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailsScreen(ad: ad, onReport: (_) {}, lang: widget.lang, heroPrefix: 'seller_'))),
    child: Container(
      width: 160,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Hero(
            tag: 'seller_ad-image-${ad.id}',
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: Container(
                height: 120,
                width: 160,
                color: const Color(0xFFF1F5F9),
                child: ad.images.isNotEmpty 
                  ? CachedNetworkImage(
                      imageUrl: ad.images.first,
                      fit: BoxFit.cover,
                      memCacheWidth: 250,
                      errorWidget: (context, url, error) => const Icon(Icons.image),
                    )
                  : const Icon(Icons.image, color: Colors.grey),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ad.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 4),
                Text(_formatPrice(ad.price), style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.black)),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildReviewsHeader() => Padding(
    key: _reviewsKey,
    padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
    child: Text(_t('reviews'), style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800)),
  );

  Widget _buildReviewsList() => StreamBuilder<List<ReviewModel>>(
    stream: ReviewService.getUserReviewsStream(widget.seller.userId),
    builder: (context, snapshot) {
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      final reviews = snapshot.data!;
      if (reviews.isEmpty) return Center(child: Padding(padding: const EdgeInsets.all(32), child: Text('Пока нет отзывов', style: GoogleFonts.inter(color: Colors.grey))));
      
      return Column(
        children: reviews.map((r) => _reviewItem(r)).toList(),
      );
    },
  );

  void _showReviewDetailsSheet(ReviewModel r) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: const Color(0xFF4A80F0).withValues(alpha: 0.1),
                          child: const Icon(Icons.person, color: Color(0xFF4A80F0), size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.fromUserName, style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16, color: const Color(0xFF0F172A))),
                              const SizedBox(height: 2),
                              Text(DateFormat('dd.MM.yyyy HH:mm').format(r.timestamp), style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Row(
                          children: List.generate(5, (i) => Icon(
                            i < r.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                            size: 22, color: Colors.amber,
                          )),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          r.rating.toStringAsFixed(1),
                          style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16, color: const Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SelectableText(
                      r.comment,
                      style: GoogleFonts.inter(fontSize: 15, color: const Color(0xFF334155), height: 1.6, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 24),
                    if (r.adTitle.isNotEmpty) ...[
                      InkWell(
                        onTap: () async {
                          try {
                            final ad = await AdService.getAdById(r.adId);
                            if (ad != null && context.mounted) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ProductDetailsScreen(ad: ad, onReport: (_) {}, lang: widget.lang, heroPrefix: 'review_'),
                                ),
                              );
                            } else {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      widget.lang == 'Қазақша'
                                          ? 'Хабарландыру табылмады немесе өшірілген'
                                          : widget.lang == 'Уйғурчә'
                                              ? 'Елан тепильмиди йаки өчүрүлгән'
                                              : 'Объявление не найдено или удалено',
                                    ),
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            debugPrint('Error getting ad by id: $e');
                          }
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4A80F0).withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF4A80F0).withValues(alpha: 0.1)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.shopping_bag_outlined, color: Color(0xFF4A80F0), size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.lang == 'Қазақша'
                                          ? 'Хабарландыру туралы:'
                                          : widget.lang == 'Уйғурчә'
                                              ? 'Елан тоғрисида:'
                                              : 'По объявлению:',
                                      style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      r.adTitle,
                                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFF4A80F0)),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF4A80F0)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    if (r.images.isNotEmpty) ...[
                      Text(
                        widget.lang == 'Қазақша'
                            ? 'Пікір суреттері'
                            : widget.lang == 'Уйғурчә'
                                ? 'Пикир сүрәтлири'
                                : 'Фотографии отзыва',
                        style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B), fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 120,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: r.images.length,
                          itemBuilder: (context, i) => GestureDetector(
                            onTap: () => _showFullScreenAvatar(r.images[i]),
                            child: Container(
                              width: 120,
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                image: DecorationImage(image: CachedNetworkImageProvider(r.images[i]), fit: BoxFit.cover),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _reviewItem(ReviewModel r) => GestureDetector(
    onTap: () => _showReviewDetailsSheet(r),
    behavior: HitTestBehavior.opaque,
    child: Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(r.fromUserName, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14)),
              const Spacer(),
              Text(DateFormat('dd.MM.yyyy').format(r.timestamp), style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (i) => Icon(
              i < r.rating ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 16, color: Colors.amber,
            )),
          ),
          const SizedBox(height: 12),
          Text(r.comment, style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF334155), height: 1.5), maxLines: 3, overflow: TextOverflow.ellipsis),
          if (r.adTitle.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.shopping_bag_outlined, size: 14, color: Color(0xFF4A80F0)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'К объявлению: ${r.adTitle}',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF4A80F0)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          if (r.images.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 60,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: r.images.length.clamp(0, 4),
                itemBuilder: (context, i) => Container(
                  width: 60,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    image: DecorationImage(image: CachedNetworkImageProvider(r.images[i]), fit: BoxFit.cover),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );

  Widget? _buildBottomActions(bool isBlocked) {
    if (isBlocked) return null;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, -5))]),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(ad: widget.seller))),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A80F0),
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Text(_t('message'), style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
          ),
          const SizedBox(width: 12),
          InkWell(
            onTap: () async {
              final uri = Uri.parse('tel:${widget.seller.userPhone ?? '+77000000000'}');
              try {
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Не удалось запустить приложение для звонков'), backgroundColor: Colors.redAccent),
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Ошибка вызова: $e'), backgroundColor: Colors.redAccent),
                  );
                }
              }
            },
            child: Container(
              height: 56, width: 56,
              decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.phone_rounded, color: Colors.white, size: 24),
            ),
          ),
        ],
      ),
    );
  }

  String _formatPrice(double price) {
    return price > 0 ? '${NumberFormat.decimalPattern('ru').format(price.toInt())} ₸' : 'Договорная';
  }
}
