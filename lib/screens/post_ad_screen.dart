import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:iqmarket/services/ad_service.dart';
import 'package:iqmarket/models/ad_model.dart';
import 'package:iqmarket/models/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iqmarket/services/user_service.dart';
import 'package:iqmarket/services/storage_service.dart';
import 'package:iqmarket/data/category_data.dart';
import 'package:iqmarket/data/kazakhstan_locations.dart';
import 'package:iqmarket/screens/product_details_screen.dart';
import 'package:iqmarket/screens/video_trimmer_screen.dart';
import 'package:iqmarket/utils/formatters.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'dart:async';
import 'dart:convert';
import 'package:iqmarket/widgets/post_ad/category_selector.dart';
import 'package:iqmarket/widgets/post_ad/location_selector.dart';
import 'package:iqmarket/widgets/post_ad/image_picker_section.dart';
import 'package:lottie/lottie.dart';
import 'package:iqmarket/services/translation_service.dart';
import 'package:iqmarket/services/category_auto_detector.dart';
import 'package:iqmarket/screens/help_center_screen.dart';

import 'package:iqmarket/widgets/phone_required_bottom_sheet.dart';
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
  final _phoneController = TextEditingController();
  final _phoneMask = MaskTextInputFormatter(
    mask: '+7 (###) ###-##-##',
    filter: {"#": RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );

  // --- State Variables ---
  String _selectedCategory = 'all'; // Usually ID or key
  String? _selectedSubCategory;
  bool _isCategoryUserOverridden = false;
  bool _isAutoDetectedCategory = false;
  String _selectedLocation = 'Чунджа';
  String? _condition;
  bool _bargainAvailable = false;
  bool _canExchange = false;
  bool _hasDelivery = false;
  bool _isLoading = false;
  bool _isSubmitting = false;
  String _uploadStatus = '';
  static const int _maxPhotos = 8;
  Timer? _draftDebounce;

  void _onTitleOrDescriptionInput() {
    _saveDraft();
    if (_isCategoryUserOverridden) return;
    final result = CategoryAutoDetector.detect(_titleController.text, _descriptionController.text);
    if (result != null) {
      if (_selectedCategory != result.categoryId || _selectedSubCategory != result.subCategoryId) {
        setState(() {
          _selectedCategory = result.categoryId;
          _selectedSubCategory = result.subCategoryId;
          _isAutoDetectedCategory = true;
        });
      }
    }
  }
  
  // Media
  final List<File> _imageFiles = [];
  List<String> _existingImageUrls = [];
  File? _videoFile;
  final ImagePicker _picker = ImagePicker();

  // Car specifics
  String? _carBrand, _carModel, _carYear, _carBody, _carTransmission, _carDrive, _carFuel, _carColor;
  // RE specifics
  String? _reRooms, _reFloor;

  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadUserAndDraft();
  }

  @override
  void dispose() {
    _draftDebounce?.cancel();
    _phoneController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _malWeightController.dispose();
    _malBreedController.dispose();
    _reAreaController.dispose();
    _carMileageController.dispose();
    _carEngineController.dispose();
    super.dispose();
  }

  void _loadUserAndDraft() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _currentUser = await UserService.getUserById(uid);
    
    // 🔒 Pre-fill phone number from profile / verified_phone
    if (_currentUser != null) {
      try {
        final docSnap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        final docData = docSnap.data();
        final String profilePhone = (docData?['verified_phone'] ?? docData?['phone'] ?? _currentUser!.phone).toString().trim();
        if (profilePhone.isNotEmpty) {
          final digits = profilePhone.replaceAll(RegExp(r'\D'), '');
          String localDigits = digits;
          if (digits.length == 11 && (digits.startsWith('7') || digits.startsWith('8'))) {
            localDigits = digits.substring(1);
          } else if (digits.length > 11) {
            localDigits = digits.substring(digits.length - 10);
          }
          if (mounted && _phoneController.text.isEmpty) {
            setState(() {
              _phoneController.text = _phoneMask.maskText(localDigits);
            });
          }
        }
      } catch (e) {
        debugPrint('[PostAd] Error loading verified phone: $e');
      }
    }

    if (mounted) {
      setState(() {
        if (widget.initialAd != null) {
          _fillFromAd(widget.initialAd!);
        } else {
          _loadDraft();
        }
      });
    }
  }

  void _fillFromAd(AdModel ad) {
    _titleController.text = ad.title;
    _descriptionController.text = ad.description;
    _priceController.text = ad.price.toInt().toString();
    _selectedCategory = ad.category;
    _selectedLocation = ad.location;
    _condition = ad.condition;
    _bargainAvailable = ad.isBargainAllowed;
    _canExchange = ad.canExchange;
    _hasDelivery = ad.hasDelivery;
    _existingImageUrls = List<String>.from(ad.images);
    if (ad.userPhone != null && ad.userPhone!.isNotEmpty) {
      final digits = ad.userPhone!.replaceAll(RegExp(r'\D'), '');
      String localDigits = digits;
      if (digits.length == 11 && (digits.startsWith('7') || digits.startsWith('8'))) {
        localDigits = digits.substring(1);
      } else if (digits.length > 11) {
        localDigits = digits.substring(digits.length - 10);
      }
      _phoneController.text = _phoneMask.maskText(localDigits);
    }
    if (ad.extraFields != null) {
      _selectedSubCategory = ad.extraFields!['subCategory'] as String?;
      if (ad.category == 'Авто') {
        _carBrand = ad.extraFields!['carBrand'] as String?;
        _carModel = ad.extraFields!['carModel'] as String?;
        _carYear = ad.extraFields!['carYear'] as String?;
        _carBody = ad.extraFields!['carBody'] as String?;
        _carTransmission = ad.extraFields!['carTransmission'] as String?;
        _carDrive = ad.extraFields!['carDrive'] as String?;
        _carFuel = ad.extraFields!['carFuel'] as String?;
        _carColor = ad.extraFields!['carColor'] as String?;
        _carMileageController.text = ad.extraFields!['carMileage']?.toString() ?? '';
        _carEngineController.text = ad.extraFields!['carEngine']?.toString() ?? '';
      } else if (ad.category == 'Недвижимость') {
        _reRooms = ad.extraFields!['reRooms'] as String?;
        _reFloor = ad.extraFields!['reFloor'] as String?;
        _reAreaController.text = ad.extraFields!['reArea']?.toString() ?? '';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = CategoryData.categories;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.initialAd != null 
              ? TranslationService.t('edit_ad', widget.lang) 
              : TranslationService.t('post_ad', widget.lang), 
          style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18, color: const Color(0xFF0F172A)),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)), 
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (ctx) => HelpCenterScreen(lang: widget.lang))),
              child: Container(
                width: 26,
                height: 26,
                margin: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF0F172A), width: 1.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: const Text(
                  '?',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    height: 1.1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: PopScope(
        canPop: !_isLoading && !_isSubmitting,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (!_isLoading && !_isSubmitting) {
            Navigator.of(context).maybePop();
          }
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
                    existingImageUrls: _existingImageUrls,
                    videoFile: _videoFile,
                    onPickImages: _isLoading ? () {} : () => _pickMedia(false),
                    onPickVideo: _isLoading ? () {} : () => _pickMedia(true),
                    onRemoveImage: (i) => setState(() { _imageFiles.removeAt(i); _saveDraft(); }),
                    onRemoveExistingImage: (i) => setState(() { _existingImageUrls.removeAt(i); }),
                    onRemoveVideo: () => setState(() { _videoFile = null; _saveDraft(); }),
                  ),
                  const SizedBox(height: 30),
                  CategorySelector(
                    categories: categories,
                    selectedCategoryId: _selectedCategory,
                    selectedSubCategoryId: _selectedSubCategory,
                    isAutoDetected: _isAutoDetectedCategory,
                    onCategorySelected: (cat) => setState(() { 
                      _selectedCategory = cat; 
                      _selectedSubCategory = null; 
                      _isCategoryUserOverridden = true;
                      _isAutoDetectedCategory = false;
                      _saveDraft(); 
                    }),
                    onSubCategorySelected: (sub) => setState(() { 
                      _selectedSubCategory = sub; 
                      _saveDraft(); 
                    }),
                  ),
                  _buildCategorySpecs(),
                  const SizedBox(height: 30),
                  _buildFormFields(),
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
    PostAdInput(
      label: TranslationService.t('title_label', widget.lang), 
      controller: _titleController, 
      hint: TranslationService.t('title_hint', widget.lang), 
      isRequired: true, 
      maxLength: 50, 
      onChanged: (_) => _onTitleOrDescriptionInput(),
    ),
    const SizedBox(height: 20),
    PostAdInput(
      label: TranslationService.t('description_label', widget.lang), 
      controller: _descriptionController, 
      hint: TranslationService.t('description_hint', widget.lang), 
      maxLines: 5, 
      maxLength: 1000, 
      onChanged: (_) => _onTitleOrDescriptionInput(),
    ),
    const SizedBox(height: 20),
    if (_selectedCategory != 'Отдам даром') ...[
      PostAdInput(
        label: TranslationService.t('price_label', widget.lang),
        controller: _priceController,
        hint: TranslationService.t('price_hint', widget.lang),
        keyboardType: TextInputType.number,
        isRequired: true,
        inputFormatters: [PriceInputFormatter()],
        onChanged: (_) => _saveDraft(),
        prefixIcon: const Icon(Icons.local_offer_outlined, color: Color(0xFF64748B), size: 20),
        suffixText: '₸',
      ),
      const SizedBox(height: 20),
    ],
    PostAdInput(
      label: TranslationService.t('phone_contact', widget.lang), 
      controller: _phoneController, 
      hint: '+7 (700) 000-00-00', 
      keyboardType: TextInputType.phone, 
      isRequired: true, 
      inputFormatters: [_phoneMask], 
      onChanged: (_) => _saveDraft(),
      prefixIcon: const Icon(Icons.phone_outlined, color: Color(0xFF64748B), size: 20),
    ),
    const SizedBox(height: 20),
    LocationSelector(
      selectedLocation: _selectedLocation, 
      displayCities: KazakhstanLocations.getAllLocations(),
      onLocationSelected: (loc) => setState(() { _selectedLocation = loc; _saveDraft(); })
    ),
    const SizedBox(height: 20),
    if (_selectedCategory != 'Малбазар' && _selectedCategory != 'Недвижимость') _buildConditionSelector(),
  ]);

  Widget _buildCategorySpecs() {
    Widget child = const SizedBox.shrink();
    if (_selectedCategory == 'Авто') {
      final vehicleSubs = ['cars', 'trucks', 'moto', 'special'];
      if (_selectedSubCategory != null && vehicleSubs.contains(_selectedSubCategory)) {
        child = CarSpecsWidget(
          carBrand: _carBrand,
          carModel: _carModel,
          carYear: _carYear,
          carBody: _carBody,
          carTransmission: _carTransmission,
          carDrive: _carDrive,
          carFuel: _carFuel,
          carColor: _carColor,
          carMileageController: _carMileageController,
          carEngineController: _carEngineController,
          onSelect: (f, v) => setState(() {
            if (f == 'carBrand') _carBrand = v;
            if (f == 'carModel') _carModel = v;
            if (f == 'carYear') _carYear = v;
            if (f == 'carBody') _carBody = v;
            if (f == 'carTransmission') _carTransmission = v;
            if (f == 'carDrive') _carDrive = v;
            if (f == 'carFuel') _carFuel = v;
            if (f == 'carColor') _carColor = v;
            _saveDraft();
          }),
        );
      }
    } else if (_selectedCategory == 'Недвижимость') {
      child = RealEstateSpecsWidget(
        reRooms: _reRooms,
        reFloor: _reFloor,
        reAreaController: _reAreaController,
        onSelect: (f, v) => setState(() {
          if (f == 'reRooms') _reRooms = v;
          if (f == 'reFloor') _reFloor = v;
          _saveDraft();
        }),
      );
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: child is SizedBox
          ? child
          : Padding(
              padding: const EdgeInsets.only(top: 30),
              child: child,
            ),
    );
  }

  Widget _buildConditionSelector() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        TranslationService.t('condition', widget.lang), 
        style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15, color: const Color(0xFF0F172A)),
      ),
      const SizedBox(height: 12),
      Row(children: [
        _conditionBtn('Новый'), const SizedBox(width: 12), _conditionBtn('Б/у'),
      ]),
    ],
  );

  Widget _conditionBtn(String label) {
    bool isSelected = _condition == label;
    String displayLabel = label == 'Новый' 
        ? TranslationService.t('cond_new', widget.lang) 
        : TranslationService.t('cond_used', widget.lang);

    final IconData icon = label == 'Новый' 
        ? Icons.auto_awesome_rounded 
        : Icons.watch_later_outlined;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() { _condition = label; _saveDraft(); }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 70,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFEBF3FF) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? const Color(0xFF1A73E8) : const Color(0xFFF1F5F9), 
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? const Color(0xFF1A73E8) : const Color(0xFF64748B),
                size: 20,
              ),
              const SizedBox(height: 6),
              Text(
                displayLabel, 
                style: GoogleFonts.inter(
                  color: isSelected ? const Color(0xFF1A73E8) : const Color(0xFF64748B), 
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, 
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptions() => Column(children: [
    PostAdOptionSwitch(
      label: TranslationService.t('bargain_switch', widget.lang), 
      value: _bargainAvailable, 
      onChanged: (v) => setState(() { _bargainAvailable = v; _saveDraft(); }),
      icon: Icons.local_offer_outlined,
    ),
    PostAdOptionSwitch(
      label: TranslationService.t('exchange_switch', widget.lang), 
      value: _canExchange, 
      onChanged: (v) => setState(() { _canExchange = v; _saveDraft(); }),
      icon: Icons.swap_horiz_rounded,
    ),
    PostAdOptionSwitch(
      label: TranslationService.t('delivery_switch', widget.lang), 
      value: _hasDelivery, 
      onChanged: (v) => setState(() { _hasDelivery = v; _saveDraft(); }),
      icon: Icons.local_shipping_outlined,
    ),
  ]);

  Widget _buildActionButtons() => Column(children: [
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F5FF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFF1A73E8), size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              TranslationService.t('ad_tip_banner', widget.lang),
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF1E3A8A),
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    ),
    const SizedBox(height: 24),
    SizedBox(
      width: double.infinity, 
      height: 56, 
      child: OutlinedButton.icon(
        onPressed: (_isLoading || _isSubmitting) ? null : _showPreview, 
        icon: const Icon(Icons.visibility_outlined, size: 20), 
        label: Text(TranslationService.t('preview', widget.lang)), 
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF1A73E8), 
          side: const BorderSide(color: Color(0xFF1A73E8), width: 1.5), 
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), 
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
    ),
    const SizedBox(height: 12),
    SizedBox(
      width: double.infinity, 
      height: 56, 
      child: ElevatedButton.icon(
        onPressed: (_isLoading || _isSubmitting) ? null : _handlePublish, 
        icon: (_isLoading || _isSubmitting)
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
              )
            : const Icon(Icons.near_me_outlined, size: 20),
        label: Text(
          (_isLoading || _isSubmitting)
              ? (widget.initialAd != null 
                  ? TranslationService.t('updating', widget.lang) 
                  : TranslationService.t('publishing', widget.lang))
              : (widget.initialAd != null 
                  ? TranslationService.t('update', widget.lang) 
                  : TranslationService.t('publish', widget.lang)), 
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1A73E8), 
          disabledBackgroundColor: const Color(0xFF93C5FD),
          foregroundColor: Colors.white, 
          disabledForegroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), 
          elevation: 0,
        ),
      ),
    ),
  ]);

  Widget _buildLoadingOverlay() => AbsorbPointer(
    absorbing: true,
    child: Container(
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
    ),
  );

  // --- Logic Methods ---

  Future<void> _pickMedia(bool isVideo) async {
    if (_isLoading || _isSubmitting) return;

    // Проверяем лимит фото ДО открытия галереи: если слотов уже нет, даже не
    // открываем пикер — раньше здесь пускали в галерею без ограничения, юзер
    // мог натыкать там хоть 20 штук, и только после возврата в приложение
    // лишние молча обрезались. Выглядело как "лимит не работает".
    int remainingSlots = 0;
    if (!isVideo) {
      remainingSlots = _maxPhotos - (_existingImageUrls.length + _imageFiles.length);
      if (remainingSlots <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(TranslationService.t('err_max_photos', widget.lang).replaceAll('{max}', '$_maxPhotos'))),
        );
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      if (isVideo) {
        final XFile? file = await _picker.pickVideo(source: ImageSource.gallery);
        if (file != null) {
          if (mounted) {
            Navigator.push(context, MaterialPageRoute(builder: (context) => VideoTrimmerScreen(
              videoFile: File(file.path),
              onSave: (path) {
                if (mounted) {
                  setState(() { _videoFile = File(path); _saveDraft(); });
                }
              }
            )));
          }
        }
      } else {
        // limit: сама галерея (Android Photo Picker / iOS PHPicker) не даёт
        // отметить больше remainingSlots штук — раньше лимита не было и
        // ограничение применялось только постфактум, после возврата в приложение.
        //
        // ВАЖНО: limit допустим только >= 2. pickMultiImage прогоняет его через
        // MultiImagePickerOptions.createAndValidate, который на значении 1
        // бросает ArgumentError. Из-за этого при ровно одном свободном слоте
        // (7 фото из 8) галерея вообще не открывалась: срабатывал catch ниже и
        // пользователь получал красный тост с текстом ошибки вместо выбора
        // фото — последнее фото добавить было невозможно. На последнем слоте
        // передаём null и полагаемся на take(remainingSlots) ниже.
        final List<XFile> picked = await _picker.pickMultiImage(
          imageQuality: 75,
          maxWidth: 1280,
          maxHeight: 1280,
          limit: remainingSlots >= 2 ? remainingSlots : null,
        );
        if (picked.isNotEmpty && mounted) {
          // Доп. страховка на случай платформы, которая limit не поддержала.
          final toAdd = picked.take(remainingSlots).toList();
          setState(() {
            _imageFiles.addAll(toAdd.map((f) => File(f.path)));
            _saveDraft();
          });
          if (toAdd.length < picked.length) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(TranslationService.t('err_max_photos', widget.lang).replaceAll('{max}', '$_maxPhotos'))),
            );
          }
        }
      }
    } catch (e) {
      debugPrint("Error picking ad media: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(TranslationService.t('errSelectMedia', widget.lang).replaceAll('{error}', e.toString())),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handlePublish() async {
    // 🔒 Synchronous Atomic Double-Submit Protection
    if (_isSubmitting || _isLoading) return;

    _isSubmitting = true;
    setState(() {
      _isLoading = true;
      _uploadStatus = widget.initialAd != null
          ? TranslationService.t('updating', widget.lang)
          : TranslationService.t('publishing', widget.lang);
    });

    // Validations
    if (_titleController.text.trim().length < 5) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(TranslationService.t('err_title_short', widget.lang))));
      } else {
        _isSubmitting = false;
      }
      return;
    }

    if (_descriptionController.text.trim().length < 10) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(TranslationService.t('err_desc_short', widget.lang))));
      } else {
        _isSubmitting = false;
      }
      return;
    }

    if (_selectedCategory == 'all' || _selectedCategory.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(TranslationService.t('err_select_cat', widget.lang))));
      } else {
        _isSubmitting = false;
      }
      return;
    }

    final priceClean = _priceController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final priceVal = double.tryParse(priceClean) ?? 0;
    if (_selectedCategory != 'Отдам даром' && priceVal <= 0) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(TranslationService.t('err_invalid_price', widget.lang))));
      } else {
        _isSubmitting = false;
      }
      return;
    }

    // 🔒 STRICT Validation: Phone number must be exactly 11 digits
    final unformattedPhone = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (unformattedPhone.length != 11) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isSubmitting = false;
        });
        final saved = await PhoneRequiredBottomSheet.showInput(
          context,
          subtitle: 'Для публикации объявления необходимо указать контактный номер телефона.',
        );
        if (saved) {
          final updatedPhone = UserService.currentUid != null ? (await UserService.getUserById(UserService.currentUid!))?.phone : null;
          final phoneToUse = (updatedPhone?.isNotEmpty == true) ? updatedPhone! : (StorageService.getString('user_phone') ?? '');
          if (phoneToUse.isNotEmpty) {
            final digits = phoneToUse.replaceAll(RegExp(r'\D'), '');
            String localDigits = digits;
            if (digits.length == 11 && (digits.startsWith('7') || digits.startsWith('8'))) {
              localDigits = digits.substring(1);
            }
            _phoneController.text = _phoneMask.maskText(localDigits);
          }
        }
      } else {
        _isSubmitting = false;
      }
      return;
    }

    if (_selectedLocation.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(TranslationService.t('err_select_city', widget.lang))));
      } else {
        _isSubmitting = false;
      }
      return;
    }

    try {
      final priceClean = _priceController.text.replaceAll(RegExp(r'[^0-9]'), '');
      final id = await AdService.uploadAndPublishAd(
        title: _titleController.text,
        description: _descriptionController.text,
        price: _selectedCategory == 'Отдам даром' ? '0' : priceClean,
        category: _selectedCategory,
        location: _selectedLocation,
        images: _imageFiles,
        existingImages: _existingImageUrls,
        video: _videoFile,
        condition: _condition,
        bargain: _bargainAvailable,
        exchange: _canExchange,
        delivery: _hasDelivery,
        lang: widget.lang,
        initialAdId: widget.initialAd?.id,
        userPhone: _phoneController.text,
        onStatusUpdate: (s) {
          if (mounted) setState(() => _uploadStatus = s);
        },
        extraFields: {
          'subCategory': _selectedSubCategory,
          if (_selectedCategory == 'Авто') ...{
            'carBrand': _carBrand, 'carModel': _carModel, 'carYear': _carYear,
            'carBody': _carBody, 'carTransmission': _carTransmission,
            'carDrive': _carDrive, 'carFuel': _carFuel, 'carColor': _carColor,
            'carMileage': _carMileageController.text, 'carEngine': _carEngineController.text,
          },
          if (_selectedCategory == 'Недвижимость') ...{
            'reRooms': _reRooms,
            'reFloor': _reFloor,
            'reArea': _reAreaController.text,
          },
        }
      );
      
      _clearDraft();
      if (mounted) _showSuccessDialog(id.isNotEmpty);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${TranslationService.t('error_saving_msg', widget.lang)}: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isSubmitting = false;
        });
      } else {
        _isSubmitting = false;
      }
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
            Lottie.network(
              'https://lottie.host/76b76a0d-959c-4f7d-8153-9110b1062a4b/pM6s7K2A8H.json',
              height: 140,
              repeat: false,
              errorBuilder: (context, error, stackTrace) {
                // World-class fallback in case of connection closed or client exception
                return Container(
                  height: 140,
                  alignment: Alignment.center,
                  child: TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 600),
                    tween: Tween(begin: 0.0, end: 1.0),
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: const Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF84CC16),
                          size: 100,
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            Text(TranslationService.t('success_dialog_title', widget.lang), style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            Text(isApproved ? TranslationService.t('success_dialog_published', widget.lang) : TranslationService.t('success_dialog_moderation', widget.lang), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () { Navigator.pop(context); Navigator.pop(context); }, child: Text(TranslationService.t('success_dialog_ok', widget.lang)))),
          ],
        ),
      ),
    );
  }

  // --- Draft Logic ---
  void _saveDraft() {
    if (widget.initialAd != null) return;
    // Debounce — эта функция дёргается на КАЖДОЕ нажатие клавиши в заголовке/
    // описании/цене/телефоне; без debounce это диск-запись SharedPreferences
    // на каждый символ.
    _draftDebounce?.cancel();
    _draftDebounce = Timer(const Duration(milliseconds: 500), _writeDraft);
  }

  Future<void> _writeDraft() async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final draft = {
      'title': _titleController.text,
      'desc': _descriptionController.text,
      'price': _priceController.text,
      'phone': _phoneController.text,
      'cat': _selectedCategory,
      'loc': _selectedLocation,
      'cond': _condition,
      'images': _imageFiles.map((f) => f.path).toList(),
      'video': _videoFile?.path,
    };
    await prefs.setString('ad_draft', jsonEncode(draft));
  }

  void _loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
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
        
        if (_phoneController.text.isEmpty && draft['phone'] != null && draft['phone'].toString().isNotEmpty) {
          _phoneController.text = draft['phone'].toString();
        }

        if (draft['images'] != null) {
          final List<dynamic> paths = draft['images'];
          for (var path in paths) {
            if (File(path).existsSync()) {
              _imageFiles.add(File(path));
            }
          }
        }
        if (draft['video'] != null) {
          if (File(draft['video']).existsSync()) {
            _videoFile = File(draft['video']);
          }
        }
      });
    }
  }

  void _clearDraft() async {
    _draftDebounce?.cancel();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('ad_draft');
  }

  void _showPreview() {
    // Basic preview
    final priceClean = _priceController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final ad = AdModel(
      id: '__preview_ad__', title: _titleController.text, description: _descriptionController.text,
      price: double.tryParse(priceClean) ?? 0.0, 
      category: _selectedCategory, 
      images: _imageFiles.map((f)=>f.path).toList(),
      videoUrl: _videoFile?.path,
      userId: '__preview_user__', userName: 'Вы', userEmail: '', timestamp: DateTime.now(), location: _selectedLocation,
      userPhone: _phoneController.text,
    );
    Navigator.push(context, MaterialPageRoute(builder: (context) => ProductDetailsScreen(ad: ad, lang: widget.lang, onReport: (_){}, heroPrefix: 'p_', isPreview: true)));
  }
}
