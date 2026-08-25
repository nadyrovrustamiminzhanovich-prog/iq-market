import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:iqmarket/data/category_data.dart';
import 'package:iqmarket/providers/app_config_provider.dart';
import 'package:iqmarket/services/translation_service.dart';

class CategorySelector extends StatelessWidget {
  final List<CategoryModel> categories;
  final String selectedCategoryId;
  final String? selectedSubCategoryId;
  final Function(String categoryId) onCategorySelected;
  final Function(String? subCategoryId) onSubCategorySelected;

  final bool isAutoDetected;

  const CategorySelector({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    this.selectedSubCategoryId,
    required this.onCategorySelected,
    required this.onSubCategorySelected,
    this.isAutoDetected = false,
  });

  String _getCatName(CategoryModel cat, String lang) {
    if (lang == 'Уйғурчә') return cat.ug.isNotEmpty ? cat.ug : cat.ru;
    if (lang == 'Қазақша') return cat.kz.isNotEmpty ? cat.kz : cat.ru;
    return cat.ru;
  }

  String _getSubCatName(SubCategoryModel sub, String lang) {
    if (lang == 'Уйғурчә') return sub.ug.isNotEmpty ? sub.ug : sub.ru;
    if (lang == 'Қазақша') return sub.kz.isNotEmpty ? sub.kz : sub.ru;
    return sub.ru;
  }

  @override
  Widget build(BuildContext context) {
    final config = Provider.of<AppConfigProvider>(context);
    final lang = config.language;

    final selectedCat = categories.firstWhere(
      (c) => c.id == selectedCategoryId,
      orElse: () => CategoryModel(
        id: '', 
        ru: '', 
        kz: '', 
        ug: '', 
        icon: Icons.error, 
        color: Colors.transparent,
      ),
    );

    final bool hasSubcategories = selectedCategoryId != 'all' && 
                                  selectedCategoryId.isNotEmpty && 
                                  selectedCat.id.isNotEmpty && 
                                  selectedCat.subCategories != null && 
                                  selectedCat.subCategories!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(TranslationService.t('category_label', lang), style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15, color: const Color(0xFF0F172A))),
            if (isAutoDetected && selectedCategoryId != 'all' && selectedCategoryId.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: Color(0xFF10B981), size: 13),
                    const SizedBox(width: 4),
                    Text(
                      'Автовыбор',
                      style: GoogleFonts.inter(color: const Color(0xFF047857), fontWeight: FontWeight.w800, fontSize: 11),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            children: [
              GestureDetector(
                onTap: () => _showAllCategoriesBottomSheet(context, categories, selectedCategoryId, lang),
                child: Container(
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.grid_view_rounded, color: Color(0xFF334155), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        TranslationService.t('all_categories_title', lang),
                        style: GoogleFonts.inter(
                          color: const Color(0xFF334155),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              ...categories.map<Widget>((cat) {
                final isSelected = selectedCategoryId == cat.id;
                return GestureDetector(
                  onTap: () => onCategorySelected(cat.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFEBF3FF) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF1A73E8) : const Color(0xFFF1F5F9),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          cat.icon,
                          color: isSelected ? const Color(0xFF1A73E8) : const Color(0xFF334155),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _getCatName(cat, lang),
                          style: GoogleFonts.inter(
                            color: isSelected ? const Color(0xFF1A73E8) : const Color(0xFF334155),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: hasSubcategories
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    Text(
                      TranslationService.t('subcategory_label', lang),
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: selectedCat.subCategories!.map((sub) {
                        final isSelected = selectedSubCategoryId == sub.id;
                        return GestureDetector(
                          onTap: () {
                            if (isSelected) {
                              onSubCategorySelected(null);
                            } else {
                              onSubCategorySelected(sub.id);
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF4A80F0).withValues(alpha: 0.1) : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isSelected ? const Color(0xFF4A80F0) : Colors.grey[300]!),
                            ),
                            child: Text(
                              _getSubCatName(sub, lang),
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected ? const Color(0xFF4A80F0) : Colors.grey[700],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                )
              : const SizedBox(width: double.infinity, height: 0),
        ),
      ],
    );
  }

  void _showAllCategoriesBottomSheet(BuildContext context, List<CategoryModel> categories, String selectedId, String lang) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                TranslationService.t('category_label', lang),
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.95,
                  ),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    final isSelected = selectedId == cat.id;
                    return GestureDetector(
                      onTap: () {
                        onCategorySelected(cat.id);
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFEBF3FF) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF1A73E8) : const Color(0xFFE2E8F0),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              cat.icon,
                              color: isSelected ? const Color(0xFF1A73E8) : const Color(0xFF475569),
                              size: 24,
                            ),
                            const SizedBox(height: 5),
                            Flexible(
                              child: Text(
                                _getCatName(cat, lang),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 10.5,
                                  height: 1.15,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected ? const Color(0xFF1A73E8) : const Color(0xFF475569),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
