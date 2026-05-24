import 'dart:io';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:iqmarket/data/legal_texts.dart';

import 'package:iqmarket/services/storage_service.dart';
import 'package:provider/provider.dart';
import 'package:iqmarket/providers/taxi_provider.dart';
import 'package:iqmarket/screens/home/home_screen.dart';
import 'package:iqmarket/translations/login_strings.dart';
import 'package:iqmarket/widgets/auth/auth_components.dart';
import 'package:iqmarket/services/user_service.dart';
import 'package:iqmarket/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  final String lang;
  const LoginScreen({super.key, this.lang = 'Русский'});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLogin = true;
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String _generatedCode = "";
  bool _isLoading = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;


  String? _tgSessionToken;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _tgSessionSub;


  late final TapGestureRecognizer _tosRecognizer;
  late final TapGestureRecognizer _privacyRecognizer;

  @override
  void initState() {
    super.initState();
    _tosRecognizer = TapGestureRecognizer()..onTap = () => _showLegalText(_t('tos_title'));
    _privacyRecognizer = TapGestureRecognizer()..onTap = () => _showLegalText(_t('privacy_title'));
  }

  // ===================== TRANSLATIONS =====================
  String _t(String key) {
    return loginStrings[key]?[widget.lang] ?? loginStrings[key]?['Русский'] ?? key;
  }

  // ===================== FIREBASE ERROR HANDLER =====================
  String _firebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use': return _t('err_email_used');
      case 'user-not-found': return _t('err_user_not_found');
      case 'wrong-password': return _t('err_wrong_pwd');
      case 'invalid-credential': return _t('err_wrong_pwd');
      case 'weak-password': return _t('err_weak_pwd');
      case 'invalid-email': return _t('err_invalid_email');
      case 'too-many-requests': return _t('err_too_many');
      default: return e.message ?? e.code;
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: const Color(0xFF10B981), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
  }

  // ===================== LEGAL TEXT =====================
  void _showLegalText(String title) {
    String content = LegalTexts.termsOfService;
    if (title.contains('конфиденц') || title.contains('Құпия') || title.contains('Мәхпий')) content = LegalTexts.privacyPolicy;
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (c) => Container(
      height: MediaQuery.of(context).size.height * 0.85, padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      child: Column(children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(10))),
        const SizedBox(height: 20),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900), textAlign: TextAlign.center),
        const SizedBox(height: 20),
        Expanded(child: SingleChildScrollView(physics: const BouncingScrollPhysics(), child: Text(content, style: const TextStyle(color: Colors.black87, height: 1.6, fontSize: 13)))),
      ]),
    ));
  }

  @override
  void dispose() {
    _tgSessionSub?.cancel();
    _nameController.dispose(); _emailController.dispose();
    _passwordController.dispose(); _confirmPasswordController.dispose();
    _tosRecognizer.dispose(); _privacyRecognizer.dispose();
    super.dispose();
  }

  // ============================================================
  //                    FIREBASE AUTH METHODS
  // ============================================================

  Future<void> _handleRegister() async {
    if (_isLoading) return;
    if (_nameController.text.trim().isEmpty) { _showError(_t('err_name')); return; }
    if (_emailController.text.trim().isEmpty || !_emailController.text.contains('@')) { _showError(_t('err_invalid_email')); return; }
    if (_passwordController.text.length < 6) { _showError(_t('err_weak_pwd')); return; }
    if (_passwordController.text != _confirmPasswordController.text) { _showError(_t('err_pwd_match')); return; }

    setState(() => _isLoading = true);
    try {
      final userCred = await AuthService.registerWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
        _nameController.text.trim(),
      );
      
      _showSuccess(_t('success_reg') + ". Проверьте почту для подтверждения!");
      
      // We don't log them in immediately if we want strict verification
      // But for better UX, we can log them in and show "Not Verified" badge
      await _finalizeLogin(userCred.user?.displayName ?? _nameController.text.trim(), email: _emailController.text.trim());
    } on FirebaseAuthException catch (e) {
      _showError(_firebaseError(e));
    } catch (e) {
      _showError(_t('err_general') + ': $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLogin() async {
    if (_isLoading) return;
    if (_emailController.text.trim().isEmpty) { _showError(_t('err_invalid_email')); return; }
    if (_passwordController.text.isEmpty) { _showError(_t('err_wrong_pwd')); return; }

    setState(() => _isLoading = true);
    try {
      final userCred = await AuthService.loginWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );
      
      final user = userCred.user;
      if (user != null && !user.emailVerified) {
        _showError("Ваш Email еще не подтвержден. Пожалуйста, проверьте почту.");
        // We can still let them in, or sign them out
        // await AuthService.signOut();
        // return;
      }

      await _finalizeLogin(user?.displayName ?? _emailController.text.split('@')[0], email: user?.email, photoUrl: user?.photoURL);
    } on FirebaseAuthException catch (e) {
      _showError(_firebaseError(e));
    } catch (e) {
      _showError(_t('err_general') + ': $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleResetPassword(String email) async {
    try {
      await AuthService.resetPassword(email.trim());
      _showSuccess(_t('success_reset'));
    } on FirebaseAuthException catch (e) {
      _showError(_firebaseError(e));
    }
  }

  void _onForgotPassword() {
    final resetEmailC = TextEditingController(text: _emailController.text);
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 25),
            const Icon(Icons.lock_reset_rounded, color: Color(0xFF4A80F0), size: 54),
            const SizedBox(height: 20),
            Text(_t('forgot_pwd_title'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            Text(_t('forgot_pwd_desc'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54, fontSize: 13, height: 1.5)),
            const SizedBox(height: 25),
            AuthField(hint: _t('email_hint'), icon: Icons.email_outlined, controller: resetEmailC, keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 25),
            SizedBox(width: double.infinity, height: 56, child: ElevatedButton(
              onPressed: () {
                if (resetEmailC.text.contains('@')) {
                  Navigator.pop(context);
                  _handleResetPassword(resetEmailC.text);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A80F0), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: Text(_t('send_link'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.white)),
            )),
            const SizedBox(height: 15),
          ]),
        ),
      ),
    );
  }

  // ===================== GOOGLE (v7) =====================
  Future<void> _handleGoogleSignIn() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final uc = await AuthService.signInWithGoogle();
      if (uc != null) {
        await _finalizeLogin(uc.user?.displayName ?? 'Google User', email: uc.user?.email, photoUrl: uc.user?.photoURL);
      }
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      String errMsg = 'Ошибка входа через Google';
      final errStr = e.toString();
      
      if (errStr.contains('ApiException: 10') || errStr.contains('status code 10')) {
        errMsg = 'Ошибка 10 (Developer Error):\n\nSHA-1 отпечаток этого телефона/компьютера не зарегистрирован в консоли Firebase.\n\nПожалуйста, воспользуйтесь входом через Telegram — он полностью настроен и готов!';
      } else if (errStr.contains('ApiException: 7') || errStr.contains('status code 7') || errStr.contains('network_error')) {
        errMsg = 'Ошибка сети (code 7):\n\nПроверьте соединение с интернетом или подключение к VPN.';
      } else if (errStr.contains('12500')) {
        errMsg = 'Ошибка 12500:\n\nНесоответствие конфигурации сервисов Google Play на этом устройстве.';
      } else if (errStr.contains('sign_in_canceled') || errStr.contains('canceled')) {
        errMsg = 'Вход через Google отменен пользователем.';
      } else {
        errMsg = 'Ошибка Google Sign-In: ${errStr.replaceAll('PlatformException', '')}';
      }
      
      _showError(errMsg);
    } finally { if (mounted) setState(() => _isLoading = false); }
  }

  // ===================== APPLE =====================
  Future<void> _handleAppleSignIn() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final uc = await AuthService.signInWithApple();
      if (uc != null) {
        await _finalizeLogin(uc.user?.displayName ?? 'Apple User', email: uc.user?.email);
      }
    } catch (e) {
      debugPrint('Apple: $e');
      _showError('Ошибка Apple Sign-In');
    } finally { if (mounted) setState(() => _isLoading = false); }
  }

  // ===================== TELEGRAM BOT (Session-based) =====================
  void _handleTelegramLogin() async {
    if (_isLoading) return;
    setState(() { _isLoading = true; });
    try {
      // 1. Create Firestore session + open bot with deep link
      _tgSessionToken = await AuthService.startTelegramSession();

      if (!mounted) return;
      
      bool hasNavigated = false;
      
      // Show waiting sheet
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _tgWaitingSheet(ctx),
      );
      
      // Listen to the session stream in a controlled subscription
      _tgSessionSub?.cancel();
      _tgSessionSub = AuthService.watchTelegramSession(_tgSessionToken!).listen((snap) {
        if (!snap.exists) return;
        final data = snap.data();
        if (data == null) return;
        
        final String? chatId = data['chat_id'];
        final String? otp = data['otp'];
        final String? customToken = data['customToken'];
        
        if (chatId != null && otp != null && otp.isNotEmpty && !hasNavigated) {
          hasNavigated = true;
          _tgSessionSub?.cancel(); // Cancel immediately to prevent duplicate triggers!
          
          if (Navigator.canPop(context)) {
            Navigator.pop(context); // Close waiting sheet
          }
          
          _generatedCode = otp;
          _showOtpDialog(chatId, customToken);
        }
      });
      
    } catch (e) {
      _showError('Ошибка: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _tgWaitingSheet(BuildContext ctx) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(10))),
        const SizedBox(height: 28),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: const Color(0xFF0088CC).withValues(alpha: 0.1), shape: BoxShape.circle),
          child: const Icon(Icons.telegram, color: Color(0xFF0088CC), size: 48),
        ),
        const SizedBox(height: 20),
        const Text('Откройте Telegram', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        const Text(
          'Нажмите кнопку «Старт» в боте @IQ_Taxi_bot.\n\nКод придёт автоматически — вводить Chat ID не нужно.\n\n⏳ Код действителен 5 минут.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black54, fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 24),
        const CircularProgressIndicator(color: Color(0xFF0088CC), strokeWidth: 3),
        const SizedBox(height: 28),
        TextButton(
          onPressed: () { 
            _tgSessionSub?.cancel();
            Navigator.pop(ctx); 
          },
          child: const Text('Отмена', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 10),
      ]),
    );
  }

  void _showOtpDialog(String chatId, String? customToken) {
    final otpCtrl = TextEditingController();
    bool isError = false;
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => StatefulBuilder(builder: (ctx, ss) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(children: [
        const Icon(Icons.telegram, color: Color(0xFF0088CC), size: 28),
        const SizedBox(width: 12),
        Text(_t('tg_otp_title'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_t('tg_otp_desc'), style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        const SizedBox(height: 10),
        const Text('⏳ Код действителен 5 минут', style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        TextField(controller: otpCtrl, keyboardType: TextInputType.number, textAlign: TextAlign.center, maxLength: 6, style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 8, color: isError ? Colors.red : Colors.black), decoration: InputDecoration(counterText: '', hintText: '••••••', hintStyle: TextStyle(color: Colors.grey[300], fontSize: 32), border: InputBorder.none)),
        if (isError) Text('❌ Неверный код. Попробуйте еще раз', style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(_t('cancel'), style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.bold))),
        ElevatedButton(
          onPressed: () async {
            if (otpCtrl.text == _generatedCode) {
              Navigator.pop(context);
              final bool isTokenValid = customToken != null && customToken.split('.').length == 3;
              if (isTokenValid) {
                setState(() => _isLoading = true);
                try {
                  // 🔒 X10 SECURITY: Sign in securely to Firebase Auth
                  final userCred = await FirebaseAuth.instance.signInWithCustomToken(customToken);
                  await _finalizeLogin(userCred.user?.displayName ?? 'Telegram User', isVerified: true, accountType: 'driver');
                } catch (e) {
                  _showError('Ошибка авторизации Firebase: $e');
                } finally {
                  setState(() => _isLoading = false);
                }
              } else {
                // 🛡️ X10 SECURITY: Анонимный вход полностью удален.
                // При ошибке генерации токена выводим понятное сообщение об ошибке.
                _showError('Не удалось создать защищенный токен авторизации. Пожалуйста, попробуйте снова или обратитесь в поддержку.');
              }
            } else {
              ss(() { isError = true; otpCtrl.clear(); });
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0088CC), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
          child: Text(_t('confirm'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
        ),
      ],
    )));
  }

  // ===================== FINALIZE =====================
  Future<void> _finalizeLogin(String name, {String? email, String? photoUrl, bool isVerified = false, String? accountType}) async {
    // 1. Сохраняем в Firebase Firestore
    await UserService.syncUserAfterLogin(
      name: name,
      email: email,
      photoUrl: photoUrl,
      isVerified: isVerified,
      accountType: accountType,
    );
    
    // 2. Локальное сохранение
    StorageService.saveProfile(name, photoUrl, false, accountType ?? 'Личный', isVerified: isVerified);
    if (email != null) StorageService.setString('user_email', email);
    StorageService.setBool('taxi_logged_in', true);
    
    if (mounted) {
      Provider.of<TaxiProvider>(context, listen: false).setLoginStatus(true);
      Provider.of<TaxiProvider>(context, listen: false).loadPreferences();
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => IQMarketHome()));
    }
  }

  // ===================== BUILD =====================
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FB),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        body: Stack(children: [
        SafeArea(child: SingleChildScrollView(physics: const BouncingScrollPhysics(), padding: const EdgeInsets.symmetric(horizontal: 24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 10),
          Text(_t('welcome'), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF1A1D1E), letterSpacing: -0.5)),
          const SizedBox(height: 8),
          AnimatedSwitcher(duration: const Duration(milliseconds: 200), child: Text(_isLogin ? _t('sub_login') : _t('sub_reg'), key: ValueKey(_isLogin), style: const TextStyle(fontSize: 16, color: Colors.black54, fontWeight: FontWeight.w600))),
          const SizedBox(height: 35),

          _buildToggle(),
          const SizedBox(height: 35),

          AnimatedCrossFade(duration: const Duration(milliseconds: 300), crossFadeState: _isLogin ? CrossFadeState.showFirst : CrossFadeState.showSecond, firstChild: const SizedBox.shrink(), secondChild: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _label(_t('name_label')), const SizedBox(height: 8),
            AuthField(hint: _t('name_hint'), icon: Icons.person_outline_rounded, controller: _nameController),
            const SizedBox(height: 20),
          ])),

          _label(_t('email_label')), const SizedBox(height: 8),
          AuthField(hint: _t('email_hint'), icon: Icons.email_outlined, controller: _emailController, keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 20),

          _label(_t('pwd_label')), const SizedBox(height: 8),
          AuthField(hint: _t('pwd_hint'), icon: Icons.lock_outline_rounded, controller: _passwordController, isPassword: true, showToggle: true, isVisible: _showPassword, onToggle: () => setState(() => _showPassword = !_showPassword)),

          AnimatedCrossFade(duration: const Duration(milliseconds: 300), crossFadeState: _isLogin ? CrossFadeState.showFirst : CrossFadeState.showSecond, firstChild: const SizedBox.shrink(), secondChild: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 20),
            _label(_t('confirm_label')), const SizedBox(height: 8),
            AuthField(hint: _t('confirm_hint'), icon: Icons.lock_outline_rounded, controller: _confirmPasswordController, isPassword: true, showToggle: true, isVisible: _showConfirmPassword, onToggle: () => setState(() => _showConfirmPassword = !_showConfirmPassword)),
          ])),

          if (_isLogin) Align(alignment: Alignment.centerRight, child: TextButton(onPressed: _onForgotPassword, child: Text(_t('forgot_pwd'), style: const TextStyle(color: Color(0xFF4A80F0), fontWeight: FontWeight.w800, fontSize: 14)))),
          const SizedBox(height: 25),

          AuthMainButton(label: _isLogin ? _t('login_btn') : _t('reg_btn'), onPressed: _isLogin ? _handleLogin : _handleRegister),

          if (!_isLogin) Padding(padding: const EdgeInsets.only(top: 20), child: Text.rich(TextSpan(text: _t('tos_text'), style: const TextStyle(color: Colors.black54, fontSize: 11, fontWeight: FontWeight.w500, height: 1.4), children: [
            TextSpan(text: _t('tos_link'), style: const TextStyle(color: Color(0xFF4A80F0), fontWeight: FontWeight.w600), recognizer: _tosRecognizer),
            TextSpan(text: _t('tos_and')),
            TextSpan(text: _t('privacy_link'), style: const TextStyle(color: Color(0xFF4A80F0), fontWeight: FontWeight.w600), recognizer: _privacyRecognizer),
          ]), textAlign: TextAlign.center)),
          const SizedBox(height: 30),

          Row(children: [
            Expanded(child: Divider(color: Colors.grey[200], thickness: 1.5)),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(_t('or_with'), style: const TextStyle(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.bold))),
            Expanded(child: Divider(color: Colors.grey[200], thickness: 1.5))
          ]),
          const SizedBox(height: 25),

          // --- Premium Social Buttons ---
          AuthSocialLongButton(
            label: 'Продолжить с Mail.ru',
            icon: Image.network('https://img.icons8.com/color/96/mailru.png', width: 24),
            onTap: () {
               // Scroll to top or focus email field? 
               // For now, just keep the fields below.
            },
          ),
 
          AuthSocialLongButton(
            label: 'Продолжить с Google',
            icon: Image.network('https://img.icons8.com/color/96/google-logo.png', width: 24),
            onTap: _handleGoogleSignIn,
          ),

          if (Platform.isIOS)
            AuthSocialLongButton(
              label: 'Продолжить с Apple',
              icon: const Icon(Icons.apple, color: Colors.white, size: 28),
              onTap: _handleAppleSignIn,
              isDark: true,
            ),

          AuthSocialLongButton(
            label: 'Продолжить с Telegram',
            icon: Image.network('https://cdn-icons-png.flaticon.com/512/2111/2111646.png', width: 24),
            onTap: _handleTelegramLogin,
            color: const Color(0xFF0088CC),
            textColor: Colors.white,
          ),

          const SizedBox(height: 12),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.1)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified_user_rounded, color: Color(0xFF10B981), size: 18),
                      const SizedBox(width: 10),
                      const Text(
                        'Верификация через Telegram',
                        style: TextStyle(color: Color(0xFF10B981), fontSize: 13, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Это дает статус «Проверен» ✅, возможность заказать такси и стать водителем в IQ-Taxi.',
                    style: TextStyle(color: Colors.black54, fontSize: 11, fontWeight: FontWeight.w500, height: 1.4),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 30),
          Center(child: GestureDetector(onTap: () => setState(() { _isLogin = !_isLogin; _passwordController.clear(); _confirmPasswordController.clear(); }), child: RichText(text: TextSpan(text: _isLogin ? _t('no_acc') : _t('have_acc'), style: const TextStyle(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w600), children: [TextSpan(text: _isLogin ? _t('reg_tab') : _t('login_tab'), style: const TextStyle(color: Color(0xFF4A80F0), fontWeight: FontWeight.w900))])))),
          const SizedBox(height: 20),
          Center(child: TextButton(onPressed: () => Navigator.pop(context), child: Text(_t('guest_btn'), style: const TextStyle(color: Color(0xFF64748B), fontSize: 14, fontWeight: FontWeight.w700, decoration: TextDecoration.underline)))),
          const SizedBox(height: 40),
        ]))),
        if (_isLoading) Container(color: Colors.black.withValues(alpha: 0.3), child: const Center(child: CircularProgressIndicator(color: Color(0xFF4A80F0), strokeWidth: 3))),
          ],
        ),
      ),
    );
  }

  // ===================== UI WIDGETS =====================
  Widget _buildToggle() => Container(height: 58, padding: const EdgeInsets.all(5), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 20, offset: const Offset(0, 10))]), child: Stack(children: [
    AnimatedAlign(duration: const Duration(milliseconds: 300), curve: Curves.easeInOutBack, alignment: _isLogin ? Alignment.centerLeft : Alignment.centerRight, child: Container(width: (MediaQuery.of(context).size.width - 58) / 2, decoration: BoxDecoration(color: const Color(0xFF4A80F0), borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: const Color(0xFF4A80F0).withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))]))),
    Row(children: [_togItem(_t('login_tab'), true), _togItem(_t('reg_tab'), false)]),
  ]));

  Widget _togItem(String t, bool s) => Expanded(child: GestureDetector(onTap: () => setState(() => _isLogin = s), behavior: HitTestBehavior.opaque, child: Center(child: Text(t, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _isLogin == s ? Colors.white : Colors.black54)))));
  Widget _label(String t) => Text(t, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF1A1D1E)));

}