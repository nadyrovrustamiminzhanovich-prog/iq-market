import 'package:flutter/material.dart';
import 'package:line_icons/line_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:iqmarket/theme/taxi_theme.dart';
import 'package:iqmarket/screens/chat_screen.dart';
import 'package:iqmarket/models/ad_model.dart';
import 'package:provider/provider.dart';

import 'package:iqmarket/providers/taxi_provider.dart';

class TaxiSupportScreen extends StatelessWidget {
  final TaxiTheme t;
  const TaxiSupportScreen({super.key, required this.t});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TaxiProvider>(context);
    
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.card,
        elevation: 0,
        title: Text(provider.translate('support'), style: GoogleFonts.inter(color: t.text)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: t.text),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(provider.translate('faq'), style: GoogleFonts.inter(color: t.text, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _faq(provider.translate('faq_1_q'), provider.translate('faq_1_a')),
          _faq(provider.translate('faq_2_q'), provider.translate('faq_2_a')),
          _faq(provider.translate('faq_3_q'), provider.translate('faq_3_a')),
          _faq(provider.translate('faq_4_q'), provider.translate('faq_4_a')),
          _faq(provider.translate('faq_5_q'), provider.translate('faq_5_a')),
          _faq(provider.translate('faq_6_q'), provider.translate('faq_6_a')),
          _faq(provider.translate('faq_7_q'), provider.translate('faq_7_a')),
          const SizedBox(height: 30),
          Text(provider.translate('contact_us'), style: GoogleFonts.inter(color: t.text, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _sBtn(LineIcons.robot, provider.translate('ai_assistant'), t.accent, () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(ad: AdModel(
                id: 'support_ai',
                title: provider.translate('ai_assistant_sub'),
                description: 'AI Support Assistant',
                price: 'Online',
                category: 'Support',
                images: [],
                userId: 'support_bot',
                userName: 'IQ Taxi AI',
                userEmail: '',
                timestamp: DateTime.now(),
                location: 'System',
              ))));
          }),
          _sBtn(LineIcons.headset, provider.translate('whatsapp_support'), t.accent, () => launchUrl(Uri.parse('https://wa.me/77089007030'))),
          _sBtn(LineIcons.comments, provider.translate('write_complaint'), t.accent, () async {
            final url = Uri.parse('https://wa.me/77089007030?text=${Uri.encodeComponent(provider.translate('whatsapp_msg'))}');
            if (await canLaunchUrl(url)) await launchUrl(url);
          }),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  Widget _faq(String q, String a) => ExpansionTile(
    title: Text(q, style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.w600, fontSize: 14)),
    children: [
      Padding(padding: const EdgeInsets.all(16), child: Text(a, style: GoogleFonts.inter(color: t.sub, height: 1.5)))
    ],
  );

  Widget _sBtn(IconData i, String l, Color c, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(i, color: c),
          const SizedBox(width: 16),
          Expanded(child: Text(l, style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.bold))),
        ],
      ),
    ),
  );
}
