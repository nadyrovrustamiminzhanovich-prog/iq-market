// ─────────────────────────────────────────────────────────────────────────────
// FILE: lib/features/taxi/presentation/widgets/ui/taxi_sos_bottom_sheet.dart
// STEP: #17 | СЛОЙ: widgets/ui
// ОТВЕЧАЕТ ЗА: SOS bottom sheet с экстренными номерами Казахстана
// ЗАВИСИМОСТИ: TaxiTheme, url_launcher, flutter/services
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:iqmarket/theme/taxi_theme.dart';
import 'package:iqmarket/providers/taxi_provider.dart';

/// SOS-панель экстренных служб Казахстана.
///
/// Вызов через статический метод:
/// ```dart
/// TaxiSosBottomSheet.show(context, t);
/// ```
class TaxiSosBottomSheet {
  TaxiSosBottomSheet._(); // не инстанцируется

  // ── Данные экстренных служб ───────────────────────────────────────────────
  static const List<_EmergencyService> _services = [
    _EmergencyService(number: '102', labelKey: 'police',        descKey: 'police_desc',       icon: Icons.local_police_rounded,        color: Color(0xFF3B82F6), bg: Color(0xFFEFF6FF)),
    _EmergencyService(number: '103', labelKey: 'ambulance',     descKey: 'ambulance_desc',    icon: Icons.medical_services_rounded,   color: Color(0xFFF43F5E), bg: Color(0xFFFFF1F2)),
    _EmergencyService(number: '101', labelKey: 'fire',          descKey: 'fire_desc',         icon: Icons.local_fire_department_rounded, color: Color(0xFFF97316), bg: Color(0xFFFFF7ED)),
    _EmergencyService(number: '104', labelKey: 'gas',           descKey: 'gas_desc',          icon: Icons.oil_barrel_rounded,         color: Color(0xFFEAB308), bg: Color(0xFFFEFCE8)),
  ];

  /// Показывает SOS bottom sheet. Принимает [context] и текущую [t]ему.
  static void show(BuildContext context, TaxiTheme t) {
    HapticFeedback.vibrate();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SosSheet(t: t, ctx: ctx),
    );
  }
}

// ── Внутренний виджет-содержимое ─────────────────────────────────────────────
class _SosSheet extends StatelessWidget {
  final TaxiTheme t;
  final BuildContext ctx;
  const _SosSheet({required this.t, required this.ctx});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TaxiProvider>(context);
    return Container(
      decoration: BoxDecoration(
        color: t.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(35)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 35, offset: const Offset(0, -10)),
        ],
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        top: 12, left: 24, right: 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 45, height: 5,
                decoration: BoxDecoration(
                  color: t.border.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildHeader(provider),
            const SizedBox(height: 20),
            _build112Button(provider),
            const SizedBox(height: 24),
            Text(
              provider.translate('other_emergency_services'),
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, color: t.sub, letterSpacing: 1.0),
            ),
            const SizedBox(height: 12),
            ...TaxiSosBottomSheet._services.map((svc) => _buildServiceTile(svc, provider)),
            const SizedBox(height: 24),
            _buildCloseButton(provider),
            const SizedBox(height: 15),
          ],
        ),
      ),
    );
  }

  // ── Шапка SOS ────────────────────────────────────────────────────────────
  Widget _buildHeader(TaxiProvider provider) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0xFFFFE4E6), Color(0xFFFFE4E6)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFFFECDD3), width: 1.5),
      boxShadow: [BoxShadow(color: const Color(0xFFE11D48).withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 8))],
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(color: Color(0xFFE11D48), shape: BoxShape.circle),
          child: const Icon(Icons.gpp_maybe_rounded, color: Colors.white, size: 30),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(provider.translate('sos_service'), style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF9F1239), letterSpacing: 0.5)),
            const SizedBox(height: 3),
            Text(provider.translate('sos_subtitle'), style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFBE123C), fontWeight: FontWeight.w600)),
          ]),
        ),
      ],
    ),
  );

  // ── Кнопка 112 ───────────────────────────────────────────────────────────
  Widget _build112Button(TaxiProvider provider) => GestureDetector(
    onTap: () async {
      HapticFeedback.heavyImpact();
      final uri = Uri.parse('tel:112');
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    },
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFE11D48), Color(0xFFBE123C)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: const Color(0xFFE11D48).withValues(alpha: 0.4), blurRadius: 25, offset: const Offset(0, 10))],
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.phone_in_talk_rounded, color: Colors.white, size: 26),
        const SizedBox(width: 12),
        Flexible(child: Text(provider.translate('call_112'), style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5), maxLines: 1, overflow: TextOverflow.ellipsis)),
      ]),
    ),
  );

  // ── Карточка службы ──────────────────────────────────────────────────────
  Widget _buildServiceTile(_EmergencyService svc, TaxiProvider provider) => GestureDetector(
    onTap: () async {
      HapticFeedback.heavyImpact();
      final uri = Uri.parse('tel:${svc.number}');
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    },
    child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: svc.bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: svc.color.withValues(alpha: 0.15), width: 1.5),
        boxShadow: [BoxShadow(color: svc.color.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: svc.color.withValues(alpha: 0.15), shape: BoxShape.circle),
          child: Icon(svc.icon, color: svc.color, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(provider.translate(svc.labelKey), style: GoogleFonts.inter(color: const Color(0xFF1E293B), fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 2),
          Text(provider.translate(svc.descKey), style: GoogleFonts.inter(color: const Color(0xFF64748B), fontWeight: FontWeight.w600, fontSize: 11)),
        ])),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(color: svc.color, borderRadius: BorderRadius.circular(14)),
          child: Text(svc.number, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
        ),
      ]),
    ),
  );

  // ── Кнопка закрыть ───────────────────────────────────────────────────────
  Widget _buildCloseButton(TaxiProvider provider) => SizedBox(
    width: double.infinity,
    child: TextButton(
      onPressed: () => Navigator.pop(ctx),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: t.border)),
      ),
      child: Text(provider.translate('close'), style: GoogleFonts.inter(color: t.sub, fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: 0.5)),
    ),
  );
}

// ── Иммутабельная модель службы ───────────────────────────────────────────────
class _EmergencyService {
  final String number;
  final String labelKey;
  final String descKey;
  final IconData icon;
  final Color color;
  final Color bg;
  const _EmergencyService({required this.number, required this.labelKey, required this.descKey, required this.icon, required this.color, required this.bg});
}
