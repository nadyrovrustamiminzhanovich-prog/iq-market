import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:iqmarket/providers/app_config_provider.dart';
import 'package:iqmarket/services/translation_service.dart';
import 'post_ad_components.dart';

class CarSpecsWidget extends StatelessWidget {
  final String? carBrand;
  final String? carModel;
  final String? carYear;
  final String? carBody;
  final String? carTransmission;
  final String? carDrive;
  final String? carFuel;
  final String? carColor;
  final TextEditingController carMileageController;
  final TextEditingController carEngineController;
  final Function(String, String) onSelect; // (field, value)

  static const Map<String, List<String>> brandModels = {
    'Toyota': ['Camry', 'Land Cruiser', 'Land Cruiser Prado', 'Corolla', 'Hilux', 'RAV4', 'Avalon', 'Carina', 'Caldina', 'Mark II', 'Altezza', 'Avensis', '4Runner', 'Previa', 'Sienna', 'Prius', 'Highlander', 'Fortuner', 'Vitz', 'Yaris'],
    'Lexus': ['RX300', 'RX330', 'RX350', 'LX470', 'LX570', 'LX600', 'GS300', 'GS350', 'ES250', 'ES300', 'ES350', 'GX460', 'GX470', 'IS250', 'LS460', 'NX200', 'NX300'],
    'Mercedes-Benz': ['E-class', 'S-class', 'C-class', 'G-class', 'ML', 'GLE', 'GL', 'GLS', 'A-class', 'B-class', 'CL', 'CLK', 'CLS', 'SL', 'SLK', 'Vito', 'Viano', 'Sprinter', '190 (W201)', '124 (W124)'],
    'BMW': ['3-series', '5-series', '7-series', 'X1', 'X3', 'X4', 'X5', 'X6', 'X7', 'M3', 'M5', 'Z4'],
    'Audi': ['100', '80', 'A3', 'A4', 'A6', 'A8', 'Q3', 'Q5', 'Q7', 'Q8', 'TT'],
    'Hyundai': ['Accent', 'Elantra', 'Sonata', 'Tucson', 'Santa Fe', 'Creta', 'Getz', 'i30', 'i40', 'Solaris', 'H-1', 'Starex'],
    'Kia': ['Rio', 'Sportage', 'Cerato', 'Sorento', 'Optima', 'K5', 'K7', 'Soul', 'Picanto', 'Carnival', 'Ceed', 'Mohave'],
    'Nissan': ['Patrol', 'Qashqai', 'Juke', 'Terrano', 'X-Trail', 'Almera', 'Maxima', 'Primera', 'Skyline', 'Teana', 'Tiida', 'Murano', 'Pathfinder'],
    'Honda': ['Civic', 'Accord', 'CR-V', 'Fit', 'HR-V', 'Odyssey', 'Pilot', 'Legend', 'Stream', 'Stepwgn'],
    'Lada (ВАЗ)': ['2101', '2105', '2106', '2107', '2108', '2109', '21099', '2110', '2112', '2114', '2115', 'Priora', 'Granta', 'Vesta', 'Niva', 'Kalina', 'Largus'],
    'Mitsubishi': ['Lancer', 'Galant', 'Pajero', 'Pajero Sport', 'Outlander', 'Montero', 'ASX', 'Delica', 'Carisma', 'Eclipse'],
    'Mazda': ['Mazda3', 'Mazda6', 'CX-5', 'CX-7', 'CX-9', '323', '626', 'MPV', 'RX-8'],
    'Chevrolet': ['Nexia', 'Cobalt', 'Lacetti', 'Aveo', 'Cruze', 'Captiva', 'Spark', 'Tahoe', 'Suburban', 'Camaro', 'Equinox', 'Malibu'],
    'Volkswagen': ['Golf', 'Passat', 'Polo', 'Jetta', 'Tiguan', 'Touareg', 'Transporter', 'Multivan', 'Caddy', 'Bora', 'Vento', 'Sharan'],
    'Subaru': ['Forester', 'Impreza', 'Legacy', 'Outback', 'XV', 'Tribeca'],
    'Ford': ['Focus', 'Mondeo', 'Fiesta', 'Explorer', 'Escape', 'Transit', 'Ranger', 'F-150'],
    'Renault': ['Logan', 'Duster', 'Sandero', 'Kaptur', 'Megan', 'Fluence', 'Scenic'],
    'Daewoo': ['Nexia', 'Matiz', 'Gentra', 'Lacetti', 'Lanos', 'Leganza'],
    'Ravon': ['R2', 'R3', 'R4', 'Gentra'],
    'Geely': ['Atlas', 'Coolray', 'Monjaro', 'Tugella', 'Emgrand', 'Okavango'],
    'Chery': ['Tiggo 2', 'Tiggo 4', 'Tiggo 7', 'Tiggo 8', 'Arrizo'],
    'Haval': ['F7', 'Jolion', 'H6', 'H9', 'Dargo'],
    'Changan': ['CS35', 'CS55', 'CS75', 'UNI-K', 'UNI-V'],
    'Exeed': ['LX', 'TXL', 'VX', 'RX'],
    'JAC': ['J7', 'S3', 'S5', 'T6', 'T8', 'iEV7S'],
    'Zeekr': ['001', '009', 'X'],
    'Li Auto (Lixiang)': ['L7', 'L8', 'L9', 'One'],
    'Porsche': ['Cayenne', 'Panamera', 'Macan', '911', 'Taycan'],
    'Land Rover': ['Range Rover', 'Range Rover Sport', 'Evoque', 'Discovery', 'Defender', 'Freelander'],
    'Volvo': ['S60', 'S80', 'S90', 'XC60', 'XC90', 'V40'],
    'Skoda': ['Octavia', 'Superb', 'Rapid', 'Kodiaq', 'Yeti', 'Fabia'],
    'Tesla': ['Model 3', 'Model Y', 'Model S', 'Model X'],
    'Другая': [],
  };

  const CarSpecsWidget({
    super.key,
    this.carBrand,
    this.carModel,
    this.carYear,
    this.carBody,
    this.carTransmission,
    this.carDrive,
    this.carFuel,
    this.carColor,
    required this.carMileageController,
    required this.carEngineController,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final config = Provider.of<AppConfigProvider>(context);
    final lang = config.language;
    final List<String> availableModels = carBrand != null ? (brandModels[carBrand] ?? []) : [];
    
    return PostAdSpecsContainer(
      title: TranslationService.t('car_specs', lang),
      icon: Icons.directions_car_rounded,
      color: const Color(0xFF1E293B),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _SelectorField('Марка', carBrand, brandModels.keys.toList(), (val) => onSelect('carBrand', val))),
              const SizedBox(width: 12),
              Expanded(child: _SelectorField('Модель', carModel, availableModels.isNotEmpty ? availableModels : ['Сначала выберите марку'], (val) => onSelect('carModel', val))),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _SelectorField('Год', carYear, List.generate(45, (i) => (2025 - i).toString()), (val) => onSelect('carYear', val))),
              const SizedBox(width: 12),
              Expanded(child: _SelectorField('Кузов', carBody, ['Седан', 'Внедорожник', 'Хэтчбек', 'Универсал', 'Купе', 'Минивэн', 'Пикап', 'Кабриолет', 'Лимузин'], (val) => onSelect('carBody', val))),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _SelectorField('КПП', carTransmission, ['Автомат', 'Механика', 'Вариатор', 'Робот'], (val) => onSelect('carTransmission', val))),
              const SizedBox(width: 12),
              Expanded(child: _SelectorField('Привод', carDrive, ['Передний', 'Задний', 'Полный'], (val) => onSelect('carDrive', val))),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _SelectorField('Топливо', carFuel, ['Бензин', 'Дизель', 'Газ-Бензин', 'Газ', 'Гибрид', 'Электро'], (val) => onSelect('carFuel', val))),
              const SizedBox(width: 12),
              Expanded(child: _SelectorField('Цвет', carColor, ['Белый', 'Черный', 'Серебристый', 'Серый', 'Синий', 'Красный', 'Зеленый', 'Желтый', 'Коричневый', 'Бежевый', 'Оранжевый', 'Фиолетовый'], (val) => onSelect('carColor', val))),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: PostAdInput(label: TranslationService.t('car_engine', lang), controller: carEngineController, hint: '2.5', keyboardType: const TextInputType.numberWithOptions(decimal: true))),
              const SizedBox(width: 12),
              Expanded(child: PostAdInput(label: TranslationService.t('car_mileage', lang), controller: carMileageController, hint: '150 000', keyboardType: TextInputType.number)),
            ],
          ),
        ],
      ),
    );
  }
}


class RealEstateSpecsWidget extends StatelessWidget {
  final String? reRooms;
  final String? reFloor;
  final TextEditingController reAreaController;
  final Function(String, String) onSelect;

  const RealEstateSpecsWidget({
    super.key,
    this.reRooms,
    this.reFloor,
    required this.reAreaController,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final config = Provider.of<AppConfigProvider>(context);
    final lang = config.language;

    return PostAdSpecsContainer(
      title: TranslationService.t('re_specs', lang),
      icon: Icons.home_work_rounded,
      color: const Color(0xFF1E293B),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _SelectorField('Комнат', reRooms, ['1', '2', '3', '4', '5+'], (val) => onSelect('reRooms', val))),
              const SizedBox(width: 12),
              Expanded(child: _SelectorField('Этаж', reFloor, List.generate(20, (i) => (i + 1).toString()), (val) => onSelect('reFloor', val))),
            ],
          ),
          const SizedBox(height: 16),
          PostAdInput(label: TranslationService.t('re_area', lang), controller: reAreaController, hint: '45.5', keyboardType: const TextInputType.numberWithOptions(decimal: true)),
        ],
      ),
    );
  }
}

class LivestockSpecsWidget extends StatelessWidget {
  final String? malAge;
  final TextEditingController malWeightController;
  final TextEditingController malBreedController;
  final Function(String, String) onSelect;

  const LivestockSpecsWidget({
    super.key,
    this.malAge,
    required this.malWeightController,
    required this.malBreedController,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final config = Provider.of<AppConfigProvider>(context);
    final lang = config.language;

    return PostAdSpecsContainer(
      title: TranslationService.t('livestock_specs', lang),
      icon: Icons.pets_rounded,
      color: const Color(0xFF1E293B),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _SelectorField('Возраст', malAge, ['Молодняк', '1 год', '2 года', '3+ года'], (val) => onSelect('malAge', val))),
              const SizedBox(width: 12),
              Expanded(child: PostAdInput(label: TranslationService.t('livestock_weight', lang), controller: malWeightController, hint: '250', keyboardType: TextInputType.number)),
            ],
          ),
          const SizedBox(height: 16),
          PostAdInput(label: TranslationService.t('livestock_breed', lang), controller: malBreedController, hint: '...'),
        ],
      ),
    );
  }
}

class _SelectorField extends StatelessWidget {
  final String label;
  final String? selectedValue;
  final List<String> options;
  final Function(String) onSelected;

  const _SelectorField(this.label, this.selectedValue, this.options, this.onSelected);

  @override
  Widget build(BuildContext context) {
    final config = Provider.of<AppConfigProvider>(context);
    final lang = config.language;

    String displayLabel = label;
    if (label == 'Марка') displayLabel = TranslationService.t('car_brand', lang);
    else if (label == 'Модель') displayLabel = TranslationService.t('car_model', lang);
    else if (label == 'Год') displayLabel = TranslationService.t('car_year', lang);
    else if (label == 'Кузов') displayLabel = TranslationService.t('car_body', lang);
    else if (label == 'КПП') displayLabel = TranslationService.t('car_transmission', lang);
    else if (label == 'Привод') displayLabel = TranslationService.t('car_drive', lang);
    else if (label == 'Топливо') displayLabel = TranslationService.t('car_fuel', lang);
    else if (label == 'Цвет') displayLabel = TranslationService.t('car_color', lang);
    else if (label == 'Комнат') displayLabel = TranslationService.t('re_rooms', lang);
    else if (label == 'Этаж') displayLabel = TranslationService.t('re_floor', lang);
    else if (label == 'Возраст') displayLabel = TranslationService.t('livestock_age', lang);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(displayLabel, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.grey[700])),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _showOptionsPicker(context, displayLabel, options, onSelected, lang),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    selectedValue != null ? TranslationService.translateSpecValue(selectedValue!, lang) : TranslationService.t('select_value', lang),
                    style: GoogleFonts.inter(
                      fontSize: 14, 
                      fontWeight: selectedValue != null ? FontWeight.w600 : FontWeight.w400,
                      color: selectedValue != null ? Colors.black : Colors.grey[500],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showOptionsPicker(BuildContext context, String title, List<String> options, Function(String) onSelected, String lang) {
    String searchQuery = "";
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final filtered = options.where((o) {
            if (o == 'Сначала выберите марку') return true;
            final translated = TranslationService.translateSpecValue(o, lang);
            return o.toLowerCase().contains(searchQuery.toLowerCase()) || 
                   translated.toLowerCase().contains(searchQuery.toLowerCase());
          }).toList();
          return Container(
            height: options.length > 10 ? MediaQuery.of(context).size.height * 0.8 : null,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                const SizedBox(height: 16),
                Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18)),
                const SizedBox(height: 16),
                if (options.length > 8) ...[
                  TextField(
                    onChanged: (v) => setModalState(() => searchQuery = v),
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      hintText: TranslationService.t('search_hint_dialog', lang),
                      prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF4A80F0)),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      String itemText = filtered[index];
                      if (itemText == 'Сначала выберите марку') {
                        itemText = lang == 'Уйғурчә' ? 'Аввал маркини таллаң' : (lang == 'Қазақша' ? 'Алдымен марканы таңдаңыз' : itemText);
                      } else {
                        itemText = TranslationService.translateSpecValue(itemText, lang);
                      }
                      return ListTile(
                        title: Text(itemText, textAlign: TextAlign.center, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                        onTap: () {
                          onSelected(filtered[index]);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        }
      ),
    );
  }
}
