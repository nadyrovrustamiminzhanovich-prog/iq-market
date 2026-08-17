import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:iqmarket/providers/app_config_provider.dart';
import 'package:iqmarket/services/translation_service.dart';
import 'package:iqmarket/services/version_service.dart';

/// Необязательное (не блокирующее) напоминание об обновлении — в отличие от
/// ForceUpdateScreen, которое жёстко блокирует запуск. Юзер может обновиться
/// сразу или закрыть и продолжить пользоваться приложением; при следующем
/// холодном старте (пока не обновится) напомнит снова.
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

  Future<void> _launchStore() async {
    final uri = Uri.parse(update.storeUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Could not launch store URL: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<AppConfigProvider>(context, listen: false).language;
    final lines = update.linesFor(lang);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 30, offset: const Offset(0, -6)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(3)),
                ),
              ),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF4A80F0), Color(0xFF2F6FE0)]),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.system_update_rounded, color: Colors.white, size: 26),
              ),
              const SizedBox(height: 14),
              Text(
                TranslationService.t('update_available_title', lang),
                style: GoogleFonts.inter(fontSize: 19, fontWeight: FontWeight.w800, color: const Color(0xFF1A1D1E)),
              ),
              const SizedBox(height: 4),
              Text(
                TranslationService.t('update_available_desc', lang),
                style: GoogleFonts.inter(fontSize: 13.5, height: 1.4, color: const Color(0xFF64748B)),
              ),
              if (lines.isNotEmpty) ...[
                const SizedBox(height: 16),
                ...lines.map((line) => Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 18,
                            height: 18,
                            margin: const EdgeInsets.only(top: 1),
                            decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.14), shape: BoxShape.circle),
                            child: const Icon(Icons.check_rounded, size: 12, color: Color(0xFF10B981)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(line, style: GoogleFonts.inter(fontSize: 13.5, height: 1.4, color: const Color(0xFF1A1D1E))),
                          ),
                        ],
                      ),
                    )),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    _launchStore();
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A80F0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: Text(
                    TranslationService.t('update_btn', lang),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    TranslationService.t('update_later_btn', lang),
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF64748B)),
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
