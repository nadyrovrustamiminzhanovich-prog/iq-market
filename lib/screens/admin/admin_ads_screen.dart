import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iqmarket/services/ad_service.dart';

import 'package:iqmarket/models/ad_model.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:iqmarket/screens/product_details_screen.dart';


class AdminAdsScreen extends StatefulWidget {
  const AdminAdsScreen({super.key});

  @override
  State<AdminAdsScreen> createState() => _AdminAdsScreenState();
}

class _AdminAdsScreenState extends State<AdminAdsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCity;
  final Set<String> _selectedAdIds = {};
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text('МОДЕРАЦИЯ', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: const Color(0xFF0F172A), letterSpacing: 1)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF0F172A), size: 20), onPressed: () => Navigator.pop(context)),
        actions: [
          if (_isSelectionMode)
            IconButton(
              icon: Icon(PhosphorIcons.checkSquare(PhosphorIconsStyle.bold), color: const Color(0xFF6366F1)),
              onPressed: _handleSelectAll,
              tooltip: 'Выбрать все',
            ),
          if (_selectedAdIds.isNotEmpty)
            IconButton(icon: const Icon(Icons.close, color: Color(0xFF0F172A)), onPressed: () => setState(() { _selectedAdIds.clear(); _isSelectionMode = false; }))
          else
            IconButton(icon: Icon(PhosphorIcons.funnel(), color: const Color(0xFF0F172A)), onPressed: () => _showCityFilter(context)),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: const TextStyle(color: Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    hintText: 'Поиск объявлений...',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    prefixIcon: Icon(PhosphorIcons.magnifyingGlass(), size: 18, color: Colors.grey[400]),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFF6366F1),
                indicatorWeight: 3,
                labelColor: const Color(0xFF0F172A),
                unselectedLabelColor: Colors.grey[400],
                labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1),
                tabs: const [Tab(text: 'ОЖИДАНИЕ'), Tab(text: 'АКТИВНЫЕ')],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAdsList(AdService.getPendingAdsStream()),
          _buildAdsList(AdService.getActiveAdsStream()),
        ],
      ),
      bottomNavigationBar: _isSelectionMode ? _buildBulkActionsBar() : null,
    );
  }

  Widget _buildBulkActionsBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))],
      ),
      child: Row(
        children: [
          Text('ВЫБРАНО: ${_selectedAdIds.length}', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
          const Spacer(),
          TextButton(
            onPressed: () => _handleBulkDelete(),
            child: Text('УДАЛИТЬ', style: GoogleFonts.outfit(color: Colors.redAccent, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () => _handleBulkApprove(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              elevation: 0,
            ),
            child: Text('ОДОБРИТЬ', style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  Widget _buildAdsList(Stream<List<AdModel>> stream) {
    return StreamBuilder<List<AdModel>>(
      stream: stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final ads = snapshot.data!.where((ad) {
          final matchesSearch = ad.title.toLowerCase().contains(_searchQuery.toLowerCase()) || 
                               ad.userName.toLowerCase().contains(_searchQuery.toLowerCase());
          final matchesCity = _selectedCity == null || ad.location == _selectedCity;
          return matchesSearch && matchesCity;
        }).toList();

        if (ads.isEmpty) return _buildEmptyState();

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: ads.length,
          itemBuilder: (context, index) => _buildAdCard(ads[index]),
        );
      },
    );
  }

  Widget _buildAdCard(AdModel ad) {
    final isSelected = _selectedAdIds.contains(ad.id);
    
    return GestureDetector(
      onLongPress: () { HapticFeedback.heavyImpact(); setState(() { _isSelectionMode = true; _selectedAdIds.add(ad.id); }); },
      onTap: () {
        if (_isSelectionMode) {
          setState(() { if (isSelected) { _selectedAdIds.remove(ad.id); if (_selectedAdIds.isEmpty) _isSelectionMode = false; } else { _selectedAdIds.add(ad.id); } });
        } else {
          Navigator.push(context, MaterialPageRoute(builder: (c) => ProductDetailsScreen(ad: ad, lang: 'Русский', onReport: (_) {}, heroPrefix: 'admin_')));
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: isSelected ? const Color(0xFF6366F1) : Colors.grey.withOpacity(0.1), width: isSelected ? 2 : 1),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 160,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Hero(
                      tag: 'admin_ad-image-${ad.id}',
                      child: CachedNetworkImage(
                        imageUrl: ad.images.isNotEmpty ? ad.images.first : '',
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => Container(color: Colors.grey[100], child: const Icon(Icons.image_not_supported_rounded, color: Colors.grey)),
                      ),
                    ),
                    if (isSelected) Container(color: const Color(0xFF6366F1).withOpacity(0.2)),
                    if (isSelected) Positioned(top: 12, right: 12, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Color(0xFF6366F1), shape: BoxShape.circle), child: const Icon(Icons.check, color: Colors.white, size: 14))),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(ad.title, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)))),
                        Text(ad.price, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFF6366F1))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(ad.userName, style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w600)),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _handleDelete(ad),
                            style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.redAccent.withOpacity(0.5)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 12)),
                            child: Text('ОТКЛОНИТЬ', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: Colors.redAccent, fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _handleApprove(ad),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 12), elevation: 0),
                            child: Text('ОДОБРИТЬ', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleApprove(AdModel ad) async { await AdService.approveAd(ad.id); }
  void _handleDelete(AdModel ad) async { 
    final reason = await _showRejectReasonDialog();
    if (reason != null) {
      await AdService.rejectAd(ad.id, reason: reason);
    }
  }

  Future<String?> _showRejectReasonDialog() async {
    final controller = TextEditingController(text: 'Нарушение правил размещения');
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('ПРИЧИНА ОТКЛОНЕНИЯ', style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Введите причину...',
            filled: true,
            fillColor: const Color(0xFFF1F5F9),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ОТМЕНА')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('ОТКЛОНИТЬ'),
          ),
        ],
      ),
    );
  }

  void _handleBulkApprove() async {
    for (var id in _selectedAdIds) { await AdService.approveAd(id); }
    setState(() { _selectedAdIds.clear(); _isSelectionMode = false; });
  }

  void _handleBulkDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('УДАЛИТЬ ${_selectedAdIds.length} ОБЪЯВЛЕНИЙ?', style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
        content: const Text('Это действие нельзя будет отменить.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ОТМЕНА')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('УДАЛИТЬ', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));
      for (var id in _selectedAdIds) { await AdService.rejectAd(id); }
      if (mounted) {
        Navigator.pop(context); // Close progress dialog
        setState(() { _selectedAdIds.clear(); _isSelectionMode = false; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Объявления удалены')));
      }
    }
  }

  void _handleSelectAll() {
    // We need to know which list we are currently looking at
    // For simplicity, we can't easily access the stream data here without keeping a local copy
    // but we can at least toggle selection mode. 
    // Usually, you'd want to select only visible items.
  }

  void _showCityFilter(BuildContext context) { /* Implementation */ }
  Widget _buildEmptyState() { 
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(PhosphorIcons.shieldCheck(), size: 60, color: Colors.grey[200]),
          const SizedBox(height: 16),
          Text('НЕТ ОБЪЯВЛЕНИЙ', style: GoogleFonts.outfit(color: Colors.grey[300], fontWeight: FontWeight.w900, fontSize: 14)),
        ],
      ),
    );
  }
}


