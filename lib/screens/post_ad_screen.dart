import 'dart:io'; 
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:iqmarket/services/file_service.dart';
import 'package:iqmarket/services/ad_service.dart';
import 'package:iqmarket/services/gemini_service.dart';
import 'package:iqmarket/models/ad_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iqmarket/data/category_data.dart';
import 'package:video_player/video_player.dart';
import 'package:iqmarket/screens/video_editor_screen.dart';
import 'package:iqmarket/screens/product_details_screen.dart';
import 'package:iqmarket/data/kazakhstan_locations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_trimmer/video_trimmer.dart';
import 'dart:async';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:connectivity_plus/connectivity_plus.dart';

import 'package:lottie/lottie.dart';
import 'package:video_compress/video_compress.dart';

import '../widgets/post_ad/post_ad_components.dart';
import '../widgets/post_ad/category_specs_widgets.dart';

class PriceInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    final numStr = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (numStr.isEmpty) return newValue.copyWith(text: '');
    final num = int.parse(numStr);
    final formatted = NumberFormat.decimalPattern('ru').format(num);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class PostAdScreen extends StatefulWidget {
  final String lang;
  final AdModel? initialAd;
  const PostAdScreen({super.key, required this.lang, this.initialAd});

  @override
  State<PostAdScreen> createState() => _PostAdScreenState();
}

class _PostAdScreenState extends State<PostAdScreen> {
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedLocation = "Чунджа";
  
  List<File> _imageFiles = [];
  File? _videoFile;
  final ImagePicker _picker = ImagePicker();
  final Trimmer _trimmer = Trimmer();
  
  String _selectedCategory = 'Авто'; 
  String _condition = 'Б/у'; 
  bool _bargainAvailable = false;
  bool _canExchange = false;
  bool _hasDelivery = false;
  bool _isLoading = false;
  String _uploadStatus = '';
  String? _titleError;
  String? _priceError;

  // Subcategory & Specs fields
  String? _selectedSubCategory;
  String? _carBrand, _carModel, _carYear, _carBody, _carTransmission, _carDrive, _carFuel, _carColor;
  final _carMileageController = TextEditingController();
  final _carEngineController = TextEditingController();
  String? _reRooms, _reFloor;
  final _reAreaController = TextEditingController();
  String? _malAge;
  final _malWeightController = TextEditingController();
  final _malBreedController = TextEditingController();

  final List<CategoryModel> _categories = CategoryData.categories;
  Timer? _autoSaveTimer;

  // Получаем список всех городов и укорачиваем нужные
  List<String> get _displayCities {
    final all = KazakhstanLocations.getAllLocations();
    // Перемещаем Чунджу на первое место
    final List<String> sorted = [];
    sorted.add('Чунджа');
    
    for (var c in all) {
      String short = c;
      if (c.contains('Алматы')) short = 'Алматы';
      else if (c.contains('Шымкент')) short = 'Шымкент';
      else if (c.contains('Туркестан')) short = 'Туркестан';
      else if (c.contains('Жаркент')) short = 'Жаркент';
      else if (c.contains('Шонжы')) continue; // Уже добавили как Чунджа
      
      if (!sorted.contains(short)) sorted.add(short);
    }
    return sorted;
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialAd != null) {
      _loadInitialAd();
    } else {
      _checkAndLoadDraft();
    }
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 20), (timer) => _saveDraft());
  }

  void _loadInitialAd() {
    final ad = widget.initialAd!;
    _titleController.text = ad.title;
    _priceController.text = ad.price.replaceAll(RegExp(r'[^0-9]'), '');
    _descriptionController.text = ad.description;
    _selectedCategory = ad.category;
    _selectedLocation = ad.location;
    _condition = ad.condition;
    _bargainAvailable = ad.isBargainAllowed;
    _canExchange = ad.canExchange;
    _hasDelivery = ad.hasDelivery;
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _titleController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _carMileageController.dispose();
    _carEngineController.dispose();
    _reAreaController.dispose();
    _malWeightController.dispose();
    _malBreedController.dispose();
    super.dispose();
  }

  void _validateTitle(String val) {
    setState(() {
      if (val.trim().isEmpty) _titleError = null;
      else if (val.trim().length < 5) _titleError = 'Минимум 5 символов';
      else _titleError = null;
    });
  }

  void _validatePrice(String val) {
    setState(() {
      if (val.trim().isEmpty) _priceError = null;
      else {
        final numStr = val.replaceAll(RegExp(r'[^0-9]'), '');
        if (numStr.isEmpty || int.parse(numStr) < 100) _priceError = 'Мин. цена 100 ₸';
        else _priceError = null;
      }
    });
  }

  bool _hasContent() {
    return _titleController.text.trim().isNotEmpty || 
           _descriptionController.text.trim().isNotEmpty || 
           (_priceController.text.trim().isNotEmpty && _priceController.text != '0') ||
           _imageFiles.isNotEmpty || 
           _videoFile != null;
  }

  Future<void> _saveDraft() async {
    final prefs = await SharedPreferences.getInstance();
    
    if (!_hasContent()) {
      // Если контента нет, удаляем черновик, чтобы не надоедать пользователю
      await prefs.remove('ad_draft');
      return;
    }

    final draft = {
      'title': _titleController.text,
      'price': _priceController.text,
      'description': _descriptionController.text,
      'location': _selectedLocation,
      'category': _selectedCategory,
      'condition': _condition,
      'subCategory': _selectedSubCategory,
    };
    await prefs.setString('ad_draft', jsonEncode(draft));
  }

  Future<void> _checkAndLoadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final draftStr = prefs.getString('ad_draft');
    if (draftStr != null && mounted) {
      final d = jsonDecode(draftStr);
      // Проверяем, есть ли там хоть какой-то полезный контент
      final bool hasMeaningfulContent = (d['title']?.toString().trim().isNotEmpty ?? false) || 
                                       (d['description']?.toString().trim().isNotEmpty ?? false) ||
                                       (d['price']?.toString().trim().isNotEmpty ?? false);

      if (!hasMeaningfulContent) {
        await prefs.remove('ad_draft');
        return;
      }

      showDialog(
        context: context, barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Восстановить черновик?', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
          content: const Text('У вас есть незавершенное объявление. Хотите продолжить?'),
          actions: [
            TextButton(onPressed: () { prefs.remove('ad_draft'); Navigator.pop(context); }, child: const Text('Удалить', style: TextStyle(color: Colors.red))),
            ElevatedButton(onPressed: () {
                setState(() { 
                  _titleController.text = d['title'] ?? ''; 
                  _priceController.text = d['price'] ?? ''; 
                  _descriptionController.text = d['description'] ?? ''; 
                  _selectedLocation = d['location'] ?? 'Чунджа'; 
                  _selectedCategory = d['category'] ?? 'Авто'; 
                  _condition = d['condition'] ?? 'Б/у';
                  _selectedSubCategory = d['subCategory'];
                });
                Navigator.pop(context);
              }, child: const Text('Восстановить')),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(title: Text('Разместить объявление', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 18)), centerTitle: true, backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            _sectionContainer(child: _buildImagePicker()),
            const SizedBox(height: 12),
            _sectionContainer(child: Column(
              children: [
                PostAdInput(label: 'Название', controller: _titleController, hint: 'Что вы продаете?', isRequired: true, onChanged: _validateTitle, errorText: _titleError),
                const SizedBox(height: 20),
                if (_selectedCategory == 'Отдам даром') _buildFreeBadge()
                else PostAdInput(label: 'Цена (₸)', controller: _priceController, hint: 'Цена', keyboardType: TextInputType.number, isRequired: true, onChanged: _validatePrice, errorText: _priceError, inputFormatters: [PriceInputFormatter()]),
              ],
            )),
            const SizedBox(height: 12),
            _sectionContainer(child: _buildCategorySelector()),
            if (_selectedCategory == 'Авто' && _selectedSubCategory == 'cars') ...[ const SizedBox(height: 12), _sectionContainer(child: CarSpecsWidget(carBrand: _carBrand, carModel: _carModel, carYear: _carYear, carBody: _carBody, carTransmission: _carTransmission, carDrive: _carDrive, carFuel: _carFuel, carColor: _carColor, carMileageController: _carMileageController, carEngineController: _carEngineController, onSelect: (f, v) => setState(() { if(f=='carBrand')_carBrand=v; else if(f=='carModel')_carModel=v; else if(f=='carYear')_carYear=v; else if(f=='carBody')_carBody=v; else if(f=='carTransmission')_carTransmission=v; else if(f=='carDrive')_carDrive=v; else if(f=='carFuel')_carFuel=v; else if(f=='carColor')_carColor=v; }))), ],
            if (_selectedCategory == 'Недвижимость') ...[ const SizedBox(height: 12), _sectionContainer(child: RealEstateSpecsWidget(reRooms: _reRooms, reFloor: _reFloor, reAreaController: _reAreaController, onSelect: (f, v) => setState(() { if(f=='reRooms')_reRooms=v; else if(f=='reFloor')_reFloor=v; }))), ],
            if (_selectedCategory == 'Малбазар') ...[ const SizedBox(height: 12), _sectionContainer(child: LivestockSpecsWidget(malAge: _malAge, malWeightController: _malWeightController, malBreedController: _malBreedController, onSelect: (f, v) => setState(() => _malAge = v))), ],
            const SizedBox(height: 12),
            _sectionContainer(child: _buildConditionSelector()),
            const SizedBox(height: 12),
            _sectionContainer(child: _buildLocationSelector()),
            const SizedBox(height: 12),
            _sectionContainer(child: PostAdInput(label: 'Описание', controller: _descriptionController, hint: 'Подробности...', maxLines: 6, isRequired: true)),
            const SizedBox(height: 12),
            _sectionContainer(child: _buildOptions()),
            const SizedBox(height: 24),
            _buildActionButtons(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _sectionContainer({required Widget child}) => Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)), child: child);
  Widget _buildFreeBadge() => Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF10B981))), child: Row(children: [const Icon(Icons.volunteer_activism_rounded, color: Color(0xFF10B981)), const SizedBox(width: 12), Text('Отдам даром (Бесплатно)', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: const Color(0xFF10B981)))]));

  Widget _buildCategorySelector() {
    final selectedCat = _categories.firstWhere((c) => c.id == _selectedCategory, orElse: () => _categories.first);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Категория', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15)),
      const SizedBox(height: 16),
      SizedBox(height: 45, child: ListView(scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(), children: _categories.map((cat) {
        final isSelected = _selectedCategory == cat.id;
        return GestureDetector(onTap: () => setState(() { _selectedCategory = cat.id; _selectedSubCategory = null; if (_selectedCategory == 'Отдам даром') _priceController.text = '0'; }), child: AnimatedContainer(duration: const Duration(milliseconds: 200), margin: const EdgeInsets.only(right: 10), padding: const EdgeInsets.symmetric(horizontal: 20), decoration: BoxDecoration(color: isSelected ? const Color(0xFF4A80F0) : const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(16)), child: Center(child: Text(cat.ru, style: GoogleFonts.inter(color: isSelected ? Colors.white : const Color(0xFF64748B), fontWeight: FontWeight.w800, fontSize: 13)))));
      }).toList())),
      if (selectedCat.subCategories != null) ...[ const SizedBox(height: 16), Text('Подкатегория', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.grey[700])), const SizedBox(height: 10), Wrap(spacing: 8, runSpacing: 8, children: selectedCat.subCategories!.map((sub) { final isSelected = _selectedSubCategory == sub.id; return GestureDetector(onTap: () => setState(() => _selectedSubCategory = sub.id), child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: isSelected ? const Color(0xFF4A80F0).withValues(alpha: 0.1) : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: isSelected ? const Color(0xFF4A80F0) : Colors.grey[300]!)), child: Text(sub.ru, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: isSelected ? const Color(0xFF4A80F0) : Colors.grey[700])))); }).toList()), ],
    ]);
  }

  Widget _buildLocationSelector() => _buildSelectorField('Выбрать город', _selectedLocation, _displayCities, (val) => setState(() => _selectedLocation = val));

  Widget _buildSelectorField(String label, String value, List<String> options, Function(String) onSelect) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15)),
      const SizedBox(height: 12),
      InkWell(onTap: () => _showOptions(label, options, onSelect), child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(16)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(value, style: GoogleFonts.inter(fontWeight: FontWeight.w700)), const Icon(Icons.keyboard_arrow_down_rounded)]))),
    ]);
  }

  void _showOptions(String title, List<String> options, Function(String) onSelect) {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 20),
          Expanded(child: ListView.builder(
            itemCount: options.length,
            itemBuilder: (context, i) {
              final isPopular = options[i] == 'Чунджа' || options[i] == 'Алматы';
              return ListTile(
                leading: Icon(isPopular ? Icons.star_rounded : Icons.location_city_rounded, color: isPopular ? Colors.orange : Colors.grey[400]),
                title: Text(options[i], style: GoogleFonts.inter(fontWeight: isPopular ? FontWeight.w800 : FontWeight.w600, color: isPopular ? Colors.black : Colors.grey[800])),
                onTap: () { onSelect(options[i]); Navigator.pop(context); }
              );
            },
          )),
        ]),
      ),
    );
  }

  Widget _buildConditionSelector() => Row(children: [Text('Состояние:', style: GoogleFonts.inter(fontWeight: FontWeight.w800)), const SizedBox(width: 16), _choiceChip('Новый'), const SizedBox(width: 12), _choiceChip('Б/у')]);
  Widget _choiceChip(String label) => GestureDetector(onTap: () => setState(() => _condition = label), child: Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), decoration: BoxDecoration(color: _condition == label ? const Color(0xFF4A80F0) : const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)), child: Text(label, style: GoogleFonts.inter(color: _condition == label ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.w700))));

  Widget _buildOptions() => Column(children: [PostAdOptionSwitch(label: 'Торг возможен', value: _bargainAvailable, onChanged: (v) => setState(() => _bargainAvailable = v)), PostAdOptionSwitch(label: 'Обмен', value: _canExchange, onChanged: (v) => setState(() => _canExchange = v)), PostAdOptionSwitch(label: 'Доставка', value: _hasDelivery, onChanged: (v) => setState(() => _hasDelivery = v))]);

  Widget _buildActionButtons() => Column(children: [
      SizedBox(width: double.infinity, height: 56, child: OutlinedButton.icon(onPressed: _showPreview, icon: const Icon(Icons.remove_red_eye_rounded), label: const Text('Предпросмотр'), style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF4A80F0), side: const BorderSide(color: Color(0xFF4A80F0), width: 2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), textStyle: GoogleFonts.inter(fontWeight: FontWeight.w800)))),
      const SizedBox(height: 12),
      SizedBox(width: double.infinity, height: 60, child: ElevatedButton(
        onPressed: (_isLoading || _titleError != null || _priceError != null) ? null : _handlePublish, 
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A80F0), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0), 
        child: _isLoading 
          ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)), 
              const SizedBox(width: 12), 
              Text(_uploadStatus, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600))
            ])
          : Text('Опубликовать', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900))
      )),
  ]);

  void _showPreview() {
    Map<String, dynamic> previewFields = {
      'Категория': _selectedCategory,
      'Состояние': _condition,
      'Местоположение': _selectedLocation,
    };

    if (_selectedSubCategory != null) previewFields['Подкатегория'] = _selectedSubCategory;
    if (_carBrand != null) previewFields['Марка'] = _carBrand;
    if (_carModel != null) previewFields['Модель'] = _carModel;
    if (_carYear != null) previewFields['Год'] = _carYear;
    if (_reRooms != null) previewFields['Комнаты'] = _reRooms;
    if (_reAreaController.text.isNotEmpty) previewFields['Площадь'] = _reAreaController.text;

    final ad = AdModel(
      id: 'p', 
      title: _titleController.text.isEmpty ? 'Предпросмотр' : _titleController.text, 
      description: _descriptionController.text.isEmpty ? 'Нет описания' : _descriptionController.text, 
      price: _selectedCategory == 'Отдам даром' ? '0 ₸' : '${_priceController.text} ₸', 
      category: _selectedCategory, 
      images: _imageFiles.map((f) => f.path).toList(), 
      videoUrl: _videoFile?.path,
      userId: FirebaseAuth.instance.currentUser?.uid ?? 'u', 
      userName: 'Вы', 
      userEmail: '', 
      timestamp: DateTime.now(), 
      location: _selectedLocation, 
      condition: _condition, 
      isBargainAllowed: _bargainAvailable, 
      canExchange: _canExchange, 
      hasDelivery: _hasDelivery, 
      extraFields: previewFields,
      expiresAt: DateTime.now().add(const Duration(days: 30)),
      notifiedExpiry: false,
    );
    Navigator.push(context, MaterialPageRoute(fullscreenDialog: true, builder: (context) => ProductDetailsScreen(ad: ad, onReport: (_) {}, lang: widget.lang)));
  }

  Widget _buildImagePicker() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Фото и Видео', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 18)), Text('${_imageFiles.length}/10 фото', style: GoogleFonts.inter(color: Colors.grey[600], fontWeight: FontWeight.bold))]),
    const SizedBox(height: 16),
    Row(children: [
      Expanded(child: _mediaBtn(Icons.add_a_photo_rounded, 'Добавить фото', () => _pickMedia(false))),
      const SizedBox(width: 12),
      Expanded(child: _mediaBtn(Icons.videocam_rounded, _videoFile != null ? 'Видео готово' : 'Добавить видео', () => _pickMedia(true), color: _videoFile != null ? const Color(0xFF10B981) : const Color(0xFF64748B))),
    ]),
    if (_imageFiles.isNotEmpty || _videoFile != null) ...[
      const SizedBox(height: 20),
      SizedBox(
        height: 110,
        child: ReorderableListView(
          scrollDirection: Axis.horizontal,
          onReorder: (oldIndex, newIndex) {
            setState(() {
              if (newIndex > oldIndex) newIndex -= 1;
              final item = _imageFiles.removeAt(oldIndex);
              _imageFiles.insert(newIndex, item);
              HapticFeedback.selectionClick();
            });
          },
          children: [
            if (_videoFile != null) 
              PostAdPreviewItem(key: const ValueKey('video_preview'), isVideo: true, onRemove: () { HapticFeedback.mediumImpact(); setState(() => _videoFile = null); }),
            ..._imageFiles.asMap().entries.map((entry) => PostAdPreviewItem(
              key: ValueKey('img_${entry.value.path}_${entry.key}'),
              file: entry.value, 
              onRemove: () {
                HapticFeedback.mediumImpact();
                setState(() => _imageFiles.removeAt(entry.key));
              }
            )),
          ],
        ),
      ),
    ],
    const SizedBox(height: 12),
    Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF4A80F0).withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)), child: Row(children: [const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF4A80F0)), const SizedBox(width: 8), Expanded(child: Text('Видео: до 20 секунд. Первое фото будет на обложке.', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF4A80F0), fontWeight: FontWeight.w600)))]))
  ]);

  Widget _mediaBtn(IconData icon, String label, VoidCallback onTap, {Color? color}) => GestureDetector(onTap: onTap, child: Container(height: 80, decoration: BoxDecoration(color: (color ?? const Color(0xFF64748B)).withValues(alpha: 0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: (color ?? const Color(0xFF64748B)).withValues(alpha: 0.2), width: 2)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: color ?? const Color(0xFF64748B), size: 28), const SizedBox(height: 6), Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: color ?? const Color(0xFF64748B)))])));

  Future<void> _pickMedia(bool isVideo) async {
    if (isVideo) {
      final XFile? file = await _picker.pickVideo(source: ImageSource.gallery);
      if (file != null) {
        await _trimmer.loadVideo(videoFile: File(file.path));
        if (mounted) Navigator.push(context, MaterialPageRoute(builder: (context) => VideoTrimmerScreen(trimmer: _trimmer, onSave: (path) => setState(() => _videoFile = File(path)))));
      }
    } else {
      final List<XFile> picked = await _picker.pickMultiImage();
      if (picked.isNotEmpty) {
        HapticFeedback.mediumImpact();
        setState(() => _imageFiles.addAll(picked.map((f) => File(f.path))));
      }
    }
  }

  Future<void> _handlePublish() async {
    if (_titleController.text.isEmpty || _priceController.text.isEmpty) { 
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Заполните название и цену'))); 
      return; 
    }
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Пожалуйста, войдите в систему'))); 
       return;
    }

    final List<ConnectivityResult> connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Нет подключения к интернету. Проверьте сеть и повторите.'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    setState(() {
      _isLoading = true;
      _uploadStatus = 'Проверка модерации ИИ...';
    });

    try {
      // 0. AI Moderation Check
      final gemini = GeminiService();
      gemini.init(widget.lang);
      final moderationResult = await gemini.checkContent(
        _titleController.text, 
        _descriptionController.text, 
        _imageFiles
      );

      if (moderationResult.startsWith('REJECTED')) {
        final reason = moderationResult.replaceFirst('REJECTED:', '').trim();
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(children: [const Icon(Icons.shield_outlined, color: Colors.red), const SizedBox(width: 10), const Text('Ошибка модерации')]),
              content: Text('К сожалению, ваше объявление отклонено автоматической системой.\n\nПричина: $reason', style: GoogleFonts.inter()),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Понятно'))],
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      // 1. Загрузка фото в Storage с предварительным сжатием
      List<String> imageUrls = [];
      final tempDir = await getTemporaryDirectory();

      for (int i = 0; i < _imageFiles.length; i++) {
        if (mounted) setState(() => _uploadStatus = 'Сжатие и загрузка фото ${i + 1} из ${_imageFiles.length}...');
        final file = _imageFiles[i];
        final targetPath = p.join(tempDir.path, '${DateTime.now().millisecondsSinceEpoch}_$i.jpg');
        
        final compressedFile = await FlutterImageCompress.compressAndGetFile(
          file.absolute.path, 
          targetPath,
          quality: 70,
          minWidth: 1080,
          minHeight: 1080,
        );

        final uploadFuture = FileService.uploadFile(File(compressedFile?.path ?? file.path), 'ads/images');
        final url = await uploadFuture.timeout(const Duration(seconds: 15), onTimeout: () => throw TimeoutException('Слишком медленный интернет для фото'));
        if (url != null) imageUrls.add(url);
      }

      // 2. Загрузка видео если есть с максимальным сжатием
      String? videoUrl;
      if (_videoFile != null) {
        if (mounted) setState(() => _uploadStatus = 'Сжатие и загрузка видео...');
        
        final MediaInfo? mediaInfo = await VideoCompress.compressVideo(
          _videoFile!.path,
          quality: VideoQuality.MediumQuality,
          deleteOrigin: false,
          includeAudio: true,
        );
        
        final fileToUpload = (mediaInfo != null && mediaInfo.path != null) ? File(mediaInfo.path!) : _videoFile!;
        final uploadVideoFuture = FileService.uploadFile(fileToUpload, 'ads/videos');
        videoUrl = await uploadVideoFuture.timeout(const Duration(seconds: 60), onTimeout: () => throw TimeoutException('Слишком медленный интернет для видео'));
      }

      if (mounted) setState(() => _uploadStatus = 'Создание объявления...');

      // 3. Создание модели объявления
      final ad = AdModel(
        id: '', // Firestore присвоит ID
        title: _titleController.text,
        description: _descriptionController.text,
        price: _selectedCategory == 'Отдам даром' ? '0 ₸' : '${_priceController.text} ₸',
        category: _selectedCategory,
        images: imageUrls,
        videoUrl: videoUrl,
        userId: user.uid,
        userName: user.displayName ?? 'Пользователь',
        userEmail: user.email ?? '',
        userPhone: user.phoneNumber ?? '',
        timestamp: DateTime.now(),
        location: _selectedLocation,
        condition: _condition,
        isBargainAllowed: _bargainAvailable,
        canExchange: _canExchange,
        hasDelivery: _hasDelivery,
        active: true,
        status: 'active',
        extraFields: {
          'subCategory': _selectedSubCategory,
          if (_selectedCategory == 'Авто') ...{
            'carBrand': _carBrand, 'carModel': _carModel, 'carYear': _carYear,
            'carBody': _carBody, 'carTransmission': _carTransmission,
            'carDrive': _carDrive, 'carFuel': _carFuel, 'carColor': _carColor,
            'carMileage': _carMileageController.text, 'carEngine': _carEngineController.text,
          },
          if (_selectedCategory == 'Недвижимость') ...{
            'reRooms': _reRooms, 'reFloor': _reFloor, 'reArea': _reAreaController.text,
          },
          if (_selectedCategory == 'Малбазар') ...{
            'malAge': _malAge, 'malWeight': _malWeightController.text, 'malBreed': _malBreedController.text,
          }
        },
        expiresAt: DateTime.now().add(const Duration(days: 30)),
        notifiedExpiry: false,
      );

      // 4. Сохранение в Firestore (используем createAd)
      await AdService.createAd(ad);
      
      // Очистка черновика
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('ad_draft');

      if (mounted) {
        HapticFeedback.heavyImpact();
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Column(children: [
              SizedBox(
                height: 120,
                child: Lottie.network('https://lottie.host/76b76a0d-959c-4f7d-8153-9110b1062a4b/pM6s7K2A8H.json', repeat: false),
              ),
              const SizedBox(height: 16),
              Text('Успешно!', style: GoogleFonts.inter(fontWeight: FontWeight.w900)),
            ]),
            content: Text('Ваше объявление отправлено на модерацию. Оно появится в ленте сразу после проверки нашими администраторами.', textAlign: TextAlign.center, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
            actions: [
              SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () { Navigator.pop(context); Navigator.pop(context); }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A80F0), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: const Text('Понятно'))),
            ],
          ),
        );
      }
    } on TimeoutException catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(children: [Icon(Icons.wifi_off, color: Colors.orange), SizedBox(width: 10), Text('Проблема с сетью')]),
            content: Text('${e.message}\nПопробуйте переключиться между Wi-Fi и мобильным интернетом.', style: GoogleFonts.inter()),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Понятно'))]
          )
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка при публикации: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

class VideoTrimmerScreen extends StatefulWidget {
  final Trimmer trimmer;
  final Function(String) onSave;
  const VideoTrimmerScreen({super.key, required this.trimmer, required this.onSave});

  @override
  State<VideoTrimmerScreen> createState() => _VideoTrimmerScreenState();
}

class _VideoTrimmerScreenState extends State<VideoTrimmerScreen> {
  double _startValue = 0.0, _endValue = 0.0;
  bool _isPlaying = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('Выбор фрагмента (20 сек)'), backgroundColor: Colors.black, foregroundColor: Colors.white, actions: [IconButton(icon: const Icon(Icons.check), onPressed: _saveVideo)]),
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(child: VideoViewer(trimmer: widget.trimmer)),
              Center(
                child: TrimViewer(
                  trimmer: widget.trimmer,
                  viewerHeight: 50.0,
                  viewerWidth: MediaQuery.of(context).size.width,
                  maxVideoLength: const Duration(seconds: 20),
                  onChangeStart: (value) => _startValue = value,
                  onChangeEnd: (value) => _endValue = value,
                  onChangePlaybackState: (value) => setState(() => _isPlaying = value),
                ),
              ),
              TextButton(child: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, size: 80, color: Colors.white), onPressed: () async {
                bool playbackState = await widget.trimmer.videoPlaybackControl(startValue: _startValue, endValue: _endValue);
                setState(() => _isPlaying = playbackState);
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _saveVideo() {
    widget.trimmer.saveTrimmedVideo(
      startValue: _startValue, endValue: _endValue,
      onSave: (path) {
        if (path != null) widget.onSave(path);
        Navigator.pop(context);
      }
    );
  }
}
