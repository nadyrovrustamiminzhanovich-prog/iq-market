import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:line_icons/line_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:iqmarket/theme/taxi_theme.dart';
import 'package:iqmarket/screens/chat_screen.dart';
import 'package:iqmarket/models/ad_model.dart';

class TaxiProfileViewScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final bool isDriver;
  final TaxiTheme theme;

  const TaxiProfileViewScreen({
    super.key, 
    required this.user, 
    required this.isDriver,
    required this.theme,
  });

  @override
  State<TaxiProfileViewScreen> createState() => _TaxiProfileViewScreenState();
}

class _TaxiProfileViewScreenState extends State<TaxiProfileViewScreen> {
  @override
  void initState() {
    super.initState();
    _enableProtection();
  }

  @override
  void dispose() {
    _disableProtection();
    super.dispose();
  }

  void _enableProtection() async {
    await ScreenProtector.preventScreenshotOn();
  }

  void _disableProtection() async {
    await ScreenProtector.preventScreenshotOff();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final u = widget.user;

    return Scaffold(
      backgroundColor: t.bg,
      body: CustomScrollView(
        slivers: [
          if (widget.isDriver)
            SliverAppBar(
              expandedHeight: 300,
              pinned: true,
              backgroundColor: t.accent,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    GestureDetector(
                      onTap: () => _showFullScreenImage(context, u['img'] ?? ''),
                      child: Hero(
                        tag: 'taxi_p_${u['name']}',
                        child: Image.network(
                          u['img'] ?? 'https://images.unsplash.com/photo-1633332755192-727a05c4013d?w=800',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.3),
                            Colors.transparent,
                            t.bg.withValues(alpha: 0.8),
                            t.bg,
                          ],
                          stops: const [0.0, 0.3, 0.8, 1.0],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverAppBar(
              pinned: true,
              backgroundColor: t.bg,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded, color: t.text),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text('ПРОФИЛЬ', style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 2)),
              centerTitle: true,
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!widget.isDriver) ...[
                    Center(
                      child: Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: t.accent.withValues(alpha: 0.2), width: 3)),
                            child: CircleAvatar(
                              radius: 60,
                              backgroundImage: NetworkImage(u['img'] ?? 'https://images.unsplash.com/photo-1633332755192-727a05c4013d?w=800'),
                              backgroundColor: t.card2,
                            ),
                          ),
                          Positioned(
                            bottom: 5, right: 5,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                              child: const Icon(Icons.check, color: Colors.white, size: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: widget.isDriver ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                          children: [
                            Text(
                              u['name'] ?? 'User',
                              style: GoogleFonts.inter(
                                color: t.text,
                                fontWeight: FontWeight.w900,
                                fontSize: 28,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: widget.isDriver ? MainAxisAlignment.start : MainAxisAlignment.center,
                              children: [
                                Icon(Icons.verified_rounded, color: t.accent, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  'ВЕРИФИЦИРОВАН',
                                  style: GoogleFonts.inter(
                                    color: t.accent,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (widget.isDriver) _ratingBox(t, '4.9'),
                    ],
                  ),
                  if (!widget.isDriver) ...[
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _statChip(t, '4.9', 'РЕЙТИНГ', Icons.star_rounded, Colors.amber),
                        _statChip(t, '154', 'ПОЕЗДОК', LineIcons.car, t.accent),
                        _statChip(t, '2 ГОДА', 'В СЕРВИСЕ', LineIcons.calendar, Colors.blue),
                      ],
                    ),
                  ],
                  const SizedBox(height: 32),
                  if (widget.isDriver) ...[
                    _sectionTitle(t, 'АВТОМОБИЛЬ'),
                    const SizedBox(height: 12),
                    _infoCard(t, LineIcons.car, u['car'] ?? 'Toyota Camry', u['plate'] ?? '01 KZ 777'),
                    const SizedBox(height: 24),
                  ],
                  _sectionTitle(t, 'ИНФОРМАЦИЯ'),
                  const SizedBox(height: 12),
                  _infoCard(t, LineIcons.calendar, 'Дата регистрации', 'Сентябрь 2023'),
                  const SizedBox(height: 12),
                  _infoCard(t, LineIcons.checkCircle, 'Завершено поездок', '150+'),
                  const SizedBox(height: 32),
                  _sectionTitle(t, 'ОТЗЫВЫ'),
                  const SizedBox(height: 12),
                  _reviewItem(t, 'Арман', 'Отличный водитель, доехали быстро и комфортно. Рекомендую!', '5.0'),
                  _reviewItem(t, 'Мадина', 'Вежливый, машина чистая. Спасибо!', '5.0'),
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: _bottomActions(context, t, u),
    );
  }

  Widget _sectionTitle(TaxiTheme t, String title) => Text(
    title,
    style: GoogleFonts.inter(
      color: t.sub,
      fontWeight: FontWeight.w900,
      fontSize: 11,
      letterSpacing: 1.5,
    ),
  );

  Widget _statChip(TaxiTheme t, String val, String label, IconData icon, Color color) => Column(
    children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 24),
      ),
      const SizedBox(height: 8),
      Text(val, style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.w900, fontSize: 16)),
      const SizedBox(height: 2),
      Text(label, style: GoogleFonts.inter(color: t.sub, fontWeight: FontWeight.w800, fontSize: 8, letterSpacing: 0.5)),
    ],
  );

  Widget _ratingBox(TaxiTheme t, String rate) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
    ),
    child: Row(
      children: [
        const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 20),
        const SizedBox(width: 4),
        Text(
          rate,
          style: GoogleFonts.inter(
            color: Colors.amber.shade700,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
      ],
    ),
  );

  Widget _infoCard(TaxiTheme t, IconData icon, String title, String value) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: t.card,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: t.border),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: t.accent.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: t.accent, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  color: t.sub,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.inter(
                  color: t.text,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _reviewItem(TaxiTheme t, String name, String text, String rate) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: t.card,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: t.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              name,
              style: GoogleFonts.inter(
                color: t.text,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
            const Spacer(),
            Icon(Icons.star_rounded, color: const Color(0xFFF59E0B), size: 14),
            Text(
              ' $rate',
              style: GoogleFonts.inter(
                color: t.text,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          text,
          style: GoogleFonts.inter(
            color: t.sub,
            fontSize: 13,
            height: 1.4,
          ),
        ),
      ],
    ),
  );

  Widget _bottomActions(BuildContext context, TaxiTheme t, Map<String, dynamic> u) => Container(
    padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
    decoration: BoxDecoration(
      color: t.bg,
      border: Border(top: BorderSide(color: t.border)),
    ),
    child: Row(
      children: [
        Expanded(
          child: _actionBtn(
            t, 
            'ЧАТ', 
            LineIcons.comment, 
            t.card, 
            t.accent,
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(ad: AdModel(
                id: 'taxi_user_${u['name']}_${DateTime.now().millisecondsSinceEpoch}',
                title: 'Taxi Trip',
                description: 'User profile chat',
                price: 'Taxi',
                category: 'Taxi',
                images: u['img'] != null && u['img'].toString().isNotEmpty ? [u['img']] : [],
                userId: 'taxi_user',
                userName: u['name'] ?? 'User',
                userEmail: '',
                timestamp: DateTime.now(),
                location: '',
              ))))
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _actionBtn(
            t, 
            'ПОЗВОНИТЬ', 
            LineIcons.phone, 
            t.accent, 
            Colors.white,
            () async {
              final url = Uri.parse('tel:${u['phone'] ?? '87001234567'}');
              if (await canLaunchUrl(url)) await launchUrl(url);
            }
          ),
        ),
      ],
    ),
  );

  Widget _actionBtn(TaxiTheme t, String label, IconData icon, Color bg, Color text, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 56,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: bg == t.card ? Border.all(color: t.border) : null,
        boxShadow: [
          BoxShadow(
            color: bg.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: text, size: 20),
          const SizedBox(width: 10),
          Text(
            label,
            style: GoogleFonts.inter(
              color: text,
              fontWeight: FontWeight.w900,
              fontSize: 13,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    ),
  );

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  child: Hero(
                    tag: 'taxi_p_${widget.user['name']}',
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              IgnorePointer(
                child: Center(
                  child: Opacity(
                    opacity: 0.15,
                    child: Transform.rotate(
                      angle: -0.5,
                      child: Text(
                        'COPYRIGHT IQ MARKET\nSECURE VIEW ONLY',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 5,
                        ),
                      ),
                    ),
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
