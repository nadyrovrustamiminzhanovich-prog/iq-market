import 'package:flutter/material.dart';
import 'package:iqmarket/screens/post_ad_screen.dart';
import 'package:iqmarket/screens/product_details_screen.dart';
import 'package:iqmarket/services/ad_service.dart';
import 'package:iqmarket/models/ad_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';

class MyAdsScreen extends StatefulWidget {
  final String lang;
  const MyAdsScreen({super.key, required this.lang});

  @override
  State<MyAdsScreen> createState() => _MyAdsScreenState();
}

class _MyAdsScreenState extends State<MyAdsScreen> {
  @override
  void initState() {
    super.initState();
    // Проверка своих объявлений на истечение при входе в раздел
    AdService.checkMyAdsLifecycle();
  }

  String _t(String key) {
    final translations = {
      'title': { 'Русский': 'Мои объявления', 'Қазақша': 'Менің хабарландыруларым', 'Уйғурчә': 'Мениң еланлирим' },
      'tab_active': { 'Русский': 'Активные', 'Қазақша': 'Белсенді', 'Уйғурчә': 'Актив' },
      'tab_archive': { 'Русский': 'Архив', 'Қазақша': 'Мұрағат', 'Уйғурчә': 'Архив' },
      'tab_pending': { 'Русский': 'На проверке', 'Қазақша': 'Тексеруде', 'Уйғурчә': 'Тәкшүрүштә' },
      'post_btn': { 'Русский': 'Разместить', 'Қазақша': 'Орналастыру', 'Уйғурчә': 'Елан бериш' },
      'empty_msg': { 'Русский': 'Тут пока пусто', 'Қазақша': 'Әзірге бос', 'Уйғурчә': 'Һеч нәрсә йоқ' },
      'delete_confirm': { 'Русский': 'Удалить это объявление?', 'Қазақша': 'Бұл хабарландыруды өшіру керек пе?', 'Уйғурчә': 'Өчүрәмсиз?' },
      'cancel': { 'Русский': 'Отмена', 'Қазақша': 'Болдырмау', 'Уйғурчә': 'Ван кечиш' },
      'delete': { 'Русский': 'Удалить', 'Қазақша': 'Өшіру', 'Уйғурчә': 'Өчүрүш' },
      'extend': { 'Русский': 'Продлить', 'Қазақша': 'Ұзарту', 'Уйғурчә': 'Узартиш' },
    };
    return translations[key]?[widget.lang] ?? translations[key]?['Русский'] ?? key;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: Text(_t('title'), style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18)),
          bottom: TabBar(
            tabs: [
              Tab(text: _t('tab_active')),
              Tab(text: _t('tab_pending')),
              Tab(text: _t('tab_archive')),
            ],
            labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700),
            indicatorColor: const Color(0xFF4A80F0),
            labelColor: const Color(0xFF4A80F0),
            unselectedLabelColor: Colors.grey,
          ),
        ),
        body: StreamBuilder<List<AdModel>>(
          stream: AdService.getMyAdsStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return _buildEmptyState();
            }

            final allAds = snapshot.data!;
            final activeAds = allAds.where((ad) => ad.active && ad.status == 'active').toList();
            final pendingAds = allAds.where((ad) => ad.status == 'pending').toList();
            final archivedAds = allAds.where((ad) => !ad.active || ad.status == 'archived' || ad.status == 'archive').toList();

            return TabBarView(
              children: [
                _buildAdsList(activeAds),
                _buildAdsList(pendingAds),
                _buildAdsList(archivedAds),
              ],
            );
          },
        ),
        floatingActionButton: Container(
          height: 58,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4A80F0), Color(0xFF3B82F6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(29),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4A80F0).withValues(alpha: 0.3),
                blurRadius: 18,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(29),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (ctx) => PostAdScreen(lang: widget.lang))),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 26),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      _t('post_btn'),
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }

  Widget _buildAdsList(List<AdModel> ads) {
    if (ads.isEmpty) return _buildEmptyState();
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: ads.length,
      itemBuilder: (ctx, idx) {
        return _buildAdCard(ads[idx]);
      },
    );
  }

  Widget _buildAdCard(AdModel ad) {
    final bool isPending = ad.status == 'pending';
    final bool isArchived = !ad.active || ad.status == 'archived' || ad.status == 'archive';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (ctx) => ProductDetailsScreen(
                      ad: ad,
                      lang: widget.lang,
                      onReport: (adId) {},
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: ad.images.isNotEmpty 
                            ? CachedNetworkImage(
                                imageUrl: ad.images.first,
                                width: 85, height: 85, fit: BoxFit.cover,
                                memCacheWidth: 250,
                                memCacheHeight: 250,
                                placeholder: (context, url) => Container(color: const Color(0xFFF1F5F9)),
                                errorWidget: (context, url, error) => const Icon(Icons.image),
                              )
                            : Container(width: 85, height: 85, color: const Color(0xFFF1F5F9), child: const Icon(Icons.image)),
                        ),
                        if (isPending)
                          Positioned(
                            top: 4, left: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(6)),
                              child: Text('ПРОВЕРКА', style: GoogleFonts.inter(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        if (isArchived)
                          Positioned(
                            top: 4, left: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(6)),
                              child: Text('АРХИВ', style: GoogleFonts.inter(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ad.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15, color: const Color(0xFF1E293B))),
                          const SizedBox(height: 6),
                          Text('${ad.price.toInt()} ₸', style: GoogleFonts.inter(color: const Color(0xFF4A80F0), fontWeight: FontWeight.w900, fontSize: 17)),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.location_on_rounded, size: 12, color: Colors.grey),
                              const SizedBox(width: 4),
                              Expanded(child: Text(ad.location, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.w500))),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              if (ad.condition != null && ad.condition!.isNotEmpty)
                                _miniTag(ad.condition!, ad.condition == 'Новый' ? const Color(0xFF10B981) : Colors.blueGrey),
                              if (ad.hasDelivery)
                                const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.local_shipping_rounded, size: 14, color: Color(0xFF4A80F0))),
                              if (ad.canExchange)
                                const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.swap_horizontal_circle_rounded, size: 14, color: Colors.orange)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(height: 1, color: const Color(0xFFF1F5F9)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (ad.expiresAt != null && (ad.expiresAt!.difference(DateTime.now()).inDays <= 3 || !ad.active))
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      child: TextButton.icon(
                        onPressed: () {
                          AdService.extendAd(ad.id);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Объявление продлено на 30 дней', style: GoogleFonts.inter()), backgroundColor: Colors.green));
                        },
                        icon: const Icon(Icons.update_rounded, size: 18, color: Colors.green),
                        label: Text(_t('extend'), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  TextButton.icon(
                    onPressed: () => _editAd(ad),
                    style: TextButton.styleFrom(foregroundColor: const Color(0xFF4A80F0)),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: Text('Редакт.', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 8),
                  if (ad.active && (ad.expiresAt == null || ad.expiresAt!.difference(DateTime.now()).inDays > 3))
                    TextButton.icon(
                      onPressed: () => AdService.toggleAdStatus(ad.id, !ad.active),
                      style: TextButton.styleFrom(foregroundColor: const Color(0xFF64748B)),
                      icon: Icon(ad.active ? Icons.archive_outlined : Icons.unarchive_outlined, size: 18),
                      label: Text(ad.active ? 'В архив' : 'Активир.', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                    ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => _confirmDelete(ad.id),
                    style: IconButton.styleFrom(foregroundColor: Colors.redAccent.withValues(alpha: 0.1)),
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniTag(String label, Color color) => Container(
    margin: const EdgeInsets.only(right: 6),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
    child: Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
  );

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.ads_click, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(_t('empty_msg'), style: GoogleFonts.inter(color: Colors.grey, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _editAd(AdModel ad) {
    Navigator.push(context, MaterialPageRoute(builder: (ctx) => PostAdScreen(lang: widget.lang, initialAd: ad)));
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t('delete')),
        content: Text(_t('delete_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(_t('cancel'))),
          TextButton(onPressed: () {
            AdService.deleteAd(id);
            Navigator.pop(ctx);
          }, child: Text(_t('delete'), style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}
