import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iqmarket/data/category_data.dart';

class CategorySelector extends StatelessWidget {
  final List<CategoryModel> categories;
  final String selectedCategoryId;
  final String? selectedSubCategoryId;
  final Function(String categoryId) onCategorySelected;
  final Function(String? subCategoryId) onSubCategorySelected;

  const CategorySelector({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    this.selectedSubCategoryId,
    required this.onCategorySelected,
    required this.onSubCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
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
        Text('Категория', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15)),
        const SizedBox(height: 16),
        SizedBox(
          height: 45,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            children: categories.map<Widget>((cat) {
              final isSelected = selectedCategoryId == cat.id;
              return GestureDetector(
                onTap: () => onCategorySelected(cat.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF4A80F0) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      cat.ru,
                      style: GoogleFonts.inter(
                        color: isSelected ? Colors.white : const Color(0xFF64748B),
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
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
                      'Подкатегория',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: selectedCat.subCategories!.map((sub) {
                        final isSelected = selectedSubCategoryId == sub.id;
                        return GestureDetector(
                          onTap: () => onSubCategorySelected(sub.id),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF4A80F0).withValues(alpha: 0.1) : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isSelected ? const Color(0xFF4A80F0) : Colors.grey[300]!),
                            ),
                            child: Text(
                              sub.ru,
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
}
