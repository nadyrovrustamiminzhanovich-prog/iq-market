import 'package:flutter/material.dart';
import 'package:iqmarket/screens/post_ad_screen.dart';
import 'package:iqmarket/services/ad_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
        body: StreamBuilder<QuerySnapshot>(
          stream: AdService.getMyAdsStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _buildEmptyState();
            }

            final allAds = snapshot.data!.docs;
            final activeAds = allAds.where((doc) => doc['status'] == 'active' && doc['active'] == true).toList();
            final pendingAds = allAds.where((doc) => doc['status'] == 'pending').toList();
            final archivedAds = allAds.where((doc) => doc['status'] == 'archived' || (doc['active'] == false && doc['status'] == 'active')).toList();

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

  Widget _buildAdsList(List<QueryDocumentSnapshot> ads) {
    if (ads.isEmpty) return _buildEmptyState();
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: ads.length,
      itemBuilder: (ctx, idx) {
        final ad = ads[idx].data() as Map<String, dynamic>;
        final adId = ads[idx].id;
        return _buildAdCard(adId, ad);
      },
    );
  }

  Widget _buildAdCard(String id, Map<String, dynamic> ad) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: ad['imageUrl'] ?? '',
                width: 70, height: 70, fit: BoxFit.cover,
                placeholder: (context, url) => Container(color: Colors.grey[200]),
                errorWidget: (context, url, error) => const Icon(Icons.image),
              ),
            ),
            title: Text(ad['title'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(ad['price'] ?? '', style: GoogleFonts.inter(color: const Color(0xFF4A80F0), fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 4),
                Text(ad['location'] ?? '', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _editAd(id, ad),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Редакт.'),
                ),
                TextButton.icon(
                  onPressed: () => _toggleStatus(id, ad),
                  icon: Icon(ad['active'] == true ? Icons.archive_outlined : Icons.unarchive_outlined, size: 18),
                  label: Text(ad['active'] == true ? 'В архив' : 'Активир.'),
                ),
                IconButton(
                  onPressed: () => _confirmDelete(id),
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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

  void _editAd(String id, Map<String, dynamic> ad) {
    Navigator.push(context, MaterialPageRoute(builder: (ctx) => PostAdScreen(lang: widget.lang, initialAd: {...ad, 'id': id})));
  }

  void _toggleStatus(String id, Map<String, dynamic> ad) {
    final currentStatus = ad['active'] ?? false;
    AdService.toggleAdStatus(id, !currentStatus);
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
