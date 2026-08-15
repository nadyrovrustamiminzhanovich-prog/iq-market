import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:iqmarket/providers/app_config_provider.dart';
import 'package:iqmarket/services/ad_service.dart';

import 'package:iqmarket/models/ad_model.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:iqmarket/screens/product_details_screen.dart';
import 'package:iqmarket/screens/post_ad_screen.dart';

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
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<AppConfigProvider>(context, listen: false).language;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text('МОДЕРАЦИЯ И АРХИВ', style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: const Color(0xFF0F172A), letterSpacing: 0.5, fontSize: 16)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF0F172A), size: 20), onPressed: () => Navigator.pop(context)),
        actions: [
          if (_selectedAdIds.isNotEmpty)
            IconButton(icon: const Icon(Icons.close, color: Color(0xFF0F172A)), onPressed: () => setState(() { _selectedAdIds.clear(); _isSelectionMode = false; }))
          else
            IconButton(icon: Icon(PhosphorIcons.funnel(), color: const Color(0xFF0F172A)), onPressed: () => _showCityFilter(context)),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(104),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Поиск по заголовку, автору, email или телефону...',
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 12.5),
                    prefixIcon: Icon(PhosphorIcons.magnifyingGlass(), size: 18, color: Colors.grey[400]),
                    suffixIcon: _searchQuery.isNotEmpty 
                      ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { _searchController.clear(); setState(() => _searchQuery = ''); })
                      : null,
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: const Color(0xFF6366F1),
                indicatorWeight: 3,
                labelColor: const Color(0xFF0F172A),
                unselectedLabelColor: Colors.grey[400],
                labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5),
                tabs: const [
                  Tab(text: 'ВСЕ ОБЪЯВЛЕНИЯ'),
                  Tab(text: 'НА ПРОВЕРКЕ'),
                  Tab(text: 'АКТИВНЫЕ'),
                  Tab(text: 'АРХИВ / ОТКЛОНЕННЫЕ'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAdsList(AdService.getAllAdsStreamAdmin(), lang),
          _buildAdsList(AdService.getPendingAdsStream(), lang),
          _buildAdsList(AdService.getActiveAdsStream(), lang),
          _buildAdsList(AdService.getArchivedAdsStreamAdmin(), lang),
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
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, -5))],
      ),
      child: Row(
        children: [
          Text('ВЫБРАНО: ${_selectedAdIds.length}', style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
          const Spacer(),
          TextButton(
            onPressed: _isProcessing ? null : () => _handleBulkDelete(),
            child: _isProcessing
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.redAccent))
                : Text('УДАЛИТЬ', style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _isProcessing ? null : () => _handleBulkApprove(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              elevation: 0,
            ),
            child: _isProcessing
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text('ОДОБРИТЬ', style: GoogleFonts.inter(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  Widget _buildAdsList(Stream<List<AdModel>> stream, String lang) {
    return StreamBuilder<List<AdModel>>(
      stream: stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final q = _searchQuery.toLowerCase().trim();
        final ads = snapshot.data!.where((ad) {
          final matchesSearch = q.isEmpty ||
              ad.title.toLowerCase().contains(q) || 
              ad.description.toLowerCase().contains(q) ||
              ad.userName.toLowerCase().contains(q) ||
              ad.userEmail.toLowerCase().contains(q) ||
              (ad.userPhone != null && ad.userPhone!.contains(q)) ||
              ad.location.toLowerCase().contains(q);
          final matchesCity = _selectedCity == null || ad.location == _selectedCity;
          return matchesSearch && matchesCity;
        }).toList();

        if (ads.isEmpty) return _buildEmptyState();

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: ads.length,
          itemBuilder: (context, index) => _buildAdCard(ads[index], lang),
        );
      },
    );
  }

  Widget _buildAdCard(AdModel ad, String lang) {
    final isSelected = _selectedAdIds.contains(ad.id);
    
    // Status Badge Logic
    Color badgeBg = Colors.grey[200]!;
    Color badgeColor = Colors.grey[700]!;
    String statusLabel = 'В АРХИВЕ';

    if (ad.status == 'pending') {
      badgeBg = Colors.amber.withValues(alpha: 0.15);
      badgeColor = Colors.amber[900]!;
      statusLabel = 'НА ПРОВЕРКЕ';
    } else if (ad.status == 'active' && ad.active) {
      badgeBg = const Color(0xFF10B981).withValues(alpha: 0.15);
      badgeColor = const Color(0xFF047857);
      statusLabel = 'АКТИВНО';
    } else if (ad.status == 'rejected') {
      badgeBg = Colors.red.withValues(alpha: 0.15);
      badgeColor = Colors.red[900]!;
      statusLabel = 'ОТКЛОНЕНО';
    }

    return GestureDetector(
      onLongPress: () { HapticFeedback.heavyImpact(); setState(() { _isSelectionMode = true; _selectedAdIds.add(ad.id); }); },
      onTap: () {
        if (_isSelectionMode) {
          setState(() { if (isSelected) { _selectedAdIds.remove(ad.id); if (_selectedAdIds.isEmpty) _isSelectionMode = false; } else { _selectedAdIds.add(ad.id); } });
        } else {
          Navigator.push(context, MaterialPageRoute(builder: (c) => ProductDetailsScreen(ad: ad, lang: lang, onReport: (_) {}, heroPrefix: 'admin_')));
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isSelected ? const Color(0xFF6366F1) : Colors.grey.withValues(alpha: 0.1), width: isSelected ? 2 : 1),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 150,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Hero(
                      tag: 'admin_ad-image-${ad.id}',
                      child: Container(
                        color: const Color(0xFFF1F5F9),
                        child: ad.images.isNotEmpty 
                          ? CachedNetworkImage(
                              imageUrl: ad.images.first,
                              fit: BoxFit.cover,
                              memCacheWidth: 400,
                              errorWidget: (context, url, error) => Container(color: Colors.grey[100], child: const Icon(Icons.image_not_supported_rounded, color: Colors.grey)),
                            )
                          : Container(color: Colors.grey[100], child: const Icon(Icons.image_not_supported_rounded, color: Colors.grey)),
                      ),
                    ),
                    Positioned(
                      top: 12, left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(8)),
                        child: Text(statusLabel, style: GoogleFonts.inter(color: badgeColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                      ),
                    ),
                    if (isSelected) Container(color: const Color(0xFF6366F1).withValues(alpha: 0.2)),
                    if (isSelected) Positioned(top: 12, right: 12, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Color(0xFF6366F1), shape: BoxShape.circle), child: const Icon(Icons.check, color: Colors.white, size: 14))),
                    if (ad.multiAccountSuspected && !isSelected)
                      Positioned(
                        top: 12, right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 12),
                              const SizedBox(width: 3),
                              Text('МУЛЬТИ-АККАУНТ', style: GoogleFonts.inter(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.3)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(ad.title, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 8),
                        Text('${ad.price.toInt()} ₸', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFF6366F1))),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Author info block
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(PhosphorIcons.user(), size: 13, color: Colors.grey[600]),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text('Автор: ${ad.userName}', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                          if (ad.userPhone != null && ad.userPhone!.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Icon(PhosphorIcons.phone(), size: 13, color: Colors.grey[600]),
                                const SizedBox(width: 6),
                                Text(ad.userPhone!, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[600])),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Action Buttons Row
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(builder: (ctx) => PostAdScreen(lang: lang, initialAd: ad)));
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF4A80F0),
                              side: const BorderSide(color: Color(0xFF4A80F0)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            icon: const Icon(Icons.edit_outlined, size: 14),
                            label: Text('РЕДАКТИРОВАТЬ', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 10)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (ad.status == 'pending' || !ad.active)
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _handleApprove(ad),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                elevation: 0,
                              ),
                              icon: const Icon(Icons.check_circle_outline, size: 14),
                              label: Text('ОДОБРИТЬ', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 10)),
                            ),
                          ),
                        if (ad.status == 'active' && ad.active)
                          IconButton(
                            onPressed: () => _handleArchive(ad),
                            icon: const Icon(Icons.archive_outlined, color: Colors.grey, size: 20),
                            tooltip: 'В архив',
                          ),
                        // Отклонить с указанием причины — доступно и для объявлений на
                        // проверке, и для уже одобренных ИИ (ИИ мог ошибиться).
                        if (ad.status == 'pending' || (ad.status == 'active' && ad.active))
                          IconButton(
                            onPressed: () => _showRejectSheet(ad),
                            icon: const Icon(Icons.block_rounded, color: Colors.redAccent, size: 20),
                            tooltip: 'Отклонить',
                          ),
                        IconButton(
                          onPressed: () => _handleDeletePermanently(ad),
                          icon: const Icon(Icons.delete_forever_outlined, color: Colors.redAccent, size: 20),
                          tooltip: 'Удалить навсегда',
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

  // ─── Шаблоны причин отклонения ────────────────────────────────────────────
  // Каждый шаблон — готовое, вежливое и конкретное сообщение для пользователя:
  // что не так и что делать дальше (переделать и опубликовать заново / не
  // пытаться повторно / обратиться в поддержку). {title} подставляется автоматически.
  static const List<Map<String, String>> _rejectReasonTemplates = [
    {
      'label': 'Запрещённый товар/услуга',
      'text': 'Объявление «{title}» отклонено: данный товар/услуга запрещены к размещению на IQ-Market. Повторная публикация того же товара приведёт к ограничению аккаунта.',
    },
    {
      'label': 'Подозрение на мошенничество',
      'text': 'Объявление «{title}» отклонено: цена или описание вызывают подозрение в достоверности. Если товар реальный — добавьте больше фото и подробное описание и опубликуйте заново.',
    },
    {
      'label': 'Нечёткие/чужие фото',
      'text': 'Объявление «{title}» отклонено: фото нечёткие, не по теме или взяты из интернета. Загрузите реальные фото товара и опубликуйте заново.',
    },
    {
      'label': 'Описание не по теме',
      'text': 'Объявление «{title}» отклонено: описание или категория не соответствуют товару. Исправьте через редактирование и опубликуйте заново.',
    },
    {
      'label': 'Дубликат объявления',
      'text': 'У вас уже есть активное объявление на этот товар. Отредактируйте существующее вместо создания копий.',
    },
    {
      'label': 'Контакты/ссылки в тексте',
      'text': 'Объявление «{title}» отклонено: в тексте указаны контакты/ссылки в обход правил площадки. Уберите их из описания и опубликуйте заново — общаться нужно через встроенный чат.',
    },
    {
      'label': 'Оскорбительный контент',
      'text': 'Объявление «{title}» отклонено за нарушение правил (недопустимый контент). Повторное нарушение может привести к блокировке аккаунта.',
    },
    {
      'label': 'Другое',
      'text': '',
    },
  ];

  void _showRejectSheet(AdModel ad) {
    final controller = TextEditingController();
    String? selectedLabel;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        bool isSending = false;
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(modalContext).viewInsets.bottom),
              // Клавиатура + развёрнутые в несколько строк чипы причин легко не
              // влезают в оставшуюся высоту экрана — без ConstrainedBox+Scroll
              // Column вылезал за пределы шита (RenderFlex overflow), хотя сама
              // отправка формы всё равно работала.
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(modalContext).size.height * 0.9),
                child: SingleChildScrollView(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Отклонить объявление', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        Text('«${ad.title}»', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _rejectReasonTemplates.map((tpl) {
                            final bool isSelected = selectedLabel == tpl['label'];
                            return ChoiceChip(
                              label: Text(tpl['label']!, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
                              selected: isSelected,
                              selectedColor: const Color(0xFF4A80F0).withValues(alpha: 0.15),
                              onSelected: (_) {
                                setModalState(() {
                                  selectedLabel = tpl['label'];
                                  controller.text = tpl['text']!.replaceAll('{title}', ad.title);
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: controller,
                          maxLines: 4,
                          style: GoogleFonts.inter(fontSize: 14),
                          onChanged: (_) => setModalState(() {}),
                          decoration: InputDecoration(
                            hintText: 'Текст сообщения пользователю...',
                            filled: true,
                            fillColor: const Color(0xFFF1F5F9),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.all(14),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: (isSending || controller.text.trim().isEmpty) ? null : () async {
                              setModalState(() => isSending = true);
                              try {
                                await AdService.rejectAd(ad.id, reason: controller.text.trim());
                                if (modalContext.mounted) Navigator.pop(modalContext);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Объявление отклонено, пользователь уведомлён ❌'), behavior: SnackBarBehavior.floating));
                                }
                              } catch (e) {
                                if (modalContext.mounted) {
                                  ScaffoldMessenger.of(modalContext).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.redAccent));
                                }
                              } finally {
                                if (modalContext.mounted) setModalState(() => isSending = false);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: isSending
                                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : Text('Отклонить и уведомить', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _handleApprove(AdModel ad) async {
    await AdService.approveAd(ad.id); 
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Объявление успешно одобрено! ✅'), behavior: SnackBarBehavior.floating));
    }
  }

  void _handleArchive(AdModel ad) async {
    await AdService.toggleAdStatus(ad.id, false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Объявление отправлено в архив 📦'), behavior: SnackBarBehavior.floating));
    }
  }

  void _handleDeletePermanently(AdModel ad) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('УДАЛИТЬ НАВСЕГДА?', style: GoogleFonts.inter(fontWeight: FontWeight.w900)),
        content: Text('Вы действительно хотите навсегда удалить объявление "${ad.title}" пользователя ${ad.userName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ОТМЕНА')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('УДАЛИТЬ'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AdService.deleteAd(ad.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Объявление полностью удалено 🗑️'), behavior: SnackBarBehavior.floating));
      }
    }
  }

  void _handleBulkApprove() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      for (var id in _selectedAdIds) { await AdService.approveAd(id); }
      if (mounted) {
        setState(() { _selectedAdIds.clear(); _isSelectionMode = false; });
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _handleBulkDelete() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('УДАЛИТЬ ${_selectedAdIds.length} ОБЪЯВЛЕНИЙ?', style: GoogleFonts.inter(fontWeight: FontWeight.w900)),
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
        try {
          for (var id in _selectedAdIds) { 
            await AdService.deleteAd(id); 
          }
          if (mounted) {
            setState(() { _selectedAdIds.clear(); _isSelectionMode = false; });
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Объявления удалены')));
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка удаления: $e'), backgroundColor: Colors.redAccent));
          }
        }
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showCityFilter(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ФИЛЬТР ПО ГОРОДАМ', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Все города'),
              trailing: _selectedCity == null ? const Icon(Icons.check, color: Color(0xFF6366F1)) : null,
              onTap: () { setState(() => _selectedCity = null); Navigator.pop(context); },
            ),
            ListTile(
              title: const Text('Чунджа'),
              trailing: _selectedCity == 'Чунджа' ? const Icon(Icons.check, color: Color(0xFF6366F1)) : null,
              onTap: () { setState(() => _selectedCity = 'Чунджа'); Navigator.pop(context); },
            ),
            ListTile(
              title: const Text('Алматы'),
              trailing: _selectedCity == 'Алматы' ? const Icon(Icons.check, color: Color(0xFF6366F1)) : null,
              onTap: () { setState(() => _selectedCity = 'Алматы'); Navigator.pop(context); },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() { 
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(PhosphorIcons.package(), size: 60, color: Colors.grey[200]),
          const SizedBox(height: 16),
          Text('НЕТ ОБЪЯВЛЕНИЙ', style: GoogleFonts.inter(color: Colors.grey[300], fontWeight: FontWeight.w900, fontSize: 14)),
        ],
      ),
    );
  }
}
