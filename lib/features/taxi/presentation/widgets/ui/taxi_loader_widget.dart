// ─────────────────────────────────────────────────────────────────────────────
// FILE: lib/features/taxi/presentation/widgets/ui/taxi_loader_widget.dart
// STEP: #21 | СЛОЙ: widgets/ui
// ОТВЕЧАЕТ ЗА: индикатор загрузки и анимированный радар-виджет
// ЗАВИСИМОСТИ: только Flutter + TaxiTheme (нет Provider, нет Firestore)
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:iqmarket/theme/taxi_theme.dart';

// ─── Простой лоадер ───────────────────────────────────────────────────────────

/// Центрированный `CircularProgressIndicator` в цвете акцента темы.
/// Используется в `TaxiServiceScreen` пока `taxiProvider.loading == true`.
class TaxiLoaderWidget extends StatelessWidget {
  final TaxiTheme t;
  const TaxiLoaderWidget({super.key, required this.t});

  @override
  Widget build(BuildContext context) {
    return Center(child: CircularProgressIndicator(color: t.lime));
  }
}

// ─── Анимированный радар ──────────────────────────────────────────────────────

/// Премиум-радар с вращающимся sweep-градиентом.
/// Показывается, пока приложение ищет поездки / водителей.
/// Не требует Provider — получает тему снаружи.
class StableRadar extends StatefulWidget {
  final TaxiTheme theme;
  const StableRadar({super.key, required this.theme});

  @override
  State<StableRadar> createState() => _StableRadarState();
}

class _StableRadarState extends State<StableRadar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 220,
      alignment: Alignment.center,
      child: SizedBox(
        width: 180,
        height: 180,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer static glow ring
            Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF4A80F0).withValues(alpha: 0.03),
                border: Border.all(
                  color: const Color(0xFF4A80F0).withValues(alpha: 0.1),
                  width: 1.5,
                ),
              ),
            ),
            // Middle ring
            Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF4A80F0).withValues(alpha: 0.02),
                border: Border.all(
                  color: const Color(0xFF4A80F0).withValues(alpha: 0.08),
                  width: 1.5,
                ),
              ),
            ),
            // Innermost ring
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF4A80F0).withValues(alpha: 0.01),
                border: Border.all(
                  color: const Color(0xFF4A80F0).withValues(alpha: 0.06),
                  width: 1.5,
                ),
              ),
            ),
            // Rotating radar sweep
            RotationTransition(
              turns: _controller,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    center: Alignment.center,
                    startAngle: 0.0,
                    endAngle: 3.14 * 2,
                    colors: [
                      const Color(0xFF4A80F0).withValues(alpha: 0.15),
                      const Color(0xFF4A80F0).withValues(alpha: 0.0),
                    ],
                    stops: const [0.2, 1.0],
                  ),
                ),
              ),
            ),
            // Glassmorphic central badge
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: const Color(0xFFF1F5F9), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4A80F0).withValues(alpha: 0.12),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const Icon(
                Icons.location_searching_rounded,
                color: Color(0xFF4A80F0),
                size: 30,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
