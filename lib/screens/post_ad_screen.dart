import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:iqmarket/services/ad_service.dart';
import 'package:iqmarket/models/ad_model.dart';
import 'package:iqmarket/models/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iqmarket/services/user_service.dart';
import 'package:iqmarket/data/category_data.dart';
import 'package:iqmarket/data/kazakhstan_locations.dart';
import 'package:iqmarket/screens/product_details_screen.dart';
import 'package:iqmarket/screens/video_trimmer_screen.dart';
import 'package:iqmarket/utils/formatters.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_trimmer/video_trimmer.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:iqmarket/widgets/post_ad/category_selector.dart';
import 'package:iqmarket/widgets/post_ad/location_selector.dart';
import 'package:iqmarket/widgets/post_ad/image_picker_section.dart';
import 'package:lottie/lottie.dart';

import '../widgets/post_ad/post_ad_components.dart';
import '../widgets/post_ad/category_specs_widgets.dart';

class PostAdScreen extends StatefulWidget {
  final String lang;
  final AdModel? initialAd;
  const PostAdScreen({super.key, required this.lang, this.initialAd});

  @override
  State<PostAdScreen> createState() => _PostAdScreenState();
}

class _PostAdScreenState extends State<PostAdScreen> {
  // --- Controllers ---
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _malWeightController = TextEditingController();
  final _malBreedController = TextEditingController();
  final _reAreaController = TextEditingController();
  final _carMileageController = TextEditingController();
  final _carEngineController = TextEditingController();

  // --- State Variables ---
  String _selectedCategory = 'all'; // Usually ID or key
  String? _selectedSubCategory;
  String _selectedLocation = 'Чунджа';
  String? _condition;
  bool _bargainAvailable = false;
  bool _canExchange = false;
  bool _hasDelivery = false;
  bool _isLoading = false;
  String _uploadStatus = '';
  
  // Media
  final List<File> _imageFiles = [];
  File? _videoFile;
  final ImagePicker _picker = ImagePicker();

  // Car specifics
  String? _carBrand, _carModel, _carYear, _carBody, _carTransmission, _carDrive, _carFuel, _carColor;
  // RE specifics
  String? _reRooms, _reFloor;
  // Mal specifics
  String? _malAge;

  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadUserAndDraft();
  }

  void _loadUserAndDraft() async {
    _currentUser = await UserService.getUserById(FirebaseAuth.instance.currentUser?.uid ?? '');
    if (widget.initialAd != null) {
      _fillFromAd(widget.initialAd!);
    } else {
      _loadDraft();
    }
  }

  void _fillFromAd(AdModel ad) {
    _titleController.text = ad.title;
    _descriptionController.text = ad.description;
    _priceController.text = ad.price.replaceAll(RegExp(r'[^0-9]'), '');
    _selectedCategory = ad.category;
    _selectedLocation = ad.location;
    _condition = ad.condition;
    _bargainAvailable = ad.isBargainAllowed;
    _canExchange = ad.canExchange;
    _hasDelivery = ad.hasDelivery;
  }

  @override
  Widget build(BuildContext context) {
    final categories = CategoryData.categories;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(widget.initialAd != null ? 'РЕДАКТИРОВАНИЕ' : 'РАЗМЕЩЕНИЕ', 
            style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16, color: const Color(0xFF0F172A), letterSpacing: 1)),
        leading: IconButton(icon: const Icon(Icons.close_rounded, color: Color(0xFF0F172A)), onPressed: () => Navigator.pop(context)),
      ),
      body: PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          Navigator.of(context).maybePop();
        },
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ImagePickerSection(
                    imageFiles: _imageFiles,
                    videoFile: _videoFile,
                    onPickImages: () => _pickMedia(false),
                    onPickVideo: () => _pickMedia(true),
                    onRemoveImage: (i) => setState(() => _imageFiles.removeAt(i)),
                    onRemoveVideo: () => setState(() => _videoFile = null),
                  ),
                  const SizedBox(height: 30),
                  CategorySelector(
                    categories: categories,
                    selectedCategoryId: _selectedCategory,
                    selectedSubCategoryId: _selectedSubCategory,
                    onCategorySelected: (cat) => setState(() { _selectedCategory = cat; _selectedSubCategory = null; _saveDraft(); }),
                    onSubCategorySelected: (sub) => setState(() { _selectedSubCategory = sub; _saveDraft(); }),
                  ),
                  const SizedBox(height: 30),
                  _buildFormFields(),
                  const SizedBox(height: 30),
                  _buildCategorySpecs(),
                  const SizedBox(height: 30),
                  _buildOptions(),
                  const SizedBox(height: 40),
                  _buildActionButtons(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
            if (_isLoading) _buildLoadingOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildFormFields() => Column(children: [
    PostAdInput(label: 'Заголовок', controller: _titleController, hint: 'Название товара или услуги', isRequired: true, maxLength: 50, onChanged: (_) => _saveDraft()),
    const SizedBox(height: 20),
    PostAdInput(label: 'Описание', controller: _descriptionController, hint: 'Расскажите подробнее...', maxLines: 5, maxLength: 1000, onChanged: (_) => _saveDraft()),
    const SizedBox(height: 20),
    if (_selectedCategory != 'Отдам даром') ...[
      PostAdInput(label: 'Цена (₸)', controller: _priceController, hint: '0', keyboardType: TextInputType.number, isRequired: true, inputFormatters: [PriceInputFormatter()], onChanged: (_) => _saveDraft()),
      const SizedBox(height: 20),
    ],
    LocationSelector(
      selectedLocation: _selectedLocation, 
      displayCities: KazakhstanLocations.getAllLocations(),
      onLocationSelected: (loc) => setState(() { _selectedLocation = loc; _saveDraft(); })
    ),
    const SizedBox(height: 20),
    if (_selectedCategory != 'Малбазар' && _selectedCategory != 'Недвижимость') _buildConditionSelector(),
  ]);

  Widget _buildCategorySpecs() {
    if (_selectedCategory == 'Авто') return CarSpecsWidget(carBrand: _carBrand, carModel: _carModel, carYear: _carYear, carBody: _carBody, carTransmission: _carTransmission, carDrive: _carDrive, carFuel: _carFuel, carColor: _carColor, carMileageController: _carMileageController, carEngineController: _carEngineController, onSelect: (f, v) => setState(() {
      if (f == 'carBrand') _carBrand = v; if (f == 'carModel') _carModel = v; if (f == 'carYear') _carYear = v;
      if (f == 'carBody') _carBody = v; if (f == 'carTransmission') _carTransmission = v; if (f == 'carDrive') _carDrive = v;
      if (f == 'carFuel') _carFuel = v; if (f == 'carColor') _carColor = v;
      _saveDraft();
    }));
    if (_selectedCategory == 'Недвижимость') return RealEstateSpecsWidget(reRooms: _reRooms, reFloor: _reFloor, reAreaController: _reAreaController, onSelect: (f, v) => setState(() {
      if (f == 'reRooms') _reRooms = v; if (f == 'reFloor') _reFloor = v;
      _saveDraft();
    }));
    if (_selectedCategory == 'Малбазар') return LivestockSpecsWidget(malAge: _malAge, malWeightController: _malWeightController, malBreedController: _malBreedController, onSelect: (f, v) => setState(() {
      if (f == 'malAge') _malAge = v;
      _saveDraft();
    }));
    return const SizedBox.shrink();
  }

  Widget _buildConditionSelector() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Состояние', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: const Color(0xFF1E293B))),
      const SizedBox(height: 12),
      Row(children: [
        _conditionBtn('Новый'), const SizedBox(width: 12), _conditionBtn('Б/у'),
      ]),
    ],
  );

  Widget _conditionBtn(String label) {
    bool isSelected = _condition == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() { _condition = label; _saveDraft(); }),
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF4A80F0) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isSelected ? const Color(0xFF4A80F0) : Colors.grey[200]!, width: 2),
            boxShadow: isSelected ? [BoxShadow(color: const Color(0xFF4A80F0).withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4))] : [],
          ),
          child: Center(child: Text(label, style: GoogleFonts.inter(color: isSelected ? Colors.white : const Color(0xFF64748B), fontWeight: FontWeight.w800, fontSize: 14))),
        ),
      ),
    );
  }

  Widget _buildOptions() => Column(children: [
    PostAdOptionSwitch(label: 'Торг возможен', value: _bargainAvailable, onChanged: (v) => setState(() { _bargainAvailable = v; _saveDraft(); })),
    PostAdOptionSwitch(label: 'Обмен', value: _canExchange, onChanged: (v) => setState(() { _canExchange = v; _saveDraft(); })),
    PostAdOptionSwitch(label: 'Доставка', value: _hasDelivery, onChanged: (v) => setState(() { _hasDelivery = v; _saveDraft(); })),
  ]);

  Widget _buildActionButtons() => Column(children: [
    SizedBox(width: double.infinity, height: 56, child: OutlinedButton.icon(onPressed: _showPreview, icon: const Icon(Icons.remove_red_eye_rounded), label: const Text('Предпросмотр'), style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF4A80F0), side: const BorderSide(color: Color(0xFF4A80F0), width: 2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), textStyle: GoogleFonts.inter(fontWeight: FontWeight.w800)))),
    const SizedBox(height: 12),
    SizedBox(width: double.infinity, height: 60, child: ElevatedButton(
      onPressed: _isLoading ? null : _handlePublish, 
      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A80F0), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0), 
      child: Text(widget.initialAd != null ? 'Обновить' : 'Опубликовать', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900))
    )),
  ]);

  Widget _buildLoadingOverlay() => Container(
    color: Colors.black.withValues(alpha: 0.7),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: Colors.white),
          const SizedBox(height: 20),
          Text(_uploadStatus, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
        ],
      ),
    ),
  );

  // --- Logic Methods ---

  Future<void> _pickMedia(bool isVideo) async {
    if (isVideo) {
      final XFile? file = await _picker.pickVideo(source: ImageSource.gallery);
      if (file != null) {
        if (mounted) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => VideoTrimmerScreen(
            videoFile: File(file.path), 
            onSave: (path) => setState(() => _videoFile = File(path))
          )));
        }
      }
    } else {
      final List<XFile> picked = await _picker.pickMultiImage();
      if (picked.isNotEmpty) {
        setState(() => _imageFiles.addAll(picked.map((f) => File(f.path))));
      }
    }
  }

  Future<void> _handlePublish() async {
    if (_titleController.text.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Заголовок должен быть не менее 5 символов')));
      return;
    }

    if (_descriptionController.text.length < 20) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Описание слишком короткое (мин. 20 симв.)')));
      return;
    }

    if (_selectedCategory == 'all' || _selectedCategory.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Выберите категорию')));
      return;
    }

    final priceClean = _priceController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final priceVal = double.tryParse(priceClean) ?? 0;
    if (_selectedCategory != 'Отдам даром' && priceVal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Укажите корректную цену')));
      return;
    }

    if (_imageFiles.isEmpty && widget.initialAd == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Добавьте хотя бы одно фото')));
      return;
    }

    if (_selectedLocation.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Выберите город')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final id = await AdService.uploadAndPublishAd(
        title: _titleController.text,
        description: _descriptionController.text,
        price: _selectedCategory == 'Отдам даром' ? '0 ₸' : '${_priceController.text} ₸',
        category: _selectedCategory,
        location: _selectedLocation,
        images: _imageFiles,
        video: _videoFile,
        condition: _condition,
        bargain: _bargainAvailable,
        exchange: _canExchange,
        delivery: _hasDelivery,
        lang: widget.lang,
        initialAdId: widget.initialAd?.id,
        onStatusUpdate: (s) => setState(() => _uploadStatus = s),
        extraFields: {
          'subCategory': _selectedSubCategory,
          if (_selectedCategory == 'Авто') ...{
            'carBrand': _carBrand, 'carModel': _carModel, 'carYear': _carYear,
            'carBody': _carBody, 'carTransmission': _carTransmission,
            'carDrive': _carDrive, 'carFuel': _carFuel, 'carColor': _carColor,
            'carMileage': _carMileageController.text, 'carEngine': _carEngineController.text,
          },
        }
      );
      
      _clearDraft();
      if (mounted) _showSuccessDialog(id.isNotEmpty);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog(bool isApproved) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Lottie.network('https://lottie.host/76b76a0d-959c-4f7d-8153-9110b1062a4b/pM6s7K2A8H.json', height: 140, repeat: false),
            const SizedBox(height: 20),
            Text('Успешно!', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            Text(isApproved ? 'Опубликовано!' : 'На модерации...', textAlign: TextAlign.center),
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () { Navigator.pop(context); Navigator.pop(context); }, child: const Text('ОТЛИЧНО'))),
          ],
        ),
      ),
    );
  }

  // --- Draft Logic ---
  void _saveDraft() async {
    if (widget.initialAd != null) return;
    final prefs = await SharedPreferences.getInstance();
    final draft = {
      'title': _titleController.text,
      'desc': _descriptionController.text,
      'price': _priceController.text,
      'cat': _selectedCategory,
      'loc': _selectedLocation,
      'cond': _condition,
    };
    await prefs.setString('ad_draft', jsonEncode(draft));
  }

  void _loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('ad_draft');
    if (raw != null) {
      final draft = jsonDecode(raw);
      setState(() {
        _titleController.text = draft['title'] ?? '';
        _descriptionController.text = draft['desc'] ?? '';
        _priceController.text = draft['price'] ?? '';
        _selectedCategory = draft['cat'] ?? 'all';
        _selectedLocation = draft['loc'] ?? 'Чунджа';
        _condition = draft['cond'];
      });
    }
  }

  void _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('ad_draft');
  }

  void _showPreview() {
    // Basic preview
    final ad = AdModel(
      id: 'p', title: _titleController.text, description: _descriptionController.text,
      price: '${_priceController.text} ₸', category: _selectedCategory, images: _imageFiles.map((f)=>f.path).toList(),
      userId: 'u', userName: 'Вы', userEmail: '', timestamp: DateTime.now(), location: _selectedLocation,
    );
    Navigator.push(context, MaterialPageRoute(builder: (context) => ProductDetailsScreen(ad: ad, lang: widget.lang, onReport: (_){}, heroPrefix: 'p_')));
  }
}
