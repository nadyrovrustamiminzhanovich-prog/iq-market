import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CategoriesHome extends StatelessWidget {
  final Function(String) onCategorySelected;
  final VoidCallback onTaxiTap;

  const CategoriesHome({
    super.key, 
    required this.onCategorySelected,
    required this.onTaxiTap,
  });

  @override
  Widget build(BuildContext context) {
    final cats = [
      {'n': 'Транспорт', 'i': Icons.directions_car_rounded, 'c': const Color(0xFF4A80F0)},
      {'n': 'Недвижимость', 'i': Icons.home_rounded, 'c': const Color(0xFFF97316)},
      {'n': 'Электроника', 'i': Icons.smartphone_rounded, 'c': const Color(0xFF8B5CF6)},
      {'n': 'Животные', 'i': Icons.pets_rounded, 'c': const Color(0xFF10B981)},
      {'n': 'Ещё', 'i': Icons.grid_view_rounded, 'c': const Color(0xFF64748B)},
    ];

    return Container(
      height: 100,
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: cats.map((cat) => _catItem(
          context,
          cat['n'] as String, 
          cat['i'] as IconData, 
          cat['c'] as Color
        )).toList(),
      ),
    );
  }

  Widget _catItem(BuildContext context, String name, IconData icon, Color color) => GestureDetector(
    onTap: () {
      if (name == 'Транспорт') {
        onTaxiTap();
      } else {
        onCategorySelected(name == 'Ещё' ? 'Все' : name);
      }
    },
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03), 
                blurRadius: 10, 
                offset: const Offset(0, 4)
              ),
            ],
          ),
          child: Icon(icon, color: const Color(0xFF1E293B), size: 28),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: 70,
          child: Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 11, 
              fontWeight: FontWeight.w600, 
              color: const Color(0xFF64748B)
            ),
          ),
        ),
      ],
    ),
  );
}
