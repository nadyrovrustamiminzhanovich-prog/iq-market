import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:iqmarket/providers/taxi_provider.dart';
import 'package:iqmarket/services/telegram_bot_service.dart';
import 'package:iqmarket/theme/taxi_theme.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:iqmarket/services/file_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:iqmarket/services/gemini_service.dart';

class DriverVerificationScreen extends StatefulWidget {
  const DriverVerificationScreen({super.key});
  @override
  State<DriverVerificationScreen> createState() => _DriverVerificationScreenState();
}

class _DriverVerificationScreenState extends State<DriverVerificationScreen>
    with TickerProviderStateMixin {
  int _step = 0;
  final _picker = ImagePicker();
  final _plateC = TextEditingController();
  final _carC   = TextEditingController();
  String? _selectedBrand;
  String? _selectedModel;
  
  final List<String> _carBrands = [
    'Toyota', 'Lexus', 'Mercedes-Benz', 'BMW', 'Audi', 'Hyundai', 'Kia', 'Nissan', 'Honda', 'Lada (ВАЗ)', 
    'Mitsubishi', 'Mazda', 'Chevrolet', 'Volkswagen', 'Subaru', 'Ford', 'Renault', 'Daewoo', 'Ravon', 
    'Geely', 'Chery', 'Haval', 'Changan', 'Exeed', 'JAC', 'Zeekr', 'Li Auto (Lixiang)', 'Voyah', 'Tank', 'BYD',
    'Porsche', 'Land Rover', 'Volvo', 'Skoda', 'Tesla', 'Другая'
  ];
  
  final Map<String, List<String>> _carModels = {
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
    'Geely': ['Atlas', 'Coolray', 'Monjaro', 'Tugella', 'Emgrand', 'Okavango', 'Geometry'],
    'Chery': ['Tiggo 2', 'Tiggo 4', 'Tiggo 7', 'Tiggo 8', 'Arrizo 6', 'Arrizo 8'],
    'Haval': ['F7', 'Jolion', 'H6', 'H9', 'Dargo', 'M6'],
    'Changan': ['CS35 Plus', 'CS55 Plus', 'CS75 Plus', 'UNI-K', 'UNI-V', 'UNI-T', 'Alsvin'],
    'Exeed': ['LX', 'TXL', 'VX', 'RX'],
    'JAC': ['J7', 'S3', 'S5', 'T6', 'T8', 'iEV7S'],
    'Zeekr': ['001', '009', 'X', '007'],
    'Li Auto (Lixiang)': ['L7', 'L8', 'L9', 'One'],
    'Voyah': ['Free', 'Dream', 'Passion'],
    'Tank': ['300', '500'],
    'BYD': ['Han', 'Tang', 'Song', 'Qin', 'Seals', 'Dolphin'],
    'Porsche': ['Cayenne', 'Panamera', 'Macan', '911', 'Taycan'],
    'Land Rover': ['Range Rover', 'Range Rover Sport', 'Evoque', 'Discovery', 'Defender', 'Freelander'],
    'Volvo': ['S60', 'S80', 'S90', 'XC60', 'XC90', 'V40'],
    'Skoda': ['Octavia', 'Superb', 'Rapid', 'Kodiaq', 'Yeti', 'Fabia'],
    'Tesla': ['Model 3', 'Model Y', 'Model S', 'Model X', 'Cybertruck'],
    'Другая': [],
  };

  final _plateMask = MaskTextInputFormatter(
    mask: '### @@@ ##', 
    filter: { "#": RegExp(r'[0-9]'), "@": RegExp(r'[A-Za-z]') },
    type: MaskAutoCompletionType.lazy,
  );

  File? _licF, _techF, _selfie, _carFront;
  bool _analyzing = false;
  bool _done = false;
  bool _needsManual = false;
  String _aiMsg = '';
  late AnimationController _dotCtrl;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _dotCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat(reverse: true);
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeInOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _dotCtrl.dispose();
    _fadeCtrl.dispose();
    _plateC.dispose();
    _carC.dispose();
    super.dispose();
  }

  // ── Source Picker for Camera or Gallery ─────────────────────────────────────
  Future<ImageSource?> _showSourcePicker() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _t('choose_source'),
              style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16, color: const Color(0xFF1E293B)),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(ctx, ImageSource.camera),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4A80F0).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF4A80F0), size: 30),
                      ),
                      const SizedBox(height: 10),
                      Text(_t('camera'), style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12, color: const Color(0xFF475569))),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.photo_library_rounded, color: Color(0xFF10B981), size: 30),
                      ),
                      const SizedBox(height: 10),
                      Text(_t('gallery'), style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12, color: const Color(0xFF475569))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ── pick image ───────────────────────────────────────────────────────────────
  Future<void> _pick(String slot, {bool fromCameraOnly = false}) async {
    HapticFeedback.selectionClick();
    final ImageSource? source = fromCameraOnly 
        ? ImageSource.camera 
        : await _showSourcePicker();
    if (source == null) return;
    
    final f = await _picker.pickImage(
      source: source, 
      imageQuality: 88,
      preferredCameraDevice: fromCameraOnly ? CameraDevice.front : CameraDevice.rear,
    );
    if (f == null) return;
    
    setState(() {
      switch (slot) {
        case 'lf': _licF  = File(f.path); break;
        case 'tf': _techF = File(f.path); break;
        case 'se': _selfie = File(f.path); break;
        case 'cf': _carFront = File(f.path); break;
      }
    });
  }

  // ── step validation ──────────────────────────────────────────────────────────
  bool get _canNext {
    switch (_step) {
      case 0: return _licF != null && _techF != null && _selfie != null;
      case 1: return _carFront != null && _plateC.text.trim().length >= 5 && (_selectedBrand != null || _carC.text.trim().length >= 4);
      default: return false;
    }
  }

  Future<void> _runAnalysis() async {
    final provider = Provider.of<TaxiProvider>(context, listen: false);
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
    final prefs = await SharedPreferences.getInstance();
    final chatId = prefs.getString('telegram_chat_id') ?? '';
    final docId = '${provider.firstName}_${_plateC.text.trim()}_${DateTime.now().millisecondsSinceEpoch}';

    try {
      // 1. Оптимизация и сжатие картинок на лету (режим Х10)
      setState(() { _analyzing = true; _aiMsg = _t('compressing'); });
      final compLicF = await FileService.compressImage(_licF!);
      final compTechF = await FileService.compressImage(_techF!);
      final compSelfie = await FileService.compressImage(_selfie!);
      final compCarFront = await FileService.compressImage(_carFront!);

      // 2. Загрузка документов в облачное хранилище Firebase Storage
      setState(() => _aiMsg = _t('uploading'));
      final licFUrl = await FileService.uploadFile(compLicF ?? _licF!, 'driver_documents/$uid/license_front');
      final techFUrl = await FileService.uploadFile(compTechF ?? _techF!, 'driver_documents/$uid/tech_front');
      final selfieUrl = await FileService.uploadFile(compSelfie ?? _selfie!, 'driver_documents/$uid/selfie');
      final carFrontUrl = await FileService.uploadFile(compCarFront ?? _carFront!, 'driver_documents/$uid/car_front');

      if (licFUrl == null || techFUrl == null || selfieUrl == null || carFrontUrl == null) {
        throw Exception(_t('upload_err'));
      }

      setState(() => _aiMsg = _t('ai_analyzing_gemini'));
      
      final gemini = GeminiService();
      gemini.init(provider.curLang);
      
      final aiResult = await gemini.analyzeDriverDocuments(
        license: compLicF ?? _licF!,
        techPassport: compTechF ?? _techF!,
        selfie: compSelfie ?? _selfie!,
        carFront: compCarFront ?? _carFront!,
        driverName: '${provider.firstName} ${provider.lastName}',
        plate: _plateC.text.trim().toUpperCase(),
        carModel: _carC.text.trim(),
      );

      final bool isLicenseValid = aiResult['license_valid'] ?? false;
      final bool isTechPassportValid = aiResult['tech_passport_valid'] ?? false;
      final bool isSelfieValid = aiResult['selfie_valid'] ?? false;
      final bool isCarValid = aiResult['car_valid'] ?? false;
      final bool isNameMatches = aiResult['name_matches'] ?? false;
      final bool isPlateMatches = aiResult['plate_matches'] ?? false;
      final bool isCarModelMatches = aiResult['car_model_matches'] ?? false;
      final bool isBlurry = aiResult['blurry_photo_detected'] ?? false;
      final String aiReason = aiResult['reason'] ?? _t('no_description');
      final String aiConfidence = aiResult['confidence'] ?? 'low';
      
      final bool aiApproved = isLicenseValid &&
          isTechPassportValid &&
          isSelfieValid &&
          isCarValid &&
          isNameMatches &&
          isPlateMatches &&
          isCarModelMatches &&
          !isBlurry &&
          aiConfidence == 'high';

      _needsManual = !aiApproved;

      // 3. Сохранение заявки с ссылками на фото в Firestore
      await FirebaseFirestore.instance.collection('driver_verifications').doc(docId).set({
        'userId'         : uid,               // ← ключевое поле для поиска по uid
        'driver_name'    : '${provider.firstName} ${provider.lastName}',
        'plate'          : _plateC.text.trim().toUpperCase(),
        'car'            : _carC.text.trim(),
        'driver_chat_id' : chatId,
        'status'         : _needsManual ? 'pending_manual' : 'approved_by_ai',
        'ai_result'      : aiResult,
        'ai_quality'     : aiConfidence,
        'submitted_at'   : FieldValue.serverTimestamp(),
        'licF'           : licFUrl,
        'techF'          : techFUrl,
        'selfie'         : selfieUrl,
        'carFront'       : carFrontUrl,
      });

      // 4. Отправка отчета со всеми фото админу в Телеграм
      if (_needsManual) {
        setState(() => _aiMsg = _t('ai_manual_msg'));
        await TelegramBotService.notifyAdminManualReview(
          driverName   : '${provider.firstName} ${provider.lastName}',
          plate        : _plateC.text.trim().toUpperCase(),
          carModel     : _carC.text.trim(),
          driverChatId : chatId,
          reviewDocId  : docId,
          reason       : '⚠️ ИИ обнаружил проблему: $aiReason (Уверенность: $aiConfidence)',
          licF         : licFUrl,
          techF        : techFUrl,
          selfie       : selfieUrl,
          carFront       : carFrontUrl,
        );
      } else {
        provider.setVehicleVerified(true);
        await TelegramBotService.notifyAdminManualReview(
          driverName   : '${provider.firstName} ${provider.lastName}',
          plate        : _plateC.text.trim().toUpperCase(),
          carModel     : _carC.text.trim(),
          driverChatId : chatId,
          reviewDocId  : docId,
          reason       : '🤖 ИИ автоматически ОДОБРИЛ. Вы можете отозвать доступ кнопкой ниже.',
          licF         : licFUrl,
          techF        : techFUrl,
          selfie       : selfieUrl,
          carFront     : carFrontUrl,
        );
      }

      await _delay(600);
      setState(() { _analyzing = false; _done = true; });
    } catch (e) {
      debugPrint('Error in _runAnalysis: $e');
      setState(() { _analyzing = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_t('verif_err_prefix')} ${e.toString()} ⚠️'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          ),
        );
      }
    }
  }

  Future<void> _delay(int ms) => Future.delayed(Duration(milliseconds: ms));

  void _next() {
    _fadeCtrl.reset();
    if (_step < 1) {
      setState(() => _step++);
      _fadeCtrl.forward();
    } else {
      _runAnalysis();
    }
  }

  String _t(String key) {
    return Provider.of<TaxiProvider>(context, listen: false).translate(key);
  }

  @override
  Widget build(BuildContext context) {
    final p = Provider.of<TaxiProvider>(context);
    final t = p.theme;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(children: [
          _header(t),
          if (!_done && !_analyzing) _progressRow(t),
          Expanded(child: _body(t, p)),
          if (!_done && !_analyzing) _bottomBar(t),
        ]),
      ),
    );
  }

  // ── header ──────────────────────────────────────────────────────────────────
  Widget _header(TaxiTheme t) => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: [t.accent, t.accent.withValues(alpha: 0.75)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    ),
    padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 12, 16, 20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_t('driver_verif_title'), style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
          Text('${_t('step')} ${_step + 1} ${_t('of')} 2 — ${_t('security')} 🛡️', style: GoogleFonts.inter(color: Colors.white70, fontSize: 11)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(24)),
          child: Text('${_step + 1}/2', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
        ),
      ]),
    ]),
  );

  // ── progress row ─────────────────────────────────────────────────────────────
  Widget _progressRow(TaxiTheme t) {
    final labels = [_t('docs_label'), _t('car_label')];
    final icons  = [Icons.assignment_rounded, Icons.directions_car_rounded];
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      child: Row(children: List.generate(2, (i) {
        final active = i == _step;
        final done   = i < _step;
        final color  = done ? Colors.green : (active ? t.accent : t.border);
        return Expanded(child: Row(children: [
          Expanded(child: i == 0 ? const SizedBox() : Container(height: 3, color: done ? Colors.green : t.border.withValues(alpha: 0.5))),
          Column(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: active ? 44 : 34, height: active ? 44 : 34,
              decoration: BoxDecoration(
                color: done ? Colors.green : (active ? t.accent.withValues(alpha: 0.1) : t.card),
                shape: BoxShape.circle,
                border: Border.all(color: color, width: active ? 2.5 : 1.5),
                boxShadow: active ? [BoxShadow(color: t.accent.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 3))] : [],
              ),
              child: Center(child: done
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                : Icon(icons[i], color: active ? t.accent : t.sub.withValues(alpha: 0.7), size: active ? 22 : 16)),
            ),
            const SizedBox(height: 6),
            Text(labels[i], style: GoogleFonts.inter(
              color: active ? t.accent : t.sub, 
              fontSize: active ? 12 : 11, 
              fontWeight: active ? FontWeight.w900 : FontWeight.w600,
              letterSpacing: -0.3
            )),
          ]),
          Expanded(child: i == 1 ? const SizedBox() : Container(height: 3, color: done ? Colors.green : t.border.withValues(alpha: 0.5))),
        ]));
      })),
    );
  }

  // ── body dispatcher ──────────────────────────────────────────────────────────
  Widget _body(TaxiTheme t, TaxiProvider p) {
    if (_analyzing) return _analyzingView(t);
    if (_done) return _doneView(t);
    return FadeTransition(
      opacity: _fadeAnim,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: [_documentsStepView, _autoStepView][_step](t),
      ),
    );
  }

  // ── STEP 1: Documents View ──────────────────────────────────────────────────
  Widget _documentsStepView(TaxiTheme t) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _sectionTitle(t, _t('step_1_title'), _t('step_1_sub')),
    const SizedBox(height: 20),
    _photoCard(t, _t('licence_label'), _t('licence_desc'), _licF, () => _pick('lf')),
    const SizedBox(height: 16),
    _photoCard(t, _t('tech_label'), _t('tech_desc'), _techF, () => _pick('tf')),
    const SizedBox(height: 16),
    _photoCard(t, _t('selfie_label'), _t('selfie_desc'), _selfie, () => _pick('se', fromCameraOnly: true)),
    const SizedBox(height: 24),
    _tipBox(t, _t('step_1_tip')),
  ]);

  // ── STEP 2: Auto View ───────────────────────────────────────────────────────
  Widget _autoStepView(TaxiTheme t) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _sectionTitle(t, _t('step_2_title'), _t('step_2_sub')),
    const SizedBox(height: 20),
    _photoCard(t, _t('car_front_label'), _t('car_front_desc'), _carFront, () => _pick('cf')),
    const SizedBox(height: 24),
    // Brand picker
    GestureDetector(
      onTap: () => _showBrandPicker(t),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: t.card, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _selectedBrand != null ? t.accent : t.border, width: _selectedBrand != null ? 2 : 1),
        ),
        child: Row(children: [
          Icon(Icons.directions_car_rounded, color: t.accent, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Text(_selectedBrand ?? _t('choose_brand'), style: GoogleFonts.inter(color: _selectedBrand != null ? t.text : t.sub, fontWeight: FontWeight.w700))),
          Icon(Icons.keyboard_arrow_down_rounded, color: t.sub),
        ]),
      ),
    ),
    const SizedBox(height: 12),
    // Model picker
    if (_selectedBrand != null && (_carModels[_selectedBrand!] ?? []).isNotEmpty)
      GestureDetector(
        onTap: () => _showModelPicker(t),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: t.card, borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _selectedModel != null ? t.accent : t.border, width: _selectedModel != null ? 2 : 1),
          ),
          child: Row(children: [
            Icon(Icons.list_rounded, color: t.accent, size: 22),
            const SizedBox(width: 12),
            Expanded(child: Text(_selectedModel ?? _t('choose_model'), style: GoogleFonts.inter(color: _selectedModel != null ? t.text : t.sub, fontWeight: FontWeight.w700))),
            Icon(Icons.keyboard_arrow_down_rounded, color: t.sub),
          ]),
        ),
      ),
    if (_selectedBrand != null && (_carModels[_selectedBrand!] ?? []).isEmpty)
      _field(t, _t('model'), _t('model_manual'), Icons.list_rounded, _carC),
    const SizedBox(height: 12),
    _field(t, _t('plate_label'), '777 AAA 05', Icons.pin_rounded, _plateC, textCaps: true, mask: _plateMask),
    const SizedBox(height: 20),
    _tipBox(t, _t('step_2_tip')),
  ]);

  void _showBrandPicker(TaxiTheme t) {
    String q = "";
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, ss) => Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(color: t.bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
          child: Column(children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: t.border, borderRadius: BorderRadius.circular(10))),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Text(_t('brand_picker_title'), style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.w900, fontSize: 18))),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                onChanged: (v) => ss(() => q = v),
                style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  hintText: _t('search_brand'),
                  prefixIcon: Icon(Icons.search_rounded, color: t.accent),
                  filled: true, fillColor: t.card,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _carBrands.where((b) => b.toLowerCase().contains(q.toLowerCase())).length,
              itemBuilder: (ctx, i) {
                final filtered = _carBrands.where((b) => b.toLowerCase().contains(q.toLowerCase())).toList();
                final b = filtered[i];
                return GestureDetector(
                  onTap: () { setState(() { _selectedBrand = b; _selectedModel = null; _carC.clear(); }); Navigator.pop(context); },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: _selectedBrand == b ? t.accent.withValues(alpha: 0.1) : t.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _selectedBrand == b ? t.accent : Colors.transparent, width: 1.5),
                    ),
                    child: Row(children: [
                      Icon(Icons.directions_car_filled_rounded, color: _selectedBrand == b ? t.accent : t.sub, size: 20),
                      const SizedBox(width: 12),
                      Text(b, style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.w700)),
                      const Spacer(),
                      if (_selectedBrand == b) Icon(Icons.check_circle_rounded, color: t.accent, size: 18),
                    ]),
                  ),
                );
              },
            )),
            const SizedBox(height: 20),
          ]),
        ),
      ),
    );
  }

  void _showModelPicker(TaxiTheme t) {
    final models = _carModels[_selectedBrand!] ?? [];
    String q = "";
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, ss) => Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(color: t.bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
          child: Column(children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: t.border, borderRadius: BorderRadius.circular(10))),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Text('${_t('model_picker_title')} $_selectedBrand', style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.w900, fontSize: 18))),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                onChanged: (v) => ss(() => q = v),
                style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  hintText: _t('search_model'),
                  prefixIcon: Icon(Icons.search_rounded, color: t.accent),
                  filled: true, fillColor: t.card,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: models.where((m) => m.toLowerCase().contains(q.toLowerCase())).length,
              itemBuilder: (ctx, i) {
                final filtered = models.where((m) => m.toLowerCase().contains(q.toLowerCase())).toList();
                final m = filtered[i];
                return GestureDetector(
                  onTap: () { setState(() { _selectedModel = m; _carC.text = '$_selectedBrand $m'; }); Navigator.pop(context); },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: _selectedModel == m ? t.accent.withValues(alpha: 0.1) : t.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _selectedModel == m ? t.accent : Colors.transparent, width: 1.5),
                    ),
                    child: Row(children: [
                      Text(m, style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.w700)),
                      const Spacer(),
                      if (_selectedModel == m) Icon(Icons.check_circle_rounded, color: t.accent, size: 18),
                    ]),
                  ),
                );
              },
            )),
            const SizedBox(height: 20),
          ]),
        ),
      ),
    );
  }

  // ── analyzing view ────────────────────────────────────────────────────────────
  Widget _analyzingView(TaxiTheme t) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    AnimatedBuilder(
      animation: _dotCtrl,
      builder: (_, __) => Container(
        width: 100, height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [
            t.accent.withValues(alpha: 0.3 + 0.4 * _dotCtrl.value),
            t.accent.withValues(alpha: 0.05),
          ]),
          boxShadow: [BoxShadow(color: t.accent.withValues(alpha: 0.4 * _dotCtrl.value), blurRadius: 30, spreadRadius: 10)],
        ),
        child: const Icon(Icons.psychology_rounded, color: Color(0xFF4A80F0), size: 48),
      ),
    ),
    const SizedBox(height: 32),
    Text(_t('ai_analyzing'), style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.w900, fontSize: 20)),
    const SizedBox(height: 12),
    AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Text(_aiMsg, key: ValueKey(_aiMsg), textAlign: TextAlign.center,
        style: GoogleFonts.inter(color: t.sub, fontSize: 14)),
    ),
    const SizedBox(height: 32),
    SizedBox(width: 200, child: LinearProgressIndicator(color: t.accent, backgroundColor: t.border, borderRadius: BorderRadius.circular(4), minHeight: 6)),
  ]));

  // ── done view ─────────────────────────────────────────────────────────────────
  Widget _doneView(TaxiTheme t) => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 110, height: 110,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: (_needsManual ? Colors.orange : Colors.green).withValues(alpha: 0.12),
          border: Border.all(color: _needsManual ? Colors.orange : Colors.green, width: 3),
        ),
        child: Icon(_needsManual ? Icons.hourglass_top_rounded : Icons.verified_rounded,
          color: _needsManual ? Colors.orange : Colors.green, size: 56),
      ),
      const SizedBox(height: 28),
      Text(
        _needsManual ? _t('verif_manual_title') : _t('verif_done_title'),
        style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.w900, fontSize: 24),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 14),
      Text(
        _needsManual ? _t('verif_manual_desc') : _t('verif_done_desc'),
        style: GoogleFonts.inter(color: t.sub, fontSize: 13, height: 1.6),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 32),
      if (_needsManual)
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.orange.withValues(alpha: 0.2))),
          child: Row(children: [
            const Icon(Icons.telegram, color: Color(0xFF0088CC), size: 28),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_t('telegram_notif'), style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.w800, fontSize: 13)),
              Text(_t('telegram_bot_hint'), style: GoogleFonts.inter(color: t.sub, fontSize: 11)),
            ])),
          ]),
        ),
      const SizedBox(height: 28),
      SizedBox(width: double.infinity, height: 54,
        child: ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: _needsManual ? Colors.orange : Colors.green,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            elevation: 0,
          ),
          child: Text(_t('go_back'), style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
        ),
      ),
    ]),
  ));

  // ── bottom nav bar ────────────────────────────────────────────────────────────
  Widget _bottomBar(TaxiTheme t) => Container(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
    decoration: BoxDecoration(color: t.bg, border: Border(top: BorderSide(color: t.border))),
    child: Row(children: [
      if (_step > 0)
        GestureDetector(
          onTap: () { setState(() => _step--); _fadeCtrl.reset(); _fadeCtrl.forward(); },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: t.card, shape: BoxShape.circle, border: Border.all(color: t.border)),
            child: Icon(Icons.arrow_back_rounded, color: t.text, size: 22),
          ),
        ),
      if (_step > 0) const SizedBox(width: 12),
      Expanded(
        child: GestureDetector(
          onTap: _canNext ? _next : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 56,
            decoration: BoxDecoration(
              gradient: _canNext
                ? LinearGradient(colors: [t.accent, t.accent.withValues(alpha: 0.7)])
                : null,
              color: _canNext ? null : t.border,
              borderRadius: BorderRadius.circular(18),
              boxShadow: _canNext ? [BoxShadow(color: t.accent.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))] : [],
            ),
            child: Center(child: Text(
              _step == 1 ? _t('run_ai_btn') : '${_t('next')} →',
              style: GoogleFonts.inter(color: _canNext ? Colors.white : t.sub, fontWeight: FontWeight.w600, fontSize: 14, letterSpacing: 0.5),
            )),
          ),
        ),
      ),
    ]),
  );

  // ── reusable widgets ──────────────────────────────────────────────────────────
  Widget _sectionTitle(TaxiTheme t, String title, String sub) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5)),
    const SizedBox(height: 4),
    Text(sub, style: GoogleFonts.inter(color: t.sub, fontSize: 12)),
  ]);

  Widget _photoCard(TaxiTheme t, String title, String sub, File? file, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 130,
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: file != null ? Colors.green : t.border, width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: file != null
        ? ClipRRect(borderRadius: BorderRadius.circular(18), child: Stack(fit: StackFit.expand, children: [
            Image.file(file, fit: BoxFit.cover),
            Positioned(top: 8, right: 8, child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
              child: const Icon(Icons.check, color: Colors.white, size: 14),
            )),
          ]))
        : Row(children: [
            const SizedBox(width: 20),
            Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: t.accent.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(Icons.add_photo_alternate_rounded, color: t.accent, size: 28)),
            const SizedBox(width: 16),
            Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.w800, fontSize: 14)),
              const SizedBox(height: 4),
              Text(sub, style: GoogleFonts.inter(color: t.sub, fontSize: 11)),
              const SizedBox(height: 8),
              Text(_t('tap_to_upload'), style: GoogleFonts.inter(color: t.accent, fontSize: 11, fontWeight: FontWeight.w700)),
            ])),
          ]),
    ),
  );

  Widget _field(TaxiTheme t, String label, String hint, IconData icon, TextEditingController c, {bool textCaps = false, MaskTextInputFormatter? mask}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: GoogleFonts.inter(color: t.sub, fontSize: 12, fontWeight: FontWeight.w700)),
    const SizedBox(height: 8),
    TextField(
      controller: c,
      inputFormatters: mask != null ? [mask] : null,
      textCapitalization: textCaps ? TextCapitalization.characters : TextCapitalization.words,
      onChanged: (_) => setState(() {}),
      style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: t.sub.withValues(alpha: 0.5)),
        prefixIcon: Icon(icon, color: t.accent, size: 20),
        filled: true, fillColor: t.card,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: t.accent, width: 2)),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
      ),
    ),
  ]);

  Widget _tipBox(TaxiTheme t, String text) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: t.accent.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(14), border: Border.all(color: t.accent.withValues(alpha: 0.15))),
    child: Row(children: [
      Icon(Icons.info_outline_rounded, color: t.accent, size: 18),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: GoogleFonts.inter(color: t.sub, fontSize: 12, height: 1.4))),
    ]),
  );
}
