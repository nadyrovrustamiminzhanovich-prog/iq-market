import 'dart:io';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:iqmarket/services/storage_service.dart';
import 'package:iqmarket/data/kazakhstan_locations.dart';
import 'package:iqmarket/screens/legal_info_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:provider/provider.dart';
import 'package:iqmarket/providers/app_config_provider.dart';
import 'package:iqmarket/providers/taxi_provider.dart';
import 'package:iqmarket/services/translation_service.dart';
import 'package:iqmarket/services/auth_service.dart';
import 'package:iqmarket/services/user_service.dart';
import 'package:iqmarket/services/file_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:iqmarket/widgets/secure_image_viewer.dart';
import 'package:iqmarket/widgets/post_ad/location_selector.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileSettingsScreen extends StatefulWidget {
  final String currentName;
  final String? profileImagePath;
  final bool isBioEnabled;
  final String accType;
  final String lang;
  final String currentTheme;
  final Map<String, Map<String, dynamic>> themes;
  final Function(String) onThemeChanged;
  final Function(String name, File? image, bool isBio, String type, String lang) onSave;

  const ProfileSettingsScreen({
    super.key,
    required this.currentName,
    this.profileImagePath,
    required this.isBioEnabled,
    required this.accType,
    required this.lang,
    required this.currentTheme,
    required this.themes,
    required this.onThemeChanged,
    required this.onSave,
  });

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  late TextEditingController _nameController;
  final _emailController = TextEditingController();
  late TextEditingController _cityController;
  final _phoneController = TextEditingController();
  
  DateTime _registrationDate = DateTime.now();
  String _userEmail = '';
  
  final _phoneMask = MaskTextInputFormatter(
    mask: '+7 (###) ###-##-##',
    filter: {"#": RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );
  File? _newImage;
  final ImagePicker _picker = ImagePicker();
  bool _isSaving = false;
  bool _isPhoneVerified = false;

  late bool _isNotificationsEnabled;
  late bool _isFaceIdEnabled;
  late String _selectedLanguage;
  late String _accountType;
  late String _currentTheme;

  bool get _isDark => _currentTheme == 'Dark' || Theme.of(context).brightness == Brightness.dark;
  Color get _bgColor => widget.themes[_currentTheme]?['background'] ?? (_isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC));
  Color get _surfaceColor => widget.themes[_currentTheme]?['surface'] ?? (_isDark ? const Color(0xFF1E293B) : Colors.white);
  Color get _txtColor => widget.themes[_currentTheme]?['text'] ?? (_isDark ? Colors.white : const Color(0xFF1A1D1E));
  Color get _subtxtColor => widget.themes[_currentTheme]?['subtext'] ?? (_isDark ? Colors.white60 : const Color(0xFF64748B));
  Color get _primaryColor => widget.themes[_currentTheme]?['primary'] ?? const Color(0xFF2563EB);
  Color get _secondaryColor => _isDark ? const Color(0xFF3B82F6) : const Color(0xFF1D4ED8);

  @override
  void initState() {
    super.initState();
    final config = Provider.of<AppConfigProvider>(context, listen: false);
    _nameController = TextEditingController(text: widget.currentName);
    _cityController = TextEditingController(text: config.city);
    _isNotificationsEnabled = StorageService.getBool('push_notifications_enabled', defaultValue: true);
    _isFaceIdEnabled = widget.isBioEnabled;
    _selectedLanguage = widget.lang;
    _accountType = widget.accType;
    _currentTheme = widget.currentTheme;

    // Load dynamic user data from Firebase Auth
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _emailController.text = user.email ?? '';
      _phoneController.text = user.phoneNumber ?? '';
      _userEmail = user.email ?? '';
      _registrationDate = user.metadata.creationTime ?? DateTime.now();
    }
    
    _loadFirestoreUserData();
    _checkLostData();
  }

  Future<void> _loadFirestoreUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        // Телефон и email лежат в users/{uid}/private/contact, а НЕ в основном
        // документе: Firestore rules запрещают владельцу писать 'phone'/'email'
        // в users/{uid}, поэтому UserService.updateUserProfile складывает их в
        // приватный поддокумент. Раньше этот экран читал data['phone'] из
        // основного документа — там этого поля не бывает никогда, и введённый
        // номер после перезахода всегда оказывался пустым.
        final contact = await UserService.getPrivateContact(uid: user.uid);
        if (doc.exists && mounted) {
          final data = doc.data();
          if (data != null) {
            setState(() {
              // verified_phone (основной документ) — подтверждённый через
              // Телеграм номер, он приоритетнее введённого вручную.
              final phoneToUse = data['verified_phone'] ?? contact['phone'];
              final String rawPhoneStr = (phoneToUse != null) ? phoneToUse.toString().trim() : '';

              // Верифицированным номер считается ТОЛЬКО при реальном
              // доказательстве: verified_phone (номер, которым поделились
              // контактом в боте и который сервер сверил с введённым) либо
              // isTelegramVerified, который ставит verifyTelegramOtp.
              //
              // Условия uid.startsWith('telegram_') здесь быть не должно: вход
              // через Телеграм НЕ вытягивает номер (бот в этом сценарии не
              // просит поделиться контактом), поэтому такой пользователь вводит
              // номер руками. С прежним условием любой введённый вручную номер
              // объявлялся «верифицированным через Telegram», поле становилось
              // read-only, и опечатку можно было исправить только через
              // модератора в WhatsApp.
              _isPhoneVerified = rawPhoneStr.isNotEmpty &&
                  (data['isTelegramVerified'] == true ||
                   data['verified_phone'] != null);

              if (rawPhoneStr.isNotEmpty) {
                final digits = rawPhoneStr.replaceAll(RegExp(r'\D'), '');
                String localDigits = digits;
                if (digits.length == 11 && (digits.startsWith('7') || digits.startsWith('8'))) {
                  localDigits = digits.substring(1);
                } else if (digits.length > 11) {
                  localDigits = digits.substring(digits.length - 10);
                }
                _phoneController.text = _phoneMask.maskText(localDigits);
              }
              if (data['location'] != null && data['location'].toString().isNotEmpty) {
                _cityController.text = data['location'].toString();
              }
              // email — по той же причине из приватного поддокумента; в
              // основном документе он тоже запрещён правилами.
              final emailFromContact = contact['email']?.toString() ?? '';
              if (emailFromContact.isNotEmpty) {
                _emailController.text = emailFromContact;
                _userEmail = emailFromContact;
              }
              if (data['registrationDate'] != null) {
                final timestamp = data['registrationDate'];
                if (timestamp is Timestamp) {
                  _registrationDate = timestamp.toDate();
                }
              }
              // Тумблер push-уведомлений раньше показывал только локальный
              // SharedPreferences-дефолт (всегда true на новом устройстве),
              // никогда не подтягивая реальное значение с сервера — на втором
              // устройстве того же аккаунта переключатель мог врать. Firestore
              // теперь ещё и реально влияет на отправку (см. isPushEnabled в
              // functions/index.js), так что отображение обязано быть верным.
              if (data['pushEnabled'] is bool) {
                _isNotificationsEnabled = data['pushEnabled'] as bool;
                StorageService.setBool('push_notifications_enabled', _isNotificationsEnabled);
              }
            });
          }
        }
      } catch (e) {
        debugPrint('Error loading user data from Firestore: $e');
      }
    }
  }

  // Pull-to-refresh: в отличие от ProfileScreen, этот экран грузит данные из
  // Firestore один раз в initState (не через .snapshots()), поэтому если
  // что-то поменялось на сервере (например верификация телефона через бота
  // в другом экране), жест "потянуть вниз" должен явно перечитать документ,
  // а не просто провернуть спиннер вхолостую.
  Future<void> _onRefresh() async {
    await _loadFirestoreUserData();
  }

  Future<void> _checkLostData() async {
    try {
      final response = await _picker.retrieveLostData();
      if (response.isEmpty || response.file == null) return;
      
      final prefs = await SharedPreferences.getInstance();
      final target = prefs.getString('lost_picker_profile');
      if (target == 'avatar' && response.file != null) {
        setState(() {
          _newImage = File(response.file!.path);
        });
        await prefs.remove('lost_picker_profile');
      }
    } catch (e) {
      debugPrint('Error retrieving lost profile image data: $e');
    }
  }

  String _t(String key) {
    return TranslationService.t(key, _selectedLanguage);
  }

  @override
  void dispose() {
    _nameController.dispose(); 
    _emailController.dispose(); 
    _cityController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  /// Номер к каноническому виду `+7XXXXXXXXXX` — в нём его пишут
  /// PhoneRequiredBottomSheet и таксишный онбординг, и в нём же он уходит в
  /// tel:-ссылки и в senderPhone чата. Хранить маску («+7 (700) 000-00-00»)
  /// нельзя: она расползается по всем этим местам.
  ///
  /// Возвращает null, если поле пустое (номер не меняем), и '' — если введён
  /// неполный номер (вызывающий обязан показать ошибку и не сохранять).
  String? _normalizePhoneInput() {
    var digits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    // Маска '+7 (###) …' держит в поле литеральный префикс, и после того как
    // пользователь всё стёр, там может остаться '+7 ('. Одна цифра кода страны
    // — это пустое поле, а не неполный номер: иначе человек без телефона не
    // смог бы сохранить даже имя, получая «введите полный номер».
    if (digits == '7' || digits == '8') digits = '';
    if (digits.isEmpty) return null;
    final local = digits.length > 10 ? digits.substring(digits.length - 10) : digits;
    if (local.length != 10) return '';
    return '+7$local';
  }

  Future<void> _saveProfile() async {
    if (_isSaving) return;

    // Валидация до любых записей, иначе профиль сохранится наполовину.
    final String? normalizedPhone = _normalizePhoneInput();
    if (normalizedPhone == '') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('enter_full_phone')),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      String? finalPhotoUrl = widget.profileImagePath?.startsWith('http') == true ? widget.profileImagePath : null;

      if (_newImage != null) {
        final File? compressed = await FileService.compressImage(_newImage!);
        final uid = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
        final String? uploadedUrl = await FileService.uploadFile(compressed ?? _newImage!, 'avatars/$uid');
        if (uploadedUrl != null) {
          finalPhotoUrl = uploadedUrl;
          if (widget.profileImagePath != null && widget.profileImagePath!.startsWith('http')) {
            await FileService.deleteFile(widget.profileImagePath!);
          }
        } else {
          // FileService.uploadFile уже сам отработал 3 попытки с backoff и
          // проглотил все ошибки, вернув null — исключение сюда не долетает.
          // Раньше это молча игнорировалось: остальные поля (имя/город/
          // телефон) сохранялись, экран закрывался как при полном успехе, а
          // аватар нигде не менялся — пользователь думал, что всё сохранено.
          // Прерываемся здесь, до всех остальных записей, тем же способом,
          // которым выше по функции уже прерывается невалидный телефон —
          // чтобы профиль не сохранялся наполовину и юзер понимал, что
          // именно не получилось.
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(_t('error_avatar_upload')),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }
      }

      final String? imagePathToSave = finalPhotoUrl ?? _newImage?.path ?? widget.profileImagePath;
      await StorageService.saveProfile(_nameController.text, imagePathToSave, _isFaceIdEnabled, _accountType);
      
      if (mounted) {
        final config = Provider.of<AppConfigProvider>(context, listen: false);
        config.setLanguage(_selectedLanguage);
        config.setCity(_cityController.text);
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // 🔒 Sync displayName and photoURL to Firebase Auth profile for taxi/unified access
        try {
          await user.updateDisplayName(_nameController.text);
          if (finalPhotoUrl != null) {
            await user.updatePhotoURL(finalPhotoUrl);
          }
        } catch (authErr) {
          debugPrint('Auth profile update error: $authErr');
        }

        final Map<String, dynamic> updateData = {
          'name': _nameController.text,
          'location': _cityController.text,
          'accountType': _accountType,
        };
        if (finalPhotoUrl != null) {
          updateData['photoUrl'] = finalPhotoUrl;
        }
        // Пустое поле НЕ затирает сохранённый номер. Пока экран читал телефон
        // не оттуда, куда писал, поле всегда выглядело пустым — и любое
        // сохранение профиля (имя, город) молча стирало номер в Firestore.
        if (normalizedPhone != null) {
          updateData['phone'] = normalizedPhone;
        }
        await UserService.updateUserProfile(updateData);

        // Локальный кэш: chat_service и product_details берут senderPhone
        // именно из StorageService('user_phone'). Без этой строки номер
        // сохранялся в Firestore, но звонки и чат продолжали видеть старый.
        if (normalizedPhone != null) {
          await StorageService.setString('user_phone', normalizedPhone);
        }
      }

      // 🔒 Notify TaxiProvider to reload preferences and update its state immediately
      if (mounted) {
        try {
          final taxiProvider = Provider.of<TaxiProvider>(context, listen: false);
          await taxiProvider.loadPreferences();
        } catch (taxiErr) {
          debugPrint('TaxiProvider update error: $taxiErr');
        }
      }

      if (mounted) {
        widget.onSave(_nameController.text, _newImage, _isFaceIdEnabled, _accountType, _selectedLanguage);
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error saving profile updates: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_t('error_saving_msg')}: $e'), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _surfaceColor,
        elevation: 0,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.all(10),
          child: Container(
            decoration: BoxDecoration(
              color: _isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: _txtColor, size: 14),
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: Text(_t('title'), style: GoogleFonts.inter(color: _txtColor, fontWeight: FontWeight.w900, fontSize: 18)),
        actions: const [],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: _isDark ? _surfaceColor : Colors.white,
          border: Border(
            top: BorderSide(
              color: _isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF1F5F9),
              width: 1.2,
            ),
          ),
        ),
        child: SafeArea(
          child: Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_primaryColor, _secondaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: _primaryColor.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                )
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: _isSaving ? null : _saveProfile,
                child: Center(
                  child: _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _t('save').toUpperCase(),
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Ambient Glows
          Positioned(
            top: -120,
            left: -120,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _primaryColor.withValues(alpha: 0.12),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _secondaryColor.withValues(alpha: 0.1),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          // Scrollable Content
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _onRefresh,
              color: _primaryColor,
              child: SingleChildScrollView(
                // AlwaysScrollableScrollPhysics вложен, чтобы жест
                // "потянуть вниз" срабатывал, даже если контент короче экрана.
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                  const SizedBox(height: 24),
                  _buildAvatarSection(),
                  const SizedBox(height: 24),
                  _buildSectionTitle(_t('personal')),
                  _buildTextField(_t('name_label'), _nameController, Icons.person_rounded, maxLength: 50),
                  if (_isPhoneVerified) ...[
                    _buildDisplayField(
                      _t('phone_label'),
                      _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : _t('phone_not_provided'),
                      Icons.verified_user_rounded,
                      trailingIcon: Icons.verified_rounded,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(_t('phone_verified_tg_notice')),
                            backgroundColor: const Color(0xFF10B981),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () async {
                        final text = Uri.encodeComponent('Здравствуйте! Я хочу сменить свой верифицированный номер телефона в аккаунте IQ-Market.');
                        final Uri url = Uri.parse('https://wa.me/77089007030?text=$text');
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url, mode: LaunchMode.externalApplication);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: _primaryColor.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _primaryColor.withValues(alpha: 0.15)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.headset_mic_rounded, size: 18, color: _primaryColor),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _t('phone_change_moderator_hint'),
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _primaryColor,
                                ),
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios_rounded, size: 12, color: _primaryColor.withValues(alpha: 0.5)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ] else ...[
                    _buildTextField(_t('phone_label'), _phoneController, Icons.phone_android_rounded, formatters: [_phoneMask], hintText: '+7 (700) 000-00-00'),
                    const SizedBox(height: 12),
                  ],
                  if (_userEmail.isNotEmpty)
                    _buildDisplayField(
                      'Email',
                      _userEmail,
                      Icons.alternate_email_rounded,
                      maxLines: 2,
                      // ellipsis, не visible: 2 строки покрывают почти любой
                      // реальный email целиком, а visible давал тексту
                      // рисоваться поверх соседних элементов, если email всё
                      // же не влезал (без клиппинга и без обрезки).
                      overflow: TextOverflow.ellipsis,
                      fontSize: 15.0,
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: _userEmail));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(Icons.check_circle, color: Colors.white, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _t('email_copied_with_value').replaceAll('{email}', _userEmail),
                                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            backgroundColor: const Color(0xFF10B981),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        );
                      },
                    ),
                  _buildLocationPicker(_t('city_label'), _cityController, Icons.location_on_rounded),
                  _buildDisplayField(
                    _t('reg_date_label'), 
                    "${_registrationDate.day.toString().padLeft(2, '0')}.${_registrationDate.month.toString().padLeft(2, '0')}.${_registrationDate.year}", 
                    Icons.calendar_today_rounded,
                    onTap: () {
                      final dateStr = "${_registrationDate.day.toString().padLeft(2, '0')}.${_registrationDate.month.toString().padLeft(2, '0')}.${_registrationDate.year}";
                      Clipboard.setData(ClipboardData(text: dateStr));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(_t('reg_date_copied')),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  _buildSectionTitle(_t('account_title')),
                  _buildSettingsCard([
                    _buildDisplayField(
                      _t('acc_type_label'), 
                      _getAccountTypeLabel(_accountType), 
                      Icons.badge_rounded, 
                      onTap: () => _showAccountTypePicker(),
                      trailingIcon: Icons.arrow_forward_ios_rounded,
                      isStandalone: false,
                    ),
                    _buildDivider(),
                    _buildDropdownItem(_t('lang_label'), _selectedLanguage, ['Русский', 'Қазақша', 'Уйғурчә'], (v) => setState(() => _selectedLanguage = v!), Icons.translate_rounded),
                    if (_accountType == 'driver') ...[
                      _buildDivider(),
                      _buildClickableItem(
                        _t('confirm_driver_phone'),
                        () => _showChangePhoneDialog(),
                        Icons.verified_user_rounded,
                      ),
                    ],
                  ]),
                  const SizedBox(height: 24),
                  _buildSectionTitle(_t('linked_accounts')),
                  _buildLinkedAccountsSection(),
                  const SizedBox(height: 24),
                  _buildSectionTitle(_t('security')),
                  _buildSettingsCard([
                    _buildSwitchItem(
                      _t('push_label'), 
                      _isNotificationsEnabled, 
                      (v) async {
                        setState(() => _isNotificationsEnabled = v);
                        await StorageService.setBool('push_notifications_enabled', v);
                        final uid = UserService.currentUid;
                        if (uid != null) {
                          try {
                            await FirebaseFirestore.instance.collection('users').doc(uid).set({
                              'pushEnabled': v,
                            }, SetOptions(merge: true));
                          } catch (e) {
                            debugPrint('Error syncing push setting: $e');
                          }
                        }
                      }, 
                      Icons.notifications_active_rounded
                    ),
                  ]),
                  const SizedBox(height: 24),
                  _buildSectionTitle(_t('about_app')),
                  _buildSettingsCard([
                    _buildClickableItem(_t('legal_label'), () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => LegalInfoScreen(lang: _selectedLanguage)));
                    }, Icons.gavel_rounded),
                  ]),
                  const SizedBox(height: 40),
                  _buildDeleteAccountButton(),
                  const SizedBox(height: 60),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarSection() => Center(
    child: Stack(
      alignment: Alignment.bottomRight,
      children: [
        GestureDetector(
          onTap: _showFullScreenPhoto,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: [
                  _primaryColor,
                  _secondaryColor,
                  _primaryColor.withValues(alpha: 0.2),
                  _primaryColor,
                ],
                stops: const [0.0, 0.5, 0.75, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: _primaryColor.withValues(alpha: 0.25),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _bgColor,
              ),
              child: CircleAvatar(
                radius: 56,
                backgroundColor: _isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                backgroundImage: _newImage != null 
                  ? FileImage(_newImage!) 
                  : (widget.profileImagePath != null && widget.profileImagePath!.isNotEmpty
                      ? (widget.profileImagePath!.startsWith('http') 
                          ? NetworkImage(widget.profileImagePath!) as ImageProvider 
                          : FileImage(File(widget.profileImagePath!)))
                      : null),
                child: (_newImage == null && (widget.profileImagePath == null || widget.profileImagePath!.isEmpty)) 
                  ? Icon(Icons.person_rounded, size: 55, color: _primaryColor) 
                  : null,
              ),
            ),
          ),
        ),
        GestureDetector(
          onTap: () => _showImagePickerOptions(),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _primaryColor.withValues(alpha: 0.85),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  void _showFullScreenPhoto() {
    if (_newImage != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SecureImageViewerScreen(
            file: _newImage,
            heroTag: 'avatar_full_settings',
          ),
        ),
      );
    } else if (widget.profileImagePath != null && widget.profileImagePath!.isNotEmpty) {
      final path = widget.profileImagePath!;
      if (path.startsWith('http')) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SecureImageViewerScreen(
              imageUrl: path,
              heroTag: 'avatar_full_settings',
            ),
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SecureImageViewerScreen(
              file: File(path),
              heroTag: 'avatar_full_settings',
            ),
          ),
        );
      }
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _surfaceColor, 
          borderRadius: const BorderRadius.vertical(top: Radius.circular(35))
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, 
              height: 4, 
              decoration: BoxDecoration(
                color: _subtxtColor.withValues(alpha: 0.2), 
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 25),
            Text(
              _t('profile_update_title'), 
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20, 
                fontWeight: FontWeight.w900, 
                color: _txtColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _t('choose_photo_source'), 
              textAlign: TextAlign.center, 
              style: GoogleFonts.plusJakartaSans(
                color: _subtxtColor, 
                fontSize: 13, 
                height: 1.5, 
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 30),
            
            _imageOptionTile(
              icon: Icons.camera_alt_rounded,
              title: _t('take_photo_now'),
              sub: _t('use_selfie_camera'),
              onTap: () async {
                Navigator.pop(context);
                try {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('lost_picker_profile', 'avatar');
                  final pickedFile = await _picker.pickImage(source: ImageSource.camera, imageQuality: 70);
                  if (pickedFile != null && mounted) {
                    setState(() => _newImage = File(pickedFile.path));
                  }
                } catch (e) {
                  debugPrint('Camera Picker Error: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text("${_t('error_camera')}$e 📸"),
                      backgroundColor: const Color(0xFFEF4444),
                      behavior: SnackBarBehavior.floating,
                    ));
                  }
                }
              },
            ),
            const SizedBox(height: 15),
            _imageOptionTile(
              icon: Icons.photo_library_rounded,
              title: _t('choose_from_gallery'),
              sub: _t('upload_ready_photo'),
              onTap: () async {
                Navigator.pop(context);
                try {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('lost_picker_profile', 'avatar');
                  final pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                  if (pickedFile != null && mounted) {
                    setState(() => _newImage = File(pickedFile.path));
                  }
                } catch (e) {
                  debugPrint('Gallery Picker Error: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text("${_t('error_gallery')}$e 🖼️"),
                      backgroundColor: const Color(0xFFEF4444),
                      behavior: SnackBarBehavior.floating,
                    ));
                  }
                }
              },
            ),
            const SizedBox(height: 25),
          ],
        ),
      ),
    );
  }

  Widget _imageOptionTile({required IconData icon, required String title, required String sub, required VoidCallback onTap}) => Container(
    decoration: BoxDecoration(
      color: _isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.015),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: _isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04), width: 1.2)
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _primaryColor.withValues(alpha: 0.12),
                      _primaryColor.withValues(alpha: 0.04),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: _primaryColor, size: 22),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title, 
                      style: GoogleFonts.plusJakartaSans(
                        color: _txtColor, 
                        fontWeight: FontWeight.w800, 
                        fontSize: 14.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      sub, 
                      style: GoogleFonts.plusJakartaSans(
                        color: _subtxtColor.withValues(alpha: 0.8), 
                        fontWeight: FontWeight.w600, 
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios_rounded, color: _subtxtColor.withValues(alpha: 0.3), size: 12),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _buildSectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 12, top: 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 3.5,
          height: 16,
          decoration: BoxDecoration(
            color: _primaryColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 12.0,
            fontWeight: FontWeight.w800,
            color: _isDark ? Colors.white70 : const Color(0xFF1E293B),
            letterSpacing: 0.8,
          ),
        ),
      ],
    ),
  );

  Widget _buildSettingsCard(List<Widget> children) => Container(
    margin: const EdgeInsets.only(bottom: 20),
    decoration: BoxDecoration(
      color: _isDark ? _surfaceColor : Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.02),
          blurRadius: 16,
          offset: const Offset(0, 8),
        )
      ],
      border: Border.all(
        color: _isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF1F5F9),
        width: 1.2,
      ),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Column(children: children),
    ),
  );

  Widget _buildDivider() => Divider(height: 1, color: _subtxtColor.withValues(alpha: 0.1), indent: 70, endIndent: 20);

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {List<TextInputFormatter>? formatters, int? maxLength, String? hintText}) => _PremiumTextField(
    label: label,
    controller: controller,
    icon: icon,
    formatters: formatters,
    maxLength: maxLength,
    hintText: hintText,
    primaryColor: _primaryColor,
    secondaryColor: _secondaryColor,
    surfaceColor: _surfaceColor,
    txtColor: _txtColor,
    subtxtColor: _subtxtColor,
    isDark: _isDark,
  );

  Widget _buildDisplayField(
    String label, 
    String value, 
    IconData icon, {
    VoidCallback? onTap, 
    IconData? trailingIcon, 
    bool isStandalone = true,
    int? maxLines,
    TextOverflow? overflow,
    double? fontSize,
  }) {
    final isCopyable = onTap != null && trailingIcon == null;
    final isDark = _isDark;

    Widget child = Row(
      children: [
        Container(
          width: isStandalone ? 48 : 44,
          height: isStandalone ? 48 : 44,
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(isStandalone ? 14 : 12),
          ),
          child: Center(
            child: Icon(icon, color: _primaryColor, size: isStandalone ? 20 : 18),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 10.0,
                  color: const Color(0xFF94A3B8),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                maxLines: maxLines ?? 1,
                overflow: overflow ?? TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: _txtColor,
                  fontWeight: FontWeight.w800,
                  fontSize: fontSize ?? (isStandalone ? 16.0 : 15.0),
                ),
              ),
            ],
          ),
        ),
        if (trailingIcon != null) ...[
          const SizedBox(width: 8),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
            ),
            child: Center(
              child: Icon(
                trailingIcon, 
                color: trailingIcon == Icons.verified_rounded ? const Color(0xFF10B981) : const Color(0xFF94A3B8), 
                size: 16,
              ),
            ),
          ),
        ] else if (isCopyable) ...[
          const SizedBox(width: 8),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.15) : const Color(0xFFE2E8F0),
                width: 1.2,
              ),
              color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.white,
            ),
            child: Center(
              child: Icon(Icons.content_copy_rounded, color: const Color(0xFF94A3B8), size: 16),
            ),
          ),
        ],
      ],
    );

    if (isStandalone) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? _surfaceColor : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF1F5F9),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 16,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: child,
        ),
      );
    } else {
      return InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: child,
        ),
      );
    }
  }

  Widget _buildLocationPicker(String label, TextEditingController controller, IconData icon) {
    final isDark = _isDark;
    return GestureDetector(
      onTap: () => _showLocationDialog(),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? _surfaceColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF1F5F9),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 16,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Icon(icon, color: _primaryColor, size: 20),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 10.0,
                      color: const Color(0xFF94A3B8),
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    controller.text == 'Все' ? _t('all_cities') : controller.text,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      fontSize: 16.0,
                      color: _txtColor,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
              ),
              child: const Center(
                child: Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchItem(String title, bool value, Function(bool) onChanged, IconData icon) {
    final isDark = _isDark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(icon, color: _primaryColor, size: 18),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w800,
                fontSize: 15.0,
                color: _txtColor,
              ),
            ),
          ),
          Switch.adaptive(
            value: value,
            activeThumbColor: _primaryColor,
            activeTrackColor: _primaryColor.withValues(alpha: 0.4),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownItem(String title, String current, List<String> items, Function(String?) onChanged, IconData icon) {
    final isDark = _isDark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(icon, color: _primaryColor, size: 18),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 9.5,
                    color: const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: current,
                    icon: const SizedBox.shrink(),
                    isDense: true,
                    style: GoogleFonts.inter(color: _txtColor, fontWeight: FontWeight.w800, fontSize: 15.0),
                    borderRadius: BorderRadius.circular(16),
                    dropdownColor: _surfaceColor,
                    onChanged: onChanged,
                    items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
            ),
            child: const Center(
              child: Icon(Icons.unfold_more_rounded, color: Color(0xFF94A3B8), size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteAccountButton() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      child: TextButton(
        onPressed: () => _showDeleteConfirmation(),
        child: Text(
          _t('delete_acc'),
          style: GoogleFonts.inter(
            color: const Color(0xFFEF4444),
            fontWeight: FontWeight.w900,
            fontSize: 13,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) {
        bool isDeleting = false;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: _surfaceColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              title: Text(_t('delete_title'), style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: _txtColor)),
              content: Text(_t('delete_desc'), style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 14, color: _subtxtColor, height: 1.5)),
              actions: [
                TextButton(
                  onPressed: isDeleting ? null : () => Navigator.pop(context), 
                  child: Text(_t('cancel'), style: GoogleFonts.inter(color: _subtxtColor, fontWeight: FontWeight.w900)),
                ),
                TextButton(
                  onPressed: isDeleting ? null : () async {
                    setModalState(() => isDeleting = true);
                    try {
                      final user = FirebaseAuth.instance.currentUser;
                      if (user != null) {
                        // 1. Delete profile image from Storage if it exists —
                        // ДО удаления аккаунта, пока пользователь точно ещё
                        // существует и Storage-правила его точно пропустят.
                        if (widget.profileImagePath != null &&
                            widget.profileImagePath!.isNotEmpty &&
                            widget.profileImagePath!.startsWith('http')) {
                          try {
                            await FileService.deleteFile(widget.profileImagePath!);
                          } catch (e) {
                            debugPrint('Error deleting profile image from storage: $e');
                          }
                        }

                        // 2. Объявления (клиент, доступ к Storage) + Firestore-
                        // данные/подколлекции/отзывы/Auth-аккаунт одним
                        // server-side вызовом (Cloud Function
                        // 'deleteUserAccount', см. UserService.deleteUserData()).
                        // Admin SDK на сервере не требует "свежего входа" —
                        // в отличие от прежнего клиентского user.delete(),
                        // поэтому ветка requires-recent-login здесь больше не
                        // нужна.
                        await UserService.deleteUserData();
                      }
                      await StorageService.clearAll();
                      if (mounted) {
                        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_t('error_deleting_msg')}: $e')));
                        Navigator.pop(context);
                      }
                    } finally {
                      if (context.mounted) {
                        setModalState(() => isDeleting = false);
                      }
                    }
                  },
                  child: isDeleting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red))
                      : Text(_t('delete_confirm'), style: GoogleFonts.inter(color: const Color(0xFFEF4444), fontWeight: FontWeight.w900)),
                ),
              ],
            );
          }
        );
      }
    );
  }

  Widget _buildLinkedAccountsSection() {
    final user = FirebaseAuth.instance.currentUser;
    final providers = user?.providerData.map((p) => p.providerId).toList() ?? [];

    final isGoogleLinked = providers.contains('google.com');
    final isEmailLinked = providers.contains('password');
    final isAppleLinked = providers.contains('apple.com');

    return _buildSettingsCard([
      _buildLinkedItem(
        'Google',
        isGoogleLinked ? _t('linked_status') : _t('click_to_link'),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
            border: Border.all(color: _isDark ? Colors.white10 : Colors.black12),
          ),
          child: Image.network(
            'https://img.icons8.com/color/96/google-logo.png',
            width: 20,
            height: 20,
            errorBuilder: (context, error, stackTrace) => const Icon(Icons.g_mobiledata_rounded, color: Color(0xFF4285F4), size: 20),
          ),
        ),
        isGoogleLinked,
        isGoogleLinked ? null : () async {
          try {
            await AuthService.linkWithGoogle();
            if (mounted) {
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('account_linked_success'))));
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
            }
          }
        }
      ),
      _buildDivider(),
      _buildLinkedItem(
        // Раньше был подписан «Mail.ru» с логотипом mail.ru, хотя по факту это
        // обычная привязка email+пароль (Firebase 'password' provider) — любой
        // email, без какого-либо OAuth в Mail.ru. Название вводило в
        // заблуждение, что нужен именно ящик на mail.ru.
        'Email',
        isEmailLinked ? user?.email ?? _t('linked_status') : _t('link_email_hint'),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
            border: Border.all(color: _isDark ? Colors.white10 : Colors.black12),
          ),
          // Локальная иконка вместо запроса к icons8.com на каждое открытие
          // экрана: тот же alternate_email_rounded уже используется для
          // отображения Email выше по этому же экрану.
          child: Icon(Icons.alternate_email_rounded, color: const Color(0xFF2563EB), size: 20),
        ),
        isEmailLinked,
        isEmailLinked ? null : () => _showLinkEmailDialog()
      ),
      // Apple Sign In работает только на iOS (как и на экране входа —
      // login_screen.dart оборачивает кнопку Apple в Platform.isIOS). Без
      // этого пункта пользователь, зарегистрировавшийся через Apple, не мог
      // привязать запасной способ входа отсюда вообще.
      if (Platform.isIOS) ...[
        _buildDivider(),
        _buildLinkedItem(
          'Apple',
          isAppleLinked ? _t('linked_status') : _t('click_to_link'),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
              border: Border.all(color: _isDark ? Colors.white10 : Colors.black12),
            ),
            child: Icon(Icons.apple_rounded, color: _isDark ? Colors.white : Colors.black, size: 20),
          ),
          isAppleLinked,
          isAppleLinked ? null : () async {
            try {
              await AuthService.linkWithApple();
              if (mounted) {
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('account_linked_success'))));
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            }
          }
        ),
      ],
    ]);
  }

  Widget _buildLinkedItem(String title, String sub, Widget leading, bool isLinked, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      fontSize: 16.0,
                      color: _txtColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 12.0,
                      color: isLinked ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
            if (isLinked)
              const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 24)
            else
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 20),
          ],
        ),
      ),
    );
  }

  void _showLinkEmailDialog() {
    final emailC = TextEditingController();
    final passC = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text(_t('link_email_title'), style: GoogleFonts.inter(fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: emailC, maxLength: 100, decoration: const InputDecoration(hintText: 'Email')),
            TextField(controller: passC, obscureText: true, decoration: const InputDecoration(hintText: 'Password')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(_t('cancel'))),
          ElevatedButton(
            onPressed: () async {
              try {
                await AuthService.linkWithEmail(emailC.text, passC.text);
                final uid = UserService.currentUid;
                if (uid != null) {
                  await FirebaseFirestore.instance.collection('users').doc(uid).collection('private').doc('contact').set({
                    'email': emailC.text.trim(),
                    'updated_at': FieldValue.serverTimestamp(),
                  }, SetOptions(merge: true));
                }
                Navigator.pop(context);
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('link_email_success'))));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: Text(_t('link_action')),
          ),
        ],
      ),
    );
  }

  Widget _buildClickableItem(String title, VoidCallback onTap, IconData icon, {Widget? trailing}) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: _primaryColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(15)),
            child: Icon(icon, color: _primaryColor, size: 20),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    title, 
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: _txtColor),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: trailing,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.arrow_forward_ios_rounded, color: _subtxtColor.withValues(alpha: 0.5), size: 14),
        ],
      ),
    ),
  );

  String _getAccountTypeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'user':
      case 'личный':
      case 'personal':
      case 'acc_personal':
        return _t('acc_personal');
      case 'business':
      case 'бизнес':
      case 'acc_business':
        return _t('acc_business');
      case 'admin':
      case 'администратор':
      case 'acc_admin':
        return _t('acc_admin');
      default:
        if (type.toLowerCase().contains('personal')) {
          return _t('acc_personal');
        }
        if (type.toLowerCase().contains('business')) {
          return _t('acc_business');
        }
        return type;
    }
  }

  void _showAccountTypePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surfaceColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: _subtxtColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 24),
            Text(_t('acc_type_label'), style: GoogleFonts.inter(color: _txtColor, fontWeight: FontWeight.w900, fontSize: 20)),
            const SizedBox(height: 24),
            _typeCard('user', _t('acc_personal'), _t('acc_type_user_desc'), Icons.person_rounded),
            const SizedBox(height: 16),
            _typeCard('business', _t('acc_business'), _t('acc_type_business_desc'), Icons.store_rounded),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _typeCard(String typeKey, String label, String desc, IconData icon) {
    final isSelected = _accountType == typeKey;
    return GestureDetector(
      onTap: () {
        setState(() => _accountType = typeKey);
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? _primaryColor.withValues(alpha: 0.05) : _bgColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isSelected ? _primaryColor : _subtxtColor.withValues(alpha: 0.1), width: 2),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: isSelected ? _primaryColor : Colors.white, borderRadius: BorderRadius.circular(15)),
              child: Icon(icon, color: isSelected ? Colors.white : _subtxtColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16, color: _txtColor)),
                  const SizedBox(height: 4),
                  Text(desc, style: GoogleFonts.inter(fontSize: 12, color: _subtxtColor, height: 1.4)),
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check_circle_rounded, color: _primaryColor, size: 24),
          ],
        ),
      ),
    );
  }

  void _showChangePhoneDialog() {
    String tgCode = '';
    bool codeSent = false;
    final dialogPhoneMask = MaskTextInputFormatter(
      mask: '+7 (###) ###-##-##',
      filter: {"#": RegExp(r'[0-9]')},
      type: MaskAutoCompletionType.lazy,
    );
    final phoneC = TextEditingController();

    // Pre-fill existing phone if valid
    String initialPhone = _phoneController.text;
    if (initialPhone.isNotEmpty) {
      final digits = initialPhone.replaceAll(RegExp(r'\D'), '');
      if (digits.length >= 10) {
        String cleanedDigits = digits;
        if (digits.startsWith('8') && digits.length == 11) {
          cleanedDigits = '7' + digits.substring(1);
        } else if (digits.length == 10) {
          cleanedDigits = '7' + digits;
        }
        phoneC.text = dialogPhoneMask.maskText(cleanedDigits);
      }
    }

    final codeC = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surfaceColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (ctx) => StatefulBuilder(builder: (context, setS) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, top: 24, left: 28, right: 28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: _subtxtColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10))),
          const SizedBox(height: 24),
          Icon(Icons.phone_android_rounded, color: _primaryColor, size: 40),
          const SizedBox(height: 16),
          Text(
            _t('driver_verification_title'), 
            style: GoogleFonts.inter(color: _txtColor, fontWeight: FontWeight.w900, fontSize: 19)
          ),
          const SizedBox(height: 8),
          Text(
            _t('driver_verification_desc'),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: _subtxtColor, fontSize: 13, height: 1.5)
          ),
          const SizedBox(height: 24),

          if (!codeSent) ...[
            _buildDialogField(_t('new_phone_label'), phoneC, Icons.phone, formatters: [dialogPhoneMask]),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: () {
                  final unformattedPhone = phoneC.text.replaceAll(RegExp(r'\D'), '');
                  if (unformattedPhone.length < 11) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_t('enter_full_phone')),
                        backgroundColor: Colors.redAccent,
                        behavior: SnackBarBehavior.floating,
                      )
                    );
                    return;
                  }
                  tgCode = (DateTime.now().millisecondsSinceEpoch % 90000 + 10000).toString(); // 5 digits
                  setS(() => codeSent = true);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${_t('code_sent_demo')}$tgCode (${_t('demo_label')})"), backgroundColor: const Color(0xFF0088CC)));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                child: Text(_t('send_code_btn'), style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
              ),
            ),
          ],
          if (codeSent) ...[
            Text("${_t('code_sent_to')}\n${phoneC.text}",
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: _primaryColor, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 16),
            _buildDialogField(_t('code_from_tg'), codeC, Icons.pin_rounded),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: () async {
                  if (codeC.text.trim() == tgCode) {
                    Navigator.pop(ctx);
                    
                    // 🔒 Senior-Level Sync: Update phone number in Firestore & Local State
                    final user = FirebaseAuth.instance.currentUser;
                    if (user != null) {
                      try {
                        await UserService.updateUserProfile({
                          'phone': phoneC.text,
                        });
                        setState(() {
                          _phoneController.text = phoneC.text;
                        });
                      } catch (e) {
                        debugPrint('Error updating phone: $e');
                      }
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_t('phone_change_success')), 
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                      )
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_t('invalid_code')), 
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                      )
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                child: Text(_t('confirm_action'), style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
              ),
            ),
          ],
          const SizedBox(height: 30),
        ]),
      )),
    ).then((_) {
      phoneC.dispose();
      codeC.dispose();
    });
  }

  Widget _buildDialogField(String hint, TextEditingController controller, IconData icon, {List<TextInputFormatter>? formatters}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _subtxtColor.withValues(alpha: 0.2)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: formatters != null ? TextInputType.phone : TextInputType.text,
        inputFormatters: formatters,
        style: GoogleFonts.inter(color: _txtColor, fontWeight: FontWeight.bold, fontSize: 16),
        decoration: InputDecoration(
          border: InputBorder.none,
          icon: Icon(icon, color: _primaryColor, size: 20),
          hintText: hint,
          hintStyle: GoogleFonts.inter(color: _subtxtColor.withValues(alpha: 0.5)),
        ),
      ),
    );
  }



  void _showLocationDialog() {
    // Плоский алфавитный список без скрытых вложенных районов — тот же
    // пикер, что и при размещении объявления (LocationSelector), вместо
    // прежней ручной drill-down навигации по KazakhstanLocations.hierarchy.
    final config = Provider.of<AppConfigProvider>(context, listen: false);
    LocationSelector.showLocationPicker(
      context,
      lang: _selectedLanguage,
      selectedLocation: config.city,
      displayCities: ['Все', ...KazakhstanLocations.getAllLocations()],
      itemLabelBuilder: (item) => item == 'Все' ? _t('all_cities') : item,
      onLocationSelected: (city) {
        setState(() => _cityController.text = city);
        config.setCity(city);
      },
    );
  }
}

class _PremiumTextField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final List<TextInputFormatter>? formatters;
  final int? maxLength;
  final String? hintText;
  final Color primaryColor;
  final Color secondaryColor;
  final Color surfaceColor;
  final Color txtColor;
  final Color subtxtColor;
  final bool isDark;

  const _PremiumTextField({
    required this.label,
    required this.controller,
    required this.icon,
    this.formatters,
    this.maxLength,
    this.hintText,
    required this.primaryColor,
    required this.secondaryColor,
    required this.surfaceColor,
    required this.txtColor,
    required this.subtxtColor,
    required this.isDark,
  });

  @override
  State<_PremiumTextField> createState() => _PremiumTextFieldState();
}

class _PremiumTextFieldState extends State<_PremiumTextField> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (mounted) {
        setState(() {
          _isFocused = _focusNode.hasFocus;
        });
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = widget.isDark;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? widget.surfaceColor : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isFocused
              ? widget.primaryColor
              : (isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF1F5F9)),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
          if (_isFocused)
            BoxShadow(
              color: widget.primaryColor.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Icon(
                widget.icon,
                color: widget.primaryColor,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.label.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 10.0,
                    color: const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  inputFormatters: widget.formatters,
                  maxLength: widget.maxLength,
                  style: GoogleFonts.inter(
                    color: widget.txtColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 16.0,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    counterText: '',
                    hintText: widget.hintText,
                    hintStyle: GoogleFonts.inter(
                      color: widget.subtxtColor.withValues(alpha: 0.4),
                      fontWeight: FontWeight.w500,
                      fontSize: 16.0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
