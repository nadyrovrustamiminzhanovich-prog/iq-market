import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:iqmarket/screens/chat_screen.dart';
import 'package:iqmarket/widgets/product_card.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:iqmarket/services/analytics_service.dart';
import 'package:iqmarket/services/translation_service.dart';
import 'package:google_fonts/google_fonts.dart';

class ProductDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> ad;
  final Function(String adId) onReport;
  final String lang;

  const ProductDetailsScreen({super.key, required this.ad, required this.onReport, required this.lang});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  late PageController _pageController;
  int _currentPage = 0;
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    if (widget.ad['video_url'] != null) {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.ad['video_url']))
        ..initialize().then((_) {
          if (!mounted) return;
          setState(() { _isVideoInitialized = true; });
          _videoController!.setLooping(true);
        });
    }
    AnalyticsService.logAdView(widget.ad['id'].toString(), widget.ad['title'].toString());
  }

  @override
  void dispose() {
    _pageController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  String _t(String key) {
    return TranslationService.t(key, widget.lang);
  }

  List<String> _getImageList() {
    final ad = widget.ad;
    final List<String> result = [];
    if (ad['images'] is List) {
      for (final img in ad['images'] as List) {
        if (img != null && img.toString().isNotEmpty) result.add(img.toString());
      }
    }
    final single = ad['image_url'] ?? ad['image'];
    if (single != null && single.toString().isNotEmpty && !result.contains(single.toString())) {
      result.add(single.toString());
    }
    if (result.isEmpty) result.add('https://images.unsplash.com/photo-1546445317-29f4545e9d53?w=800');
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final images = _getImageList();
    final hasVideo = widget.ad['video_url'] != null;
    final int itemCount = images.length + (hasVideo ? 1 : 0);

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 400,
            pinned: true,
            backgroundColor: Colors.white,
            elevation: 0,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: Colors.white.withValues(alpha: 0.9),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF1E293B)),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            actions: [
              CircleAvatar(
                backgroundColor: Colors.white.withValues(alpha: 0.9),
                child: IconButton(
                  icon: const Icon(Icons.ios_share, size: 20, color: Color(0xFF1E293B)),
                  onPressed: _showShareBottomSheet,
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: Colors.white.withValues(alpha: 0.9),
                child: IconButton(
                  icon: const Icon(Icons.favorite_border_rounded, size: 20, color: Color(0xFF1E293B)),
                  onPressed: () {},
                ),
              ),
              const SizedBox(width: 16),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    controller: _pageController,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    itemCount: itemCount,
                    itemBuilder: (context, index) {
                      if (hasVideo && index == 0) {
                        return _isVideoInitialized 
                          ? GestureDetector(
                              onTap: () => setState(() => _videoController!.value.isPlaying ? _videoController!.pause() : _videoController!.play()),
                              child: VideoPlayer(_videoController!),
                            )
                          : const Center(child: CircularProgressIndicator());
                      }
                      final imgUrl = images[hasVideo ? index - 1 : index];
                      return CachedNetworkImage(imageUrl: imgUrl, fit: BoxFit.cover);
                    },
                  ),
                  Positioned(
                    bottom: 24,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_currentPage + 1}/$itemCount',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.ad['title'] ?? 'Без названия',
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1E293B),
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Цена и Торг с защитой от оверфлоу
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        Text(
                          widget.ad['price'] ?? '0 ₸',
                          style: GoogleFonts.inter(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF4A80F0),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Торг уместен',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF166534),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Метаданные со скроллом
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          _buildMetaItem(Icons.location_on_outlined, widget.ad['location'] ?? 'Неизвестно'),
                          const SizedBox(width: 16),
                          _buildMetaItem(Icons.calendar_today_outlined, '28.04.2026, 02:40'),
                          const SizedBox(width: 16),
                          _buildMetaItem(Icons.visibility_outlined, '245 просмотров'),
                        ],
                      ),
                    ),
                    const Divider(height: 48, color: Color(0xFFF1F5F9)),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundImage: widget.ad['userImage'] != null 
                            ? NetworkImage(widget.ad['userImage']) 
                            : const NetworkImage('https://i.pravatar.cc/150'),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.ad['userName'] ?? 'Айбек',
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1E293B),
                                ),
                              ),
                              Text(
                                'Онлайн',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: const Color(0xFF10B981),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionButton(
                            'Написать',
                            Icons.chat_bubble_rounded,
                            const Color(0xFF4A80F0),
                            Colors.white,
                            () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(ad: widget.ad))),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActionButton(
                            'Позвонить',
                            Icons.phone_rounded,
                            const Color(0xFF4A80F0).withValues(alpha: 0.1),
                            const Color(0xFF4A80F0),
                            () => launchUrl(Uri.parse("tel:+77089007030")),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Описание',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.ad['description'] ?? 'Продаю корову породы Голштин с теленком. Возраст коровы — 4 года, теленка — 3 месяца. Молочная, дает в среднем 20-25 литров в день. Здорова, все прививки сделаны. Цена договорная, возможен торг.',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: const Color(0xFF475569),
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 40),
                    _buildSimilarAds(),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildStickyBottomActions(),
    );
  }

  Widget _buildMetaItem(IconData icon, String text) => Row(
    children: [
      Icon(icon, size: 16, color: const Color(0xFF94A3B8)),
      const SizedBox(width: 6),
      Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 13,
          color: const Color(0xFF64748B),
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );

  Widget _buildActionButton(String label, IconData icon, Color bg, Color text, VoidCallback onTap) => ElevatedButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 20),
    label: Text(label),
    style: ElevatedButton.styleFrom(
      backgroundColor: bg,
      foregroundColor: text,
      elevation: 0,
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15),
    ),
  );

  Widget _buildStickyBottomActions() => Container(
    padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: const Color(0xFFF1F5F9), width: 1)),
    ),
    child: Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => launchUrl(Uri.parse("tel:+77089007030")),
            icon: const Icon(Icons.phone_rounded),
            label: const Text('Позвонить'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF4A80F0),
              side: const BorderSide(color: Color(0xFF4A80F0), width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(ad: widget.ad))),
            icon: const Icon(Icons.chat_bubble_rounded),
            label: const Text('Написать'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A80F0),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildSimilarAds() {
    final List<Map<String, dynamic>> similar = [
      {'title': 'MacBook Pro 14', 'price': '850 000 ₸', 'image_url': 'https://images.unsplash.com/photo-1517336714731-489689fd1ca8?w=400'},
      {'title': 'Samsung S24 Ultra', 'price': '620 000 ₸', 'image_url': 'https://images.unsplash.com/photo-1610945415295-d9bbf067e59c?w=400'},
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_t('similar_ads'), style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
        const SizedBox(height: 16),
        SizedBox(
          height: 220,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: similar.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (_, index) {
              final item = similar[index];
              return Container(
                width: 160,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      child: CachedNetworkImage(imageUrl: item['image_url'], height: 110, width: 160, fit: BoxFit.cover),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item['title'], maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text(item['price'], style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: const Color(0xFF4A80F0), fontSize: 14)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showShareBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_t('share_title'), style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: Text(_t('copied_clipboard')),
              onTap: () {
                HapticFeedback.lightImpact();
                Clipboard.setData(ClipboardData(text: "${widget.ad['title']} - ${widget.ad['price']}"));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('copied_clipboard'))));
              },
            ),
          ],
        ),
      ),
    );
  }
}
