import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:iqmarket/services/biometric_service.dart';
import 'package:iqmarket/services/storage_service.dart';
import 'package:iqmarket/data/kazakhstan_locations.dart';
import 'package:iqmarket/services/location_service.dart';
import 'package:iqmarket/screens/legal_info_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:provider/provider.dart';
import 'package:iqmarket/providers/app_config_provider.dart';
import 'package:iqmarket/services/translation_service.dart';

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
  final _emailController = TextEditingController(text: "alex@example.com");
  late TextEditingController _cityController;
  final _phoneController = TextEditingController(text: "7089007030");
  
  final _phoneMask = MaskTextInputFormatter(
    mask: '+7 (###) ###-##-##',
    filter: {"#": RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );
  File? _newImage;
  final ImagePicker _picker = ImagePicker();

  late bool _isNotificationsEnabled;
  late bool _isFaceIdEnabled;
  late String _selectedLanguage;
  late String _accountType;
  late String _currentTheme;

  bool get _isDark => _currentTheme == 'Dark' || Theme.of(context).brightness == Brightness.dark;
  Color get _bgColor => Theme.of(context).colorScheme.surface;
  Color get _surfaceColor => Theme.of(context).colorScheme.surface;
  Color get _txtColor => Theme.of(context).colorScheme.onSurface;
  Color get _subtxtColor => Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
  Color get _primaryColor => Theme.of(context).colorScheme.primary;

  @override
  void initState() {
    super.initState();
    final config = Provider.of<AppConfigProvider>(context, listen: false);
    _nameController = TextEditingController(text: widget.currentName);
    _cityController = TextEditingController(text: config.city);
    _isNotificationsEnabled = true;
    _isFaceIdEnabled = widget.isBioEnabled;
    _selectedLanguage = widget.lang;
    _accountType = widget.accType;
    _currentTheme = widget.currentTheme;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _surfaceColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: _txtColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(_t('title'), style: GoogleFonts.inter(color: _txtColor, fontWeight: FontWeight.w900, fontSize: 18)),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: TextButton(
              onPressed: () async {
                final String? imagePathToSave = _newImage?.path ?? widget.profileImagePath;
                await StorageService.saveProfile(_nameController.text, imagePathToSave, _isFaceIdEnabled, _accountType);
                
                // Sync with global config
                if (mounted) {
                  final config = Provider.of<AppConfigProvider>(context, listen: false);
                  config.setLanguage(_selectedLanguage);
                  config.setCity(_cityController.text);
                }

                widget.onSave(_nameController.text, _newImage, _isFaceIdEnabled, _accountType, _selectedLanguage);
                Navigator.pop(context);
              },
              style: TextButton.styleFrom(
                backgroundColor: _primaryColor.withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: Text(_t('save'), style: GoogleFonts.inter(color: _primaryColor, fontWeight: FontWeight.w900, fontSize: 14)),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 30),
            _buildAvatarSection(),
            const SizedBox(height: 40),
            _buildSectionTitle(_t('personal')),
            _buildSettingsCard([
              _buildTextField(_t('name_label'), _nameController, Icons.person_rounded),
              _buildDivider(),
              _buildTextField('Номер телефона', _phoneController, Icons.phone_android_rounded, formatters: [_phoneMask]),
              _buildDivider(),
              _buildLocationPicker(_t('city_label'), _cityController, Icons.location_on_rounded),
              _buildDivider(),
              _buildClickableItem(
                _selectedLanguage == 'Русский' ? 'Дата регистрации' : (_selectedLanguage == 'Қазақша' ? 'Тіркелген күні' : 'Тизимләнгән күни'), 
                () {}, // Read-only
                Icons.calendar_today_rounded, 
                trailing: Text('12.05.2023', style: GoogleFonts.inter(color: _subtxtColor, fontWeight: FontWeight.w700, fontSize: 13))
              ),
            ]),
            const SizedBox(height: 30),
            _buildSectionTitle(_t('account_title')),
            _buildSettingsCard([
              _buildClickableItem(
                _t('acc_type_label'), 
                () => _showAccountTypePicker(), 
                Icons.badge_rounded, 
                trailing: Text(_accountType, style: GoogleFonts.inter(color: _primaryColor, fontWeight: FontWeight.w900, fontSize: 13))
              ),
              _buildDivider(),
              _buildDropdownItem(_t('lang_label'), _selectedLanguage, ['Русский', 'Қазақша', 'Уйғурчә'], (v) => setState(() => _selectedLanguage = v!), Icons.translate_rounded),
              _buildDivider(),
              _buildClickableItem(_t('change_phone'), () => _showChangePhoneDialog(), Icons.phone_android_rounded),
            ]),
            const SizedBox(height: 30),
            _buildSectionTitle('Связанные аккаунты'),
            _buildLinkedAccountsSection(),
            const SizedBox(height: 30),
            _buildSectionTitle(_t('security')),
            _buildSettingsCard([
              _buildSwitchItem(_t('push_label'), _isNotificationsEnabled, (v) => setState(() => _isNotificationsEnabled = v), Icons.notifications_active_rounded),
              _buildDivider(),
              _buildSwitchItem(_t('bio_label'), _isFaceIdEnabled, (v) async {
                if (v && await BiometricService.authenticate()) {
                  setState(() => _isFaceIdEnabled = true);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('success_bio')), backgroundColor: const Color(0xFF10B981), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))));
                } else {
                  setState(() => _isFaceIdEnabled = false);
                }
              }, Icons.fingerprint_rounded),
            ]),
            const SizedBox(height: 30),
            _buildSectionTitle(_t('about_app')),
            _buildSettingsCard([
              _buildClickableItem(_t('legal_label'), () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => LegalInfoScreen(lang: _selectedLanguage)));
              }, Icons.gavel_rounded),
            ]),
            const SizedBox(height: 30),
            _buildSectionTitle(_t('theme_title')),
            _buildThemeSection(),
            const SizedBox(height: 40),
            _buildDeleteAccountButton(),
            const SizedBox(height: 60),
          ],
        ),
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
              gradient: LinearGradient(colors: [_primaryColor, _primaryColor.withValues(alpha: 0.7)]),
              boxShadow: [BoxShadow(color: _primaryColor.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10))],
            ),
            child: CircleAvatar(
              radius: 55,
              backgroundColor: Colors.white,
              backgroundImage: _newImage != null 
                ? FileImage(_newImage!) 
                : (widget.profileImagePath != null ? FileImage(File(widget.profileImagePath!)) : null),
              child: (_newImage == null && widget.profileImagePath == null) 
                ? Icon(Icons.person_rounded, size: 55, color: _primaryColor) 
                : null,
            ),
          ),
        ),
        GestureDetector(
          onTap: () => _showImagePickerOptions(),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _primaryColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)],
            ),
            child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
          ),
        ),
      ],
    ),
  );

  void _showFullScreenPhoto() {
    final imageProvider = _newImage != null 
        ? FileImage(_newImage!) 
        : (widget.profileImagePath != null ? FileImage(File(widget.profileImagePath!)) : null);
    
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
            Container(width: 40, height: 4, decoration: BoxDecoration(color: _subtxtColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 25),
            Text('Обновление профиля', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: _txtColor)),
            const SizedBox(height: 10),
            Text('Выберите источник для нового фото', textAlign: TextAlign.center, style: GoogleFonts.inter(color: _subtxtColor, fontSize: 13, height: 1.5, fontWeight: FontWeight.w500)),
            const SizedBox(height: 30),
            
            _imageOptionTile(
              icon: Icons.camera_alt_rounded,
              title: 'Сделать фото сейчас',
              sub: 'Используйте камеру для селфи',
              color: const Color(0xFF10B981),
              onTap: () async {
                Navigator.pop(context);
                final pickedFile = await _picker.pickImage(source: ImageSource.camera, imageQuality: 70);
                if (pickedFile != null) setState(() => _newImage = File(pickedFile.path));
              },
            ),
            const SizedBox(height: 15),
            _imageOptionTile(
              icon: Icons.photo_library_rounded,
              title: 'Выбрать из галереи',
              sub: 'Загрузите готовое фото',
              color: _primaryColor,
              onTap: () async {
                Navigator.pop(context);
                final pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                if (pickedFile != null) setState(() => _newImage = File(pickedFile.path));
              },
            ),
            const SizedBox(height: 25),
          ],
        ),
      ),
    );
  }

  Widget _imageOptionTile({required IconData icon, required String title, required String sub, required Color color, required VoidCallback onTap}) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05), 
        borderRadius: BorderRadius.circular(24), 
        border: Border.all(color: color.withValues(alpha: 0.15), width: 1.5)
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.8)]),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(color: color, fontWeight: FontWeight.w900, fontSize: 15)),
                const SizedBox(height: 2),
                Text(sub, style: GoogleFonts.inter(color: color.withValues(alpha: 0.6), fontWeight: FontWeight.w600, fontSize: 11)),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded, size: 14, color: color.withValues(alpha: 0.3)),
        ],
      ),
    ),
  );

  Widget _buildSectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 12),
    child: Row(
      children: [
        Container(width: 4, height: 14, decoration: BoxDecoration(color: _primaryColor, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 10),
        Text(title.toUpperCase(), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, color: _subtxtColor, letterSpacing: 1.0)),
      ],
    ),
  );

  Widget _buildSettingsCard(List<Widget> children) => Container(
    margin: const EdgeInsets.only(bottom: 20),
    decoration: BoxDecoration(
      color: _surfaceColor,
      borderRadius: BorderRadius.circular(28),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 20, offset: const Offset(0, 10))],
      border: Border.all(color: _isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05), width: 1.2),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Column(children: children),
    ),
  );

  Widget _buildDivider() => Divider(height: 1, color: _subtxtColor.withValues(alpha: 0.1), indent: 70, endIndent: 20);

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {List<TextInputFormatter>? formatters}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: _primaryColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(15)),
          child: Icon(icon, color: _primaryColor, size: 20),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(), style: GoogleFonts.inter(fontSize: 9, color: _primaryColor, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              const SizedBox(height: 2),
              TextField(
                controller: controller,
                inputFormatters: formatters,
                style: GoogleFonts.inter(color: _txtColor, fontWeight: FontWeight.w800, fontSize: 15),
                decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildLocationPicker(String label, TextEditingController controller, IconData icon) => InkWell(
    onTap: () => _showLocationDialog(),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: _primaryColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(15)),
            child: Icon(icon, color: _primaryColor, size: 20),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(), style: GoogleFonts.inter(fontSize: 9, color: _primaryColor, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                const SizedBox(height: 2),
                Text(controller.text, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15, color: _txtColor)),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded, color: _subtxtColor.withValues(alpha: 0.4), size: 14),
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
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка при удалении: $e')));
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
        isGoogleLinked ? 'Подключено' : 'Нажмите, чтобы связать',
        isGoogleLinked ? Icons.check_circle_rounded : Icons.add_link_rounded,
        isGoogleLinked ? const Color(0xFF10B981) : _subtxtColor,
        isGoogleLinked ? null : () async {
          try {
            await AuthService.linkWithGoogle();
            setState(() {});
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Аккаунты успешно связаны!')));
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
          }
        }
      ),
      _buildDivider(),
      _buildLinkedItem(
        'Email', 
        isEmailLinked ? user?.email ?? 'Подключено' : 'Привязать почту',
        isEmailLinked ? Icons.check_circle_rounded : Icons.alternate_email_rounded,
        isEmailLinked ? const Color(0xFF10B981) : _subtxtColor,
        isEmailLinked ? null : () => _showLinkEmailDialog()
      ),
    ]);
  }

  Widget _buildLinkedItem(String title, String sub, IconData icon, Color color, VoidCallback? onTap) => ListTile(
    onTap: onTap,
    leading: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(15)),
      child: Icon(icon, color: color, size: 20),
    ),
    title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14, color: _txtColor)),
    subtitle: Text(sub, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 11, color: color.withValues(alpha: 0.7))),
    trailing: onTap != null ? Icon(Icons.arrow_forward_ios_rounded, color: _subtxtColor.withValues(alpha: 0.3), size: 14) : null,
  );

  void _showLinkEmailDialog() {
    final emailC = TextEditingController();
    final passC = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text('Привязать Email', style: GoogleFonts.inter(fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: emailC, decoration: const InputDecoration(hintText: 'Email')),
            TextField(controller: passC, obscureText: true, decoration: const InputDecoration(hintText: 'Пароль')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () async {
              try {
                await AuthService.linkWithEmail(emailC.text, passC.text);
                Navigator.pop(context);
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email успешно привязан!')));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
              }
            },
            child: const Text('Связать'),
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
            child: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: _txtColor)),
          ),
          if (trailing != null) ...[
            trailing,
            const SizedBox(width: 8),
          ],
          Icon(Icons.arrow_forward_ios_rounded, color: _subtxtColor.withValues(alpha: 0.5), size: 14),
        ],
      ),
    ),
  );

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
            _typeCard('Личный', 'Для продажи личных вещей. Бесплатно. Простой профиль.', Icons.person_rounded),
            const SizedBox(height: 16),
            _typeCard('Бизнес', 'Для магазинов и услуг. Бейдж "Магазин". Безлимит. Доверие клиентов.', Icons.store_rounded),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _typeCard(String type, String desc, IconData icon) {
    final isSelected = _accountType == type;
    return GestureDetector(
      onTap: () {
        setState(() => _accountType = type);
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
                  Text(type, style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16, color: _txtColor)),
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
    final phoneC = TextEditingController(text: '+7 ');
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
          Text(_t('change_phone'), style: GoogleFonts.inter(color: _txtColor, fontWeight: FontWeight.w900, fontSize: 20)),
          const SizedBox(height: 8),
          Text('Для изменения номера необходимо подтвердить его через Telegram-бота.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: _subtxtColor, fontSize: 13, height: 1.5)),
          const SizedBox(height: 24),

          if (!codeSent) ...[
            _buildDialogField('Новый номер телефона', phoneC, Icons.phone),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: () {
                  if (phoneC.text.trim().length < 10) return;
                  tgCode = (DateTime.now().millisecondsSinceEpoch % 90000 + 10000).toString(); // 5 digits
                  setS(() => codeSent = true);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Код отправлен в Telegram: $tgCode (демо)'), backgroundColor: const Color(0xFF0088CC)));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                child: Text('Отправить код', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
              ),
            ),
          ],
          if (codeSent) ...[
            Text('Код отправлен на номер\n${phoneC.text}',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: _primaryColor, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 16),
            _buildDialogField('Код из Telegram', codeC, Icons.pin_rounded),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: () {
                  if (codeC.text.trim() == tgCode) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Номер успешно изменен!'), backgroundColor: Colors.green));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Неверный код!'), backgroundColor: Colors.red));
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                child: Text('Подтвердить', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
              ),
            ),
          ],
          const SizedBox(height: 30),
        ]),
      )),
    );
  }

  Widget _buildDialogField(String hint, TextEditingController controller, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _subtxtColor.withValues(alpha: 0.2)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.phone,
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

  Widget _buildThemeSection() => Padding(
    padding: const EdgeInsets.only(left: 4, right: 4, bottom: 20),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: widget.themes.keys.map((themeName) {
        final isSelected = _currentTheme == themeName;
        final primary = widget.themes[themeName]?['primary'] ?? _primaryColor;
        
        return GestureDetector(
          onTap: () {
            setState(() => _currentTheme = themeName);
            widget.onThemeChanged(themeName);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? primary.withValues(alpha: 0.1) : _surfaceColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: isSelected ? primary : _subtxtColor.withValues(alpha: 0.1), width: 2),
            ),
            child: Column(
              children: [
                Icon(
                  themeName == 'Light' ? Icons.wb_sunny_rounded : Icons.nightlight_round_outlined,
                  color: isSelected ? primary : _subtxtColor,
                  size: 32,
                ),
                const SizedBox(height: 8),
                Text(
                  themeName == 'Light' ? 'Светлая' : 'Темная',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, color: isSelected ? primary : _subtxtColor),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    ),
  );

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
            listToDisplay = ['Чунджа'] + KazakhstanLocations.hierarchy.keys.toList();
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
                        searchCity.isNotEmpty ? 'Результаты поиска' : (selectedParent ?? 'Выберите локацию'), 
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
                      hintText: 'Введите название города...',
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
                    title: Text('Определить автоматически', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: _primaryColor, fontSize: 15)), 
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
                        title: Text(item, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15, color: _txtColor)),
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
