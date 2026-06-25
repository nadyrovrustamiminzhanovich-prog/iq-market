import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:iqmarket/providers/app_config_provider.dart';
import 'package:iqmarket/services/translation_service.dart';

class LocationSelector extends StatelessWidget {
  final String selectedLocation;
  final List<String> displayCities;
  final Function(String location) onLocationSelected;

  const LocationSelector({
    super.key,
    required this.selectedLocation,
    required this.displayCities,
    required this.onLocationSelected,
  });

  @override
  Widget build(BuildContext context) {
    final config = Provider.of<AppConfigProvider>(context);
    final lang = config.language;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(TranslationService.t('select_city', lang), style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15)),
        const SizedBox(height: 12),
        InkWell(
          onTap: () => _showOptions(context, lang),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(16)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(selectedLocation, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                const Icon(Icons.keyboard_arrow_down_rounded),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showOptions(BuildContext context, String lang) {
    String searchQuery = "";
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final filtered = displayCities.where((o) => o.toLowerCase().contains(searchQuery.toLowerCase())).toList();
          return Container(
            height: MediaQuery.of(context).size.height * 0.8,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                Text(TranslationService.t('select_city', lang), style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18)),
                const SizedBox(height: 20),
                TextField(
                  onChanged: (v) => setModalState(() => searchQuery = v),
                  style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: TranslationService.t('search_city', lang),
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF4A80F0)),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, i) => ListTile(
                      title: Text(filtered[i], style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                      trailing: selectedLocation == filtered[i] ? const Icon(Icons.check_circle, color: Color(0xFF4A80F0)) : null,
                      onTap: () {
                        onLocationSelected(filtered[i]);
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
