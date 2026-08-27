import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iqmarket/models/app_version_info.dart';

/// Премиальный диалог обновления приложения мирового уровня
class UpdateDialog extends StatelessWidget {
  final AppVersionInfo versionInfo;
  final String language;
  final bool isForceUpdate;
  final VoidCallback onUpdate;
  final VoidCallback onDismiss;

  const UpdateDialog({
    super.key,
    required this.versionInfo,
    required this.language,
    required this.isForceUpdate,
    required this.onUpdate,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Локализованные тексты
    final isKk = language.contains('Қазақ') || language == 'kk';
    final isUg = language.contains('Уйғур') || language == 'ug';

    final title = isKk
        ? 'Жаңа нұсқа қолжетімді!'
        : isUg
            ? 'يېڭى نۇسخا تەمىنلەندى!'
            : 'Доступно обновление!';

    final subtitle = isKk
        ? 'IQ-Market қолданбасын соңғы нұсқаға дейін жаңартыңыз'
        : isUg
            ? 'IQ-Market ئەپىنى ئەڭ يېڭى نۇسخىغا يېڭىلاڭ'
            : 'Обновите IQ-Market для стабильной и быстрой работы';

    final whatsNewTitle = isKk
        ? 'Не жаңалық:'
        : isUg
            ? 'نېمىلەر يېڭىلاندى:'
            : 'Что нового:';

    final updateButtonText = isKk
        ? 'Жаңарту'
        : isUg
            ? 'يېڭىلاش'
            : 'Обновить';

    final laterButtonText = isKk
        ? 'Кейінірек'
        : isUg
            ? 'كېيىنرەك'
            : 'Позже';

    final changelog = versionInfo.getChangelogForLanguage(language);

    return PopScope(
      canPop: !isForceUpdate,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        elevation: 16,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: isDark
                ? const LinearGradient(
                    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  )
                : const LinearGradient(
                    colors: [Colors.white, Color(0xFFF8FAFC)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Иконка обновления с градиентом
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2563EB), Color(0xFF38BDF8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.rocket_launch_rounded,
                    color: Colors.white,
                    size: 38,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 2. Бейдж версии
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    'Версия ${versionInfo.latestVersionName}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF2563EB),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 3. Заголовок
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),

              // 4. Подзаголовок
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 20),

              // 5. Блок "Что нового"
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF334155).withValues(alpha: 0.4) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF475569) : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome_rounded,
                          size: 16,
                          color: Color(0xFF2563EB),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          whatsNewTitle,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...changelog.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '• ',
                              style: TextStyle(
                                color: const Color(0xFF2563EB),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                item,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 6. Кнопки действий
              Row(
                children: [
                  if (!isForceUpdate) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onDismiss,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(
                            color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          laterButtonText,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: isForceUpdate ? 1 : 1,
                    child: ElevatedButton(
                      onPressed: onUpdate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shadowColor: const Color(0xFF2563EB).withValues(alpha: 0.4),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.download_rounded, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            updateButtonText,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
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
  }
}
