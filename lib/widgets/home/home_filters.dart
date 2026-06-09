import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:iqmarket/providers/app_config_provider.dart';
import 'package:iqmarket/services/translation_service.dart';
import 'package:iqmarket/data/kazakhstan_locations.dart';

class PriceInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    final text = newValue.text.replaceAll(' ', '');
    final intValue = int.tryParse(text);
    if (intValue == null) return oldValue;
    final newText = intValue.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]} ');
    int offset = newValue.selection.end;
    if (offset >= newValue.text.length && newValue.text.length < newText.length) {
      offset += newText.length - newValue.text.length;
    }
    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: offset > newText.length ? newText.length : offset),
    );
  }
}

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
  late TextEditingController _minController;
  late TextEditingController _maxController;

  @override
  void initState() {
    super.initState();
    _sortBy = widget.currentSort;
    _minPrice = widget.minPrice;
    _maxPrice = widget.maxPrice;
    _selectedCondition = widget.condition;
    _selectedCity = widget.city;
    
    _minController = TextEditingController(text: _minPrice != null ? _minPrice!.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]} ') : '');
    _maxController = TextEditingController(text: _maxPrice != null ? _maxPrice!.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]} ') : '');
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<AppConfigProvider>(context).language;
    String _t(String key) => TranslationService.t(key, lang);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
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
                Text(_t('filters_title'), style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.onSurface)),
                TextButton(
                  onPressed: () => setState(() {
                    _sortBy = 'newest'; _minPrice = null; _maxPrice = null; _selectedCondition = 'Все'; _selectedCity = null;
                    _minController.clear(); _maxController.clear();
                  }),
                  child: Text(_t('reset'), style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 30),
            
            _label(_t('sorting')),
            const SizedBox(height: 12),
            Wrap(spacing: 8, children: [
              _chip(_t('newest_first'), _sortBy == 'newest', () => setState(() => _sortBy = 'newest')),
              _chip(_t('oldest_first'), _sortBy == 'oldest', () => setState(() => _sortBy = 'oldest')),
            ]),
            const SizedBox(height: 30),

            _label(_t('price_tenge')),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _priceField(_t('price_from'), (val) => setState(() => _minPrice = double.tryParse(val.replaceAll(' ', ''))), _minController)),
              const SizedBox(width: 12),
              Expanded(child: _priceField(_t('price_to'), (val) => setState(() => _maxPrice = double.tryParse(val.replaceAll(' ', ''))), _maxController)),
            ]),
            const SizedBox(height: 30),

            _label(_t('condition')),
            const SizedBox(height: 12),
            Wrap(spacing: 8, children: [
              _chip(_t('cond_all'), _selectedCondition == 'Все', () => setState(() => _selectedCondition = 'Все')),
              _chip(_t('cond_new'), _selectedCondition == 'Новый', () => setState(() => _selectedCondition = 'Новый')),
              _chip(_t('cond_used'), _selectedCondition == 'Б/у', () => setState(() => _selectedCondition = 'Б/у')),
            ]),
            const SizedBox(height: 30),

            _label(_t('city')),
            const SizedBox(height: 12),
            _citySelector(_t),
            
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity, height: 60,
              child: ElevatedButton(
                onPressed: () => widget.onApply(_sortBy, _minPrice, _maxPrice, _selectedCondition, _selectedCity),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A80F0), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                child: Text(_t('apply'), style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8)));

  Widget _chip(String label, bool selected, VoidCallback onSelect) => ChoiceChip(
    label: Text(label), selected: selected, onSelected: (s) => onSelect(),
    selectedColor: const Color(0xFF4A80F0).withValues(alpha: 0.1),
    labelStyle: GoogleFonts.inter(color: selected ? const Color(0xFF4A80F0) : const Color(0xFF64748B), fontWeight: selected ? FontWeight.w800 : FontWeight.w600, fontSize: 13),
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: selected ? const Color(0xFF4A80F0) : Colors.transparent)),
    showCheckmark: false,
  );

  Widget _priceField(String hint, Function(String) onChanged, TextEditingController controller) => Container(
    decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(16)),
    child: TextField(
      controller: controller,
      onChanged: onChanged, keyboardType: TextInputType.number,
      inputFormatters: [PriceInputFormatter()],
      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
      decoration: InputDecoration(hintText: hint, border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
    ),
  );

  Widget _citySelector(String Function(String) _t) => GestureDetector(
    onTap: () => _showCityPicker(_t),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(16), border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5))),
      child: Row(children: [
        const Icon(Icons.location_on_rounded, color: Color(0xFF4A80F0), size: 18),
        const SizedBox(width: 12),
        Text(_selectedCity ?? _t('all_cities'), style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
        const Spacer(),
        const Icon(Icons.keyboard_arrow_right_rounded, color: Color(0xFF64748B)),
      ]),
    ),
  );

  void _showCityPicker(String Function(String) _t) {
    String searchCity = '';
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final allCities = KazakhstanLocations.getAllLocations();
            final filteredCities = searchCity.isEmpty 
                ? allCities 
                : allCities.where((c) => c.toLowerCase().contains(searchCity.toLowerCase())).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              padding: const EdgeInsets.only(top: 20, left: 20, right: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 15),
                  Text(
                    _t('select_city'),
                    style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.onSurface),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    onChanged: (v) => setModalState(() => searchCity = v),
                    style: GoogleFonts.inter(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w800),
                    decoration: InputDecoration(
                      hintText: _t('search_by_name'),
                      hintStyle: GoogleFonts.inter(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontWeight: FontWeight.w600),
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Expanded(
                    child: ListView.builder(
                      itemCount: searchCity.isEmpty ? filteredCities.length + 1 : filteredCities.length,
                      itemBuilder: (context, index) {
                        final isAll = searchCity.isEmpty && index == 0;
                        final cityName = isAll ? _t('all_cities') : filteredCities[searchCity.isEmpty ? index - 1 : index];
                        final isSelected = isAll ? _selectedCity == null : _selectedCity == cityName;
                        return ListTile(
                          onTap: () {
                            setState(() {
                              _selectedCity = isAll ? null : cityName;
                            });
                            Navigator.pop(ctx);
                          },
                          leading: Icon(
                            Icons.location_on_rounded,
                            color: isSelected ? const Color(0xFF4A80F0) : Colors.grey,
                          ),
                          title: Text(
                            cityName,
                            style: GoogleFonts.inter(
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: isSelected ? const Color(0xFF4A80F0) : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          trailing: isSelected ? const Icon(Icons.check_rounded, color: Color(0xFF4A80F0)) : null,
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
