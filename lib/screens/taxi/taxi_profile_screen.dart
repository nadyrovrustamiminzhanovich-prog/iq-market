import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iqmarket/theme/taxi_theme.dart';
import 'package:provider/provider.dart';
import 'package:iqmarket/providers/taxi_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

class TaxiProfileScreen extends StatefulWidget {
  final TaxiTheme t;
  const TaxiProfileScreen({super.key, required this.t});

  @override
  State<TaxiProfileScreen> createState() => _TaxiProfileScreenState();
}

class _TaxiProfileScreenState extends State<TaxiProfileScreen> {
  late TextEditingController _fnC;
  late TextEditingController _lnC;
  late TextEditingController _phC;
  final _phoneMask = MaskTextInputFormatter(
    mask: '+7 (###) ###-##-##',
    filter: {"#": RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<TaxiProvider>(context, listen: false);
    _fnC = TextEditingController(text: provider.firstName);
    _lnC = TextEditingController(text: provider.lastName);
    
    // Sanitize phone on startup: replace 8 with 7, add +7 if missing, and format with mask
    String rawPhone = provider.phone;
    String formattedPhone = rawPhone;
    if (rawPhone.isNotEmpty) {
      String digits = rawPhone.replaceAll(RegExp(r'\D'), '');
      if (digits.startsWith('8') && digits.length == 11) {
        digits = '7' + digits.substring(1);
      }
      if (digits.length == 10) {
        digits = '7' + digits;
      }
      if (digits.startsWith('7')) {
        formattedPhone = _phoneMask.maskText(digits);
      }
    }
    _phC = TextEditingController(text: formattedPhone);
  }

  @override
  void dispose() {
    _fnC.dispose();
    _lnC.dispose();
    _phC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TaxiProvider>(context);
    final tr = provider.translate;
    final imageFile = provider.profileImage;

    return Scaffold(
      backgroundColor: widget.t.bg,
      appBar: AppBar(
        backgroundColor: widget.t.card,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: widget.t.text),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(tr('profile'), style: GoogleFonts.inter(color: widget.t.text)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Stack(
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: widget.t.card2,
                    shape: BoxShape.circle,
                    border: Border.all(color: widget.t.accent, width: 3),
                  ),
                  child: ClipOval(
                    child: imageFile != null
                        ? Image.file(imageFile, fit: BoxFit.cover)
                        : Icon(Icons.person, size: 60, color: widget.t.sub),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () => _showPhotoPicker(provider),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: widget.t.accent,
                        shape: BoxShape.circle,
                        border: Border.all(color: widget.t.bg, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                    ),
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 40),
          _pf(tr('fname'), _fnC),
          const SizedBox(height: 16),
          _pf(tr('lname'), _lnC),
          const SizedBox(height: 16),
          _pf(tr('phone'), _phC),
          const SizedBox(height: 40),
          GestureDetector(
            onTap: () {
              provider.updateProfile(_fnC.text, _lnC.text, _phC.text);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved Successfully! ✅')));
              Navigator.pop(context);
            },
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                color: widget.t.accent,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(color: widget.t.accent.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 5))
                ],
              ),
              child: Center(
                child: Text(
                  tr('save'),
                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _pf(String l, TextEditingController c) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(l, style: GoogleFonts.inter(color: widget.t.sub, fontSize: 12, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: widget.t.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: widget.t.border),
        ),
        child: TextField(
          controller: c,
          inputFormatters: c == _phC ? [_phoneMask] : null,
          keyboardType: c == _phC ? TextInputType.phone : TextInputType.text,
          style: GoogleFonts.inter(color: widget.t.text, fontWeight: FontWeight.w600),
          decoration: const InputDecoration(border: InputBorder.none),
        ),
      )
    ],
  );

  void _showPhotoPicker(TaxiProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: widget.t.bg, 
          borderRadius: const BorderRadius.vertical(top: Radius.circular(35))
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: widget.t.sub.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 25),
            Text(
              provider.translate('profile_photo'), 
              style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: widget.t.text)
            ),
            const SizedBox(height: 10),
            Text(
              'Выберите способ загрузки фото', 
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: widget.t.sub, fontSize: 13, fontWeight: FontWeight.w500)
            ),
            const SizedBox(height: 30),
            
            _photoOption(
              icon: Icons.camera_alt_rounded,
              title: provider.translate('camera'),
              sub: 'Сделать снимок сейчас',
              color: widget.t.accent,
              onTap: () {
                Navigator.pop(context);
                _pickImage(provider, ImageSource.camera);
              },
            ),
            const SizedBox(height: 15),
            _photoOption(
              icon: Icons.photo_library_rounded,
              title: provider.translate('gallery'),
              sub: 'Выбрать из медиатеки',
              color: widget.t.accent,
              onTap: () {
                Navigator.pop(context);
                _pickImage(provider, ImageSource.gallery);
              },
            ),
            const SizedBox(height: 25),
          ],
        ),
      ),
    );
  }

  Widget _photoOption({required IconData icon, required String title, required String sub, required Color color, required VoidCallback onTap}) => GestureDetector(
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
                Text(title, style: GoogleFonts.inter(color: color, fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 2),
                Text(sub, style: GoogleFonts.inter(color: color.withValues(alpha: 0.6), fontWeight: FontWeight.w500, fontSize: 11)),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded, size: 14, color: color.withValues(alpha: 0.3)),
        ],
      ),
    ),
  );

  Future<void> _pickImage(TaxiProvider provider, ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(source: source, imageQuality: 50);
      if (pickedFile != null) {
        provider.setProfileImage(File(pickedFile.path));
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }
}
