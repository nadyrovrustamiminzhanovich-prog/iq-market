import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iqmarket/screens/product_details_screen.dart';
import 'package:iqmarket/screens/chat_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:screen_protector/screen_protector.dart';

class SellerProfileScreen extends StatefulWidget {
  final Map<String, dynamic> seller;
  final String lang;
  final List<Map<String, dynamic>> sellerAds;

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
      'response_time': { 'Русский': 'Время ответа', 'Қазақша': 'Жауап беру уақыты', 'Уйғурчә': 'Җавап бериш вақти' },
      'fast': { 'Русский': 'Очень быстро', 'Қазақша': 'Өте жылдам', 'Уйғурчә': 'Наһайити тез' },
      'verified': { 'Русский': 'Верифицирован', 'Қазақша': 'Расталған', 'Уйғурчә': 'Тәкшүрүлгән' },
      'member_since': { 'Русский': 'На IQ-Market с 12.05.2023', 'Қазақша': '12.05.2023 жылдан бастап IQ-Market-те', 'Уйғурчә': '12.05.2023-жилдин башлап IQ-Market-тә' },
      'call': { 'Русский': 'Позвонить', 'Қазақша': 'Қоңырау шалу', 'Уйғурчә': 'Телефон қилиш' },
      'message': { 'Русский': 'Написать', 'Қазақша': 'Жазу', 'Уйғурчә': 'Йезиш' },
    };
    return translations[key]?[widget.lang] ?? translations[key]?['Русский'] ?? key;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildStatsSection(),
                _buildAdsSection(),
                _buildReviewsSection(),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomActions(),
    );
  }

  Widget _buildSliverAppBar() => SliverAppBar(
    expandedHeight: 280,
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
            colors: [Color(0xFF4A80F0), Color(0xFF00D2FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 60),
                GestureDetector(
                  onTap: () async {
                    if (widget.seller['image_url'] != null) {
                      await ScreenProtector.preventScreenshotOn();
                      showDialog(
                        context: context,
                        builder: (context) => Dialog(
                          backgroundColor: Colors.transparent,
                          insetPadding: EdgeInsets.zero,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: Container(color: Colors.black.withValues(alpha: 0.95), width: double.infinity, height: double.infinity),
                              ),
                              Hero(
                                tag: 'seller_avatar',
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: Image.network(widget.seller['image_url'], fit: BoxFit.contain),
                                ),
                              ),
                              Positioned(
                                top: 50,
                                right: 25,
                                child: IconButton(
                                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 32),
                                  onPressed: () => Navigator.pop(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ).then((_) => ScreenProtector.preventScreenshotOff());
                    }
                  },
                  child: Hero(tag: 'seller_avatar', child: _buildAvatar()),
                ),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.seller['name'] ?? 'Кайнар',
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                    ),
                    if (widget.seller['isVerified'] ?? true) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.verified_rounded, color: Colors.white, size: 22),
                    ],
                  ],
                ),
            const SizedBox(height: 5),
            Text(
              _t('member_since'),
              style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.8), fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _buildAvatar() => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
    ),
    child: CircleAvatar(
      radius: 50,
      backgroundColor: Colors.white.withValues(alpha: 0.2),
      child: widget.seller['image_url'] != null
        ? ClipRRect(
            borderRadius: BorderRadius.circular(50),
            child: Image.network(widget.seller['image_url'], fit: BoxFit.cover, width: 100, height: 100),
          )
        : Text(
            (widget.seller['name'] ?? 'K')[0].toUpperCase(),
            style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.white),
          ),
    ),
  );

  Widget _buildStatsSection() => Container(
    margin: const EdgeInsets.all(20),
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(30),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 20, offset: const Offset(0, 10))],
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _statItem('4.9', _t('rating'), Icons.star_rounded, Colors.amber),
        _statItem('38', _t('sales'), Icons.shopping_bag_rounded, const Color(0xFF4A80F0)),
      ],
    ),
  );

  Widget _statItem(String value, String label, IconData icon, Color color) => Column(
    children: [
      Icon(icon, color: color, size: 24),
      const SizedBox(height: 8),
      Text(value, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFF1A1D1E))),
      const SizedBox(height: 2),
      Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey.shade500)),
    ],
  );

  Widget _buildAdsSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_t('active_ads'), style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF1A1D1E))),
            Text('${widget.sellerAds.length}', style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
      SizedBox(
        height: 260,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(left: 24, right: 10),
          physics: const BouncingScrollPhysics(),
          itemCount: widget.sellerAds.length,
          itemBuilder: (context, index) => _adCard(widget.sellerAds[index]),
        ),
      ),
    ],
  );

  Widget _adCard(Map<String, dynamic> ad) => GestureDetector(
    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailsScreen(ad: ad, onReport: (_) {}, lang: widget.lang))),
    child: Container(
      width: 170,
      margin: const EdgeInsets.only(right: 14, bottom: 20, top: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: Image.network(ad['image_url'] ?? ad['image'], height: 130, width: 170, fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(color: Colors.grey.shade200, child: const Icon(Icons.broken_image))),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ad['title'], maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13)),
                const SizedBox(height: 4),
                Text(ad['price'], style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 14, color: const Color(0xFF4A80F0))),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildReviewsSection() => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_t('reviews'), style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF1A1D1E))),
        const SizedBox(height: 20),
        _reviewItem('Алия', 'Отличный продавец, все честно и быстро!', 5, '15.01.2024', 'iPhone 15 Pro Max'),
        _reviewItem('Максат', 'Товар соответствует описанию. Рекомендую!', 5, '08.01.2024', 'Toyota Camry 70'),
      ],
    ),
  );

  Widget _reviewItem(String name, String text, int rating, String date, String adTitle) => GestureDetector(
    onTap: () {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Отзыв от $name', style: GoogleFonts.inter(fontWeight: FontWeight.w900)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: List.generate(5, (i) => Icon(Icons.star_rounded, size: 18, color: i < rating ? Colors.amber : Colors.grey.shade300))),
              const SizedBox(height: 12),
              Text(text, style: GoogleFonts.inter(fontSize: 14, height: 1.5, color: Colors.grey.shade800)),
              const SizedBox(height: 16),
              Text('К объявлению: $adTitle', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF4A80F0))),
              const SizedBox(height: 4),
              Text(date, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ЗАКРЫТЬ', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4A80F0))),
            ),
          ],
        ),
      );
    },
    child: Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
              const SizedBox(width: 10),
              Text(date, style: TextStyle(color: Colors.grey.shade400, fontSize: 11, fontWeight: FontWeight.w600)),
              const Spacer(),
              Row(children: List.generate(5, (i) => Icon(Icons.star_rounded, size: 14, color: i < rating ? Colors.amber : Colors.grey.shade300))),
            ],
          ),
          const SizedBox(height: 10),
          Text(adTitle, style: const TextStyle(color: Color(0xFF4A80F0), fontSize: 12, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade700, fontSize: 13, height: 1.4, fontWeight: FontWeight.w500)),
        ],
      ),
    ),
  );

  Widget _buildBottomActions() => Container(
    padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
    decoration: BoxDecoration(
      color: Colors.white,
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, -5))],
    ),
    child: Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(
                ad: widget.sellerAds.isNotEmpty ? widget.sellerAds[0] : {
                  'title': 'Интересуюсь вашими товарами',
                  'price': '...',
                  'seller': widget.seller['name'] ?? 'Продавец',
                  'images': []
                }
              )));
            },
            icon: const Icon(Icons.chat_bubble_rounded, size: 20),
            label: Text(_t('message')),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A80F0),
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 55),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(18),
          ),
          child: IconButton(
            icon: const Icon(Icons.call_rounded, color: Color(0xFF10B981)),
            onPressed: () async {
              final Uri launchUri = Uri(scheme: 'tel', path: widget.seller['phone'] ?? '+77770001122');
              if (await canLaunchUrl(launchUri)) {
                await launchUrl(launchUri);
              }
            },
            padding: const EdgeInsets.all(15),
          ),
        ),
      ],
    ),
  );
}
