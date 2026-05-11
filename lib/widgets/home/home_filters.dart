import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iqmarket/data/kazakhstan_locations.dart';

class HomeFilterSheet extends StatefulWidget {
  final String currentSort;
  final double? minPrice;
  final double? maxPrice;
  final String condition;
  final String? city;
  final Function(String sort, double? min, double? max, String cond, String? city) onApply;

  const HomeFilterSheet({
    super.key,
    required this.currentSort,
    this.minPrice,
    this.maxPrice,
    required this.condition,
    this.city,
    required this.onApply,
  });

  @override
  State<HomeFilterSheet> createState() => _HomeFilterSheetState();
}

class _HomeFilterSheetState extends State<HomeFilterSheet> {
  late String _sortBy;
  late double? _minPrice;
  late double? _maxPrice;
  late String _selectedCondition;
  late String? _selectedCity;

  @override
  void initState() {
    super.initState();
    _sortBy = widget.currentSort;
    _minPrice = widget.minPrice;
    _maxPrice = widget.maxPrice;
    _selectedCondition = widget.condition;
    _selectedCity = widget.city;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 20, left: 24, right: 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Фильтры', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: const Color(0xFF1E293B))),
                TextButton(
                  onPressed: () => setState(() {
                    _sortBy = 'newest'; _minPrice = null; _maxPrice = null; _selectedCondition = 'Все'; _selectedCity = null;
                  }),
                  child: Text('Сбросить', style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 30),
            
            _label('Сортировка'),
            const SizedBox(height: 12),
            Wrap(spacing: 8, children: [
              _chip('Сначала новые', _sortBy == 'newest', () => setState(() => _sortBy = 'newest')),
              _chip('Сначала старые', _sortBy == 'oldest', () => setState(() => _sortBy = 'oldest')),
            ]),
            const SizedBox(height: 30),

            _label('Цена (₸)'),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _priceField('От', (val) => setState(() => _minPrice = double.tryParse(val)), _minPrice)),
              const SizedBox(width: 12),
              Expanded(child: _priceField('До', (val) => setState(() => _maxPrice = double.tryParse(val)), _maxPrice)),
            ]),
            const SizedBox(height: 30),

            _label('Состояние'),
            const SizedBox(height: 12),
            Wrap(spacing: 8, children: [
              _chip('Все', _selectedCondition == 'Все', () => setState(() => _selectedCondition = 'Все')),
              _chip('Новый', _selectedCondition == 'Новый', () => setState(() => _selectedCondition = 'Новый')),
              _chip('Б/у', _selectedCondition == 'Б/у', () => setState(() => _selectedCondition = 'Б/у')),
            ]),
            const SizedBox(height: 30),

            _label('Город'),
            const SizedBox(height: 12),
            _citySelector(),
            
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity, height: 60,
              child: ElevatedButton(
                onPressed: () => widget.onApply(_sortBy, _minPrice, _maxPrice, _selectedCondition, _selectedCity),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A80F0), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                child: Text('Применить', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF334155)));

  Widget _chip(String label, bool selected, VoidCallback onSelect) => ChoiceChip(
    label: Text(label), selected: selected, onSelected: (s) => onSelect(),
    selectedColor: const Color(0xFF4A80F0).withValues(alpha: 0.1),
    labelStyle: GoogleFonts.inter(color: selected ? const Color(0xFF4A80F0) : const Color(0xFF64748B), fontWeight: selected ? FontWeight.w800 : FontWeight.w600, fontSize: 13),
    backgroundColor: const Color(0xFFF1F5F9),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: selected ? const Color(0xFF4A80F0) : Colors.transparent)),
    showCheckmark: false,
  );

  Widget _priceField(String hint, Function(String) onChanged, double? current) => Container(
    decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(16)),
    child: TextField(
      onChanged: onChanged, keyboardType: TextInputType.number,
      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
      decoration: InputDecoration(hintText: hint, border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
    ),
  );

  Widget _citySelector() => GestureDetector(
    onTap: _showCityPicker,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Row(children: [
        const Icon(Icons.location_on_rounded, color: Color(0xFF4A80F0), size: 18),
        const SizedBox(width: 12),
        Text(_selectedCity ?? 'Все города', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
        const Spacer(),
        const Icon(Icons.keyboard_arrow_right_rounded, color: Color(0xFF64748B)),
      ]),
    ),
  );

  void _showCityPicker() {
    // Re-use logic for city picking inside filters
  }
}
