import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class SplashScreen extends StatefulWidget {
  final Widget nextScreen;
  const SplashScreen({super.key, required this.nextScreen});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // ── Контроллеры анимаций ──────────────────────────────────────────────────
  late final AnimationController _logoCtrl;
  late final AnimationController _textCtrl;
  late final AnimationController _ringCtrl;
  late final AnimationController _exitCtrl;
  late final AnimationController _particleCtrl;

  // Логотип
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoBlur;

  // Текст
  late final Animation<double> _textOpacity;
  late final Animation<Offset> _textSlide;

  // Кольца
  late final Animation<double> _ring1;
  late final Animation<double> _ring2;

  // Выход
  late final Animation<double> _exitOpacity;

  @override
  void initState() {
    super.initState();

    // Edge-to-edge (убираем белую вспышку статусбара)
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    // ── Инициализация контроллеров ────────────────────────────────────────
    _logoCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _textCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _ringCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800));
    _exitCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _particleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2200))
      ..repeat();

    // ── Анимации логотипа ─────────────────────────────────────────────────
    _logoScale = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _logoCtrl,
          curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
    );
    _logoBlur = Tween<double>(begin: 12.0, end: 0.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOut),
    );

    // ── Анимации текста ───────────────────────────────────────────────────
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut),
    );
    _textSlide = Tween<Offset>(
            begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeOutCubic));

    // ── Кольца-пульс ─────────────────────────────────────────────────────
    _ring1 = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _ringCtrl,
          curve: const Interval(0.0, 0.8, curve: Curves.easeOut)),
    );
    _ring2 = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _ringCtrl,
          curve: const Interval(0.25, 1.0, curve: Curves.easeOut)),
    );

    // ── Выход ─────────────────────────────────────────────────────────────
    _exitOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _exitCtrl, curve: Curves.easeIn),
    );

    // ── Запуск последовательности ─────────────────────────────────────────
    _startSequence();
  }

  Future<void> _startSequence() async {
    await Future.delayed(const Duration(milliseconds: 100));

    // 1. Кольца + логотип вместе
    _ringCtrl.forward();
    _logoCtrl.forward();

    await Future.delayed(const Duration(milliseconds: 400));

    // 2. Текст выезжает снизу
    _textCtrl.forward();

    // 3. Ждём и уходим
    await Future.delayed(const Duration(milliseconds: 400));
    _particleCtrl.stop();
    
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => widget.nextScreen,
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    }
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _textCtrl.dispose();
    _ringCtrl.dispose();
    _exitCtrl.dispose();
    _particleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _exitOpacity,
      builder: (_, child) => Opacity(opacity: _exitOpacity.value, child: child),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Логотип ─────────────────────────────────────────────────
              AnimatedBuilder(
                animation: _logoCtrl,
                builder: (_, child) => Opacity(
                  opacity: _logoOpacity.value,
                  child: Transform.scale(
                    scale: _logoScale.value,
                    child: child,
                  ),
                ),
                child: Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(36),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4A80F0), Color(0xFF1E40AF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4A80F0).withValues(alpha: 0.3),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Center(
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'i',
                            style: GoogleFonts.inter(
                              fontSize: 54,
                              fontWeight: FontWeight.w300,
                              color: Colors.white,
                            ),
                          ),
                          TextSpan(
                            text: 'Q',
                            style: GoogleFonts.inter(
                              fontSize: 58,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              // Текст под логотипом
              SlideTransition(
                position: _textSlide,
                child: FadeTransition(
                  opacity: _textOpacity,
                  child: Column(
                    children: [
                      Text(
                        'IQ-Market',
                        style: GoogleFonts.inter(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF1E40AF),
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Сделано в Казахстане 🇰🇿',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Painter для частиц (мерцающие звёздочки на фоне)
// ──────────────────────────────────────────────────────────────────────────────
class _ParticlePainter extends CustomPainter {
  final double progress;
  static final List<_Particle> _particles = List.generate(
    35,
    (i) => _Particle(seed: i),
  );

  _ParticlePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in _particles) {
      final t = (progress + p.offset) % 1.0;
      final opacity = (sin(t * pi * 2) * 0.5 + 0.5) * 0.6;
      final paint = Paint()
        ..color = p.color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(p.x * size.width, p.y * size.height),
        p.radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => true;
}

class _Particle {
  final double x;
  final double y;
  final double radius;
  final double offset;
  final Color color;

  _Particle({required int seed})
      : x = _hash(seed * 7 + 1),
        y = _hash(seed * 13 + 3),
        radius = 1.0 + _hash(seed * 17 + 7) * 2.0,
        offset = _hash(seed * 5 + 2),
        color = seed % 3 == 0
            ? const Color(0xFF4A80F0)
            : seed % 3 == 1
                ? const Color(0xFF00B2FF)
                : Colors.white;

  static double _hash(int n) {
    // Простой детерминированный "рандом" для одинаковой картинки каждый раз
    final x = (n * 1664525 + 1013904223) & 0xFFFFFFFF;
    return (x / 0xFFFFFFFF).clamp(0.0, 1.0);
  }
}
