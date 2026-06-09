import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:iqmarket/data/category_data.dart';
import 'package:iqmarket/providers/app_config_provider.dart';
import 'package:iqmarket/services/translation_service.dart';

class CategoriesHome extends StatelessWidget {
  final Function(String) onCategorySelected;
  final VoidCallback onTaxiTap;
  final String selectedCategoryId;

  const CategoriesHome({
    super.key, 
    required this.onCategorySelected,
    required this.onTaxiTap,
    this.selectedCategoryId = 'Все',
  });

  String _getCatName(CategoryModel cat, String lang) {
    if (lang == 'Уйғурчә') return cat.ug.isNotEmpty ? cat.ug : cat.ru;
    if (lang == 'Қазақша') return cat.kz.isNotEmpty ? cat.kz : cat.ru;
    return cat.ru;
  }

  @override
  Widget build(BuildContext context) {
    final config = Provider.of<AppConfigProvider>(context);
    final lang = config.language;

    return Container(
      height: 120, // Увеличил высоту для больших иконок
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        physics: const BouncingScrollPhysics(),
        children: [
          // "Все" Категория
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _catItem(
              context,
              TranslationService.t('all', lang), 
              Icons.grid_view_rounded, 
              const Color(0xFF4A80F0),
              () => onCategorySelected('Все'),
              isSelected: selectedCategoryId == 'Все'
            ),
          ),
          
          ...CategoryData.categories.take(7).map((cat) => Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _catItem(
              context,
              _getCatName(cat, lang), 
              cat.icon, 
              cat.color,
              () => onCategorySelected(cat.id),
              isSelected: selectedCategoryId == cat.id
            ),
          )).toList(),
          
          if (CategoryData.categories.length > 7)
            Builder(
              builder: (context) {
                final bool isMoreSelected = selectedCategoryId != 'Все' && 
                    !CategoryData.categories.take(7).any((cat) => cat.id == selectedCategoryId);
                return _catItem(
                  context,
                  TranslationService.t('more_btn', lang),
                  Icons.more_horiz_rounded,
                  const Color(0xFF64748B),
                  () => _showAllCategoriesSheet(context, lang),
                  isSelected: isMoreSelected
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _catItem(BuildContext context, String name, IconData icon, Color color, VoidCallback onTap, {bool isSelected = false}) => GestureDetector(
    onTap: onTap,
    child: Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(16), // Увеличил отступ (было 10)
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF4A80F0) : const Color(0xFFF1F5F9), 
            borderRadius: BorderRadius.circular(20), // More rounded corners
            border: Border.all(
              color: isSelected ? const Color(0xFF4A80F0) : const Color(0xFFE2E8F0),
              width: 2, // Thicker border
            ),
            boxShadow: isSelected ? [
              BoxShadow(
                color: const Color(0xFF4A80F0).withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 6),
              )
            ] : [],
          ),
          child: Icon(
            icon, 
            color: isSelected ? Colors.white : const Color(0xFF4A80F0), 
            size: 26 // Large icon
          ), 
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: 75, // Slightly wider for text
          child: Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 12, 
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600, 
              color: isSelected ? const Color(0xFF4A80F0) : const Color(0xFF1E293B)
            ),
          ),
        ),
      ],
    ),
  );

  void _showAllCategoriesSheet(BuildContext context, String lang) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(TranslationService.t('all_categories_title', lang), style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
                IconButton(
                  onPressed: () => Navigator.pop(context), 
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B))
                ),
              ],
            ),
            const SizedBox(height: 32),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 120,
                  mainAxisSpacing: 24,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.75,
                ),
                itemCount: CategoryData.categories.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _catItem(
                      context, 
                      TranslationService.t('all', lang), 
                      Icons.grid_view_rounded, 
                      const Color(0xFF4A80F0), 
                      () {
                        onCategorySelected('Все');
                        Navigator.pop(context);
                      },
                      isSelected: selectedCategoryId == 'Все'
                    );
                  }
                  final cat = CategoryData.categories[index - 1];
                  return _catItem(
                    context, 
                    _getCatName(cat, lang), 
                    cat.icon, 
                    cat.color, 
                    () {
                      onCategorySelected(cat.id);
                      Navigator.pop(context);
                    },
                    isSelected: selectedCategoryId == cat.id
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
