import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iqmarket/screens/login_screen.dart';
import 'package:iqmarket/providers/app_config_provider.dart';
import 'package:provider/provider.dart';

class AuthGateBottomSheet extends StatefulWidget {
  final String message;
  final String title;
  final String confirmText;
  final String cancelText;

  const AuthGateBottomSheet({
    super.key,
    required this.message,
    this.title = 'Требуется авторизация',
    this.confirmText = 'Войти в аккаунт',
    this.cancelText = 'Позже',
  });

  static Future<bool> show(BuildContext context, {
    String? title,
    required String message,
    String? confirmText,
    String? cancelText,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (context) => AuthGateBottomSheet(
        title: title ?? 'Требуется авторизация',
        message: message,
        confirmText: confirmText ?? 'Войти в аккаунт',
        cancelText: cancelText ?? 'Позже',
      ),
    );
    return result ?? false;
  }

  @override
  State<AuthGateBottomSheet> createState() => _AuthGateBottomSheetState();
}

class _AuthGateBottomSheetState extends State<AuthGateBottomSheet> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(_scaleAnimation);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final language = Provider.of<AppConfigProvider>(context, listen: false).language;

    // Translations for basic texts based on app language
    String titleText = widget.title;
    String descText = widget.message;
    String ctaText = widget.confirmText;
    String closeText = widget.cancelText;

    if (language == 'Қазақша') {
      if (widget.title == 'Требуется авторизация') titleText = 'Авторизация қажет';
      if (widget.confirmText == 'Войти в аккаунт') ctaText = 'Жүйеге кіру';
      if (widget.cancelText == 'Позже') closeText = 'Кейінірек';
    } else if (language == 'Уйғурчә') {
      if (widget.title == 'Требуется авторизация') titleText = 'Кириш тәләп қилиниду';
      if (widget.confirmText == 'Войти в аккаунт') ctaText = 'Кириш';
      if (widget.cancelText == 'Позже') closeText = 'Кейинәрәк';
    }

    return Container(
      padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).padding.bottom + 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 30,
            offset: Offset(0, -10),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 24),

          // High-end Pulsing Heart/Lock Graphic
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFEF4444).withValues(alpha: 0.15),
                    const Color(0xFFF43F5E).withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Container(
                  width: 66,
                  height: 66,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFFEF4444), Color(0xFFF43F5E)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x66EF4444),
                        blurRadius: 16,
                        offset: Offset(0, 6),
                      )
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(
                        Icons.favorite_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                      Positioned(
                        bottom: 12,
                        right: 12,
                        child: Container(
                          padding: EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: Colors.black26, blurRadius: 4)
                            ]
                          ),
                          child: Icon(
                            Icons.lock_rounded,
                            color: Color(0xFFEF4444),
                            size: 11,
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Title
          Text(
            titleText,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),

          // Message
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              descText,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF475569),
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Premium gradient button: Login
          Container(
            width: double.infinity,
            height: 58,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [Color(0xFF4A80F0), Color(0xFF3B82F6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4A80F0).withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                )
              ],
            ),
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LoginScreen(lang: language),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                ctaText,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Neutral Cancel Button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: TextButton(
              onPressed: () => Navigator.pop(context, false),
              style: TextButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Text(
                closeText,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
