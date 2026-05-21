import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:iqmarket/models/ad_model.dart';
import 'package:iqmarket/providers/app_config_provider.dart';
import 'package:iqmarket/services/ad_service.dart';
import 'package:iqmarket/widgets/product_card.dart';

class FavoritesScreen extends StatefulWidget {
  final String lang;
  final Map<String, Map<String, dynamic>> themes;
  final String currentTheme;
  final Function(AdModel) onShowDetails;

  const FavoritesScreen({
    super.key, 
    required this.lang,
    required this.themes,
    required this.currentTheme,
    required this.onShowDetails,
  });

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  bool get _isDark => widget.currentTheme == 'Dark';
  Color get _bgColor => widget.themes[widget.currentTheme]?['background'] ?? Theme.of(context).scaffoldBackgroundColor;
  Color get _surfaceColor => widget.themes[widget.currentTheme]?['surface'] ?? Theme.of(context).colorScheme.surface;
  Color get _txtColor => widget.themes[widget.currentTheme]?['text'] ?? Theme.of(context).colorScheme.onSurface;
  Color get _subtxtColor => widget.themes[widget.currentTheme]?['subtext'] ?? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
  Color get _primaryColor => widget.themes[widget.currentTheme]?['primary'] ?? Theme.of(context).colorScheme.primary;

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
    return translations[key]?[widget.lang] ?? translations[key]?['Русский'] ?? key;
  }

  @override
  Widget build(BuildContext context) {
    final favoriteIds = context.watch<AppConfigProvider>().favoriteIds.toList();

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _surfaceColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: _txtColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(_t('title'), style: GoogleFonts.inter(color: _txtColor, fontWeight: FontWeight.w900, fontSize: 18)),
      ),
      body: favoriteIds.isEmpty 
        ? _buildEmptyState()
        : FutureBuilder<List<AdModel>>(
            future: AdService.getAdsByIds(favoriteIds),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              final ads = snapshot.data ?? [];
              if (ads.isEmpty) return _buildEmptyState();

              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.58,
                ),
                itemCount: ads.length,
                itemBuilder: (context, index) {
                  final ad = ads[index];
                  return ProductCard(
                    heroPrefix: 'fav_',
                    ad: ad,
                    onTap: () => widget.onShowDetails(ad),
                    onToggleFavorite: () {
                      context.read<AppConfigProvider>().toggleFavorite(ad.id);
                      setState(() {}); // Refresh future
                    },
                    isFavorite: true,
                  );
                },
              );
            },
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
