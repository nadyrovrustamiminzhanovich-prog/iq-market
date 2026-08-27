import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:iqmarket/providers/app_config_provider.dart';
import 'package:iqmarket/services/translation_service.dart';
import 'package:iqmarket/services/version_service.dart';

/// Вежливое и красивое напоминание об обновлении IQ-Market
class UpdateAvailableSheet extends StatelessWidget {
  final UpdateChangelog update;
  const UpdateAvailableSheet({super.key, required this.update});

  static Future<void> show(BuildContext context, UpdateChangelog update) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UpdateAvailableSheet(update: update),
    );
  }

  /// Открытие страницы приложения в Google Play (прямой интент market:// с веб-фоллбеком)
  Future<void> _launchStore() async {
    final marketUri = Uri.parse('market://details?id=${VersionService.packageName}');
    final webUri = Uri.parse(
      update.storeUrl.isNotEmpty
          ? update.storeUrl
          : 'https://play.google.com/store/apps/details?id=${VersionService.packageName}',
    );

    try {
      if (await canLaunchUrl(marketUri)) {
        await launchUrl(marketUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (e) {
      debugPrint('UpdateAvailableSheet: could not launch market scheme: $e');
    }

    try {
      if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('UpdateAvailableSheet: could not launch web URL: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<AppConfigProvider>(context, listen: false).language;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final lines = update.linesFor(lang);

    final isKk = lang.contains('Қазақ') || lang == 'kk';
    final isUg = lang.contains('Уйғур') || lang == 'ug';

    final whatsNewTitle = isKk
        ? 'Не жаңалық:'
        : isUg
            ? 'نېمىلەر يېڭىلاندى:'
            : 'Что нового:';

    final versionLabel = update.latestVersionName.isNotEmpty
        ? 'v${update.latestVersionName}'
        : 'v${update.latestVersionCode}';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
                blurRadius: 30,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Верхний индикатор свайпа
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),

              // 2. Иконка с градиентом и бейдж версии
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF38BDF8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                TranslationService.t('update_available_title', lang),
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                versionLabel,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF2563EB),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          TranslationService.t('update_available_desc', lang),
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 3. Блок списка изменений (Что нового)
              if (lines.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF334155).withValues(alpha: 0.35)
                        : const Color(0xFFF8FAFC),
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
                            size: 15,
                            color: Color(0xFF2563EB),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            whatsNewTitle,
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...lines.map(
                        (line) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 16,
                                height: 16,
                                margin: const EdgeInsets.only(top: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check_rounded, size: 11, color: Color(0xFF10B981)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  line,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    height: 1.35,
                                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
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
                const SizedBox(height: 18),
              ],

              // 4. Кнопки действий: "Обновить" и "Позже"
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
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
                        TranslationService.t('update_later_btn', lang),
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        _launchStore();
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        elevation: 3,
                        shadowColor: const Color(0xFF2563EB).withValues(alpha: 0.35),
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
                            TranslationService.t('update_btn', lang),
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
