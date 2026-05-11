import 'package:flutter/material.dart';
import 'package:iqmarket/screens/post_ad_screen.dart';
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
            // Simplified status logic for now
            final activeAds = allAds.where((ad) => ad.active).toList();
            final pendingAds = <AdModel>[]; // Add logic if status field is added to model
            final archivedAds = allAds.where((ad) => !ad.active).toList();

            return TabBarView(
              children: [
                _buildAdsList(activeAds),
                _buildAdsList(pendingAds),
                _buildAdsList(archivedAds),
              ],
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (ctx) => PostAdScreen(lang: widget.lang))),
          label: Text(_t('post_btn'), style: const TextStyle(fontWeight: FontWeight.bold)),
          icon: const Icon(Icons.add),
          backgroundColor: const Color(0xFF4A80F0),
        ),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ad.images.isNotEmpty 
                ? CachedNetworkImage(
                    imageUrl: ad.images.first,
                    width: 70, height: 70, fit: BoxFit.cover,
                    placeholder: (context, url) => Container(color: Colors.grey[200]),
                    errorWidget: (context, url, error) => const Icon(Icons.image),
                  )
                : Container(width: 70, height: 70, color: Colors.grey[200], child: const Icon(Icons.image)),
            ),
            title: Text(ad.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(ad.price, style: GoogleFonts.inter(color: const Color(0xFF4A80F0), fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 4),
                Text(ad.location, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (ad.condition != null && ad.condition!.isNotEmpty)
                      _miniTag(ad.condition!, ad.condition == 'Новый' ? Colors.green : Colors.blueGrey),
                    if (ad.hasDelivery)
                      const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.local_shipping_rounded, size: 14, color: Color(0xFF4A80F0))),
                    if (ad.canExchange)
                      const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.swap_horizontal_circle_rounded, size: 14, color: Colors.orange)),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (ad.expiresAt != null && (ad.expiresAt!.difference(DateTime.now()).inDays <= 3 || !ad.active))
                  TextButton.icon(
                    onPressed: () {
                      AdService.extendAd(ad.id);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Объявление продлено на 30 дней', style: GoogleFonts.inter()), backgroundColor: Colors.green));
                    },
                    icon: const Icon(Icons.update_rounded, size: 18, color: Colors.green),
                    label: Text(_t('extend'), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  ),
                if (ad.active && (ad.expiresAt == null || ad.expiresAt!.difference(DateTime.now()).inDays > 3))
                  TextButton.icon(
                    onPressed: () => _editAd(ad),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Редакт.'),
                  ),
                if (ad.active && (ad.expiresAt == null || ad.expiresAt!.difference(DateTime.now()).inDays > 3))
                  TextButton.icon(
                    onPressed: () => AdService.toggleAdStatus(ad.id, !ad.active),
                    icon: Icon(ad.active ? Icons.archive_outlined : Icons.unarchive_outlined, size: 18),
                    label: Text(ad.active ? 'В архив' : 'Активир.'),
                  ),
                IconButton(
                  onPressed: () => _confirmDelete(ad.id),
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                ),
              ],
            ),
          ),
        ],
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
