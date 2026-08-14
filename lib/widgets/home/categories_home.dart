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

    // Локализация подписей (короткие названия во избежание переполнения)
    String transportName = 'Авто';
    String malBazarName = 'МалБазар';
    String electroName = 'Техника';
    String reName = 'Жилье';
    String allCatsName = 'Категории';

    if (lang == 'Қазақша') {
      transportName = 'Авто';
      malBazarName = 'Малбазар';
      electroName = 'Техника';
      reName = 'Мүлік';
      allCatsName = 'Санаттар';
    } else if (lang == 'Уйғурчә') {
      transportName = 'Авто';
      malBazarName = 'Малбазар';
      electroName = 'Техника';
      reName = 'Мүлүк';
      allCatsName = 'Категориялар';
    }

    final bool isTransportSelected = selectedCategoryId == 'Авто';
    final bool isMalBazarSelected = selectedCategoryId == 'Малбазар';
    final bool isElectroSelected = selectedCategoryId == 'Электроника';
    final bool isReSelected = selectedCategoryId == 'Недвижимость';
    
    // "Все категории" считается выбранной, если активен любой другой фильтр, кроме этих четырех
    final bool isAllCatsSelected = selectedCategoryId != 'Все' && 
        !['Авто', 'Малбазар', 'Электроника', 'Недвижимость'].contains(selectedCategoryId);

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 0),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _rowCatItem(
            context,
            transportName,
            Icons.directions_car_rounded,
            () => onCategorySelected('Авто'),
            isSelected: isTransportSelected,
          ),
          _rowCatItem(
            context,
            malBazarName,
            Icons.shopping_basket_rounded,
            () => onCategorySelected('Малбазар'),
            isSelected: isMalBazarSelected,
          ),
          _rowCatItem(
            context,
            electroName,
            Icons.smartphone_rounded,
            () => onCategorySelected('Электроника'),
            isSelected: isElectroSelected,
          ),
          _rowCatItem(
            context,
            reName,
            Icons.home_rounded,
            () => onCategorySelected('Недвижимость'),
            isSelected: isReSelected,
          ),
          _rowCatItem(
            context,
            allCatsName,
            Icons.grid_view_rounded,
            () => _showAllCategoriesSheet(context, lang),
            isSelected: isAllCatsSelected,
          ),
        ],
      ),
    );
  }

  Widget _rowCatItem(BuildContext context, String name, IconData icon, VoidCallback onTap, {bool isSelected = false}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFDBEAFE),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : const Color(0xFF2563EB),
                size: 26,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sheetCatItem(BuildContext context, String name, IconData icon, VoidCallback onTap, {bool isSelected = false}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              icon,
              color: isSelected ? Colors.white : const Color(0xFF2563EB),
              size: 26,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  void _showAllCategoriesSheet(BuildContext context, String lang) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  TranslationService.t('all_categories_title', lang), 
                  style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context), 
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 110,
                  mainAxisSpacing: 20,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.8,
                ),
                itemCount: CategoryData.categories.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _sheetCatItem(
                      context, 
                      TranslationService.t('all', lang), 
                      Icons.grid_view_rounded, 
                      () {
                        onCategorySelected('Все');
                        Navigator.pop(context);
                      },
                      isSelected: selectedCategoryId == 'Все',
                    );
                  }
                  final cat = CategoryData.categories[index - 1];
                  return _sheetCatItem(
                    context, 
                    _getCatName(cat, lang), 
                    cat.icon, 
                    () {
                      onCategorySelected(cat.id);
                      Navigator.pop(context);
                    },
                    isSelected: selectedCategoryId == cat.id,
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
