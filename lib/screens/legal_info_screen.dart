import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:iqmarket/data/legal_texts.dart';

class LegalInfoScreen extends StatelessWidget {
  final String lang;
  const LegalInfoScreen({super.key, required this.lang});

  String _t(String key) {
    final translations = {
      'title': { 'Русский': 'Юридическая информация', 'Қазақша': 'Құқықтық ақпарат', 'Уйғурчә': 'Қанунлуқ учүр' },
      'tos': { 'Русский': 'Пользовательское соглашение', 'Қазақша': 'Пайдаланушы келісімі', 'Уйғурчә': 'Пайдиланғучи келишими' },
      'privacy': { 'Русский': 'Политика конфиденциальности', 'Қазақша': 'Құпиялылық саясаты', 'Уйғурчә': 'Мәхпийлик байанати' },
      'rules': { 'Русский': 'Правила безопасности', 'Қазақша': 'Қауіпсіздік ережелері', 'Уйғурчә': 'Бихәтәрлик қаидилири' },
      'visit_web': { 'Русский': 'Перейти на сайт', 'Қазақша': 'Сайтқа өту', 'Уйғурчә': 'Тор бәткә өтүш' },
      'copy': { 'Русский': '© 2026 IQ-Market. Все права защищены.', 'Қазақша': '© 2026 IQ-Market. Барлық құқықтар қорғалған.', 'Уйғурчә': '© 2026 IQ-Market. Барлиқ һоқуқлар қоғдалған.' },
    };
    return translations[key]?[lang] ?? translations[key]?['Русский'] ?? key;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AppBar(
              backgroundColor: Colors.white.withValues(alpha: 0.7),
              elevation: 0,
              centerTitle: true,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF1A1D1E), size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(_t('title'), style: const TextStyle(color: Color(0xFF1A1D1E), fontWeight: FontWeight.w900, fontSize: 18)),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildLegalCard(
              context,
              icon: Icons.gavel_rounded,
              title: _t('tos'),
              content: LegalTexts.termsOfService,
              color: const Color(0xFF4A80F0),
            ),
            const SizedBox(height: 16),
            _buildLegalCard(
              context,
              icon: Icons.shield_outlined,
              title: _t('privacy'),
              content: LegalTexts.privacyPolicy,
              color: const Color(0xFF10B981),
            ),
            const SizedBox(height: 16),
            _buildLegalCard(
              context,
              icon: Icons.rule_folder_outlined,
              title: _t('rules'),
              content: LegalTexts.publicationRules,
              color: const Color(0xFFF59E0B),
            ),
            const SizedBox(height: 40),
            Center(
              child: Text(
                _t('copy'),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade400, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildLegalCard(BuildContext context, {required IconData icon, required String title, required String content, required Color color}) {
    return GestureDetector(
      onTap: () => _showFullText(context, title, content, title == _t('tos') ? 'terms' : (title == _t('privacy') ? 'privacy' : 'rules')),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 20, offset: const Offset(0, 8)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1A1D1E))),
                  const SizedBox(height: 4),
                  Text('Нажмите, чтобы прочитать полностью', style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey.shade300, size: 16),
          ],
        ),
      ),
    );
  }

  void _showFullText(BuildContext context, String title, String content, String webPath) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1A1D1E)))),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: Colors.black54)),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    Text(
                      content,
                      style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.6, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton.icon(
                      onPressed: () => launchUrl(Uri.parse('https://sites.google.com/view/iqmarket-kz/$webPath'), mode: LaunchMode.externalApplication),
                      icon: const Icon(Icons.open_in_browser_rounded, color: Colors.white),
                      label: Text(_t('visit_web'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4A80F0),
                        minimumSize: const Size(double.infinity, 54),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
