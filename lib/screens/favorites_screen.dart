import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FavoritesScreen extends StatelessWidget {
  final List<Map<String, dynamic>> favoriteAds;
  final Function(Map<String, dynamic>) onUnfavorite;
  final Function(Map<String, dynamic>) onShowDetails;
  final String lang;
  final Map<String, Map<String, dynamic>> themes;
  final String currentTheme;

  const FavoritesScreen({
    super.key, 
    required this.favoriteAds, 
    required this.onUnfavorite,
    required this.onShowDetails,
    required this.lang,
    required this.themes,
    required this.currentTheme,
  });

  bool get _isDark => currentTheme == 'Dark';
  Color get _bgColor => themes[currentTheme]?['background'] ?? const Color(0xFFF1F5F9);
  Color get _surfaceColor => themes[currentTheme]?['surface'] ?? Colors.white;
  Color get _txtColor => themes[currentTheme]?['text'] ?? const Color(0xFF1A1D1E);
  Color get _subtxtColor => themes[currentTheme]?['subtext'] ?? const Color(0xFF64748B);
  Color get _primaryColor => themes[currentTheme]?['primary'] ?? const Color(0xFF4A80F0);

  String _t(String key) {
    final translations = {
      'title': { 'Русский': 'Избранное', 'Қазақша': 'Таңдаулы', 'Уйғурчә': 'Талланған' },
      'empty_title': { 'Русский': 'Пока ничего нет', 'Қазақша': 'Әлі ештеңе жоқ', 'Уйғурчә': 'Һеч нәрсә йоқ' },
      'empty_subtitle': { 
        'Русский': 'Добавляйте товары в избранное, чтобы не потерять их', 
        'Қазақша': 'Тауарларды жоғалтып алмау үшін таңдаулыларға қосыңыз', 
        'Уйғурчә': 'Дөләтләрни йоқитип қоймаслиқ үчүн талланғанларға қошуш' 
      },
    };
    return translations[key]?[lang] ?? translations[key]?['Русский'] ?? key;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: _txtColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(_t('title'), style: GoogleFonts.inter(color: _txtColor, fontWeight: FontWeight.w900, fontSize: 18)),
      ),
      body: favoriteAds.isEmpty 
        ? _buildEmptyState()
        : GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.75,
            ),
            itemCount: favoriteAds.length,
            itemBuilder: (context, index) => _buildAdCard(context, favoriteAds[index]),
          ),
    );
  }

  Widget _buildAdCard(BuildContext context, Map<String, dynamic> ad) {
    return GestureDetector(
      onTap: () => onShowDetails(ad),
      child: Container(
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _isDark ? _txtColor.withValues(alpha: 0.1) : Colors.transparent),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    child: Image.network(ad['images'][0], fit: BoxFit.cover, width: double.infinity),
                  ),
                  Positioned(
                    top: 8, right: 8,
                    child: GestureDetector(
                      onTap: () => onUnfavorite(ad),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: const Icon(Icons.favorite_rounded, color: Colors.red, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ad['price'], style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16, color: _primaryColor)),
                  const SizedBox(height: 4),
                  Text(ad['title'], maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: _txtColor)),
                  const SizedBox(height: 4),
                  Text(ad['location'], style: GoogleFonts.inter(color: _subtxtColor, fontSize: 11, fontWeight: FontWeight.w500)),
                ],
              ),
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
          Icon(Icons.favorite_border_rounded, size: 80, color: _subtxtColor.withValues(alpha: 0.2)),
          const SizedBox(height: 20),
          Text(_t('empty_title'), style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: _txtColor)),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(_t('empty_subtitle'), textAlign: TextAlign.center, style: GoogleFonts.inter(color: _subtxtColor, fontSize: 14, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
