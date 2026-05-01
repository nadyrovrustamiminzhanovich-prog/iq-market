import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:line_icons/line_icons.dart';
import 'package:iqmarket/providers/taxi_provider.dart';
import 'package:iqmarket/theme/taxi_theme.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:iqmarket/services/user_service.dart';
import 'package:iqmarket/services/auth_service.dart';

class TaxiAuthForm extends StatefulWidget {
  final TaxiProvider provider;
  final TaxiTheme t;
  final VoidCallback onSuccess;

  const TaxiAuthForm({
    super.key,
    required this.provider,
    required this.t,
    required this.onSuccess,
  });

  @override
  State<TaxiAuthForm> createState() => _TaxiAuthFormState();
}

class _TaxiAuthFormState extends State<TaxiAuthForm> {
  bool _isRegister = false;
  bool _isLoading = false;
  bool _obscure1 = true;
  bool _obscure2 = true;

  final _emailC = TextEditingController();
  final _passC = TextEditingController();
  final _pass2C = TextEditingController();

  TaxiProvider get p => widget.provider;
  TaxiTheme get t => widget.t;

  @override
  void dispose() {
    _emailC.dispose();
    _passC.dispose();
    _pass2C.dispose();
    super.dispose();
  }

  bool _isValidEmail(String e) => RegExp(r'^[\w\-\.]+@[\w\-]+(\.[\w\-]+)+$').hasMatch(e);

  void _snack(String msg, Color c) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg, style: GoogleFonts.inter(fontWeight: FontWeight.w600)), backgroundColor: c, duration: const Duration(seconds: 3)));

  Future<void> _handleEmailAction() async {
    final email = _emailC.text.trim();
    final pass = _passC.text;
    final pass2 = _pass2C.text;

    if (email.isEmpty || pass.isEmpty) {
      _snack(p.translate('err_empty'), Colors.orange);
      return;
    }
    if (!_isValidEmail(email)) {
      _snack(p.translate('err_email'), Colors.orange);
      return;
    }
    if (_isRegister && pass != pass2) {
      _snack(p.translate('err_pass_match'), Colors.orange);
      return;
    }
    if (_isRegister && pass.length < 6) {
      _snack(p.translate('err_pass_short'), Colors.orange);
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (_isRegister) {
        await AuthService.registerWithEmail(email, pass, 'Taxi User');
        _snack(p.translate('success_reg'), Colors.green);
      } else {
        await AuthService.loginWithEmail(email, pass);
      }
      widget.onSuccess();
    } on FirebaseAuthException catch (e) {
      _snack(e.message ?? e.code, Colors.redAccent);
    } catch (e) {
      _snack('Error: $e', Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _doGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final uc = await AuthService.signInWithGoogle();
      if (uc != null) {
        widget.onSuccess();
      }
    } catch (e) {
      _snack('Google error: $e', Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _doAppleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final uc = await AuthService.signInWithApple();
      if (uc != null) {
        widget.onSuccess();
      }
    } catch (e) {
      _snack('Apple error: $e', Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildToggle(),
        const SizedBox(height: 30),
        _field(_emailC, p.translate('email'), LineIcons.envelope, false),
        const SizedBox(height: 16),
        _field(_passC, p.translate('pass'), LineIcons.lock, true, 
          obscure: _obscure1, 
          onToggle: () => setState(() => _obscure1 = !_obscure1)),
        if (_isRegister) ...[
          const SizedBox(height: 16),
          _field(_pass2C, p.translate('pass_confirm'), LineIcons.lock, true, 
            obscure: _obscure2, 
            onToggle: () => setState(() => _obscure2 = !_obscure2)),
        ],
        const SizedBox(height: 24),
        _mainButton(),
        const SizedBox(height: 30),
        _divider(),
        const SizedBox(height: 30),
        _socialRow(),
      ],
    );
  }

  Widget _buildToggle() => Container(
    height: 50,
    decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(16)),
    child: Row(
      children: [
        _toggleItem(p.translate('login'), !_isRegister),
        _toggleItem(p.translate('register'), _isRegister),
      ],
    ),
  );

  Widget _toggleItem(String label, bool active) => Expanded(
    child: GestureDetector(
      onTap: () => setState(() => _isRegister = !active),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? t.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(label, style: GoogleFonts.inter(
          color: active ? Colors.white : t.subtext,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        )),
      ),
    ),
  );

  Widget _field(TextEditingController c, String h, IconData icon, bool isPass, {bool obscure = false, VoidCallback? onToggle}) => Container(
    decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: t.border)),
    child: TextField(
      controller: c,
      obscureText: obscure,
      style: GoogleFonts.inter(color: t.text, fontSize: 15, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: h,
        hintStyle: GoogleFonts.inter(color: t.subtext, fontSize: 14),
        prefixIcon: Icon(icon, color: t.primary, size: 20),
        suffixIcon: isPass ? IconButton(icon: Icon(obscure ? LineIcons.eyeSlash : LineIcons.eye, color: t.subtext), onPressed: onToggle) : null,
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    ),
  );

  Widget _mainButton() => SizedBox(
    width: double.infinity,
    height: 60,
    child: ElevatedButton(
      onPressed: _isLoading ? null : _handleEmailAction,
      style: ElevatedButton.styleFrom(
        backgroundColor: t.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 0,
      ),
      child: _isLoading 
        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
        : Text(_isRegister ? p.translate('register_btn') : p.translate('login_btn'), style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
    ),
  );

  Widget _divider() => Row(
    children: [
      Expanded(child: Divider(color: t.border)),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(p.translate('or_with'), style: GoogleFonts.inter(color: t.subtext, fontSize: 12, fontWeight: FontWeight.w600))),
      Expanded(child: Divider(color: t.border)),
    ],
  );

  Widget _socialRow() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      _socialBtn('https://cdn-icons-png.flaticon.com/512/300/300221.png', _doGoogleSignIn),
      const SizedBox(width: 20),
      _socialBtn('https://cdn-icons-png.flaticon.com/512/0/747.png', _doAppleSignIn),
    ],
  );

  Widget _socialBtn(String url, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 60, height: 60,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: t.card, shape: BoxShape.circle, border: Border.all(color: t.border)),
      child: Image.network(url),
    ),
  );
}
