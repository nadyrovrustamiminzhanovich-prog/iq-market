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
import 'package:url_launcher/url_launcher.dart';

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
      );
      
      _showSuccess(_t('success_reg') + ". Проверьте почту для подтверждения!");
      
      // Строгая верификация: выходим из сессии, не пускаем внутрь
      await AuthService.signOut();
      
      if (!mounted) return;
      // Автоматически переключаем на вкладку "Вход"
      setState(() => _isLogin = true);
      _passwordController.clear();
      _confirmPasswordController.clear();
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
        await AuthService.signOut();
        return; // Жёстко блокируем вход!
      }

      await _finalizeLogin(
        user?.displayName ?? _emailController.text.split('@')[0],
        email: user?.email,
        photoUrl: user?.photoURL,
        isVerified: user?.emailVerified ?? false,
      );
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
    setState(() => _isLoading = true);
    try {
      final uc = await AuthService.signInWithGoogle();
      if (uc != null) {
        await _finalizeLogin(
          uc.user?.displayName ?? 'Google User',
          email: uc.user?.email,
          photoUrl: uc.user?.photoURL,
          isVerified: uc.user?.emailVerified ?? true, // Google = verified
        );
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
        await _finalizeLogin(
          uc.user?.displayName ?? 'Apple User',
          email: uc.user?.email,
          isVerified: true, // Apple = verified
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
    setState(() { _isLoading = true; });
    try {
      // 1. Create Firestore session (WITHOUT auto-launching Telegram)
      _tgSessionToken = await AuthService.startTelegramSession();
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
      });

    } catch (e) {
      _showError('Ошибка: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openTelegramBot() async {
    if (_tgBotUrl == null) return;
    await launchUrl(Uri.parse(_tgBotUrl!), mode: LaunchMode.externalApplication);
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
              const Text(
                'Верификация через Telegram',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1A1D1E)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              const Text(
                'Следуйте инструкции для подтверждения номера',
                style: TextStyle(color: Colors.black45, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),

              // Step-by-step guide
              _tgStep('1', Icons.open_in_new_rounded, 'Откройте бота @IQ_Taxi_bot', 'Ссылка откроется автоматически'),
              const SizedBox(height: 14),
              _tgStep('2', Icons.play_circle_outline_rounded, 'Нажмите кнопку «START»', 'Бот запустится и попросит контакт'),
              const SizedBox(height: 14),
              _tgStep('3', Icons.contact_phone_rounded, 'Поделитесь своим контактом', 'Нажмите кнопку в боте'),
              const SizedBox(height: 14),
              _tgStep('4', Icons.keyboard_rounded, 'Введите код в приложении', 'Бот пришлёт 6-значный код'),
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
                                'Открытие Telegram через $remaining сек...',
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
                            child: const Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.telegram_rounded, color: Colors.white, size: 22),
                                  SizedBox(width: 10),
                                  Text('Открыть Telegram', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      // Always-visible manual button
                      GestureDetector(
                        onTap: _openTelegramBot,
                        child: const Text(
                          'Открыть вручную →',
                          style: TextStyle(color: Color(0xFF0088CC), fontWeight: FontWeight.w700, fontSize: 13, decoration: TextDecoration.underline),
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
                  const Text('Ожидаем подтверждения...', style: TextStyle(color: Colors.black38, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  _tgSessionSub?.cancel();
                  _tgCountdownTimer?.cancel();
                  _tgSheetStateSetter = null;
                  Navigator.pop(ctx);
                },
                child: const Text('Отмена', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
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
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => Dialog(
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
              ]
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
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
                    Text(
                      _t('tg_otp_title'),
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: const Color(0xFF1A1D1E),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Description
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
                
                // Expiry info
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.timer_outlined, color: Colors.orange, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'Код действителен в течение 5 минут',
                      style: GoogleFonts.inter(
                        color: Colors.orange,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Beautiful 6-box input code
                Stack(
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
                        onChanged: (v) {
                          ss(() {});
                        },
                        decoration: const InputDecoration(counterText: ""),
                      ),
                    ),
                    IgnorePointer(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(6, (index) {
                          String char = "";
                          if (otpCtrl.text.length > index) {
                            char = otpCtrl.text[index];
                          }
                          
                          bool isFocused = otpCtrl.text.length == index;
                          if (otpCtrl.text.length == 6 && index == 5) {
                            isFocused = true;
                          }
                          
                          return Container(
                            width: 38,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF6F8FA),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isError 
                                    ? Colors.redAccent 
                                    : (isFocused ? const Color(0xFF0088CC) : const Color(0xFFE6E8EB)),
                                width: isFocused ? 2.2 : 1.0,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              char,
                              style: GoogleFonts.inter(
                                fontSize: 20, 
                                fontWeight: FontWeight.w900, 
                                color: const Color(0xFF1A1D1E),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
                
                if (isError) ...[
                  const SizedBox(height: 16),
                  Text(
                    '❌ Неверный код. Попробуйте еще раз',
                    style: GoogleFonts.inter(
                      color: Colors.redAccent, 
                      fontSize: 12, 
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
                
                const SizedBox(height: 28),
                
                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFE6E8EB)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          _t('cancel'),
                          style: GoogleFonts.inter(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: otpCtrl.text.length < 6 ? null : () async {
                          if (otpCtrl.text == _generatedCode) {
                            Navigator.pop(context);
                            setState(() => _isLoading = true);
                            try {
                              if (customToken == null || customToken.split('.').length != 3) {
                                await Future.delayed(const Duration(seconds: 2));
                                final freshSnap = await FirebaseFirestore.instance
                                    .collection('tg_auth_sessions')
                                    .doc(_tgSessionToken)
                                    .get();
                                final freshToken = freshSnap.data()?['customToken'] as String?;
                                
                                if (freshToken == null || freshToken.split('.').length != 3) {
                                  throw Exception(
                                    'Сервер не смог создать токен авторизации.\n\n'
                                    'Попробуйте еще раз через 30 секунд.'
                                  );
                                }
                                final userCred2 = await FirebaseAuth.instance.signInWithCustomToken(freshToken);
                                await _finalizeLogin(
                                  userCred2.user?.displayName ?? 'Telegram User',
                                  isVerified: true,
                                  accountType: null,
                                );
                                return;
                              }
                              final userCred = await FirebaseAuth.instance.signInWithCustomToken(customToken);
                              await _finalizeLogin(
                                userCred.user?.displayName ?? 'Telegram User',
                                isVerified: true,
                                accountType: null,
                              );
                            } catch (e) {
                              _showError('Ошибка авторизации: $e');
                            } finally {
                              setState(() => _isLoading = false);
                            }
                          } else {
                            ss(() {
                              isError = true;
                              otpCtrl.clear();
                            });
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0088CC),
                          disabledBackgroundColor: const Color(0xFF0088CC).withValues(alpha: 0.45),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                        ),
                        child: Text(
                          _t('confirm'),
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
      ),
    );
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

          const SizedBox(height: 12),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF229ED9).withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF229ED9).withValues(alpha: 0.1)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified_user_rounded, color: Color(0xFF229ED9), size: 18),
                      const SizedBox(width: 10),
                      const Text(
                        'Верификация через Telegram',
                        style: TextStyle(color: Color(0xFF229ED9), fontSize: 13, fontWeight: FontWeight.w900),
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