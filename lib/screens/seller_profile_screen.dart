import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iqmarket/screens/product_details_screen.dart';
import 'package:iqmarket/screens/chat_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:iqmarket/models/ad_model.dart';
import 'package:iqmarket/models/review_model.dart';
import 'package:iqmarket/services/review_service.dart';
import 'package:iqmarket/screens/leave_review_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

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
  String _t(String key) {
    final translations = {
      'seller_profile': { 'Русский': 'Профиль продавца', 'Қазақша': 'Сатушы профилі', 'Уйғурчә': 'Сатқучи профили' },
      'active_ads': { 'Русский': 'Активные объявления', 'Қазақша': 'Белсенді хабарландырулар', 'Уйғурчә': 'Актив еланлар' },
      'reviews': { 'Русский': 'Отзывы покупателей', 'Қазақша': 'Сатып алушылар пікірлері', 'Уйғурчә': 'Сетивалғучилар пикирлири' },
      'sales': { 'Русский': 'Продаж', 'Қазақша': 'Сатылым', 'Уйғурчә': 'Сетиш' },
      'rating': { 'Русский': 'Рейтинг', 'Қазақша': 'Рейтинг', 'Уйғурчә': 'Рейтинг' },
      'member_since': { 'Русский': 'На IQ-Market с 2023', 'Қазақша': '2023 жылдан бастап IQ-Market-те', 'Уйғурчә': '2023-жилдин башлап IQ-Market-тә' },
      'call': { 'Русский': 'Позвонить', 'Қазақша': 'Қоңырау шалу', 'Уйғурчә': 'Телефон қилиш' },
      'message': { 'Русский': 'Написать', 'Қазақша': 'Йезиш' },
      'leave_review': { 'Русский': 'Оставить отзыв', 'Қазақша': 'Пікір қалдыру', 'Уйғурчә': 'Пикир қалдуруш' },
    };
    return translations[key]?[widget.lang] ?? translations[key]?['Русский'] ?? key;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildStatsSection(),
                _buildAdsSection(),
                _buildReviewsHeader(),
                _buildReviewsList(),
                const SizedBox(height: 120),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomActions(),
    );
  }

  Widget _buildSliverAppBar() => SliverAppBar(
    expandedHeight: 240,
    pinned: true,
    backgroundColor: const Color(0xFF4A80F0),
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
      onPressed: () => Navigator.pop(context),
    ),
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
            _buildAvatar(),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.seller.userName,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 20),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _t('member_since'),
              style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.7), fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _buildAvatar() => Hero(
    tag: 'seller_avatar',
    child: Container(
      width: 90, height: 90,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 4),
        image: widget.seller.images.isNotEmpty
            ? (widget.seller.images.isNotEmpty 
                ? DecorationImage(image: CachedNetworkImageProvider(widget.seller.images.first), fit: BoxFit.cover)
                : null)
            : null,
      ),
      child: widget.seller.images.isEmpty
          ? const Icon(Icons.person, color: Colors.white, size: 40)
          : null,
    ),
  );

  Widget _buildStatsSection() => Container(
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
        _statItem('4.9', _t('rating'), Icons.star_rounded, Colors.amber),
        Container(width: 1, height: 30, color: const Color(0xFFF1F5F9)),
        _statItem('38', _t('sales'), Icons.shopping_bag_rounded, const Color(0xFF4A80F0)),
      ],
    ),
  );

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
        child: widget.sellerAds.isEmpty 
          ? Center(child: Text('Нет активных объявлений', style: GoogleFonts.inter(color: Colors.grey)))
          : ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              physics: const BouncingScrollPhysics(),
              itemCount: widget.sellerAds.length,
              itemBuilder: (context, index) => _adCard(widget.sellerAds[index]),
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
              child: ad.images.isNotEmpty 
                ? CachedNetworkImage(
                    imageUrl: ad.images.isNotEmpty ? ad.images.first : '',
                    height: 120, width: 160, fit: BoxFit.cover,
                    errorWidget: (context, url, error) => const Icon(Icons.image),
                  )
                : Container(height: 120, color: const Color(0xFFF1F5F9)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ad.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 4),
                Text(ad.price, style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.black)),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildReviewsHeader() => Padding(
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

  Widget _reviewItem(ReviewModel r) => Container(
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
        Text(r.comment, style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF334155), height: 1.5)),
        
        if (r.images.isNotEmpty) ...[
          const SizedBox(height: 16),
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: r.images.length,
              itemBuilder: (context, i) => Container(
                width: 80,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: DecorationImage(image: CachedNetworkImageProvider(r.images[i]), fit: BoxFit.cover),
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );

  Widget _buildBottomActions() => Container(
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
            if (await canLaunchUrl(uri)) await launchUrl(uri);
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
