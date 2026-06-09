import 'dart:io';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:iqmarket/services/storage_service.dart';
import 'package:iqmarket/data/kazakhstan_locations.dart';
import 'package:iqmarket/services/location_service.dart';
import 'package:iqmarket/screens/legal_info_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:provider/provider.dart';
import 'package:iqmarket/providers/app_config_provider.dart';
import 'package:iqmarket/services/translation_service.dart';
import 'package:iqmarket/services/auth_service.dart';
import 'package:iqmarket/services/user_service.dart';
import 'package:iqmarket/services/file_service.dart';

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
  Color get _primaryColor => widget.themes[_currentTheme]?['primary'] ?? const Color(0xFF4A80F0);
  Color get _secondaryColor => _isDark ? const Color(0xFF6366F1) : const Color(0xFF4F46E5);

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
  }

  Future<void> _loadFirestoreUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists && mounted) {
          final data = doc.data();
          if (data != null) {
            setState(() {
              if (data['phone'] != null && data['phone'].toString().isNotEmpty) {
                final rawPhone = data['phone'].toString();
                final digits = rawPhone.replaceAll(RegExp(r'\D'), '');
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
              if (data['email'] != null && data['email'].toString().isNotEmpty) {
                _emailController.text = data['email'].toString();
                _userEmail = data['email'].toString();
              }
              if (data['registrationDate'] != null) {
                final timestamp = data['registrationDate'];
                if (timestamp is Timestamp) {
                  _registrationDate = timestamp.toDate();
                }
              }
            });
          }
        }
      } catch (e) {
        debugPrint('Error loading user data from Firestore: $e');
      }
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

  Future<void> _saveProfile() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      String? finalPhotoUrl = widget.profileImagePath?.startsWith('http') == true ? widget.profileImagePath : null;

      if (_newImage != null) {
        final File? compressed = await FileService.compressImage(_newImage!);
        final String? uploadedUrl = await FileService.uploadFile(compressed ?? _newImage!, 'avatars');
        if (uploadedUrl != null) {
          finalPhotoUrl = uploadedUrl;
          if (widget.profileImagePath != null && widget.profileImagePath!.startsWith('http')) {
            await FileService.deleteFile(widget.profileImagePath!);
          }
        }
      }

      final String? imagePathToSave = _newImage?.path ?? widget.profileImagePath;
      await StorageService.saveProfile(_nameController.text, imagePathToSave, _isFaceIdEnabled, _accountType);
      
      if (mounted) {
        final config = Provider.of<AppConfigProvider>(context, listen: false);
        config.setLanguage(_selectedLanguage);
        config.setCity(_cityController.text);
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final Map<String, dynamic> updateData = {
          'name': _nameController.text,
          'phone': _phoneController.text,
          'location': _cityController.text,
          'accountType': _accountType,
        };
        if (finalPhotoUrl != null) {
          updateData['photoUrl'] = finalPhotoUrl;
        }
        await UserService.updateUserProfile(updateData);
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

  Widget _buildProfileCompleteness() {
    int percent = 0;
    final user = FirebaseAuth.instance.currentUser;
    final providers = user?.providerData.map((p) => p.providerId).toList() ?? [];
    
    if (_newImage != null || (widget.profileImagePath != null && widget.profileImagePath!.isNotEmpty)) {
      percent += 20;
    }
    if (_nameController.text.trim().isNotEmpty) {
      percent += 20;
    }
    if (_phoneController.text.trim().isNotEmpty) {
      percent += 20;
    }
    if (_cityController.text.trim().isNotEmpty && _cityController.text != 'Все') {
      percent += 20;
    }
    if (_userEmail.isNotEmpty || providers.isNotEmpty) {
      percent += 20;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surfaceColor.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.bolt_rounded, color: _primaryColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t('profile_completeness_title'),
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: _txtColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      percent == 100 
                          ? _t('profile_complete_good') 
                          : _t('profile_complete_prompt'),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10.5,
                        color: _subtxtColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$percent%',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: _primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: percent / 100.0,
              minHeight: 8,
              backgroundColor: _isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
              valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
            ),
          ),
        ],
      ),
    );
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
          color: _surfaceColor,
          border: Border(
            top: BorderSide(
              color: _isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
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
                  color: _primaryColor.withValues(alpha: 0.3),
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
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(width: 10),
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
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  _buildAvatarSection(),
                  const SizedBox(height: 20),
                  _buildProfileCompleteness(),
                  const SizedBox(height: 24),
                  _buildSectionTitle(_t('personal')),
                  _buildTextField(_t('name_label'), _nameController, Icons.person_rounded),
                  _buildTextField(_t('phone_label'), _phoneController, Icons.phone_android_rounded, formatters: [_phoneMask]),
                  if (_userEmail.isNotEmpty)
                    _buildDisplayField(
                      'Email', 
                      _userEmail, 
                      Icons.alternate_email_rounded,
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: _userEmail));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(_t('email_copied')),
                            behavior: SnackBarBehavior.floating,
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
    final imageProvider = _newImage != null 
        ? FileImage(_newImage!) 
        : (widget.profileImagePath != null && widget.profileImagePath!.isNotEmpty
            ? (widget.profileImagePath!.startsWith('http') 
                ? NetworkImage(widget.profileImagePath!) as ImageProvider 
                : FileImage(File(widget.profileImagePath!)))
            : null);
    
    if (imageProvider == null) return;

    Navigator.push(context, MaterialPageRoute(builder: (context) => Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image(image: imageProvider, fit: BoxFit.contain),
        ),
      ),
    )));
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
                  final pickedFile = await _picker.pickImage(source: ImageSource.camera, imageQuality: 70);
                  if (pickedFile != null) setState(() => _newImage = File(pickedFile.path));
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
                  final pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                  if (pickedFile != null) setState(() => _newImage = File(pickedFile.path));
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
    padding: const EdgeInsets.only(left: 4, bottom: 12, top: 8),
    child: Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [_primaryColor, _secondaryColor]),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title.toUpperCase(),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11.0,
            fontWeight: FontWeight.w800,
            color: _txtColor.withValues(alpha: 0.75),
            letterSpacing: 1.2,
          ),
        ),
      ],
    ),
  );

  Widget _buildSettingsCard(List<Widget> children) => Container(
    margin: const EdgeInsets.only(bottom: 20),
    decoration: BoxDecoration(
      color: _surfaceColor.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.02),
          blurRadius: 16,
          offset: const Offset(0, 8),
        )
      ],
      border: Border.all(
        color: _isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
        width: 1.2,
      ),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Column(children: children),
    ),
  );

  Widget _buildDivider() => Divider(height: 1, color: _subtxtColor.withValues(alpha: 0.1), indent: 70, endIndent: 20);

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {List<TextInputFormatter>? formatters}) => _PremiumTextField(
    label: label,
    controller: controller,
    icon: icon,
    formatters: formatters,
    primaryColor: _primaryColor,
    secondaryColor: _secondaryColor,
    surfaceColor: _surfaceColor,
    txtColor: _txtColor,
    subtxtColor: _subtxtColor,
    isDark: _isDark,
  );

  Widget _buildDisplayField(String label, String value, IconData icon, {VoidCallback? onTap, IconData? trailingIcon}) {
    final isCopyable = onTap != null && trailingIcon == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: _isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.01),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
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
              child: Icon(icon, color: _primaryColor, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9.5,
                      color: _primaryColor.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: GoogleFonts.plusJakartaSans(
                      color: _txtColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 15.0,
                    ),
                  ),
                ],
              ),
            ),
            if (trailingIcon != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _subtxtColor.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(trailingIcon, color: _subtxtColor.withValues(alpha: 0.5), size: 12),
              ),
            ] else if (isCopyable) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _primaryColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.copy_all_rounded, color: _primaryColor.withValues(alpha: 0.7), size: 14),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLocationPicker(String label, TextEditingController controller, IconData icon) => GestureDetector(
    onTap: () => _showLocationDialog(),
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.01),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _secondaryColor.withValues(alpha: 0.15),
                  _secondaryColor.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: _secondaryColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label.toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9.5,
                    color: _secondaryColor,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  controller.text == 'Все' ? _t('all_cities') : controller.text,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 15.0,
                    color: _txtColor,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _subtxtColor.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.arrow_forward_ios_rounded, color: _subtxtColor.withValues(alpha: 0.5), size: 12),
          ),
        ],
      ),
    ),
  );

  Widget _buildSwitchItem(String title, bool value, Function(bool) onChanged, IconData icon) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: _primaryColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(15)),
          child: Icon(icon, color: _primaryColor, size: 20),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: _txtColor)),
        ),
        Switch.adaptive(
          value: value, 
          activeThumbColor: _primaryColor,
          activeTrackColor: _primaryColor.withValues(alpha: 0.5),
          onChanged: onChanged,
        ),
      ],
    ),
  );

  Widget _buildDropdownItem(String title, String current, List<String> items, Function(String?) onChanged, IconData icon) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: _primaryColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(15)),
          child: Icon(icon, color: _primaryColor, size: 20),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: _txtColor)),
        ),
        DropdownButton<String>(
          value: current,
          icon: Icon(Icons.unfold_more_rounded, size: 20, color: _subtxtColor.withValues(alpha: 0.4)),
          underline: const SizedBox(),
          style: GoogleFonts.inter(color: _primaryColor, fontWeight: FontWeight.w800, fontSize: 14),
          borderRadius: BorderRadius.circular(20),
          dropdownColor: _surfaceColor,
          onChanged: onChanged,
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        ),
      ],
    ),
  );

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
      builder: (context) => AlertDialog(
        backgroundColor: _surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text(_t('delete_title'), style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: _txtColor)),
        content: Text(_t('delete_desc'), style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 14, color: _subtxtColor, height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(_t('cancel'), style: GoogleFonts.inter(color: _subtxtColor, fontWeight: FontWeight.w900))),
          TextButton(
            onPressed: () async {
              try {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  await user.delete();
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
              }
            },
            child: Text(_t('delete_confirm'), style: GoogleFonts.inter(color: const Color(0xFFEF4444), fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkedAccountsSection() {
    final user = FirebaseAuth.instance.currentUser;
    final providers = user?.providerData.map((p) => p.providerId).toList() ?? [];
    
    final isGoogleLinked = providers.contains('google.com');
    final isEmailLinked = providers.contains('password');

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
            setState(() {});
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('copied_clipboard'))));
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
          }
        }
      ),
      _buildDivider(),
      _buildLinkedItem(
        'Mail.ru', 
        isEmailLinked ? user?.email ?? _t('linked_status') : _t('link_email_hint'),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
            border: Border.all(color: _isDark ? Colors.white10 : Colors.black12),
          ),
          child: Image.network(
            'https://img.icons8.com/color/96/mailru.png',
            width: 20,
            height: 20,
            errorBuilder: (context, error, stackTrace) => const Icon(Icons.mail_rounded, color: Color(0xFF005FFC), size: 20),
          ),
        ),
        isEmailLinked,
        isEmailLinked ? null : () => _showLinkEmailDialog()
      ),
    ]);
  }

  Widget _buildLinkedItem(String title, String sub, Widget leading, bool isLinked, VoidCallback? onTap) => ListTile(
    onTap: onTap,
    leading: leading,
    title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14, color: _txtColor)),
    subtitle: Text(sub, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 11, color: isLinked ? const Color(0xFF10B981) : _subtxtColor.withValues(alpha: 0.7))),
    trailing: isLinked 
        ? const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 22)
        : (onTap != null ? Icon(Icons.arrow_forward_ios_rounded, color: _subtxtColor.withValues(alpha: 0.3), size: 14) : null),
  );

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
            TextField(controller: emailC, decoration: const InputDecoration(hintText: 'Email')),
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
                  await FirebaseFirestore.instance.collection('users').doc(uid).update({
                    'email': emailC.text.trim(),
                  });
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
        return _t('acc_personal');
      case 'business':
      case 'бизнес':
        return _t('acc_business');
      case 'admin':
      case 'администратор':
        return _t('acc_admin');
      default:
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
            listToDisplay = ['Все', 'Чунджа'] + KazakhstanLocations.hierarchy.keys.toList();
          }

          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: BoxDecoration(color: _surfaceColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(35))),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: _subtxtColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10))),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      if (selectedParent != null && searchCity.isEmpty)
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: _txtColor),
                          onPressed: () => setModalState(() => selectedParent = null),
                        ),
                      if (selectedParent != null && searchCity.isEmpty) const SizedBox(width: 15),
                      Text(
                        searchCity.isNotEmpty ? _t('search_results') : (selectedParent ?? _t('select_location_title')), 
                        style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: _txtColor)
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: TextField(
                    onChanged: (v) => setModalState(() => searchCity = v),
                    style: GoogleFonts.inter(color: _txtColor, fontWeight: FontWeight.w800),
                    decoration: InputDecoration(
                      hintText: _t('search_city_hint'),
                      hintStyle: GoogleFonts.inter(color: _subtxtColor.withValues(alpha: 0.6), fontWeight: FontWeight.w600),
                      prefixIcon: Icon(Icons.search_rounded, color: _primaryColor),
                      filled: true,
                      fillColor: _subtxtColor.withValues(alpha: 0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                if (selectedParent == null && searchCity.isEmpty) ...[
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                    leading: Icon(Icons.my_location_rounded, color: _primaryColor), 
                    title: Text(_t('auto_locate'), style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: _primaryColor, fontSize: 15)), 
                    onTap: () async {
                      final city = await LocationService.getCurrentCity();
                      if (city != null) {
                        setState(() => _cityController.text = city);
                        StorageService.setString('user_location', city);
                        Navigator.pop(context);
                      }
                    }
                  ),
                  const Divider(indent: 24, endIndent: 24, color: Colors.transparent),
                ],
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: listToDisplay.length,
                    separatorBuilder: (c, i) => Divider(color: _subtxtColor.withValues(alpha: 0.05), height: 1),
                    itemBuilder: (context, index) {
                      final item = listToDisplay[index];
                      final isParent = KazakhstanLocations.hierarchy.containsKey(item) && searchCity.isEmpty;

                      return ListTile(
                        leading: Icon(isParent ? Icons.location_city_rounded : Icons.location_on_rounded, color: _subtxtColor.withValues(alpha: 0.6)),
                        title: Text(item == 'Все' ? _t('all_cities') : item, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15, color: _txtColor)),
                        trailing: Icon(isParent ? Icons.arrow_forward_ios_rounded : Icons.check_circle_outline_rounded, size: 14, color: isParent ? _subtxtColor.withValues(alpha: 0.4) : const Color(0xFF10B981)),
                        onTap: () { 
                          if (isParent) {
                            setModalState(() => selectedParent = item);
                          } else {
                            setState(() => _cityController.text = item); 
                            final config = Provider.of<AppConfigProvider>(context, listen: false);
                            config.setCity(item);
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
}

class _PremiumTextField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final List<TextInputFormatter>? formatters;
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: widget.surfaceColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _isFocused
              ? widget.primaryColor
              : (widget.isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04)),
          width: _isFocused ? 2.0 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: _isFocused
                ? widget.primaryColor.withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: 0.01),
            blurRadius: _isFocused ? 14 : 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _isFocused
                    ? [widget.primaryColor, widget.secondaryColor]
                    : [
                        widget.primaryColor.withValues(alpha: 0.12),
                        widget.primaryColor.withValues(alpha: 0.04),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: _isFocused
                  ? [
                      BoxShadow(
                        color: widget.primaryColor.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      )
                    ]
                  : [],
            ),
            child: Icon(
              widget.icon,
              color: _isFocused ? Colors.white : widget.primaryColor,
              size: 20,
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
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9.5,
                    color: _isFocused ? widget.primaryColor : widget.subtxtColor.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  inputFormatters: widget.formatters,
                  style: GoogleFonts.plusJakartaSans(
                    color: widget.txtColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 15.0,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
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
