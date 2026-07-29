import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:iqmarket/providers/app_config_provider.dart';
import 'package:iqmarket/providers/taxi_provider.dart';
import 'package:iqmarket/services/auth_service.dart';
import 'package:iqmarket/services/file_service.dart';
import 'package:iqmarket/services/gemini_service.dart';
import 'package:iqmarket/services/storage_service.dart';
import 'package:iqmarket/services/telegram_bot_service.dart';
import 'package:iqmarket/services/translation_service.dart';
import 'package:iqmarket/theme/taxi_theme.dart';

/// Единый мастер (wizard) верификации водителя "Стать водителем".
/// 
/// Состоит из 3 шагов:
///   Шаг 1 из 3: Подтверждение номера телефона через Telegram (Telegram OTP)
///   Шаг 2 из 3: Загрузка 3 фото (авто с номерами, удостоверение, техпаспорт) + выбор авто
///   Шаг 3 из 3: Статус заявки (Модерация / Одобрено ИИ / Отклонено)
class DriverOnboardingWizard extends StatefulWidget {
  final int? initialStep;
  const DriverOnboardingWizard({super.key, this.initialStep});

  @override
  State<DriverOnboardingWizard> createState() => _DriverOnboardingWizardState();
}

class _DriverOnboardingWizardState extends State<DriverOnboardingWizard>
    with TickerProviderStateMixin {
  int _step = 0; // 0: Telegram, 1: Docs & Car, 2: Status View
  bool _isLoadingState = true;

  // ── Step 1: Telegram State ──────────────────────────────────────────────────
  int _tgStep = 0; // 0: Phone Input, 1: OTP Input
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _otpCtrl = TextEditingController();
  final MaskTextInputFormatter _phoneMask = MaskTextInputFormatter(
    mask: '+7 (###) ###-##-##',
    filter: {"#": RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );
  bool _isWaitingForBot = false;
  int _timerSeconds = 180;
  Timer? _timer;
  String? _tgSessionToken;
  String? _chatId;
  StreamSubscription? _tgSessionSub;
  String? _tgErrorText;
  bool _isVerifyingOtp = false;

  // ── Step 2: Documents & Car State ──────────────────────────────────────────
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _plateC = TextEditingController();
  final TextEditingController _carC = TextEditingController();
  String? _selectedBrand;
  String? _selectedModel;
  String? _selectedColor;

  final List<String> _carColors = [
    'Белый', 'Черный', 'Серебристый', 'Серый', 'Синий', 'Красный', 'Бежевый', 
    'Зеленый', 'Коричневый', 'Желтый', 'Золотистый', 'Другой'
  ];

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

  final MaskTextInputFormatter _plateMask = MaskTextInputFormatter(
    mask: '### @@@ ##',
    filter: {"#": RegExp(r'[0-9]'), "@": RegExp(r'[A-Za-z]')},
    type: MaskAutoCompletionType.lazy,
  );

  File? _techF;    // Фото техпаспорта
  File? _carFront; // Фото автомобиля с читаемыми номерами

  bool _analyzing = false;
  bool _needsManual = false;
  bool _isRejected = false;
  String _rejectedReason = '';
  String _aiMsg = '';
  late AnimationController _dotCtrl;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _dotCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat(reverse: true);
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeInOut);
    _fadeCtrl.forward();

    _loadUserProgress();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tgSessionSub?.cancel();
    _dotCtrl.dispose();
    _fadeCtrl.dispose();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _plateC.dispose();
    _carC.dispose();
    super.dispose();
  }

  // ── Load User Progress & Verification Status ─────────────────────────────
  Future<void> _loadUserProgress() async {
    final user = FirebaseAuth.instance.currentUser;
    final provider = Provider.of<TaxiProvider>(context, listen: false);

    // Prefill phone
    String initialPhone = user?.phoneNumber ?? provider.phone;
    if (initialPhone.isNotEmpty) {
      final digits = initialPhone.replaceAll(RegExp(r'\D'), '');
      String localDigits = digits;
      if (digits.length == 11 && (digits.startsWith('7') || digits.startsWith('8'))) {
        localDigits = digits.substring(1);
      } else if (digits.length > 11) {
        localDigits = digits.substring(digits.length - 10);
      }
      _phoneCtrl.text = _phoneMask.maskText(localDigits);
    }

    if (user == null) {
      setState(() {
        _step = 0;
        _isLoadingState = false;
      });
      return;
    }

    try {
      final uid = user.uid;

      // 1. Query REAL driver_verifications submission document
      final verifSnap = await FirebaseFirestore.instance
          .collection('driver_verifications')
          .where('userId', isEqualTo: uid)
          .limit(1)
          .get();

      if (verifSnap.docs.isNotEmpty) {
        final verifData = verifSnap.docs.first.data();
        final status = verifData['status']?.toString() ?? '';
        final reason = verifData['rejection_reason'] ?? verifData['reason'] ?? 'Документы не соответствуют требованиям';

        if (status == 'pending_manual' || status == 'approved_by_ai') {
          setState(() {
            _needsManual = (status == 'pending_manual');
            _isRejected = false;
            _step = 2; // Step 3 of 3: Status View
            _isLoadingState = false;
          });
          return;
        } else if (status == 'rejected') {
          setState(() {
            _isRejected = true;
            _rejectedReason = reason.toString();
            _step = 2; // Step 3 of 3: Status View showing Rejection Card
            _isLoadingState = false;
          });
          return;
        }
      }

      // 2. If NO real document exists in driver_verifications, check Telegram verification state
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final data = userDoc.data() ?? {};
        final bool isTgVerified = data['isTelegramVerified'] == true ||
            data['verified_phone'] != null ||
            uid.startsWith('telegram_');
        
        final int savedStep = data['driverOnboardingStep'] is int ? data['driverOnboardingStep'] : 1;

        if (widget.initialStep != null) {
          _step = widget.initialStep!;
        } else if (isTgVerified || savedStep >= 2) {
          // If no driver_verifications doc exists, user MUST be on Step 2 (upload photos/car)
          _step = 1;
          if (savedStep >= 3) {
            // Repair inconsistent step in Firestore
            await _updateOnboardingStep(2);
          }
        } else {
          _step = 0; // Step 1 of 3: Telegram OTP
        }
      }
    } catch (e) {
      debugPrint('[DriverWizard] Error loading user progress: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingState = false);
      }
    }
  }

  // ── Save Onboarding Step to Firestore ─────────────────────────────────────
  Future<void> _updateOnboardingStep(int stepNumber) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'driverOnboardingStep': stepNumber,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[DriverWizard] Error updating driverOnboardingStep: $e');
    }
  }

  // ── Step 1: Telegram OTP Logic ─────────────────────────────────────────────
  void _startTimer() {
    setState(() {
      _timerSeconds = 180;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerSeconds == 0) {
        timer.cancel();
      } else {
        if (mounted) setState(() => _timerSeconds--);
      }
    });
  }

  bool _validatePhone(String cleanPhone) {
    if (cleanPhone.length != 11) {
      setState(() => _tgErrorText = 'Номер должен состоять из 11 цифр! Пример: +7 (707) 123-45-67');
      return false;
    }
    if (!cleanPhone.startsWith('7')) {
      setState(() => _tgErrorText = 'Номер должен начинаться с +7 или 8!');
      return false;
    }
    final operatorCode = cleanPhone.substring(1, 4);
    final validPrefixes = [
      '700', '701', '702', '703', '704', '705', '706', '707', '708', '709',
      '747', '750', '751', '760', '761', '762', '763', '764',
      '771', '775', '776', '777', '778'
    ];
    if (!validPrefixes.contains(operatorCode)) {
      setState(() => _tgErrorText = 'Неверный код оператора Казахстана: $operatorCode');
      return false;
    }
    return true;
  }

  Future<void> _sendTelegramCode() async {
    String cleanPhone = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.startsWith('8') && cleanPhone.length == 11) {
      cleanPhone = '7${cleanPhone.substring(1)}';
    } else if (cleanPhone.length == 10) {
      cleanPhone = '7$cleanPhone';
    }

    if (!_validatePhone(cleanPhone)) return;

    setState(() {
      _isWaitingForBot = true;
      _tgErrorText = null;
    });

    try {
      _tgSessionToken = await AuthService.startTelegramSession(phone: cleanPhone);
      final botUrl = TelegramBotService.buildBotUrl(_tgSessionToken!);
      await launchUrl(Uri.parse(botUrl), mode: LaunchMode.externalApplication);

      _tgSessionSub?.cancel();
      _tgSessionSub = AuthService.watchTelegramSession(_tgSessionToken!).listen((snap) {
        if (!snap.exists) return;
        final data = snap.data();
        if (data == null) return;
        final String? chatId = data['chat_id'];
        final String? otp = data['otp'];

        if (chatId != null && otp != null && otp.isNotEmpty) {
          _tgSessionSub?.cancel();
          if (mounted) {
            setState(() {
              _chatId = chatId;
              _isWaitingForBot = false;
              _tgStep = 1;
            });
            _startTimer();
          }
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isWaitingForBot = false;
          _tgErrorText = 'Ошибка запуска сессии: $e';
        });
      }
    }
  }

  Future<void> _verifyTelegramOtp() async {
    if (_isVerifyingOtp) return;
    setState(() {
      _isVerifyingOtp = true;
      _tgErrorText = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      final provider = Provider.of<TaxiProvider>(context, listen: false);
      if (user == null) {
        throw Exception('Вы не авторизованы!');
      }

      final callable = FirebaseFunctions.instance.httpsCallable('verifyTelegramOtp');
      final result = await callable.call({
        'otp': _otpCtrl.text.trim(),
        'phone': _phoneCtrl.text,
        'sessionToken': _tgSessionToken,
      });

      if (result.data != null && result.data['success'] == true) {
        final cleanPhone = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');

        final existingQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('verified_phone', isEqualTo: cleanPhone)
            .get();

        for (var doc in existingQuery.docs) {
          if (doc.id != user.uid) {
            throw Exception('Этот номер уже привязан к другому аккаунту.');
          }
        }

        final tgData = result.data;
        final String? returnedChatId = tgData is Map ? (tgData['chatId']?.toString() ?? _chatId) : _chatId;
        final String? returnedTgUser = tgData is Map ? tgData['telegramUsername']?.toString() : null;
        final String? returnedTgFirst = tgData is Map ? tgData['telegramFirstName']?.toString() : null;
        final String? returnedTgLast = tgData is Map ? tgData['telegramLastName']?.toString() : null;

        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'verified_phone': cleanPhone,
          'phone': _phoneCtrl.text,
          'isTelegramVerified': true,
          'driverOnboardingStep': 2,
          if (returnedChatId != null) 'telegramChatId': returnedChatId,
          if (returnedTgUser != null && returnedTgUser.isNotEmpty) 'telegram_username': returnedTgUser,
          if (returnedTgFirst != null && returnedTgFirst.isNotEmpty) 'telegram_first_name': returnedTgFirst,
          if (returnedTgLast != null && returnedTgLast.isNotEmpty) 'telegram_last_name': returnedTgLast,
        }, SetOptions(merge: true));

        StorageService.saveProfile(
          '${provider.firstName} ${provider.lastName}',
          null,
          false,
          provider.verificationStatus,
          isVerified: provider.isVehicleVerified,
        );
        await StorageService.setString('user_phone', _phoneCtrl.text);

        final finalChatId = returnedChatId ?? _chatId;
        if (finalChatId != null) {
          provider.setTelegramAuth(
            finalChatId,
            username: returnedTgUser,
            firstName: returnedTgFirst,
            lastName: returnedTgLast,
          );
          provider.updateProfile(provider.firstName, provider.lastName, _phoneCtrl.text);
        }

        if (mounted) {
          setState(() {
            _isVerifyingOtp = false;
            _step = 1; // Advance to Step 2 of 3 (Docs & Car)
          });
          _fadeCtrl.reset();
          _fadeCtrl.forward();
        }
      } else {
        final msg = result.data is Map ? (result.data['message'] ?? 'Неверный код!') : 'Неверный код!';
        throw Exception(msg);
      }
    } on FirebaseException catch (fe) {
      if (mounted) {
        setState(() {
          _isVerifyingOtp = false;
          _otpCtrl.clear();
          _tgErrorText = fe.message ?? 'Ошибка сервера при проверке кода OTP. ❌';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isVerifyingOtp = false;
          _otpCtrl.clear();
          _tgErrorText = 'Ошибка: ${e.toString().replaceAll('Exception: ', '')} ❌';
        });
      }
    }
  }

  // ── Step 2: Photo Pickers & Submission Logic ────────────────────────────────
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
              TranslationService.t('choose_source', Provider.of<AppConfigProvider>(context, listen: false).language),
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
                          color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF2563EB), size: 30),
                      ),
                      const SizedBox(height: 10),
                      Text(TranslationService.t('camera', Provider.of<AppConfigProvider>(context, listen: false).language), style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12, color: const Color(0xFF475569))),
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
                      Text(TranslationService.t('gallery', Provider.of<AppConfigProvider>(context, listen: false).language), style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12, color: const Color(0xFF475569))),
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

  Future<void> _pickPhoto(String slot) async {
    final source = await _showSourcePicker();
    if (source == null) return;

    try {
      final f = await _picker.pickImage(source: source, imageQuality: 88);
      if (f != null && mounted) {
        setState(() {
          switch (slot) {
            case 'cf': _carFront = File(f.path); break;
            case 'tf': _techF    = File(f.path); break;
          }
        });
      }
    } catch (e) {
      debugPrint('[DriverWizard] Photo pick error: $e');
    }
  }

  bool get _canSubmitStep2 {
    return _carFront != null &&
        _techF != null &&
        _plateC.text.trim().length >= 5 &&
        (_selectedBrand != null || _carC.text.trim().length >= 4);
  }

  Future<void> _submitVerification() async {
    if (_analyzing) return;
    final provider = Provider.of<TaxiProvider>(context, listen: false);
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final chatId = prefs.getString('telegram_chat_id') ?? '';
    final carFullModel = _selectedBrand != null && _selectedModel != null
        ? '$_selectedBrand $_selectedModel'
        : _carC.text.trim();
    final docId = '${provider.firstName}_${_plateC.text.trim()}_${DateTime.now().millisecondsSinceEpoch}';

    try {
      if (mounted) setState(() { _analyzing = true; _aiMsg = 'Сжимаем фотографии... 📸'; });
      
      final results = await Future.wait([
        FileService.compressImage(_techF!),
        FileService.compressImage(_carFront!),
      ]);
      final compTechF = results[0];
      final compCarFront = results[1];

      // Upload files
      if (mounted) setState(() => _aiMsg = 'Загружаем техпаспорт (1/2) 📄');
      final techFUrl = await FileService.uploadFile(
        compTechF ?? _techF!,
        'driver_documents/$uid/tech_front',
        onProgress: (p, a) {
          if (mounted) setState(() => _aiMsg = 'Загружаем техпаспорт (1/2) 📄 — ${(p * 100).toInt()}%');
        },
      );

      if (mounted) setState(() => _aiMsg = 'Загружаем фото авто (2/2) 🚘');
      final carFrontUrl = await FileService.uploadFile(
        compCarFront ?? _carFront!,
        'driver_documents/$uid/car_front',
        onProgress: (p, a) {
          if (mounted) setState(() => _aiMsg = 'Загружаем фото авто (2/2) 🚘 — ${(p * 100).toInt()}%');
        },
      );

      if (techFUrl == null || carFrontUrl == null) {
        throw Exception('Ошибка загрузки фотографий. Попробуйте снова.');
      }

      if (mounted) setState(() => _aiMsg = 'ИИ анализирует фото авто и техпаспорт... 🤖');

      final gemini = GeminiService();
      gemini.init(provider.curLang);

      final aiResult = await gemini.analyzeDriverDocuments(
        techPassport: compTechF ?? _techF!,
        carFront: compCarFront ?? _carFront!,
        driverName: '${provider.firstName} ${provider.lastName}',
        plate: _plateC.text.trim().toUpperCase(),
        carModel: carFullModel,
      );

      final bool isTechPassportValid = aiResult['tech_passport_valid'] == true;
      final bool isCarValid = aiResult['car_valid'] == true;
      final bool isPlateMatches = aiResult['plate_matches'] == true;
      final bool isBlurry = aiResult['blurry_photo_detected'] == true;
      final String aiReason = aiResult['reason'] ?? 'На проверке модератором';
      final String aiConfidence = aiResult['confidence'] ?? 'medium';

      // 🤖 AUTOMATIC VERIFICATION LOGIC:
      // Auto-approval if car photo, tech passport, and plate match are valid.
      final bool aiApproved = isTechPassportValid &&
          isCarValid &&
          isPlateMatches &&
          !isBlurry &&
          aiConfidence != 'low';

      _needsManual = !aiApproved;
      _isRejected = false;
      final finalStatus = _needsManual ? 'pending_manual' : 'approved_by_ai';

      // Save driver_verifications record
      await FirebaseFirestore.instance.collection('driver_verifications').doc(docId).set({
        'userId': uid,
        'driver_name': '${provider.firstName} ${provider.lastName}',
        'plate': _plateC.text.trim().toUpperCase(),
        'car': carFullModel,
        'color': _selectedColor ?? '',
        'driver_chat_id': chatId,
        'status': finalStatus,
        'ai_result': aiResult,
        'ai_quality': aiConfidence,
        'submitted_at': FieldValue.serverTimestamp(),
        'techF': techFUrl,
        'carFront': carFrontUrl,
      });

      // Save step 3 & update user profile in Firestore
      await _updateOnboardingStep(3);
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'driverOnboardingStep': 3,
        'carModel': carFullModel,
        'carPlate': _plateC.text.trim().toUpperCase(),
        if (!_needsManual) 'isVerified': true,
      }, SetOptions(merge: true));

      // 📩 TELEGRAM NOTIFICATIONS FOR ALL REGISTRATIONS:
      if (chatId.isNotEmpty) {
        if (!_needsManual) {
          await TelegramBotService.notifyDriverResult(
            driverChatId: chatId,
            isApproved: true,
            reason: '🎉 Ваша верификация водителя (фото авто + техпаспорт) автоматически одобрена ИИ!',
          );
        } else {
          await TelegramBotService.notifyDriverResult(
            driverChatId: chatId,
            isApproved: false,
            reason: '⏳ Ваша заявка передана модератору на ручную проверку. Обычно это занимает от 10 до 30 минут.',
          );
        }
      }

      // Always notify Telegram Admin for all registrations!
      if (_needsManual) {
        await TelegramBotService.notifyAdminManualReview(
          driverName: '${provider.firstName} ${provider.lastName}',
          plate: _plateC.text.trim().toUpperCase(),
          carModel: carFullModel,
          driverChatId: chatId,
          reviewDocId: docId,
          reason: '⚠️ Требуется ручная проверка: $aiReason',
          licF: techFUrl,
          techF: techFUrl,
          selfie: carFrontUrl,
          carFront: carFrontUrl,
        );
      } else {
        provider.setVehicleVerified(true);
        await TelegramBotService.notifyAdminManualReview(
          driverName: '${provider.firstName} ${provider.lastName}',
          plate: _plateC.text.trim().toUpperCase(),
          carModel: carFullModel,
          driverChatId: chatId,
          reviewDocId: docId,
          reason: '🤖 ИИ автоматически одобрил документы (фото авто и техпаспорт сверены).',
          licF: techFUrl,
          techF: techFUrl,
          selfie: carFrontUrl,
          carFront: carFrontUrl,
        );
      }

      await Future.delayed(const Duration(milliseconds: 400));

      if (mounted) {
        setState(() {
          _analyzing = false;
          _step = 2; // Step 3 of 3: Status View
        });
        _fadeCtrl.reset();
        _fadeCtrl.forward();
      }
    } catch (e) {
      debugPrint('[DriverWizard] Submit error: $e');
      if (mounted) {
        setState(() => _analyzing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка отправки: $e ⚠️'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _restartVerification() async {
    setState(() {
      _isRejected = false;
      _rejectedReason = '';
      _techF = null;
      _carFront = null;
      _step = 1; // Return to Step 2 of 3: Photos & Car upload
    });
    await _updateOnboardingStep(2);
    _fadeCtrl.reset();
    _fadeCtrl.forward();
  }

  // ── BUILD MAIN SCREEN ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TaxiProvider>(context);
    final t = provider.theme;

    if (_isLoadingState) {
      return Scaffold(
        backgroundColor: t.bg,
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF2563EB)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildWizardHeader(t),
            _buildProgressBar(t),
            Expanded(child: _buildBody(t, provider)),
          ],
        ),
      ),
    );
  }

  // ── WIZARD HEADER ────────────────────────────────────────────────────────────
  Widget _buildWizardHeader(TaxiTheme t) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 8, 16, 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              if (_step > 0 && _step < 2) {
                // Allow user to go back to step 1 without losing form data
                setState(() => _step--);
                _fadeCtrl.reset();
                _fadeCtrl.forward();
              } else {
                Navigator.pop(context);
              }
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Стать водителем IQ-Market',
                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17),
                ),
                Text(
                  _step == 0
                      ? 'Шаг 1 из 3 — Подтверждение Telegram'
                      : _step == 1
                          ? 'Шаг 2 из 3 — Фото и данные автомобиля'
                          : 'Шаг 3 из 3 — Статус проверки',
                  style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_step + 1}/3',
              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // ── PROGRESS BAR ─────────────────────────────────────────────────────────────
  Widget _buildProgressBar(TaxiTheme t) {
    final stepTitles = ['Telegram', 'Данные & Фото', 'Модерация'];
    final stepIcons = [Icons.telegram_rounded, Icons.directions_car_rounded, Icons.hourglass_top_rounded];

    return Container(
      color: t.card,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: List.generate(3, (index) {
          final isDone = index < _step;
          final isActive = index == _step;
          final color = isDone
              ? const Color(0xFF10B981)
              : (isActive ? const Color(0xFF2563EB) : t.border);

          return Expanded(
            child: Row(
              children: [
                if (index > 0)
                  Expanded(
                    child: Container(
                      height: 3,
                      color: isDone ? const Color(0xFF10B981) : t.border.withValues(alpha: 0.4),
                    ),
                  ),
                Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: isActive ? 38 : 30,
                      height: isActive ? 38 : 30,
                      decoration: BoxDecoration(
                        color: isDone
                            ? const Color(0xFF10B981)
                            : (isActive ? const Color(0xFF2563EB).withValues(alpha: 0.1) : t.bg),
                        shape: BoxShape.circle,
                        border: Border.all(color: color, width: isActive ? 2.5 : 1.5),
                      ),
                      child: Center(
                        child: isDone
                            ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                            : Icon(stepIcons[index],
                                color: isActive ? const Color(0xFF2563EB) : t.sub.withValues(alpha: 0.6),
                                size: isActive ? 18 : 14),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stepTitles[index],
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: isActive ? FontWeight.w900 : FontWeight.w600,
                        color: isActive ? const Color(0xFF2563EB) : t.sub,
                      ),
                    ),
                  ],
                ),
                if (index < 2)
                  Expanded(
                    child: Container(
                      height: 3,
                      color: isDone ? const Color(0xFF10B981) : t.border.withValues(alpha: 0.4),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ── BODY DISPATCHER ──────────────────────────────────────────────────────────
  Widget _buildBody(TaxiTheme t, TaxiProvider provider) {
    if (_analyzing) return _buildAnalyzingView(t);

    return FadeTransition(
      opacity: _fadeAnim,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: [
          _buildStep1TelegramView(t, provider),
          _buildStep2DocsAndCarView(t),
          _buildStep3StatusView(t),
        ][_step],
      ),
    );
  }

  // ── STEP 1 VIEW: Telegram Phone Confirmation ─────────────────────────────────
  Widget _buildStep1TelegramView(TaxiTheme t, TaxiProvider provider) {
    final lang = provider.curLang;
    String explainText =
        'Для безопасности пассажиров нужно подтвердить номер телефона через Telegram. Это отдельная проверка, а не повторный вход в аккаунт.';

    if (lang == 'kz') {
      explainText =
          'Жолаушылардың қауіпсіздігі үшін телефон нөмірін Telegram арқылы растау қажет. Бұл аккаунтқа қайта кіру емес, бөлек тексеру.';
    } else if (lang == 'uyg') {
      explainText =
          'Йоловчиларниң бихәтарлиғи үчүн телефон номурини Telegram арқилик тәстиқләш керәк. Бу һесабатқа қайта кириш әмәс, бөләк тәкшүрүш.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Explanatory Callout Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0088CC).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF0088CC).withValues(alpha: 0.25), width: 1.5),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Color(0xFF0088CC),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.shield_outlined, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Зачем нужна проверка Telegram?',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: t.text,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      explainText,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: t.sub,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        if (_tgStep == 0) ...[
          Text(
            'Введите ваш номер телефона',
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: t.text),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: t.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _tgErrorText != null ? Colors.redAccent : t.border, width: 1.5),
            ),
            child: TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              inputFormatters: [_phoneMask],
              enabled: !_isWaitingForBot,
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: t.text, fontSize: 16),
              decoration: InputDecoration(
                hintText: '+7 (700) 000-00-00',
                hintStyle: TextStyle(color: t.sub.withValues(alpha: 0.4)),
                border: InputBorder.none,
                prefixIcon: Icon(Icons.phone_rounded, color: const Color(0xFF2563EB), size: 22),
              ),
            ),
          ),

          if (_tgErrorText != null) ...[
            const SizedBox(height: 12),
            Text(
              _tgErrorText!,
              style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],

          if (_isWaitingForBot) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0088CC).withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF0088CC).withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Color(0xFF0088CC), strokeWidth: 2.5)),
                  const SizedBox(height: 12),
                  Text(
                    'Ожидаем запуск бота в Telegram... 🤖',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: t.text),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'В открывшемся боте нажмите «СТАРТ» и поделитесь контактом.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 12, color: t.sub),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _isWaitingForBot ? null : _sendTelegramCode,
              icon: const Icon(Icons.telegram_rounded, color: Colors.white, size: 22),
              label: Text(
                'ОТКРЫТЬ TELEGRAM БОТА',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0088CC),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                elevation: 0,
              ),
            ),
          ),
        ] else ...[
          // OTP Code Entry
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0088CC).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                const Icon(Icons.mark_email_read_rounded, color: Color(0xFF0088CC), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Код отправлен в ваш Telegram!',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: t.text),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Введите 6-значный код:', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: t.text)),
          const SizedBox(height: 14),

          TextField(
            controller: _otpCtrl,
            keyboardType: TextInputType.number,
            maxLength: 6,
            autofocus: true,
            enabled: !_isVerifyingOtp,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 8, color: t.text),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              counterText: "",
              hintText: "••••••",
              filled: true,
              fillColor: t.card,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: t.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF0088CC), width: 2)),
            ),
            onChanged: (v) {
              if (v.length == 6 && !_isVerifyingOtp) _verifyTelegramOtp();
            },
          ),

          if (_tgErrorText != null) ...[
            const SizedBox(height: 12),
            Text(_tgErrorText!, style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
          ],

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: (_otpCtrl.text.length == 6 && !_isVerifyingOtp) ? _verifyTelegramOtp : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                elevation: 0,
              ),
              child: _isVerifyingOtp
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : Text('ПОДТВЕРДИТЬ И ПЕРЕЙТИ К ШАГУ 2 →', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, fontSize: 13)),
            ),
          ),
        ],
      ],
    );
  }

  // ── STEP 2 VIEW: Documents & Car Information ─────────────────────────────────
  Widget _buildStep2DocsAndCarView(TaxiTheme t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '1. Загрузите 2 фотографии',
          style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.w900, fontSize: 16),
        ),
        const SizedBox(height: 6),
        Text(
          'Загрузите фото автомобиля спереди и фото техпаспорта для сверки госномера.',
          style: GoogleFonts.inter(color: t.sub, fontSize: 12),
        ),
        const SizedBox(height: 16),

        _photoUploadCard(t, 'Фото автомобиля спереди', 'С читаемым госномером спереди', _carFront, () => _pickPhoto('cf')),
        const SizedBox(height: 12),
        _photoUploadCard(t, 'Техпаспорт автомобиля', 'Свидетельство о регистрации ТС (для сверки с авто)', _techF, () => _pickPhoto('tf')),

        const SizedBox(height: 24),
        Text(
          '2. Укажите данные автомобиля',
          style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.w900, fontSize: 16),
        ),
        const SizedBox(height: 14),

        // Brand Picker
        GestureDetector(
          onTap: () => _showBrandPickerModal(t),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: t.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _selectedBrand != null ? const Color(0xFF2563EB) : t.border, width: _selectedBrand != null ? 2 : 1),
            ),
            child: Row(
              children: [
                const Icon(Icons.directions_car_filled_rounded, color: Color(0xFF2563EB), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedBrand ?? 'Выберите марку автомобиля',
                    style: GoogleFonts.inter(color: _selectedBrand != null ? t.text : t.sub, fontWeight: FontWeight.w700),
                  ),
                ),
                Icon(Icons.keyboard_arrow_down_rounded, color: t.sub),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Model Picker
        if (_selectedBrand != null && (_carModels[_selectedBrand!] ?? []).isNotEmpty)
          GestureDetector(
            onTap: () => _showModelPickerModal(t),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: t.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _selectedModel != null ? const Color(0xFF2563EB) : t.border, width: _selectedModel != null ? 2 : 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.list_alt_rounded, color: Color(0xFF2563EB), size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedModel ?? 'Выберите модель автомобиля',
                      style: GoogleFonts.inter(color: _selectedModel != null ? t.text : t.sub, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Icon(Icons.keyboard_arrow_down_rounded, color: t.sub),
                ],
              ),
            ),
          ),

        if (_selectedBrand != null && (_carModels[_selectedBrand!] ?? []).isEmpty) ...[
          _inputTextField(t, 'Модель авто', 'Например: Accent', Icons.list_alt_rounded, _carC),
          const SizedBox(height: 12),
        ],

        const SizedBox(height: 12),
        // Color Picker Dropdown
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: t.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _selectedColor != null ? const Color(0xFF2563EB) : t.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedColor,
              hint: Row(
                children: [
                  const Icon(Icons.color_lens_rounded, color: Color(0xFF2563EB), size: 20),
                  const SizedBox(width: 12),
                  Text('Цвет кузова', style: GoogleFonts.inter(color: t.sub, fontWeight: FontWeight.w700, fontSize: 14)),
                ],
              ),
              isExpanded: true,
              dropdownColor: t.card,
              items: _carColors.map((c) => DropdownMenuItem(value: c, child: Text(c, style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.w700)))).toList(),
              onChanged: (v) => setState(() => _selectedColor = v),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // License Plate Input
        _inputTextField(t, 'Госномер автомобиля', '777 AAA 05', Icons.pin_rounded, _plateC, textCaps: true, mask: _plateMask),

        const SizedBox(height: 28),

        // Action Buttons Row (Back & Submit)
        Row(
          children: [
            OutlinedButton(
              onPressed: () {
                setState(() => _step = 0);
                _fadeCtrl.reset();
                _fadeCtrl.forward();
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                side: BorderSide(color: t.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Icon(Icons.arrow_back_rounded, color: Color(0xFF2563EB)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: _canSubmitStep2 ? _submitVerification : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: _canSubmitStep2
                        ? const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)])
                        : null,
                    color: _canSubmitStep2 ? null : t.border,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: _canSubmitStep2
                        ? [BoxShadow(color: const Color(0xFF2563EB).withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))]
                        : [],
                  ),
                  child: Center(
                    child: Text(
                      'ОТПРАВИТЬ НА ПРОВЕРКУ 🚀',
                      style: GoogleFonts.plusJakartaSans(
                        color: _canSubmitStep2 ? Colors.white : t.sub,
                        fontWeight: FontWeight.w900,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── STEP 3 VIEW: Status View (Moderation Pending / Approved / Rejected) ──────
  Widget _buildStep3StatusView(TaxiTheme t) {
    if (_isRejected) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red.withValues(alpha: 0.12),
                  border: Border.all(color: Colors.red, width: 3),
                ),
                child: const Icon(Icons.cancel_rounded, color: Colors.red, size: 54),
              ),
              const SizedBox(height: 24),
              Text(
                'Заявка отклонена ❌',
                style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.w900, fontSize: 22),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                ),
                child: Column(
                  children: [
                    Text(
                      'Причина отказа:',
                      style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _rejectedReason,
                      style: GoogleFonts.inter(color: t.text, fontSize: 13.5, height: 1.4, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _restartVerification,
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
                  label: Text('ПОДАТЬ ЗАЯВКУ ЗАНОВО', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (_needsManual ? Colors.orange : Colors.green).withValues(alpha: 0.12),
                border: Border.all(color: _needsManual ? Colors.orange : Colors.green, width: 3),
              ),
              child: Icon(
                _needsManual ? Icons.hourglass_top_rounded : Icons.verified_rounded,
                color: _needsManual ? Colors.orange : Colors.green,
                size: 50,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _needsManual ? 'Заявка отправлена на проверку!' : 'Документы одобрены ИИ!',
              style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.w900, fontSize: 22),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              _needsManual
                  ? 'Модераторы проверяют ваши фотографии. Обычно это занимает от 10 до 30 минут. Уведомление о готовности придет в ваш Telegram.'
                  : 'Ваш профиль водителя успешно активирован! Теперь вам доступны все функции создания поездок и выполнения заказов.',
              style: GoogleFonts.inter(color: t.sub, fontSize: 13.5, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0088CC).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF0088CC).withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.telegram, color: Color(0xFF0088CC), size: 26),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Уведомление в Бот', style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.w800, fontSize: 13)),
                        Text('Статус верификации автоматически обновится в приложении.', style: GoogleFonts.inter(color: t.sub, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _needsManual ? Colors.orange : Colors.green,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  elevation: 0,
                ),
                child: Text('ВЕРНУТЬСЯ НА ГЛАВНУЮ', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── ANALYZING VIEW ───────────────────────────────────────────────────────────
  Widget _buildAnalyzingView(TaxiTheme t) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _dotCtrl,
            builder: (_, __) => Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  const Color(0xFF2563EB).withValues(alpha: 0.3 + 0.4 * _dotCtrl.value),
                  const Color(0xFF2563EB).withValues(alpha: 0.05),
                ]),
              ),
              child: const Icon(Icons.smart_toy_rounded, color: Color(0xFF2563EB), size: 44),
            ),
          ),
          const SizedBox(height: 24),
          Text('ИИ проверяет документы...', style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(_aiMsg, key: ValueKey(_aiMsg), textAlign: TextAlign.center, style: GoogleFonts.inter(color: t.sub, fontSize: 13)),
          ),
          const SizedBox(height: 28),
          SizedBox(width: 180, child: LinearProgressIndicator(color: const Color(0xFF2563EB), backgroundColor: t.border, borderRadius: BorderRadius.circular(4), minHeight: 6)),
        ],
      ),
    );
  }

  // ── HELPER MODALS & COMPONENTS ───────────────────────────────────────────────
  Widget _photoUploadCard(TaxiTheme t, String title, String sub, File? file, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 110,
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: file != null ? const Color(0xFF10B981) : t.border, width: file != null ? 2 : 1),
        ),
        child: file != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(file, fit: BoxFit.cover),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                        child: const Icon(Icons.check, color: Colors.white, size: 14),
                      ),
                    ),
                  ],
                ),
              )
            : Row(
                children: [
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFF2563EB).withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.add_a_photo_rounded, color: Color(0xFF2563EB), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.w800, fontSize: 13.5)),
                        const SizedBox(height: 2),
                        Text(sub, style: GoogleFonts.inter(color: t.sub, fontSize: 11)),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF94A3B8), size: 14),
                  const SizedBox(width: 16),
                ],
              ),
      ),
    );
  }

  Widget _inputTextField(TaxiTheme t, String label, String hint, IconData icon, TextEditingController c, {bool textCaps = false, MaskTextInputFormatter? mask}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(color: t.sub, fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        TextField(
          controller: c,
          inputFormatters: [
            if (mask != null) mask,
            if (textCaps) UpperCaseTextFormatter(),
          ],
          textCapitalization: textCaps ? TextCapitalization.characters : TextCapitalization.words,
          onChanged: (_) => setState(() {}),
          style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(color: t.sub.withValues(alpha: 0.5)),
            prefixIcon: Icon(icon, color: const Color(0xFF2563EB), size: 20),
            filled: true,
            fillColor: t.card,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: t.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2)),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ],
    );
  }

  void _showBrandPickerModal(TaxiTheme t) {
    String q = "";
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, ss) => Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(color: t.bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
          child: Column(
            children: [
              Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: t.border, borderRadius: BorderRadius.circular(10))),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Text('Выберите марку авто', style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.w900, fontSize: 18))),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  onChanged: (v) => ss(() => q = v),
                  style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    hintText: 'Поиск марки...',
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF2563EB)),
                    filled: true,
                    fillColor: t.card,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _carBrands.where((b) => b.toLowerCase().contains(q.toLowerCase())).length,
                  itemBuilder: (ctx, i) {
                    final filtered = _carBrands.where((b) => b.toLowerCase().contains(q.toLowerCase())).toList();
                    final b = filtered[i];
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedBrand = b;
                          _selectedModel = null;
                          _carC.clear();
                        });
                        Navigator.pop(context);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: _selectedBrand == b ? const Color(0xFF2563EB).withValues(alpha: 0.1) : t.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _selectedBrand == b ? const Color(0xFF2563EB) : Colors.transparent, width: 1.5),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.directions_car_filled_rounded, color: _selectedBrand == b ? const Color(0xFF2563EB) : t.sub, size: 20),
                            const SizedBox(width: 12),
                            Text(b, style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.w700)),
                            const Spacer(),
                            if (_selectedBrand == b) const Icon(Icons.check_circle_rounded, color: Color(0xFF2563EB), size: 18),
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
      ),
    );
  }

  void _showModelPickerModal(TaxiTheme t) {
    final models = _carModels[_selectedBrand!] ?? [];
    String q = "";
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, ss) => Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(color: t.bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
          child: Column(
            children: [
              Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: t.border, borderRadius: BorderRadius.circular(10))),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Text('Модель $_selectedBrand', style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.w900, fontSize: 18))),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  onChanged: (v) => ss(() => q = v),
                  style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    hintText: 'Поиск модели...',
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF2563EB)),
                    filled: true,
                    fillColor: t.card,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: models.where((m) => m.toLowerCase().contains(q.toLowerCase())).length,
                  itemBuilder: (ctx, i) {
                    final filtered = models.where((m) => m.toLowerCase().contains(q.toLowerCase())).toList();
                    final m = filtered[i];
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedModel = m;
                          _carC.text = '$_selectedBrand $m';
                        });
                        Navigator.pop(context);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: _selectedModel == m ? const Color(0xFF2563EB).withValues(alpha: 0.1) : t.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _selectedModel == m ? const Color(0xFF2563EB) : Colors.transparent, width: 1.5),
                        ),
                        child: Row(
                          children: [
                            Text(m, style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.w700)),
                            const Spacer(),
                            if (_selectedModel == m) const Icon(Icons.check_circle_rounded, color: Color(0xFF2563EB), size: 18),
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
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
