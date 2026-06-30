import 'dart:io';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

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
import 'package:iqmarket/services/telegram_bot_service.dart';
import 'package:iqmarket/services/network_service.dart';
import 'package:url_launcher/url_launcher.dart';

class LoginScreen extends StatefulWidget {
  final String lang;
  final bool autoStartTelegramLogin;
  const LoginScreen({
    super.key,
    this.lang = 'Русский',
    this.autoStartTelegramLogin = false,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with WidgetsBindingObserver {
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
  String? _tgBotUrl;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _tgSessionSub;
  Timer? _tgCountdownTimer;
  int _tgCountdown = 4;
  StateSetter? _tgSheetStateSetter;


  late final TapGestureRecognizer _tosRecognizer;
  late final TapGestureRecognizer _privacyRecognizer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tosRecognizer = TapGestureRecognizer()..onTap = () => _showLegalText(_t('tos_title'));
    _privacyRecognizer = TapGestureRecognizer()..onTap = () => _showLegalText(_t('privacy_title'));
    if (widget.autoStartTelegramLogin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleTelegramLogin();
      });
    }
  }

  // ===================== TRANSLATIONS =====================
  String _t(String key) {
    return loginStrings[key]?[widget.lang] ?? loginStrings[key]?['Русский'] ?? key;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_tgSessionToken != null && !_isLoading) {
        _checkTelegramSessionManually(isAutoCheck: true);
      }
    }
  }

  Future<bool> _ensureOnline() async {
    if (await NetworkService.isOffline()) {
      _showError(_t('err_offline'));
      return false;
    }
    return true;
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
      case 'network-request-failed': return _t('err_network_failed');
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
    WidgetsBinding.instance.removeObserver(this);
    _tgSessionSub?.cancel();
    _tgCountdownTimer?.cancel();
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
    if (!await _ensureOnline()) return;
    if (_nameController.text.trim().isEmpty) { _showError(_t('err_name')); return; }
    if (_emailController.text.trim().isEmpty || !_emailController.text.contains('@')) { _showError(_t('err_invalid_email')); return; }
    if (_passwordController.text.length < 6) { _showError(_t('err_weak_pwd')); return; }
    if (_passwordController.text != _confirmPasswordController.text) { _showError(_t('err_pwd_match')); return; }

    setState(() => _isLoading = true);
    try {
      await AuthService.registerWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
        _nameController.text.trim(),
      ).timeout(const Duration(seconds: 25));
      
      _showSuccess(_t('success_reg') + ". Проверьте почту для подтверждения!");
      
      // Строгая верификация: выходим из сессии, не пускаем внутрь
      await AuthService.signOut();
      
      if (!mounted) return;
      // Автоматически переключаем на вкладку "Вход"
      setState(() => _isLogin = true);
      _passwordController.clear();
      _confirmPasswordController.clear();
    } on TimeoutException {
      _showError(_t('err_timeout'));
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
    if (!await _ensureOnline()) return;
    if (_emailController.text.trim().isEmpty) { _showError(_t('err_invalid_email')); return; }
    if (_passwordController.text.isEmpty) { _showError(_t('err_wrong_pwd')); return; }

    setState(() => _isLoading = true);
    try {
      final userCred = await AuthService.loginWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      ).timeout(const Duration(seconds: 25));
      
      final user = userCred.user;
      if (user != null && !user.emailVerified) {
        _showError(_t('email_not_verified'));
        await AuthService.signOut();
        return; // Жёстко блокируем вход!
      }

      await _finalizeLogin(
        user?.displayName ?? _emailController.text.split('@')[0],
        email: user?.email,
        photoUrl: user?.photoURL,
        isVerified: false,
      );
    } on TimeoutException {
      _showError(_t('err_timeout'));
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
            Text(_t('forgot_title'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            Text(_t('forgot_desc'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54, fontSize: 13, height: 1.5)),
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
              child: Text(_t('forgot_send'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.white)),
            )),
            const SizedBox(height: 15),
          ]),
        ),
      ),
    ).then((_) {
      // ✅ Освобождаем контроллер после закрытия шторки
      resetEmailC.dispose();
    });
  }

  // ===================== GOOGLE (v7) =====================
  Future<void> _handleGoogleSignIn() async {
    if (_isLoading) return;
    if (!await _ensureOnline()) return;
    setState(() => _isLoading = true);
    try {
      final uc = await AuthService.signInWithGoogle().timeout(const Duration(seconds: 25));
      if (uc != null) {
        await _finalizeLogin(
          uc.user?.displayName ?? 'Google User',
          email: uc.user?.email,
          photoUrl: uc.user?.photoURL,
          isVerified: false,
        );
      }
    } on TimeoutException {
      _showError(_t('err_timeout'));
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
        await _finalizeLogin(
          uc.user?.displayName ?? 'Apple User',
          email: uc.user?.email,
          isVerified: false,
        );
      }
    } catch (e) {
      debugPrint('Apple: $e');
      _showError('Ошибка Apple Sign-In');
    } finally { if (mounted) setState(() => _isLoading = false); }
  }

  // ===================== TELEGRAM BOT (Session-based) =====================
  void _handleTelegramLogin() async {
    if (_isLoading) return;
    if (!await _ensureOnline()) return;
    setState(() { _isLoading = true; });
    try {
      // 1. Create Firestore session (WITHOUT auto-launching Telegram)
      _tgSessionToken = await AuthService.startTelegramSession().timeout(const Duration(seconds: 25));
      _tgBotUrl = TelegramBotService.buildBotUrl(_tgSessionToken!);

      if (!mounted) return;

      bool hasNavigated = false;

      // Show waiting sheet with countdown
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _tgWaitingSheet(ctx),
      );

      // Listen to the session stream
      _tgSessionSub?.cancel();
      _tgSessionSub = AuthService.watchTelegramSession(_tgSessionToken!).listen((snap) {
        if (!snap.exists) return;
        final data = snap.data();
        if (data == null) return;

        final String? chatId = data['chat_id'];
        final String? otp = data['otp'];
        final String? customToken = data['customToken'];

        // Chat ID and OTP are set — show OTP dialog
        if (chatId != null && otp != null && otp.isNotEmpty && !hasNavigated) {
          hasNavigated = true;
          _tgSessionSub?.cancel();
          _tgCountdownTimer?.cancel();

          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }

          _generatedCode = otp;
          _showOtpDialog(chatId, customToken);
        }
      }, onError: (err) {
        debugPrint('watchTelegramSession error: $err');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка сессии авторизации: $err'), backgroundColor: Colors.redAccent),
          );
        }
      });

    } on TimeoutException {
      _showError(_t('err_timeout'));
    } catch (e) {
      _showError('Ошибка: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkTelegramSessionManually({bool isAutoCheck = false}) async {
    if (_tgSessionToken == null) return;

    if (!isAutoCheck) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('checking_auth')),
          duration: const Duration(seconds: 1),
        ),
      );
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection('tg_auth_sessions')
          .doc(_tgSessionToken)
          .get()
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;
      if (!snap.exists) return;
      final data = snap.data();
      if (data == null) return;

      final String? chatId = data['chat_id'];
      final String? otp = data['otp'];
      final String? customToken = data['customToken'];

      if (chatId != null && otp != null && otp.isNotEmpty) {
        _tgSessionSub?.cancel();
        _tgCountdownTimer?.cancel();

        if (Navigator.canPop(context)) Navigator.pop(context);

        _generatedCode = otp;
        _showOtpDialog(chatId, customToken);
      } else {
        if (!isAutoCheck) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_t('bot_no_contact')),
              duration: const Duration(seconds: 3),
              backgroundColor: Colors.orangeAccent,
            ),
          );
        }
      }
    } on TimeoutException {
      debugPrint('[TG manual check] Timeout');
      if (!isAutoCheck && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_t('err_timeout')),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      debugPrint('[TG manual check] Error: $e');
      if (!isAutoCheck && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_t('err_check_failed')),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _openTelegramBot() async {
    if (_tgBotUrl == null) return;
    try {
      final uri = Uri.parse(_tgBotUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Приложение Telegram не установлено'), backgroundColor: Colors.redAccent),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Приложение Telegram не установлено'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Widget _tgWaitingSheet(BuildContext ctx) {
    // Start countdown on first build
    if (_tgCountdownTimer == null || !_tgCountdownTimer!.isActive) {
      _tgCountdown = 4;
      _tgCountdownTimer?.cancel();
      _tgCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) { timer.cancel(); return; }
        if (_tgCountdown <= 0) {
          timer.cancel();
          _openTelegramBot();
          return;
        }
        if (_tgSheetStateSetter != null) {
          _tgSheetStateSetter!(() {
            _tgCountdown--;
          });
        } else {
          _tgCountdown--;
        }
      });
    }

    return StatefulBuilder(
      builder: (ctx, ss) {
        _tgSheetStateSetter = ss;
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 24),

              // Telegram icon with glow
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const RadialGradient(
                    colors: [Color(0xFFD6EEFF), Color(0xFFEBF5FF)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF0088CC).withValues(alpha: 0.18), blurRadius: 24, spreadRadius: 4),
                  ],
                ),
                child: const Icon(Icons.telegram_rounded, color: Color(0xFF0088CC), size: 52),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                _t('tg_verification'),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1A1D1E)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                _t('tg_verification_desc'),
                style: const TextStyle(color: Colors.black45, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),

              // Step-by-step guide
              _tgStep('1', Icons.open_in_new_rounded, _t('tg_step_1_title'), _t('tg_step_1_desc')),
              const SizedBox(height: 14),
              _tgStep('2', Icons.play_circle_outline_rounded, _t('tg_step_2_title'), _t('tg_step_2_desc')),
              const SizedBox(height: 14),
              _tgStep('3', Icons.contact_phone_rounded, _t('tg_step_3_title'), _t('tg_step_3_desc')),
              const SizedBox(height: 14),
              _tgStep('4', Icons.keyboard_rounded, _t('tg_step_4_title'), _t('tg_step_4_desc')),
              const SizedBox(height: 28),

              // Countdown + auto-open button
              // Countdown display — reads from _tgCountdown directly (no stream needed)
              Builder(
                builder: (context) {
                  final remaining = _tgCountdown;
                  return Column(
                    children: [
                      if (remaining > 0)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0088CC).withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFF0088CC).withValues(alpha: 0.15)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.timer_outlined, color: Color(0xFF0088CC), size: 20),
                              const SizedBox(width: 10),
                              Text(
                                _t('opening_tg_in').replaceAll('{sec}', remaining.toString()),
                                style: const TextStyle(color: Color(0xFF0088CC), fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                            ],
                          ),
                        )
                      else
                        GestureDetector(
                          onTap: _openTelegramBot,
                          child: Container(
                            width: double.infinity,
                            height: 52,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0088CC),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [BoxShadow(color: const Color(0xFF0088CC).withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))],
                            ),
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.telegram_rounded, color: Colors.white, size: 22),
                                  const SizedBox(width: 10),
                                  Text(_t('open_tg_btn'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      // Always-visible manual button
                      GestureDetector(
                        onTap: _openTelegramBot,
                        child: Text(
                          _t('open_manually'),
                          style: const TextStyle(color: Color(0xFF0088CC), fontWeight: FontWeight.w700, fontSize: 13, decoration: TextDecoration.underline),
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 20),
              // Waiting indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(color: const Color(0xFF0088CC).withValues(alpha: 0.5), strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Text(_t('waiting_confirm'), style: const TextStyle(color: Colors.black38, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _checkTelegramSessionManually,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(_t('shared_contact_btn'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0088CC).withValues(alpha: 0.1),
                  foregroundColor: const Color(0xFF0088CC),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  _tgSessionSub?.cancel();
                  _tgCountdownTimer?.cancel();
                  _tgSheetStateSetter = null;
                  Navigator.pop(ctx);
                },
                child: Text(_t('cancel'), style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _tgStep(String num, IconData icon, String title, String sub) {
    return Row(
      children: [
        Container(
          width: 36, height: 36,
          decoration: const BoxDecoration(color: Color(0xFF0088CC), shape: BoxShape.circle),
          child: Center(child: Text(num, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15))),
        ),
        const SizedBox(width: 14),
        Icon(icon, color: const Color(0xFF0088CC), size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF1A1D1E))),
              Text(sub, style: const TextStyle(color: Colors.black45, fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }

  void _showOtpDialog(String chatId, String? customToken) {
    final otpCtrl = TextEditingController();
    bool isError = false;
    bool isDialogLoading = false;
    String? dialogErrorMsg;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) {
          // ─── inner confirm action ─────────────────────────────────────
          Future<void> onConfirm() async {
            if (otpCtrl.text != _generatedCode) {
              ss(() { isError = true; otpCtrl.clear(); dialogErrorMsg = null; });
              return;
            }
            // Code matches — start loading inside dialog (do NOT pop yet)
            ss(() { isDialogLoading = true; isError = false; dialogErrorMsg = null; });
            try {
              String? tokenToUse = customToken;

              // If customToken is absent/invalid — fetch fresh one from Firestore
              if (tokenToUse == null || tokenToUse.split('.').length != 3) {
                await Future.delayed(const Duration(milliseconds: 800));
                final freshSnap = await FirebaseFirestore.instance
                    .collection('tg_auth_sessions')
                    .doc(_tgSessionToken)
                    .get()
                    .timeout(const Duration(seconds: 15));
                tokenToUse = freshSnap.data()?['customToken'] as String?;
              }

              if (tokenToUse == null || tokenToUse.split('.').length != 3) {
                throw Exception('Сервер не смог создать токен. Попробуйте через 30 сек.');
              }

              final userCred = await FirebaseAuth.instance
                  .signInWithCustomToken(tokenToUse)
                  .timeout(const Duration(seconds: 20));

              // ✅ Success — pop dialog, then finalize
              if (mounted && Navigator.of(ctx, rootNavigator: true).canPop()) {
                Navigator.of(ctx, rootNavigator: true).pop();
              }
              await _finalizeLogin(
                userCred.user?.displayName ?? 'Telegram User',
                isVerified: true,
                accountType: null,
              );

            } on TimeoutException {
              // Stay in dialog — show retry message
              ss(() {
                isDialogLoading = false;
                dialogErrorMsg = _t('err_timeout');
              });
            } catch (e) {
              ss(() {
                isDialogLoading = false;
                dialogErrorMsg = 'Ошибка: ${e.toString().replaceAll('Exception:', '').trim()}';
              });
            }
          }
          // ─────────────────────────────────────────────────────────────

          return PopScope(
            canPop: !isDialogLoading,
            child: Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    )
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Header ────────────────────────────────────────────
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFFE5F5FF),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.telegram_rounded, color: Color(0xFF0088CC), size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _t('tg_otp_title'),
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              color: const Color(0xFF1A1D1E),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── Description ───────────────────────────────────────
                    Text(
                      _t('tg_otp_desc'),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: Colors.black54,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Expiry badge ───────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.timer_outlined, color: Colors.orange, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          _t('otp_valid_5m'),
                          style: GoogleFonts.inter(
                            color: Colors.orange,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ── 6-box OTP input ────────────────────────────────────
                    AbsorbPointer(
                      absorbing: isDialogLoading,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Opacity(
                            opacity: 0.0,
                            child: TextField(
                              controller: otpCtrl,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              autofocus: true,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              onChanged: (_) => ss(() { isError = false; dialogErrorMsg = null; }),
                              decoration: const InputDecoration(counterText: ''),
                            ),
                          ),
                          IgnorePointer(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: List.generate(6, (i) {
                                final char = otpCtrl.text.length > i ? otpCtrl.text[i] : '';
                                final focused = otpCtrl.text.length == i ||
                                    (otpCtrl.text.length == 6 && i == 5);
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 120),
                                  width: 38,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: isDialogLoading
                                        ? const Color(0xFFF0F4F8)
                                        : const Color(0xFFF6F8FA),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isError
                                          ? Colors.redAccent
                                          : (focused
                                              ? const Color(0xFF0088CC)
                                              : const Color(0xFFE6E8EB)),
                                      width: focused ? 2.2 : 1.0,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: isDialogLoading && char.isNotEmpty
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFF0088CC),
                                          ),
                                        )
                                      : Text(
                                          char,
                                          style: GoogleFonts.inter(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w900,
                                            color: isDialogLoading
                                                ? Colors.black38
                                                : const Color(0xFF1A1D1E),
                                          ),
                                        ),
                                );
                              }),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Error messages ─────────────────────────────────────
                    AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      child: isError
                          ? Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.error_outline_rounded,
                                      color: Colors.redAccent, size: 15),
                                  const SizedBox(width: 6),
                                  Text(
                                    _t('err_invalid_otp_retry'),
                                    style: GoogleFonts.inter(
                                      color: Colors.redAccent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : dialogErrorMsg != null
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 14),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: Colors.orange.withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(Icons.wifi_off_rounded,
                                            color: Colors.orange, size: 15),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            dialogErrorMsg!,
                                            style: GoogleFonts.inter(
                                              color: Colors.orange.shade800,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              height: 1.4,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                    ),

                    const SizedBox(height: 24),

                    // ── Loading status text ────────────────────────────────
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: isDialogLoading
                          ? Padding(
                              key: const ValueKey('loading_status'),
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: const Color(0xFF0088CC).withValues(alpha: 0.7),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Входим в аккаунт...',
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF0088CC),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : const SizedBox(key: ValueKey('idle_status')),
                    ),

                    // ── Buttons ────────────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isDialogLoading
                                ? null
                                : () => Navigator.of(ctx, rootNavigator: true).pop(),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: isDialogLoading
                                    ? Colors.grey.shade200
                                    : const Color(0xFFE6E8EB),
                              ),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(
                              _t('cancel'),
                              style: GoogleFonts.inter(
                                color: isDialogLoading
                                    ? Colors.grey.shade300
                                    : Colors.grey[600],
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: (otpCtrl.text.length < 6 || isDialogLoading)
                                ? null
                                : onConfirm,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0088CC),
                              disabledBackgroundColor:
                                  const Color(0xFF0088CC).withValues(alpha: 0.45),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                            ),
                            child: isDialogLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    dialogErrorMsg != null
                                        ? 'Повторить'
                                        : _t('confirm'),
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ===================== FINALIZE =====================
  Future<void> _finalizeLogin(String name, {String? email, String? photoUrl, bool isVerified = false, String? accountType}) async {
    // 1. Сохраняем в Firebase Firestore
    final bool finalVerified = await UserService.syncUserAfterLogin(
      name: name,
      email: email,
      photoUrl: photoUrl,
      isVerified: isVerified,
      accountType: accountType,
    );
    
    // 2. Локальное сохранение
    StorageService.saveProfile(name, photoUrl, false, accountType ?? 'Личный', isVerified: finalVerified);
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
          AnimatedSwitcher(duration: const Duration(milliseconds: 200), child: Text(_isLogin ? _t('sub_login') : _t('sub_reg'), key: ValueKey(_isLogin), maxLines: 1, softWrap: false, style: const TextStyle(fontSize: 16, color: Colors.black54, fontWeight: FontWeight.w600))),
          const SizedBox(height: 35),

          _buildToggle(),
          const SizedBox(height: 35),

          AnimatedCrossFade(duration: const Duration(milliseconds: 300), crossFadeState: _isLogin ? CrossFadeState.showFirst : CrossFadeState.showSecond, firstChild: const SizedBox.shrink(), secondChild: SingleChildScrollView(physics: const NeverScrollableScrollPhysics(), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _label(_t('name_label')), const SizedBox(height: 8),
            AuthField(hint: _t('name_hint'), icon: Icons.person_outline_rounded, controller: _nameController),
            const SizedBox(height: 20),
          ]))),

          _label(_t('email_label')), const SizedBox(height: 8),
          AuthField(hint: _t('email_hint'), icon: Icons.email_outlined, controller: _emailController, keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 20),

          _label(_t('pwd_label')), const SizedBox(height: 8),
          AuthField(hint: _t('pwd_hint'), icon: Icons.lock_outline_rounded, controller: _passwordController, isPassword: true, showToggle: true, isVisible: _showPassword, onToggle: () => setState(() => _showPassword = !_showPassword)),

          AnimatedCrossFade(duration: const Duration(milliseconds: 300), crossFadeState: _isLogin ? CrossFadeState.showFirst : CrossFadeState.showSecond, firstChild: const SizedBox.shrink(), secondChild: SingleChildScrollView(physics: const NeverScrollableScrollPhysics(), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 20),
            _label(_t('confirm_label')), const SizedBox(height: 8),
            AuthField(hint: _t('confirm_hint'), icon: Icons.lock_outline_rounded, controller: _confirmPasswordController, isPassword: true, showToggle: true, isVisible: _showConfirmPassword, onToggle: () => setState(() => _showConfirmPassword = !_showConfirmPassword)),
          ]))),

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
          /*
          AuthSocialLongButton(
            label: 'Продолжить с Mail.ru',
            icon: Container(
              width: 28, height: 28,
              decoration: const BoxDecoration(color: Color(0xFF005FF9), shape: BoxShape.circle),
              child: const Center(child: Text('@', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900))),
            ),
            onTap: () {
               // Scroll to top or focus email field? 
               // For now, just keep the fields below.
            },
          ),
          */
 
          AuthSocialLongButton(
            label: 'Продолжить с Google',
            icon: Image.network(
              'https://img.icons8.com/color/96/google-logo.png',
              width: 26,
              height: 26,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.g_mobiledata_rounded, color: Color(0xFF4285F4), size: 26),
            ),
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
            icon: const Icon(Icons.telegram_rounded, color: Colors.white, size: 30),
            onTap: _handleTelegramLogin,
            color: const Color(0xFF0088CC),
            textColor: Colors.white,
          ),

          const SizedBox(height: 30),
        ]))),
        if (_isLoading) Container(color: Colors.black.withValues(alpha: 0.3), child: const Center(child: CircularProgressIndicator(color: Color(0xFF4A80F0), strokeWidth: 3))),
          ],
        ),
      ),
    );
  }

  // ===================== UI WIDGETS =====================
  Widget _buildToggle() => Container(
        height: 58, 
        padding: const EdgeInsets.all(5), 
        decoration: BoxDecoration(
          color: Colors.white, 
          borderRadius: BorderRadius.circular(20), 
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04), 
              blurRadius: 20, 
              offset: const Offset(0, 10),
            ),
          ],
        ), 
        child: Stack(
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 300), 
              curve: Curves.easeInOutBack, 
              alignment: _isLogin ? Alignment.centerLeft : Alignment.centerRight, 
              child: FractionallySizedBox(
                widthFactor: 0.5,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A80F0), 
                    borderRadius: BorderRadius.circular(16), 
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4A80F0).withValues(alpha: 0.3), 
                        blurRadius: 10, 
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Row(
              children: [
                _togItem(_t('login_tab'), true), 
                _togItem(_t('reg_tab'), false),
              ],
            ),
          ],
        ),
      );

  Widget _togItem(String t, bool s) => Expanded(
    child: GestureDetector(
      onTap: () => setState(() => _isLogin = s), 
      behavior: HitTestBehavior.opaque, 
      child: Center(
        child: Text(
          t, 
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontSize: 15, 
            fontWeight: FontWeight.w900, 
            color: _isLogin == s ? Colors.white : Colors.black54,
          ),
        ),
      ),
    ),
  );
  Widget _label(String t) => Text(t, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF1A1D1E)));

}