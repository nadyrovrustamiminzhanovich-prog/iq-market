import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:iqmarket/data/kazakhstan_locations.dart';
import 'package:iqmarket/services/storage_service.dart';
import 'package:iqmarket/services/location_service.dart';
import 'package:path/path.dart' as p;
import 'package:iqmarket/screens/video_editor_screen.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:iqmarket/services/analytics_service.dart';
import 'package:iqmarket/services/ad_service.dart';
import 'package:iqmarket/services/file_service.dart';

class PostAdScreen extends StatefulWidget {
  final String lang;
  final Map<String, dynamic>? initialAd;
  const PostAdScreen({super.key, required this.lang, this.initialAd});

  @override
  State<PostAdScreen> createState() => _PostAdScreenState();
}

class _PostAdScreenState extends State<PostAdScreen> {
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController(text: "Чунджа (Шонжы)");
  final _streetController = TextEditingController();
  final _houseController = TextEditingController();
  
  // Поля для Авто (Kolesa-style)
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _engineVolumeController = TextEditingController(text: "2.0");
  String _fuelType = "Бензин";
  String _transmission = "Автомат";
  String _drive = "Передний";
  String _steering = "Слева";
  bool _customsCleared = true;
  String _color = "Белый";

  // Константы для выбора (переводим ниже)
  List<String> get _fuelTypes => widget.lang == 'Қазақша' ? ["Бензин", "Дизель", "Газ", "Гибрид", "Электро"] : widget.lang == 'Уйғурчә' ? ["Бензин", "Дизель", "Газ", "Гибрид", "Электр"] : ["Бензин", "Дизель", "Газ", "Гибрид", "Электро"];
  List<String> get _transmissions => widget.lang == 'Қазақша' ? ["Автомат", "Механика", "Типтроник", "Вариатор"] : widget.lang == 'Уйғурчә' ? ["Автомат", "Механика", "Типтроник", "Вариатор"] : ["Автомат", "Механика", "Типтроник", "Вариатор"];
  List<String> get _drives => widget.lang == 'Қазақша' ? ["Алдыңғы", "Артқы", "Толық"] : widget.lang == 'Уйғурчә' ? ["Алдинқи", "Кәйни", "Толуқ"] : ["Передний", "Задний", "Полный"];
  List<String> get _steerings => widget.lang == 'Қазақша' ? ["Сол жақта", "Оң жақта"] : widget.lang == 'Уйғурчә' ? ["Сол тарипида", "Оң тарипида"] : ["Слева", "Справа"];
  final List<Map<String, dynamic>> _colors = [
    {"name": "Белый", "color": Colors.white}, {"name": "Черный", "color": Colors.black},
    {"name": "Серебристый", "color": const Color(0xFFC0C0C0)}, {"name": "Серый", "color": Colors.grey},
    {"name": "Синий", "color": Colors.blue.shade900}, {"name": "Красный", "color": Colors.red.shade900},
    {"name": "Зеленый", "color": Colors.green.shade900}, {"name": "Коричневый", "color": Colors.brown},
    {"name": "Бежевый", "color": const Color(0xFFF5F5DC)}, {"name": "Золотистый", "color": const Color(0xFFFFD700)},
    {"name": "Оранжевый", "color": Colors.orange}, {"name": "Фиолетовый", "color": Colors.purple},
  ];

  // Поля для Малбазар
  final _animalTypeController = TextEditingController();
  final _weightController = TextEditingController();
  
  // Поля для Работа
  final _jobPositionController = TextEditingController();
  final _experienceController = TextEditingController();

  final _sizeController = TextEditingController();
  final _conditionController = TextEditingController();
  final _ageController = TextEditingController();

  File? _image;
  bool _isVideo = false;
  final ImagePicker _picker = ImagePicker();
  bool _isImprovingPhoto = false;
  bool _bargainAvailable = false;
  String _condition = 'Б/У';
  String? _initialImageUrl;
  String _selectedCategory = 'Все';
  bool _isLoading = false;

  String _t(String key) {
    final translations = {
      'screen_title': { 'Русский': 'Создать объявление', 'Қазақша': 'Хабарландыру жасау', 'Уйғурчә': 'Елан қуруш' },
      'photo': { 'Русский': 'Фотография', 'Қазақша': 'Фотосурет', 'Уйғурчә': 'Сүрәт' },
      'add_photo': { 'Русский': 'Добавить фото', 'Қазақша': 'Фото қосу', 'Уйғурчә': 'Сүрәт қошуш' },
      'main_info': { 'Русский': 'Основные сведения', 'Қазақша': 'Негізгі мәліметтер', 'Уйғурчә': 'Асасий учурлар' },
      'price_label': { 'Русский': 'Цена (₸)', 'Қазақша': 'Бағасы (₸)', 'Уйғурчә': 'Баһаси (₸)' },
      'bargain': { 'Русский': 'Торг', 'Қазақша': 'Саудаласу', 'Уйғурчә': 'Сода' },
      'location': { 'Русский': 'Местоположение', 'Қазақша': 'Орналасқан жері', 'Уйғурчә': 'Орны' },
      'choose_city': { 'Русский': 'Выберите город', 'Қазақша': 'Қаланы таңдаңыз', 'Уйғурчә': 'Шәһәр таллаң' },
      'category_title': { 'Русский': 'Выберите категорию', 'Қазақша': 'Санатты таңдаңыз', 'Уйғурчә': 'Категория таллаң' },
      'description': { 'Русский': 'Описание', 'Қазақша': 'Сипаттамасы', 'Уйғурчә': 'Тәсвирлиниши' },
      'ai_magic': { 'Русский': 'Магия ИИ ✨', 'Қазақша': 'ИИ сиқыры ✨', 'Уйғурчә': 'ИИ сеһири ✨' },
      'publish': { 'Русский': 'Опубликовать', 'Қазақша': 'Жариялау', 'Уйғурчә': 'Елан қилиш' },
      'customs': { 'Русский': 'Растаможен в КЗ', 'Қазақша': 'Кеденнен өткен', 'Уйғурчә': 'Растаможка болған' },
      'street': { 'Русский': 'Улица', 'Қазақша': 'Көше', 'Уйғурчә': 'Коча' },
      'house': { 'Русский': 'Дом', 'Қазақша': 'Үй', 'Уйғурчә': 'Өй' },
      'ai_writing': { 'Русский': 'ИИ анализирует и пишет текст... ✨', 'Қазақша': 'ИИ мәтінді жазып жатыр... ✨', 'Уйғурчә': 'ИИ мәтинни йезиватиду... ✨' },
      'ai_wait': { 'Русский': 'Сначала введите название (минимум 3 буквы)!', 'Қазақша': 'Алдымен атауын енгізіңіз!', 'Уйғурчә': 'Башлап исмини йезиң!' },
      'title_label': { 'Русский': 'Название', 'Қазақша': 'Атауы', 'Уйғурчә': 'Ати' },
      'char_auto': { 'Русский': 'Характеристики Авто', 'Қазақша': 'Авто сипаттамалары', 'Уйғурчә': 'Машина хусусийәтлири' },
      'brand': { 'Русский': 'Марка', 'Қазақша': 'Маркасы', 'Уйғурчә': 'Маркиси' },
      'model': { 'Русский': 'Модель', 'Қазақша': 'Моделі', 'Уйғурчә': 'Модели' },
      'year': { 'Русский': 'Год', 'Қазақша': 'Жылы', 'Уйғурчә': 'Йили' },
      'engine': { 'Русский': 'Объем (л)', 'Қазақша': 'Көлемі (л)', 'Уйғурчә': 'Сығими (л)' },
      'fuel': { 'Русский': 'Топливо', 'Қазақша': 'Жанармай', 'Уйғурчә': 'Йенилғу' },
      'box': { 'Русский': 'Коробка', 'Қазақша': 'Беріліс қорабы', 'Уйғурчә': 'Сүрәт қотуси' },
      'drive': { 'Русский': 'Привод', 'Қазақша': 'Жетек', 'Уйғурчә': 'Қозғатқуч' },
      'steering': { 'Русский': 'Руль', 'Қазақша': 'Рөл', 'Уйғурчә': 'Рул' },
      'color': { 'Русский': 'Цвет', 'Қазақша': 'Түсі', 'Уйғурчә': 'Рәңги' },
      'malbazar_title': { 'Русский': 'Детали', 'Қазақша': 'Мәліметтер', 'Уйғурчә': 'Тәпсилати' },
      'animal_type': { 'Русский': 'Порода', 'Қазақша': 'Тұқымы', 'Уйғурчә': 'Нәсли' },
      'weight': { 'Русский': 'Вес (кг)', 'Қазақша': 'Салмағы (кг)', 'Уйғурчә': 'Еғирлиғи (кг)' },
      'age': { 'Русский': 'Возраст', 'Қазақша': 'Жасы', 'Уйғурчә': 'Йеши' },
      'job_pos': { 'Русский': 'Должность', 'Қазақша': 'Лауазымы', 'Уйғурчә': 'Вәзиписи' },
      'experience': { 'Русский': 'Опыт работы', 'Қазақша': 'Жұмыс өтілі', 'Уйғурчә': 'Иш тәжрибиси' },
      'cloth_details': { 'Русский': 'Детали вещи', 'Қазақша': 'Киім мәліметтері', 'Уйғурчә': 'Кийим тәпсилати' },
      'size': { 'Русский': 'Размер', 'Қазақша': 'Өлшемі', 'Уйғурчә': 'Өлчими' },
      'condition': { 'Русский': 'Состояние', 'Қазақша': 'Жағдайы', 'Уйғурчә': 'Әһвали' },
      'improve_photo': { 'Русский': '✨ Улучшить фон (ИИ)', 'Қазақша': '✨ Фотоны жақсарту (ИИ)', 'Уйғурчә': '✨ Сүрәтни яхшилаш (ИИ)' },
      'improving': { 'Русский': 'ИИ удаляет фон... ✨', 'Қазақша': 'ИИ фонды өшіріп жатыр... ✨', 'Уйғурчә': 'ИИ фонни өчүрүватиду... ✨' },
      'photo_improved': { 'Русский': 'Готово! Фото теперь выглядит как в студии 📸', 'Қазақша': 'Дайын! Фото студиядағыдай көрінеді 📸', 'Уйғурчә': 'Таййар! Сүрәт студиядикидәк көрүниду 📸' },
      'search': { 'Русский': 'Поиск города...', 'Қазақша': 'Қаланы іздеу...', 'Уйғурчә': 'Шәһәр издәш...' },
      'add_media': { 'Русский': 'Добавить фото/видео', 'Қазақша': 'Фото/видео қосу', 'Уйғурчә': 'Сүрәт/видео қошуш' },
      'ad_added': { 'Русский': 'Объявление добавлено! ✅', 'Қазақша': 'Хабарландыру қосылды! ✅', 'Уйғурчә': 'Елан қошулди! ✅' },
      'where_to_search': { 'Русский': 'Где искать?', 'Қазақша': 'Қайдан іздейміз?', 'Уйғурчә': 'Қәйәрдин издәймиз?' },
      'search_results': { 'Русский': 'Результаты поиска', 'Қазақша': 'Іздеу нәтижелері', 'Уйғурчә': 'Издәш нәтижилири' },
      'search_city_hint': { 'Русский': 'Введите название города...', 'Қазақша': 'Қала атын енгізіңіз...', 'Уйғурчә': 'Шәһәр атини йезиң...' },
      'auto_detect': { 'Русский': 'Определить автоматически', 'Қазақша': 'Автоматты түрде анықтау', 'Уйғурчә': 'Автоматлиқ ениқлаш' },
    };
    return translations[key]?[widget.lang] ?? translations[key]?['Русский'] ?? key;
  }

  final List<Map<String, dynamic>> _categories = [
    {'id': 'Все', 'ru': 'Все', 'kz': 'Барлығы', 'ug': 'Һәммиси', 'emoji': '🏠', 'color': Color(0xFF4A80F0)},
    {'id': 'Авто', 'ru': 'Авто', 'kz': 'Авто', 'ug': 'Авто', 'emoji': '🚗', 'color': Color(0xFF2D5CDB)},
    {'id': 'Малбазар', 'ru': 'Малбазар', 'kz': 'Малбазар', 'ug': 'Малбазар', 'emoji': '🐄', 'color': Color(0xFF27AE60)},
    {'id': 'Работа', 'ru': 'Работа', 'kz': 'Жұмыс', 'ug': 'Иш', 'emoji': '💼', 'color': Color(0xFFF39C12)},
    {'id': 'Запчасти', 'ru': 'Запчасти', 'kz': 'Бөлшектер', 'ug': 'Пайпилақлар', 'emoji': '🔧', 'color': Color(0xFF7F8C8D)},
    {'id': 'Детский мир', 'ru': 'Детский мир', 'kz': 'Балалар', 'ug': 'Балилар', 'emoji': '🎊', 'color': Color(0xFFE91E63)},
    {'id': 'Одежда', 'ru': 'Одежда', 'kz': 'Киім', 'ug': 'Кийим', 'emoji': '👕', 'color': Color(0xFF9B59B6)},
    {'id': 'Отдам даром', 'ru': 'Отдам даром', 'kz': 'Тегін', 'ug': 'Тәкин', 'emoji': '🎁', 'color': Color(0xFF1ABC9C)},
    {'id': 'Недвижимость', 'ru': 'Недвижимость', 'kz': 'Жылжымайтын', 'ug': 'Муқим мүлүк', 'emoji': '🏠', 'color': Color(0xFFE67E22)},
    {'id': 'Электроника', 'ru': 'Электроника', 'kz': 'Электроника', 'ug': 'Электроника', 'emoji': '📱', 'color': Color(0xFF3498DB)},
    {'id': 'Сад/Дача', 'ru': 'Сад/Дача', 'kz': 'Бақша', 'ug': 'Бағча', 'emoji': '🌿', 'color': Color(0xFF2ECC71)},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialAd != null) {
      final ad = widget.initialAd!;
      _titleController.text = ad['title'] ?? '';
      _priceController.text = (ad['price'] as String? ?? '').replaceAll(' ₸', '').replaceAll(' ', '');
      _descriptionController.text = ad['description'] ?? '';
      _locationController.text = ad['location'] ?? 'Чунджа (Шонжы)';
      _streetController.text = ad['street'] ?? '';
      _houseController.text = ad['house'] ?? '';
      _selectedCategory = ad['category'] ?? 'Все';
      _condition = ad['condition'] ?? 'Б/У';
      _bargainAvailable = ad['bargain'] ?? false;
      
      if (ad['image_file'] is File) {
        _image = ad['image_file'];
      }
      _initialImageUrl = ad['image_url'];
      _isVideo = ad['is_video'] ?? false;

      // Характеристики авто
      _brandController.text = ad['brand'] ?? '';
      _modelController.text = ad['model'] ?? '';
      _yearController.text = ad['year'] ?? '';
      _engineVolumeController.text = ad['engine_volume'] ?? '2.0';
      _fuelType = ad['fuel_type'] ?? 'Бензин';
      _transmission = ad['transmission'] ?? 'Автомат';
      _drive = ad['drive_type'] ?? 'Передний';
      _steering = ad['steering'] ?? 'Слева';
      _customsCleared = ad['customs_cleared'] ?? true;
      _color = ad['color'] ?? 'Белый';

      // Малбазар
      _animalTypeController.text = ad['animal_type'] ?? '';
      _weightController.text = ad['weight'] ?? '';
      _ageController.text = ad['age'] ?? '';

      // Работа
      _jobPositionController.text = ad['job_position'] ?? '';
      _experienceController.text = ad['experience'] ?? '';

      // Одежда
      _sizeController.text = ad['size'] ?? '';
      _conditionController.text = ad['condition_detail'] ?? '';
    } else {
      final savedLoc = StorageService.getString('user_location');
      if (savedLoc != null) _locationController.text = savedLoc;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.close, color: Color(0xFF1A1D1E)), onPressed: () => Navigator.pop(context)),
        title: Text(_t('screen_title'), style: const TextStyle(color: Color(0xFF1A1D1E), fontWeight: FontWeight.w900, fontSize: 18)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(_t('photo')),
            _buildImagePicker(),
            const SizedBox(height: 25),
            _buildSectionTitle(_t('main_info')),
            _buildModernInputGroup([
              _buildModernTextField(_t('title_label'), _titleController, 'iPhone 15', icon: Icons.label_important_outline_rounded),
              Row(
                children: [
                  Expanded(flex: 2, child: _buildModernTextField(_t('price_label'), _priceController, '500 000', keyboardType: TextInputType.number, icon: Icons.account_balance_wallet_outlined)),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Text(_t('bargain'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1A1D1E))),
                        const SizedBox(width: 4),
                        Switch.adaptive(
                          value: _bargainAvailable, 
                          activeThumbColor: const Color(0xFF4A80F0),
                          onChanged: (v) => setState(() => _bargainAvailable = v),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              _buildModernLocationRow(),
              _buildModernConditionRow(),
              Row(
                children: [
                  Expanded(child: _buildModernTextField(_t('street'), _streetController, 'Достык', icon: Icons.map_outlined)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildModernTextField(_t('house'), _houseController, '15/1')),
                ],
              ),
            ]),
            const SizedBox(height: 25),
            _buildModernCategorySelector(),
            const SizedBox(height: 25),
            _buildDynamicFields(),
            const SizedBox(height: 25),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionTitle(_t('description')),
              ],
            ),
            _buildModernTextField('', _descriptionController, _t('description') + '...', maxLines: 6),
            const SizedBox(height: 30),
            _buildPublishButton(),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildModernInputGroup(List<Widget> children) {
    return Column(
      children: children.map((child) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: child,
      )).toList(),
    );
  }

  Widget _buildModernTextField(String label, TextEditingController controller, String hint, {TextInputType keyboardType = TextInputType.text, int maxLines = 1, IconData? icon}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF1A1D1E).withValues(alpha: 0.5), letterSpacing: 0.5)),
            ),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1A1D1E)),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey.withValues(alpha: 0.5), fontSize: 14, fontWeight: FontWeight.w500),
              prefixIcon: icon != null ? Icon(icon, color: const Color(0xFF64748B), size: 20) : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernLocationRow() => GestureDetector(
    onTap: _showLocationPicker,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on_rounded, color: Color(0xFF4A80F0), size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_t('location'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF4A80F0).withValues(alpha: 0.7), letterSpacing: 0.5)),
              const SizedBox(height: 2),
              Text(_locationController.text, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1A1D1E), fontSize: 15)),
            ],
          ),
          const Spacer(),
          const Icon(Icons.keyboard_arrow_right_rounded, color: Colors.grey),
        ],
      ),
    ),
  );

  Widget _buildModernCategorySelector() {
    final selectedCat = _categories.firstWhere((c) => c['id'] == _selectedCategory, orElse: () => _categories[0]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(_t('category_title')),
        GestureDetector(
          onTap: _showCategoryPickerSheet,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [selectedCat['color'], (selectedCat['color'] as Color).withValues(alpha: 0.8)]),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: (selectedCat['color'] as Color).withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8))],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                  child: Text(selectedCat['emoji'], style: const TextStyle(fontSize: 24)),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.lang == 'Уйғурчә' ? selectedCat['ug'] : (widget.lang == 'Қазақша' ? selectedCat['kz'] : selectedCat['ru']),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
                      ),
                      Text(_t('category_title'), style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 28),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showCategoryPickerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 20),
            Text(_t('category_title'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                  childAspectRatio: 0.85,
                ),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isSelected = _selectedCategory == cat['id'];
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedCategory = cat['id']);
                      Navigator.pop(context);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? cat['color'] : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: isSelected ? Colors.transparent : Colors.grey.withValues(alpha: 0.1)),
                        boxShadow: [BoxShadow(color: isSelected ? (cat['color'] as Color).withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.03), blurRadius: 10)],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(cat['emoji'], style: const TextStyle(fontSize: 32)),
                          const SizedBox(height: 8),
                          Text(
                            widget.lang == 'Уйғурчә' ? cat['ug'] : (widget.lang == 'Қазақша' ? cat['kz'] : cat['ru']),
                            style: TextStyle(color: isSelected ? Colors.white : Colors.black, fontWeight: FontWeight.w900, fontSize: 11),
                            textAlign: TextAlign.center,
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
      ),
    );
  }

  Widget _buildSectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 16), 
    child: Row(
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1A1D1E))),
      ],
    ),
  );

  Widget _buildImagePicker() => GestureDetector(
    onTap: () async {
      // Выбираем медиа (фото или видео)
      final XFile? pickedFile = await _picker.pickMedia();
      if (pickedFile != null) {
        final ext = p.extension(pickedFile.path).toLowerCase();
        final isVid = ext == '.mp4' || ext == '.mov' || ext == '.avi';
        
        if (isVid) {
          // Открываем экран обрезки видео
          final File? trimmedVideo = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VideoEditorScreen(videoFile: File(pickedFile.path), lang: widget.lang),
            ),
          );
          if (trimmedVideo != null) {
            setState(() {
              _image = trimmedVideo;
              _isVideo = true;
            });
          }
        } else {
          setState(() => _isImprovingPhoto = true);
          final compressed = await _compressImage(File(pickedFile.path));
          setState(() {
            _image = compressed;
            _isVideo = false;
            _isImprovingPhoto = false;
          });
        }
      }
    },
    child: Column(
      children: [
        Container(
          width: double.infinity, height: 160, 
          decoration: BoxDecoration(
            color: Colors.white, 
            borderRadius: BorderRadius.circular(20), 
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: _image != null 
            ? Stack(
                children: [
                  _isVideo 
                    ? Container(
                        width: double.infinity,
                        decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(20)),
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 50),
                              SizedBox(height: 10),
                              Text("Видео до 20 сек", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ]
                          )
                        )
                      )
                    : ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.file(_image!, fit: BoxFit.cover, width: double.infinity)), 
                  if (_isImprovingPhoto)
                    Container(
                      decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(20)),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(color: Colors.white),
                            const SizedBox(height: 12),
                            Text(_t('improving'), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                Positioned(right: 8, top: 8, child: GestureDetector(onTap: () => setState(() { _image = null; _isVideo = false; }), child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.close, color: Colors.white, size: 12))))
                ],
              ) 
            : (_initialImageUrl != null 
                ? Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20), 
                        child: Image.network(_initialImageUrl!, fit: BoxFit.cover, width: double.infinity, errorBuilder: (c, e, s) => Container(color: Colors.grey.shade200, child: const Icon(Icons.broken_image_rounded, color: Colors.grey)))
                      ),
                      Positioned(right: 8, top: 8, child: GestureDetector(onTap: () => setState(() { _initialImageUrl = null; }), child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.close, color: Colors.white, size: 12))))
                    ],
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center, 
                      children: [
                        const Icon(Icons.video_library_rounded, color: Color(0xFF4A80F0), size: 30), 
                        const SizedBox(height: 8), 
                        Text(_t('add_media'), style: const TextStyle(color: Color(0xFF4A80F0), fontWeight: FontWeight.w900, fontSize: 12)),
                      ]
                    )
                  )),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF4A80F0)),
            const SizedBox(width: 6),
            Text(
              widget.lang == 'Русский' ? 'Видео до 20 секунд' : (widget.lang == 'Қазақша' ? 'Видео 20 секундқа дейін' : 'Видео 20 секондқичә'),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF4A80F0)),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _buildDynamicFields() {
    if (_selectedCategory == 'Авто') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(_t('char_auto')),
          _buildModernInputGroup([
            _buildModernTextField(_t('brand'), _brandController, 'Toyota', icon: Icons.stars_rounded),
            _buildModernTextField(_t('model'), _modelController, 'Camry', icon: Icons.drive_eta_rounded),
            _buildModernTextField(_t('year'), _yearController, '2023', keyboardType: TextInputType.number, icon: Icons.calendar_month_rounded),
            _buildModernTextField(_t('engine'), _engineVolumeController, '2.0', keyboardType: const TextInputType.numberWithOptions(decimal: true), icon: Icons.local_gas_station_rounded),
            _buildChoiceRow(_t('fuel'), _fuelTypes, _fuelType, (v) => setState(() => _fuelType = v)),
            _buildChoiceRow(_t('box'), _transmissions, _transmission, (v) => setState(() => _transmission = v)),
            _buildChoiceRow(_t('drive'), _drives, _drive, (v) => setState(() => _drive = v)),
            _buildChoiceRow(_t('steering'), _steerings, _steering, (v) => setState(() => _steering = v)),
            _buildChoiceRow(_t('color'), _colors.map((c) => c['name'] as String).toList(), _color, (v) => setState(() => _color = v)),
            _buildCustomsSwitch(),
          ]),
        ],
      );
    } else if (_selectedCategory == 'Малбазар') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(_t('malbazar_title')),
          _buildModernInputGroup([
            _buildModernTextField(_t('animal_type'), _animalTypeController, 'Қой, Жылқы...', icon: Icons.pets_rounded),
            _buildModernTextField(_t('weight'), _weightController, '150', keyboardType: TextInputType.number, icon: Icons.monitor_weight_rounded),
            _buildModernTextField(_t('age'), _ageController, '2', icon: Icons.av_timer_rounded),
          ]),
        ],
      );
    } else if (_selectedCategory == 'Работа') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(_t('malbazar_title')),
          _buildModernInputGroup([
            _buildModernTextField(_t('job_pos'), _jobPositionController, 'Водитель', icon: Icons.work_outline_rounded),
            _buildModernTextField(_t('experience'), _experienceController, '3', icon: Icons.timeline_rounded),
          ]),
        ],
      );
    } else if (_selectedCategory == 'Одежда' || _selectedCategory == 'Детский мир') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(_t('cloth_details')),
          _buildModernInputGroup([
            _buildModernTextField(_t('size'), _sizeController, 'S, M, 42', icon: Icons.straighten_rounded),
            _buildModernTextField(_t('condition'), _conditionController, 'Новое / Б/У', icon: Icons.star_border_rounded),
          ]),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildChoiceRow(String label, List<String> options, String selected, Function(String) onSelect) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(children: [Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1A1D1E))), const Spacer(), DropdownButton<String>(value: selected, style: const TextStyle(color: Color(0xFF1A1D1E), fontWeight: FontWeight.bold), onChanged: (v) => onSelect(v!), items: options.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 12)))).toList())]),
  );

  Widget _buildCustomsSwitch() => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(_t('customs'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1A1D1E))), Switch.adaptive(value: _customsCleared, activeThumbColor: const Color(0xFF4A80F0), onChanged: (v) => setState(() => _customsCleared = v))]);



  Widget _buildPublishButton() => Container(
    width: double.infinity,
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0xFF4A80F0), Color(0xFF3B6AD1)]), 
      borderRadius: BorderRadius.circular(18),
      boxShadow: [BoxShadow(color: const Color(0xFF4A80F0).withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8))],
    ),
    child: ElevatedButton(
      onPressed: _isLoading ? null : _handlePublish,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent, 
        shadowColor: Colors.transparent, 
        minimumSize: const Size(double.infinity, 55), 
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))
      ),
      child: _isLoading 
        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
        : Text(
            widget.initialAd != null ? (widget.lang == 'Русский' ? 'Сохранить изменения' : 'Өзгерістерді сақтау') : _t('publish'), 
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)
          ),
    ),
  );

  Future<void> _handlePublish() async {
    if (_titleController.text.trim().isEmpty) {
      _showError('Введите название');
      return;
    }
    if (_image == null && _initialImageUrl == null) {
      _showError('Добавьте фото или видео');
      return;
    }
    if (_priceController.text.trim().isEmpty) {
      _showError('Укажите цену');
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? finalMediaUrl = _initialImageUrl;
      
      // Если выбрано новое фото/видео, загружаем его
      if (_image != null) {
        finalMediaUrl = await FileService.uploadFile(_image!, 'ads');
        if (finalMediaUrl == null) throw Exception('Ошибка при загрузке медиа');
      }

      final String title = _titleController.text.trim();
      final Map<String, dynamic> adData = {
        'title': title, 
        'title_lowercase': title.toLowerCase(),
        'price': '${_priceController.text} ₸', 
        'description': _descriptionController.text,
        'imageUrl': finalMediaUrl,
        'isVideo': _isVideo,
        'category': _selectedCategory, 
        'location': _locationController.text, 
        'street': _streetController.text, 
        'house': _houseController.text,
        'condition': _condition,
        'bargain': _bargainAvailable,
        
        // Специфичные поля
        'brand': _brandController.text,
        'model': _modelController.text,
        'year': _yearController.text,
        'engine_volume': _engineVolumeController.text,
        'fuel_type': _fuelType,
        'transmission': _transmission,
        'drive_type': _drive,
        'steering': _steering,
        'customs_cleared': _customsCleared,
        'color': _color,
        'animal_type': _animalTypeController.text,
        'weight': _weightController.text,
        'age': _ageController.text,
        'job_position': _jobPositionController.text,
        'experience': _experienceController.text,
        'size': _sizeController.text,
        'condition_detail': _conditionController.text,
      };

      if (widget.initialAd != null) {
        // Обновляем существующее
        final adId = widget.initialAd!['id'];
        await AdService.updateAd(adId, adData);
      } else {
        // Создаем новое
        await AdService.createAd(adData);
      }

      AnalyticsService.logAdPost();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t('ad_added')), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating),
        );
        Navigator.pop(context, true); // Возвращаем true как признак успеха
      }
    } catch (e) {
      debugPrint('Publish error: $e');
      _showError('Ошибка при сохранении: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
    );
  }



  Widget _buildModernConditionRow() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Icon(Icons.stars_rounded, size: 20, color: const Color(0xFF1A1D1E).withValues(alpha: 0.4)),
        const SizedBox(width: 12),
        Text('Состояние:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: const Color(0xFF1A1D1E).withValues(alpha: 0.8))),
        const Spacer(),
        _conditionOption('Новый'),
        const SizedBox(width: 8),
        _conditionOption('Б/У'),
      ],
    ),
  );

  Widget _conditionOption(String label) => GestureDetector(
    onTap: () => setState(() => _condition = label),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _condition == label ? const Color(0xFF4A80F0) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: TextStyle(color: _condition == label ? Colors.white : const Color(0xFF1A1D1E), fontWeight: FontWeight.w800, fontSize: 12)),
    ),
  );

  void _showLocationPicker() {
    String searchCity = "";
    String? selectedParent;

    showModalBottomSheet(
      context: context, 
      isScrollControlled: true, 
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          List<String> listToDisplay;

          if (searchCity.isNotEmpty) {
            listToDisplay = KazakhstanLocations.getAllLocations()
                .where((l) => l.toLowerCase().contains(searchCity.toLowerCase()))
                .toList();
          } else if (selectedParent != null) {
            listToDisplay = KazakhstanLocations.hierarchy[selectedParent] ?? [];
          } else {
            listToDisplay = ['Чунджа'] + KazakhstanLocations.hierarchy.keys.toList();
          }

          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(10))),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      if (selectedParent != null && searchCity.isEmpty)
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                          onPressed: () => setModalState(() => selectedParent = null),
                        ),
                      if (selectedParent != null && searchCity.isEmpty) const SizedBox(width: 15),
                      Text(
                        searchCity.isNotEmpty ? _t('search_results') : (selectedParent ?? _t('where_to_search')), 
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: TextField(
                    onChanged: (v) => setModalState(() => searchCity = v),
                    style: const TextStyle(color: Color(0xFF1A1D1E), fontWeight: FontWeight.w900),
                    decoration: InputDecoration(
                      hintText: _t('search_city_hint'),
                      hintStyle: TextStyle(color: const Color(0xFF1A1D1E).withValues(alpha: 0.6)),
                      prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF4A80F0)),
                      filled: true,
                      fillColor: const Color(0xFFF0F2F5),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                if (selectedParent == null && searchCity.isEmpty) ...[
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                    leading: const Icon(Icons.my_location_rounded, color: Color(0xFF4A80F0)), 
                    title: Text(_t('auto_detect'), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4A80F0))), 
                    onTap: () async {
                      final city = await LocationService.getCurrentCity();
                      if (city != null) {
                        setState(() => _locationController.text = city);
                        StorageService.setString('user_location', city);
                        Navigator.pop(context);
                      }
                    }
                  ),
                  const Divider(indent: 24, endIndent: 24),
                ],
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: listToDisplay.length,
                    separatorBuilder: (c, i) => Divider(color: Colors.grey.withValues(alpha: 0.05)),
                    itemBuilder: (context, index) {
                      final item = listToDisplay[index];
                      final isParent = KazakhstanLocations.hierarchy.containsKey(item) && searchCity.isEmpty;

                      return ListTile(
                        leading: Icon(isParent ? Icons.location_city_rounded : Icons.location_on_rounded, color: const Color(0xFF94A3B8)),
                        title: Text(item, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        trailing: Icon(isParent ? Icons.arrow_forward_ios_rounded : Icons.check_circle_outline_rounded, size: 14, color: isParent ? const Color(0xFF94A3B8) : const Color(0xFF10B981)),
                        onTap: () { 
                          if (isParent) {
                            setModalState(() => selectedParent = item);
                          } else {
                            setState(() => _locationController.text = item); 
                            StorageService.setString('user_location', item);
                            Navigator.pop(context); 
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<File> _compressImage(File file) async {
    final tempDir = await path_provider.getTemporaryDirectory();
    final path = tempDir.path;
    final targetPath = "$path/${DateTime.now().millisecondsSinceEpoch}.jpg";

    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 80,
      minWidth: 1024,
      minHeight: 1024,
    );

    return File(result!.path);
  }
}
