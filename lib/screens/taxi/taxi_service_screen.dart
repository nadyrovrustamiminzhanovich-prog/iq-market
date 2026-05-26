import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:line_icons/line_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:math';

import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:iqmarket/data/kazakhstan_locations.dart';
import 'package:iqmarket/screens/chat_screen.dart';
import 'package:iqmarket/providers/taxi_provider.dart';
import 'package:iqmarket/theme/taxi_theme.dart';
import 'package:iqmarket/services/notification_service.dart';

// Import newly extracted screens
import 'package:iqmarket/screens/taxi/taxi_settings_screen.dart';
import 'package:iqmarket/screens/taxi/taxi_profile_screen.dart';
import 'package:iqmarket/screens/taxi/taxi_history_screen.dart';
import 'package:iqmarket/screens/taxi/taxi_support_screen.dart';
import 'package:iqmarket/screens/taxi/taxi_user_profile_view.dart';
import 'package:iqmarket/screens/taxi/driver_verification_screen.dart';
import 'package:iqmarket/screens/login_screen.dart';
import 'package:iqmarket/widgets/taxi/taxi_order_card.dart';
import 'package:iqmarket/widgets/taxi/taxi_driver_card.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:iqmarket/widgets/taxi/taxi_ui_components.dart';
import 'package:iqmarket/widgets/auth/taxi_auth_form.dart';
import 'package:iqmarket/models/ad_model.dart';

class TaxiServiceScreen extends StatefulWidget {
  final String lang;
  const TaxiServiceScreen({super.key, required this.lang});

  @override
  State<TaxiServiceScreen> createState() => _TaxiServiceScreenState();
}

class _TaxiServiceScreenState extends State<TaxiServiceScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ImagePicker _picker = ImagePicker();
  final Set<String> _shownAutoResolutionRides = {};
  final TextEditingController _mainPhoneController = TextEditingController();
  final MaskTextInputFormatter _mainPhoneMask = MaskTextInputFormatter(
    mask: '+7 (###) ###-##-##',
    filter: {"#": RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _activeOrderPriceController = TextEditingController();
  final FocusNode _activeOrderPriceFocusNode = FocusNode();

  bool _showFromError = false;
  bool _showToError = false;
  bool _showDateError = false;
  bool _showTimeError = false;
  bool _showPhoneError = false;
  bool _showPriceError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<TaxiProvider>(context, listen: false);
      if (provider.curLang != widget.lang) {
        provider.setLanguage(widget.lang);
      }
      final initialPhone = (provider.phone == "+7 701 000 11 22" || provider.phone == "87010001122") ? "" : provider.phone;
      if (_mainPhoneController.text.isEmpty && initialPhone.isNotEmpty) {
        _mainPhoneController.text = initialPhone;
      }
      final initialPrice = provider.maxPrice > 0 ? provider.maxPrice.toString() : "";
      if (_priceController.text.isEmpty && initialPrice.isNotEmpty) {
        _priceController.text = initialPrice;
      }
    });
  }

  @override
  void dispose() {
    _mainPhoneController.dispose();
    _priceController.dispose();
    _activeOrderPriceController.dispose();
    _activeOrderPriceFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final taxiProvider = Provider.of<TaxiProvider>(context);
    final t = taxiProvider.theme;
    _checkAndShowPendingRidesDialog(taxiProvider, t);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: taxiProvider.isDarkGlobal ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: t.bg,
        drawer: _sideMenu(taxiProvider, t),
        body: Column(
          children: [
            _topBar(taxiProvider, t),
            Expanded(
              child: taxiProvider.loading
                  ? _loader(t)
                  : ListView(
                      padding: EdgeInsets.zero,
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _newHeader(taxiProvider, t),
                        _premiumSelector(taxiProvider, t),
                        taxiProvider.tab == 0 ? _passengerView(taxiProvider, t) : _driverView(taxiProvider, t),
                      ],
                    ),
            )
          ],
        ),

        ),
      ),
    );
  }

  Widget _loader(TaxiTheme t) => Center(child: CircularProgressIndicator(color: t.lime));



  Widget _topBar(TaxiProvider provider, TaxiTheme t) => AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(Icons.menu_rounded, size: 22),
            color: const Color(0xFF1E293B),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF4A80F0),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF4A80F0).withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))
                ],
              ),
              child: Text(
                'IQ',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'TAXI',
              style: GoogleFonts.inter(
                fontSize: 18, 
                fontWeight: FontWeight.w900, 
                color: const Color(0xFF1E293B), 
                letterSpacing: 1,
              ),
            ),
          ],
        ),

        actions: [
          IconButton(
            icon: const Icon(Icons.gpp_maybe_rounded, color: Colors.red, size: 24),
            tooltip: 'SOS',
            onPressed: () => _showSosDialog(provider, t),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            color: const Color(0xFF1E293B),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 8),
        ],
      );

  void _showSosDialog(TaxiProvider provider, TaxiTheme t) {
    HapticFeedback.vibrate();
    
    final List<Map<String, dynamic>> emergencyNumbers = [
      {'number': '102', 'label': 'Полиция', 'desc': 'Криминальные ситуации', 'icon': Icons.local_police_rounded, 'color': const Color(0xFF3B82F6), 'bg': const Color(0xFFEFF6FF)},
      {'number': '103', 'label': 'Скорая помощь', 'desc': 'Медицинские экстренные случаи', 'icon': Icons.medical_services_rounded, 'color': const Color(0xFFF43F5E), 'bg': const Color(0xFFFFF1F2)},
      {'number': '101', 'label': 'Пожарная служба', 'desc': 'Возгорания и пожары', 'icon': Icons.local_fire_department_rounded, 'color': const Color(0xFFF97316), 'bg': const Color(0xFFFFF7ED)},
      {'number': '104', 'label': 'Служба газа', 'desc': 'Утечка газа', 'icon': Icons.oil_barrel_rounded, 'color': const Color(0xFFEAB308), 'bg': const Color(0xFFFEFCE8)},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: t.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(35)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 35,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 24, top: 12, left: 24, right: 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 45,
                  height: 5,
                  decoration: BoxDecoration(
                    color: t.border.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Ultra-Premium Header with beautiful glow
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFE4E6), Color(0xFFFFE4E6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFFECDD3), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE11D48).withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE11D48),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.gpp_maybe_rounded, color: Colors.white, size: 30),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'СЛУЖБА СПАСЕНИЯ SOS',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF9F1239),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Экстренный вызов спецслужб Казахстана',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFFBE123C),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
  
              // Giant Premium Pulse Button for 112
              GestureDetector(
                onTap: () async {
                  HapticFeedback.heavyImpact();
                  final Uri url = Uri.parse('tel:112');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url);
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE11D48), Color(0xFFBE123C)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE11D48).withValues(alpha: 0.4),
                        blurRadius: 25,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.phone_in_talk_rounded, color: Colors.white, size: 26),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          'ВЫЗВАТЬ 112 (ЕДИНАЯ СЛУЖБА)',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              Text(
                'ДРУГИЕ ЭКСТРЕННЫЕ СЛУЖБЫ:',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: t.sub,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12),
  
              Column(
                children: List.generate(emergencyNumbers.length, (idx) {
                  final item = emergencyNumbers[idx];
                  final String number = item['number'];
                  final String label = item['label'];
                  final String desc = item['desc'];
                  final IconData icon = item['icon'];
                  final Color color = item['color'];
                  final Color bg = item['bg'];

                  return GestureDetector(
                    onTap: () async {
                      HapticFeedback.heavyImpact();
                      final Uri url = Uri.parse('tel:$number');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url);
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: color.withValues(alpha: 0.15), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(icon, color: color, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  label,
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF1E293B),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  desc,
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF64748B),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              number,
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
              
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: t.border),
                    ),
                  ),
                  child: Text(
                    'ЗАКРЫТЬ',
                    style: GoogleFonts.inter(
                      color: t.sub,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 15),
            ],
          ),
        ),
      ),
    );
  }


  Widget _newHeader(TaxiProvider provider, TaxiTheme t) => Container(
    padding: const EdgeInsets.fromLTRB(20, 20, 0, 10),
    child: Stack(
      children: [
        SizedBox(
          width: MediaQuery.of(context).size.width * 0.55,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Межгород и\nмежду сёлами',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF1E293B),
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Поездки с комфортом на любые расстояния',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        Positioned(
          right: 25,
          top: 15,
          child: Transform.flip(
            flipX: true,
            child: Image.asset(
              'assets/images/taxi_car.png',
              width: 130,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
            ),
          ),
        ),




      ],
    ),
  );


  Widget _premiumSelector(TaxiProvider provider, TaxiTheme t) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: const Color(0xFFF1F5F9),
      borderRadius: BorderRadius.circular(28),
    ),
    padding: const EdgeInsets.all(4),
    child: Row(
      children: [
        TaxiRoleCard(
          label: provider.translate('pass'),
          icon: Icons.person_rounded,
          isSelected: provider.tab == 0,
          t: t,
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              _showFromError = false;
              _showToError = false;
              _showDateError = false;
              _showTimeError = false;
              _showPhoneError = false;
              _showPriceError = false;
            });
            provider.setTab(0);
          },
        ),
        TaxiRoleCard(
          label: provider.translate('drive'),
          icon: Icons.directions_car_rounded,
          isSelected: provider.tab == 1,
          t: t,
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              _showFromError = false;
              _showToError = false;
              _showDateError = false;
              _showTimeError = false;
              _showPhoneError = false;
              _showPriceError = false;
            });
            provider.setTab(1);
          },
        ),
      ],
    ),
  );



  Widget _sideMenu(TaxiProvider provider, TaxiTheme t) => Drawer(
        backgroundColor: t.bg,
        child: Column(
          children: [
            _drawerHeader(provider, t),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                children: [
                  _drawerItem(t, LineIcons.user, provider.translate('profile'), () => _openProfile(provider, t)),
                  _drawerItem(t, LineIcons.history, provider.translate('history_full'),
                      () => Navigator.push(context, MaterialPageRoute(builder: (_) => TaxiHistoryScreen(t: t)))),
                  _drawerItem(t, LineIcons.headset, provider.translate('support_full'),
                      () => Navigator.push(context, MaterialPageRoute(builder: (_) => TaxiSupportScreen(t: t)))),
                  const Divider(),
                  _drawerItem(t, LineIcons.cog, provider.translate('settings'),
                      () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TaxiSettingsScreen()))),
                  // Empty space where logout used to be
                ],
              ),
            )
          ],
        ),
      );

  Widget _drawerHeader(TaxiProvider provider, TaxiTheme t) => Container(
      padding: const EdgeInsets.fromLTRB(24, 70, 24, 30),
      decoration: BoxDecoration(color: t.card, border: Border(bottom: BorderSide(color: t.border))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                  color: t.accent.withValues(alpha: 0.1), shape: BoxShape.circle, border: Border.all(color: t.lime, width: 2)),
              child: ClipOval(
                  child: provider.profileImage != null
                      ? Image.file(provider.profileImage!, fit: BoxFit.cover)
                      : Center(child: Icon(LineIcons.user, color: t.lime, size: 30)))),
          const SizedBox(width: 16),
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${provider.firstName} ${provider.lastName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: t.text)),
            const SizedBox(height: 4),
            Text(provider.phone,
                style: GoogleFonts.inter(color: t.sub, fontSize: 13, fontWeight: FontWeight.w500))
          ]))
        ]),
      ]));

  Widget _drawerItem(TaxiTheme t, IconData icon, String label, VoidCallback onTap, {Color? color}) =>
      ListTile(leading: Icon(icon, color: color ?? t.lime), title: Text(label, style: GoogleFonts.inter(color: color ?? t.text, fontWeight: FontWeight.w600)), onTap: onTap);

  void _openProfile(TaxiProvider provider, TaxiTheme t) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => TaxiProfileScreen(t: t)));
  }

  void _navigateToLogin(TaxiProvider provider) {
    String loginLang = 'Русский';
    if (provider.curLang == 'kz') {
      loginLang = 'Қазақша';
    } else if (provider.curLang == 'uyg') {
      loginLang = 'Уйғурчә';
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LoginScreen(lang: loginLang),
      ),
    );
  }

  Widget _activeBidsWidget(TaxiProvider provider, TaxiTheme t) {
    final activeBids = provider.activeBids;
    final currentUser = FirebaseAuth.instance.currentUser;
    if (activeBids.isEmpty || currentUser == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: t.accent.withValues(alpha: 0.2), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt_rounded, color: t.accent, size: 22),
              const SizedBox(width: 8),
              Text(
                'Активные предложения торгов (${activeBids.length})',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: t.text,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: activeBids.length,
            separatorBuilder: (_, __) => Divider(color: t.border.withValues(alpha: 0.5), height: 16),
            itemBuilder: (context, index) {
              final bid = activeBids[index];
              final bool isSender = bid['senderId'] == currentUser.uid;
              final int price = bid['offeredPrice'] ?? 0;
              final String name = bid['senderName'] ?? 'Пользователь';
              final String bidId = bid['id'] ?? '';

              return Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: t.bg,
                    backgroundImage: bid['senderImg'] != null && bid['senderImg'].toString().isNotEmpty
                        ? CachedNetworkImageProvider(bid['senderImg'])
                        : null,
                    child: bid['senderImg'] == null || bid['senderImg'].toString().isEmpty
                        ? Icon(Icons.person, color: t.sub)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isSender ? 'Ваше предложение' : name,
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: t.text),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isSender ? 'Ожидание решения • $price ₸' : 'Предлагает цену: $price ₸',
                          style: GoogleFonts.inter(fontSize: 11, color: t.sub),
                        ),
                      ],
                    ),
                  ),
                  if (isSender)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'В обработке',
                        style: GoogleFonts.inter(color: Colors.amber[800], fontWeight: FontWeight.bold, fontSize: 10),
                      ),
                    )
                  else
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () async {
                            HapticFeedback.mediumImpact();
                            await provider.acceptBid(bidId);
                            NotificationService.notify(context, 'Принято', 'Вы согласились на предложение за $price ₸', isSuccess: true);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF84CC16),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Принять',
                              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () async {
                            HapticFeedback.lightImpact();
                            await provider.rejectBid(bidId);
                            NotificationService.notify(context, 'Отклонено', 'Вы отклонили предложение', isSuccess: false);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Отклонить',
                              style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  void _showFeedbackDialog(TaxiProvider provider, TaxiTheme t, String targetUserId, String targetUserName) {
    double selectedRating = 5.0;
    final List<String> tags = ['Быстро', 'Вежливо', 'Чистое авто', 'Безопасное вождение', 'Комфортно'];
    final List<String> selectedTags = [];
    final TextEditingController commentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: t.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (c, ss) => SingleChildScrollView(
          padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom, top: 24, left: 24, right: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: t.border, borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 24),
              Text(
                'Как прошла поездка с',
                style: GoogleFonts.inter(fontSize: 14, color: t.sub, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Text(
                targetUserName,
                style: GoogleFonts.inter(fontSize: 22, color: t.text, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final double starVal = index + 1.0;
                  final bool isSelected = starVal <= selectedRating;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      ss(() => selectedRating = starVal);
                    },
                    child: Icon(
                      isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: isSelected ? Colors.amber : t.border,
                      size: 48,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),
              Text(
                'Что вам понравилось?',
                style: GoogleFonts.inter(fontSize: 13, color: t.sub, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: tags.map((tag) {
                  final bool isSelected = selectedTags.contains(tag);
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      ss(() {
                        if (isSelected) {
                          selectedTags.remove(tag);
                        } else {
                          selectedTags.add(tag);
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? t.accent : t.card,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isSelected ? t.accent : t.border),
                      ),
                      child: Text(
                        tag,
                        style: GoogleFonts.inter(
                          color: isSelected ? Colors.white : t.text,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: commentController,
                maxLines: 3,
                style: GoogleFonts.inter(color: t.text),
                decoration: InputDecoration(
                  hintText: 'Напишите ваш комментарий...',
                  hintStyle: GoogleFonts.inter(color: t.sub),
                  filled: true,
                  fillColor: t.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: t.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: t.accent),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              GestureDetector(
                onTap: () async {
                  Navigator.pop(ctx);
                  HapticFeedback.heavyImpact();

                  final String reviewComment = [
                    if (selectedTags.isNotEmpty) '[${selectedTags.join(", ")}]',
                    commentController.text.trim()
                  ].join(' ').trim();

                  await provider.submitReview(
                    targetUserId: targetUserId,
                    rating: selectedRating,
                    comment: reviewComment.isEmpty ? 'Без комментариев' : reviewComment,
                  );

                  if (mounted) {
                    NotificationService.notify(context, 'Отзыв отправлен', 'Спасибо за вашу оценку!', isSuccess: true);
                  }
                },
                child: Container(
                  width: double.infinity,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF84CC16), Color(0xFF4D7C0F)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF84CC16).withValues(alpha: 0.4), blurRadius: 15, offset: const Offset(0, 8)),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      'ОТПРАВИТЬ ОТЗЫВ',
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  void _showCancelSurveyDialog(TaxiProvider provider, TaxiTheme t, String orderId) {
    String? selectedReason;
    final List<String> reasons = [
      'Договорился с водителем',
      'Передумал ехать',
      'Не нашел водителя',
      'Другая причина'
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: t.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (c, ss) => SingleChildScrollView(
          padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom, top: 24, left: 24, right: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: t.border,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Укажите причину отмены',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  color: t.text,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Ваш отзыв помогает нам улучшать безопасность и качество поездок',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: t.sub,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              ...reasons.map((reason) {
                final bool isSelected = selectedReason == reason;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    ss(() {
                      selectedReason = reason;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: isSelected ? t.accent.withValues(alpha: 0.08) : t.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? t.accent : t.border,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            reason,
                            style: GoogleFonts.inter(
                              color: t.text,
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                        ),
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? t.accent : t.sub.withValues(alpha: 0.3),
                              width: 2,
                            ),
                            color: isSelected ? t.accent : Colors.transparent,
                          ),
                          child: isSelected
                              ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                              : null,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: selectedReason == null
                    ? null
                    : () async {
                        Navigator.pop(ctx);
                        HapticFeedback.heavyImpact();
                        await provider.cancelOrder(orderId, reason: selectedReason);
                        if (mounted) {
                          NotificationService.notify(
                            context,
                            'Заказ отменен',
                            'Ваш заказ успешно удален',
                            isSuccess: false,
                          );
                        }
                      },
                child: Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    color: selectedReason == null ? t.border : Colors.red,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: selectedReason == null
                        ? null
                        : [
                            BoxShadow(
                              color: Colors.red.withValues(alpha: 0.25),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            )
                          ],
                  ),
                  child: Center(
                    child: Text(
                      'ПОДТВЕРДИТЬ ОТМЕНУ',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: selectedReason == null ? t.sub : Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  void _showMatchSuccessDialog({
    required BuildContext context,
    required String driverName,
    required String driverPhone,
    required String driverImg,
    required String driverCar,
    required String driverPlate,
    required int price,
    required String bidId,
    required TaxiProvider provider,
    required TaxiTheme t,
  }) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: t.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: const BoxDecoration(
                color: Color(0xFF84CC16),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              'Вы успешно договорились!',
              style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: t.text),
            ),
            const SizedBox(height: 8),
            Text(
              'Вы приняли предложение от водителя за $price ₸',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: t.sub, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 24),
            // Driver Card Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: t.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: t.border),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: (driverImg.isNotEmpty && driverImg.startsWith('http')) ? NetworkImage(driverImg) : null,
                    child: (driverImg.isEmpty || !driverImg.startsWith('http')) ? const Icon(Icons.person, color: Color(0xFF64748B)) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          driverName,
                          style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15, color: t.text),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$driverCar • $driverPlate',
                          style: GoogleFonts.inter(fontSize: 12, color: t.sub, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Quick call actions
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      HapticFeedback.lightImpact();
                      if (driverPhone.isNotEmpty) {
                        launchUrl(Uri.parse('tel:$driverPhone'));
                      }
                    },
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4A80F0),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4A80F0).withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.phone_rounded, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Позвонить водителю',
                              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () async {
                HapticFeedback.mediumImpact();
                Navigator.pop(ctx);
                
                // Complete order and remove active status
                await provider.acceptBid(bidId); // Updates bids status
                // Mark order completed immediately to return to normal search view
                final orderId = provider.allPassengerOrders.firstWhere(
                  (o) => o['passengerId'] == FirebaseAuth.instance.currentUser?.uid && o['status'] == 'active',
                  orElse: () => <String, dynamic>{},
                )['id'];
                if (orderId != null) {
                  await provider.completeOrder(orderId);
                }
              },
              child: Text(
                'Готово (Закрыть)',
                style: GoogleFonts.inter(color: t.sub, fontWeight: FontWeight.w800, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _activeTripBanner(TaxiProvider provider, TaxiTheme t) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const SizedBox.shrink();

    final myOrder = provider.allPassengerOrders.firstWhere(
      (o) => o['passengerId'] == currentUser.uid && o['status'] == 'active',
      orElse: () => <String, dynamic>{},
    );

    final myDrive = provider.allDrives.firstWhere(
      (d) => d['driverId'] == currentUser.uid && d['status'] == 'active',
      orElse: () => <String, dynamic>{},
    );

    final bool hasOrder = myOrder.isNotEmpty && _tab == 0;
    final bool hasDrive = myDrive.isNotEmpty && _tab == 1;

    if (!hasOrder && !hasDrive) return const SizedBox.shrink();

    final String from = hasOrder ? (myOrder['from'] ?? '') : (myDrive['from'] ?? '');
    final String to = hasOrder ? (myOrder['to'] ?? '') : (myDrive['to'] ?? '');
    final String roleText = hasOrder ? 'Пассажир' : 'Водитель';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.accent.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: const BoxDecoration(color: Color(0xFF84CC16), shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Вы $roleText: $from → $to',
              style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: t.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Text(
              'В ПУТИ',
              style: GoogleFonts.inter(color: t.accent, fontWeight: FontWeight.w900, fontSize: 9, letterSpacing: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  void _promptTripCompletion(TaxiProvider provider, TaxiTheme t, String docId, bool isOrder, String targetUserId, String targetUserName) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: t.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: Text('ЗАВЕРШЕНИЕ ПОЕЗДКИ', style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: t.text)),
        content: Text(
          'Вы уже завершили эту поездку? Если поездка состоялась, вы можете закрыть её прямо сейчас.', 
          style: GoogleFonts.inter(color: t.sub)
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('НЕТ, ЕЩЕ ЕДЕМ', style: GoogleFonts.inter(color: t.sub, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              HapticFeedback.heavyImpact();
              if (isOrder) {
                await provider.completeOrder(docId);
                if (mounted) {
                  NotificationService.notify(context, 'Успешно', 'Заказ успешно завершен!', isSuccess: true);
                  _showFeedbackDialog(provider, t, targetUserId, targetUserName);
                }
              } else {
                await provider.completeRide(docId);
                if (mounted) {
                  NotificationService.notify(context, 'Успешно', 'Рейс успешно завершен!', isSuccess: true);
                  _showFeedbackDialog(provider, t, targetUserId, targetUserName);
                }
              }
            },
            child: Text('ДА, ЗАВЕРШИТЬ', style: GoogleFonts.inter(color: t.accent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _passengerView(TaxiProvider provider, TaxiTheme t) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const SizedBox.shrink();

    // Check if the current passenger has an active order (looking for drivers)
    final myActiveOrder = provider.allPassengerOrders.firstWhere(
      (o) => o['passengerId'] == currentUser.uid && o['status'] == 'active',
      orElse: () => <String, dynamic>{},
    );

    // Check if the current passenger has an accepted/in progress order
    final myAssignedOrder = provider.allPassengerOrders.firstWhere(
      (o) => o['passengerId'] == currentUser.uid && o['status'] == 'accepted',
      orElse: () => <String, dynamic>{},
    );

    if (myActiveOrder.isNotEmpty) {
      return _activeOrderTrackingView(provider, t, myActiveOrder);
    }

    if (myAssignedOrder.isNotEmpty) {
      return _assignedDriverView(provider, t, myAssignedOrder);
    }

    // Default search/create order view
    final drivers = provider.filteredDrives;
    return Column(
      children: [
        _complexForm(provider, t),
        const SizedBox(height: 24),
        // Section header with count badge
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  provider.translate('drivers'),
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B)),
                ),
              ),
              if (provider.isLoggedIn && !provider.isVehicleVerified)
                GestureDetector(
                  onTap: () => _showVerificationInfoDialog(context, provider, t),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.25), width: 1),
                    ),
                    child: const Icon(Icons.verified_user_rounded, color: Color(0xFF0284C7), size: 16),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 12),
        if (drivers.isEmpty) ...[
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: t.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: t.accent.withValues(alpha: 0.18), width: 1),
              boxShadow: [
                BoxShadow(
                  color: t.accent.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: t.accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.near_me_rounded, color: t.accent, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'На этом маршруте пока нет водителей',
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: t.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Создайте заказ сейчас! Водители сразу увидят его на доске и свяжутся с вами по телефону или в чате.',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: t.sub,
                          height: 1.35,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (provider.allDrives.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 12),
              child: Text(
                'Другие активные водители в сети:',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900, color: const Color(0xFF64748B), letterSpacing: 0.5),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: provider.allDrives.take(5).map((d) => TaxiDriverCard(
                  provider: provider,
                  t: t,
                  driver: d,
                  onShowProfile: () => _showUserProfile(provider, t, d['name'] ?? 'Водитель', d['img'] ?? '', d['car'] ?? '', true, d['driverId'] ?? '', isVerified: d['driverVerified'] == true || d['isVehicleVerified'] == true || d['driverVerified'] == 'true'),
                  onCall: () => _handlePassengerCallOrChat(provider, t, d, isCall: true),
                  onChat: () => _handlePassengerCallOrChat(provider, t, d, isCall: false),
                  onNegotiate: () {
                    if (!provider.isLoggedIn) {
                      _navigateToLogin(provider);
                      return;
                    }
                    _showNegotiateDialog(provider, t, {
                      'price': d['price'] ?? 0,
                      'name': d['name'] ?? 'Водитель',
                      'targetId': d['id'] ?? '',
                      'targetType': 'ride',
                      'receiverId': d['driverId'] ?? '',
                    });
                  },
                )).toList(),
              ),
            ),
          ],
        ]
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: drivers.map((d) => TaxiDriverCard(
                provider: provider,
                t: t,
                driver: d,
                onShowProfile: () => _showUserProfile(provider, t, d['name'] ?? 'Водитель', d['img'] ?? '', d['car'] ?? '', true, d['driverId'] ?? '', isVerified: d['driverVerified'] == true || d['isVehicleVerified'] == true || d['driverVerified'] == 'true'),
                onCall: () => _handlePassengerCallOrChat(provider, t, d, isCall: true),
                onChat: () => _handlePassengerCallOrChat(provider, t, d, isCall: false),
                onNegotiate: () {
                  if (!provider.isLoggedIn) {
                    _navigateToLogin(provider);
                    return;
                  }
                  _showNegotiateDialog(provider, t, {
                    'price': d['price'] ?? 0,
                    'name': d['name'] ?? 'Водитель',
                    'targetId': d['id'] ?? '',
                    'targetType': 'ride',
                    'receiverId': d['driverId'] ?? '',
                  });
                },
              )).toList(),
            ),
          ),
        const SizedBox(height: 100)
      ],
    );
  }

  Widget _activeOrderTrackingView(TaxiProvider provider, TaxiTheme t, Map<String, dynamic> order) {
    final orderId = order['id'] ?? '';
    final currentPrice = (order['price'] ?? 0) as int;
    final bids = provider.activeBids.where((b) => b['targetId'] == orderId).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // Order summary card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 20, offset: const Offset(0, 10))
              ],
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'АКТИВНЫЙ ЗАКАЗ',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: const Color(0xFF4A80F0), fontSize: 11, letterSpacing: 1),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4A80F0).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Поиск водителей',
                        style: GoogleFonts.inter(color: const Color(0xFF4A80F0), fontWeight: FontWeight.w800, fontSize: 10),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '${order['from']} → ${order['to']}',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: const Color(0xFF1E293B), fontSize: 16),
                ),
                const SizedBox(height: 12),
                const Divider(color: Color(0xFFF1F5F9)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _infoChip(Icons.calendar_today_rounded, order['date'] == 'today' ? 'Сегодня' : (order['date'] == 'tomorrow' ? 'Завтра' : order['date'] ?? ''), t),
                    _infoChip(Icons.access_time_rounded, order['time'] == 'time' ? 'Время не указано' : order['time'] ?? '', t),
                    _infoChip(Icons.group_rounded, '${order['seats'] ?? 1} мест', t),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          StatefulBuilder(
            builder: (ctx, ss) {
              if (!_activeOrderPriceFocusNode.hasFocus) {
                final currentText = _activeOrderPriceController.text;
                if (currentText.isEmpty || int.tryParse(currentText) != currentPrice) {
                  _activeOrderPriceController.text = currentPrice.toString();
                }
              }
              int typedPrice = int.tryParse(_activeOrderPriceController.text.replaceAll(RegExp(r'\D'), '')) ?? currentPrice;

              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 15, offset: const Offset(0, 5))
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'Предложить новую стоимость поездки (указано $currentPrice ₸):',
                      style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF1E293B), fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            if (typedPrice > currentPrice + 100) {
                              ss(() {
                                typedPrice -= 100;
                                _activeOrderPriceController.text = typedPrice.toString();
                              });
                            } else if (typedPrice > currentPrice) {
                              ss(() {
                                typedPrice = currentPrice;
                                _activeOrderPriceController.text = typedPrice.toString();
                              });
                            }
                          },
                          child: _circleBtn(t, Icons.remove),
                        ),
                        const SizedBox(width: 15),
                        Container(
                          width: 130,
                          alignment: Alignment.center,
                          child: TextField(
                            controller: _activeOrderPriceController,
                            focusNode: _activeOrderPriceFocusNode,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: t.text),
                            decoration: InputDecoration(
                              suffixText: ' ₸',
                              suffixStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: t.text),
                              border: InputBorder.none,
                            ),
                            onChanged: (val) {
                              final valClean = val.replaceAll(RegExp(r'\D'), '');
                              ss(() {
                                if (valClean.isNotEmpty) {
                                  typedPrice = int.tryParse(valClean) ?? currentPrice;
                                } else {
                                  typedPrice = currentPrice;
                                }
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 15),
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            ss(() {
                              if (typedPrice < currentPrice) {
                                typedPrice = currentPrice + 100;
                              } else {
                                typedPrice += 100;
                              }
                              _activeOrderPriceController.text = typedPrice.toString();
                            });
                          },
                          child: _circleBtn(t, Icons.add),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              HapticFeedback.mediumImpact();
                              final newPrice = currentPrice + 100;
                              ss(() {
                                typedPrice = newPrice;
                                _activeOrderPriceController.text = typedPrice.toString();
                              });
                              await provider.updateOrderPrice(orderId, newPrice);
                              if (mounted) {
                                NotificationService.notify(context, 'Цена повышена', 'Вы подняли цену до $newPrice ₸', isSuccess: true);
                              }
                            },
                            child: Container(
                              height: 38,
                              decoration: BoxDecoration(
                                color: const Color(0xFF4A80F0).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF4A80F0).withValues(alpha: 0.1)),
                              ),
                              child: Center(
                                child: Text(
                                  '+100 ₸',
                                  style: GoogleFonts.inter(color: const Color(0xFF4A80F0), fontWeight: FontWeight.w800, fontSize: 11),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              HapticFeedback.mediumImpact();
                              final newPrice = currentPrice + 200;
                              ss(() {
                                typedPrice = newPrice;
                                _activeOrderPriceController.text = typedPrice.toString();
                              });
                              await provider.updateOrderPrice(orderId, newPrice);
                              if (mounted) {
                                NotificationService.notify(context, 'Цена повышена', 'Вы подняли цену до $newPrice ₸', isSuccess: true);
                              }
                            },
                            child: Container(
                              height: 38,
                              decoration: BoxDecoration(
                                color: const Color(0xFF4A80F0).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF4A80F0).withValues(alpha: 0.1)),
                              ),
                              child: Center(
                                child: Text(
                                  '+200 ₸',
                                  style: GoogleFonts.inter(color: const Color(0xFF4A80F0), fontWeight: FontWeight.w800, fontSize: 11),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              HapticFeedback.mediumImpact();
                              final newPrice = currentPrice + 500;
                              ss(() {
                                typedPrice = newPrice;
                                _activeOrderPriceController.text = typedPrice.toString();
                              });
                              await provider.updateOrderPrice(orderId, newPrice);
                              if (mounted) {
                                NotificationService.notify(context, 'Цена повышена', 'Вы подняли цену до $newPrice ₸', isSuccess: true);
                              }
                            },
                            child: Container(
                              height: 38,
                              decoration: BoxDecoration(
                                color: const Color(0xFF4A80F0).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF4A80F0).withValues(alpha: 0.1)),
                              ),
                              child: Center(
                                child: Text(
                                  '+500 ₸',
                                  style: GoogleFonts.inter(color: const Color(0xFF4A80F0), fontWeight: FontWeight.w800, fontSize: 11),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: typedPrice <= currentPrice
                          ? null
                          : () async {
                              _activeOrderPriceFocusNode.unfocus();
                              HapticFeedback.heavyImpact();
                              await provider.updateOrderPrice(orderId, typedPrice);
                              NotificationService.notify(context, 'Цена повышена', 'Вы подняли цену до $typedPrice ₸', isSuccess: true);
                            },
                      child: Container(
                        width: double.infinity,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: typedPrice <= currentPrice
                              ? null
                              : const LinearGradient(
                                  colors: [Color(0xFF4A80F0), Color(0xFF1D4ED8)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                          color: typedPrice <= currentPrice ? const Color(0xFFE2E8F0) : null,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: typedPrice <= currentPrice
                              ? null
                              : [
                                  BoxShadow(
                                    color: const Color(0xFF4A80F0).withValues(alpha: 0.25),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  )
                                ],
                        ),
                        child: Center(
                          child: Text(
                            typedPrice <= currentPrice ? 'УКАЖИТЕ СУММУ БОЛЬШЕ ТЕКУЩЕЙ' : 'ПОВЫСИТЬ СТОИМОСТЬ ДО $typedPrice ₸',
                            style: GoogleFonts.inter(
                              color: typedPrice <= currentPrice ? const Color(0xFF94A3B8) : Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          
          const SizedBox(height: 24),
          
          // Driver Bids Section
          if (bids.isNotEmpty) ...[
            _sectionHeader(t, 'Предложения от водителей (${bids.length})'),
            const SizedBox(height: 12),
            Column(
              children: bids.map((bid) {
                final int bidPrice = bid['offeredPrice'] ?? 0;
                final String driverName = bid['senderName'] ?? 'Водитель';
                final String bidId = bid['id'] ?? '';
                final String driverId = bid['senderId'] ?? '';

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))
                    ],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: const Color(0xFFF1F5F9),
                        backgroundImage: bid['senderImg'] != null && bid['senderImg'].toString().isNotEmpty
                            ? NetworkImage(bid['senderImg'])
                            : null,
                        child: bid['senderImg'] == null || bid['senderImg'].toString().isEmpty
                            ? const Icon(Icons.person, color: Color(0xFF64748B))
                            : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              driverName,
                              style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14, color: const Color(0xFF1E293B)),
                            ),
                            const SizedBox(height: 4),
                            _ratingWidget(provider, t, driverId),
                            const SizedBox(height: 4),
                            Text(
                              'Предлагает: $bidPrice ₸ за место',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF4A80F0)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () async {
                              HapticFeedback.mediumImpact();
                              _showMatchSuccessDialog(
                                context: context,
                                driverName: driverName,
                                driverPhone: bid['senderPhone'] ?? '',
                                driverImg: bid['senderImg'] ?? '',
                                driverCar: bid['senderCar'] ?? 'Машина не указана',
                                driverPlate: bid['senderPlate'] ?? 'Б/Н',
                                price: bidPrice,
                                bidId: bidId,
                                provider: provider,
                                t: t,
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF84CC16),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                'Да',
                                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () async {
                              HapticFeedback.lightImpact();
                              await provider.rejectBid(bidId);
                              if (mounted) {
                                NotificationService.notify(context, 'Отклонено', 'Вы отклонили предложение', isSuccess: false);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.close_rounded, color: Colors.red, size: 16),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              child: Center(
                child: Column(
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4A80F0)),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Ждем откликов от водителей...',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ],
          
          const SizedBox(height: 32),
          
          // Cancel order button
          GestureDetector(
            onTap: () {
              HapticFeedback.heavyImpact();
              _showCancelSurveyDialog(provider, t, orderId);
            },
            child: Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.red.withValues(alpha: 0.1)),
              ),
              child: Center(
                child: Text(
                  'ОТМЕНИТЬ ЗАКАЗ',
                  style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Edit/Modify order button
          GestureDetector(
            onTap: () async {
              HapticFeedback.heavyImpact();
              await provider.cancelOrder(orderId, reason: 'Изменение параметров заказа');
              NotificationService.notify(context, 'Редактирование', 'Вы можете изменить параметры поездки и запустить поиск снова!', isSuccess: true);
            },
            child: Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF4A80F0).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF4A80F0).withValues(alpha: 0.1)),
              ),
              child: Center(
                child: Text(
                  'ИЗМЕНИТЬ ПАРАМЕТРЫ ЗАКАЗА',
                  style: GoogleFonts.inter(color: const Color(0xFF4A80F0), fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _assignedDriverView(TaxiProvider provider, TaxiTheme t, Map<String, dynamic> order) {
    final orderId = order['id'] ?? '';
    final driverId = order['driverId'] ?? 'demo_driver_id';
    final driverName = order['driverName'] ?? 'Водитель';
    final driverPhone = order['driverPhone'] ?? '';
    final driverCar = order['driverCar'] ?? 'Toyota Camry';
    final driverPlate = order['driverPlate'] ?? '777 BBA 05';
    final driverImg = order['driverImg'] ?? '';
    final price = (order['price'] ?? 0) as int;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // Visual trip header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: t.card,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: t.accent.withValues(alpha: 0.15), width: 1.5),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 15, offset: const Offset(0, 5))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF4A80F0), shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Text(
                          'ПОЕЗДКА ПРИНЯТА',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: const Color(0xFF4A80F0), fontSize: 11, letterSpacing: 1),
                        ),
                      ],
                    ),
                    Text(
                      'Стоимость: $price ₸',
                      style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '${order['from']} → ${order['to']}',
                  style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  'Выезд: ${order['date'] == 'today' ? 'Сегодня' : order['date'] == 'tomorrow' ? 'Завтра' : order['date'] ?? ''} в ${order['time']}',
                  style: GoogleFonts.inter(color: t.sub, fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Assigned Driver Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFFF1F5F9)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 15, offset: const Offset(0, 5))
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: const Color(0xFFF1F5F9),
                      backgroundImage: driverImg.isNotEmpty ? NetworkImage(driverImg) : null,
                      child: driverImg.isEmpty ? const Icon(Icons.person, color: Color(0xFF64748B), size: 28) : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                driverName,
                                style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16, color: const Color(0xFF1E293B)),
                              ),
                              if (order['driverVerified'] == true) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.verified_user_rounded, color: Colors.green, size: 16),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          _ratingWidget(provider, t, driverId),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                const Divider(color: Color(0xFFF1F5F9)),
                const SizedBox(height: 20),
                
                // Vehicle detail row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4A80F0).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.directions_car_rounded, color: Color(0xFF4A80F0), size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            driverCar,
                            style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14, color: const Color(0xFF1E293B)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Гос. номер: $driverPlate',
                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Action buttons: Call and Chat
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    if (driverPhone.isNotEmpty) {
                      launchUrl(Uri.parse('tel:$driverPhone'));
                      Future.delayed(const Duration(seconds: 2), () {
                        if (mounted) {
                          _promptTripCompletion(provider, t, orderId, true, driverId, driverName);
                        }
                      });
                    } else {
                      NotificationService.notify(context, 'Ошибка', 'Номер телефона не указан водителем', isSuccess: false);
                    }
                  },
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))
                      ],
                    ),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.phone_rounded, color: Color(0xFF4A80F0), size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Позвонить',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF4A80F0),
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(ad: AdModel(
                      id: 'taxi_chat_$orderId',
                      title: '${order['from']} → ${order['to']}',
                      description: 'Чат по поездке',
                      price: price.toDouble(),
                      category: 'Taxi',
                      images: driverImg.isNotEmpty ? [driverImg] : [],
                      userId: driverId,
                      userName: driverName,
                      userEmail: '',
                      timestamp: DateTime.now(),
                      location: order['from'] ?? '',
                    )))).then((_) {
                      _promptTripCompletion(provider, t, orderId, true, driverId, driverName);
                    });
                  },
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))
                      ],
                    ),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF4A80F0), size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Написать',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF4A80F0),
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          
          // Complete ride button
          GestureDetector(
            onTap: () async {
              HapticFeedback.heavyImpact();
              await provider.completeOrder(orderId);
              if (mounted) {
                NotificationService.notify(context, 'Поездка завершена', 'Благодарим вас за выбор нашего сервиса!', isSuccess: true);
                _showFeedbackDialog(provider, t, driverId, driverName);
              }
            },
            child: Container(
              width: double.infinity,
              height: 60,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF84CC16), Color(0xFF4D7C0F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF84CC16).withValues(alpha: 0.4), blurRadius: 15, offset: const Offset(0, 8))
                ],
              ),
              child: Center(
                child: Text(
                  'ЗАВЕРШИТЬ ПОЕЗДКУ',
                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              HapticFeedback.heavyImpact();
              _showCancelSurveyDialog(provider, t, orderId);
            },
            child: Text(
              'Отменить заказ',
              style: GoogleFonts.inter(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _assignedPassengerView(TaxiProvider provider, TaxiTheme t, Map<String, dynamic> data, {required bool isOrder}) {
    final docId = data['id'] ?? '';
    final passengerName = data['passengerName'] ?? data['name'] ?? 'Пассажир';
    final passengerPhone = data['passengerPhone'] ?? data['phone'] ?? '';
    final passengerImg = data['passengerImg'] ?? data['img'] ?? '';
    final passengerId = data['passengerId'] ?? data['userId'] ?? 'demo_passenger_id';
    final price = (data['price'] ?? 0) as int;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // Visual trip header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: t.card,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: t.accent.withValues(alpha: 0.15), width: 1.5),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 15, offset: const Offset(0, 5))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF4A80F0), shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Text(
                          'АКТИВНЫЙ ЗАКАЗ',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: const Color(0xFF4A80F0), fontSize: 11, letterSpacing: 1),
                        ),
                      ],
                    ),
                    Text(
                      'Стоимость: $price ₸',
                      style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '${data['from']} → ${data['to']}',
                  style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  'Выезд: ${data['date'] == 'today' ? 'Сегодня' : data['date'] == 'tomorrow' ? 'Завтра' : data['date'] ?? ''} в ${data['time']}',
                  style: GoogleFonts.inter(color: t.sub, fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Assigned Passenger Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFFF1F5F9)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 15, offset: const Offset(0, 5))
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: const Color(0xFFF1F5F9),
                      backgroundImage: passengerImg.isNotEmpty ? NetworkImage(passengerImg) : null,
                      child: passengerImg.isEmpty ? const Icon(Icons.person, color: Color(0xFF64748B), size: 28) : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            passengerName,
                            style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16, color: const Color(0xFF1E293B)),
                          ),
                          const SizedBox(height: 4),
                          _ratingWidget(provider, t, passengerId),
                        ],
                      ),
                    ),
                  ],
                ),
                if (data['comment'] != null && data['comment'].toString().trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF64748B), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          data['comment'],
                          style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF475569), height: 1.3, fontStyle: FontStyle.italic),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Action buttons: Call and Chat
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    if (passengerPhone.isNotEmpty) {
                      launchUrl(Uri.parse('tel:$passengerPhone'));
                      Future.delayed(const Duration(seconds: 2), () {
                        if (mounted) {
                          _promptTripCompletion(provider, t, docId, isOrder, passengerId, passengerName);
                        }
                      });
                    } else {
                      NotificationService.notify(context, 'Ошибка', 'Номер телефона не указан пассажиром', isSuccess: false);
                    }
                  },
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))
                      ],
                    ),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.phone_rounded, color: Color(0xFF4A80F0), size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Позвонить',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF4A80F0),
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(ad: AdModel(
                      id: 'taxi_chat_$docId',
                      title: '${data['from']} → ${data['to']}',
                      description: 'Чат по поездке',
                      price: price.toDouble(),
                      category: 'Taxi',
                      images: passengerImg.isNotEmpty ? [passengerImg] : [],
                      userId: passengerId,
                      userName: passengerName,
                      userEmail: '',
                      timestamp: DateTime.now(),
                      location: data['from'] ?? '',
                    )))).then((_) {
                      _promptTripCompletion(provider, t, docId, isOrder, passengerId, passengerName);
                    });
                  },
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))
                      ],
                    ),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF4A80F0), size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Написать',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF4A80F0),
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          
          // Complete ride button
          GestureDetector(
            onTap: () async {
              HapticFeedback.heavyImpact();
              if (isOrder) {
                await provider.completeOrder(docId);
              } else {
                await provider.completeRide(docId);
              }
              if (mounted) {
                NotificationService.notify(context, 'Поездка завершена', 'Благодарим вас за работу!', isSuccess: true);
                _showFeedbackDialog(provider, t, passengerId, passengerName);
              }
            },
            child: Container(
              width: double.infinity,
              height: 60,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF84CC16), Color(0xFF4D7C0F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF84CC16).withValues(alpha: 0.4), blurRadius: 15, offset: const Offset(0, 8))
                ],
              ),
              child: Center(
                child: Text(
                  'ЗАВЕРШИТЬ ПОЕЗДКУ',
                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () async {
              HapticFeedback.heavyImpact();
              final bool? confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: t.bg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  title: Text('Отменить поездку?', style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: t.text)),
                  content: Text('Вы действительно хотите отменить текущую поездку? Это действие отменит связь с пассажиром.', style: GoogleFonts.inter(color: t.sub, fontSize: 13)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Нет', style: GoogleFonts.inter(color: t.sub, fontWeight: FontWeight.bold))),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text('Да, отменить', style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                if (isOrder) {
                  await provider.cancelOrder(docId);
                } else {
                  await provider.cancelRide(docId);
                }
                if (mounted) {
                  NotificationService.notify(context, 'Поездка отменена', 'Связь успешно отменена', isSuccess: false);
                }
              }
            },
            child: Text(
              'Мы не поехали / Отменить',
              style: GoogleFonts.inter(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  void _checkAndShowPendingRidesDialog(TaxiProvider provider, TaxiTheme t) {
    if (!mounted) return;
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // Scan accepted orders
    for (var order in provider.myAcceptedOrders) {
      final orderId = order['id'];
      if (orderId == null || _shownAutoResolutionRides.contains(orderId)) continue;

      final createdAt = order['createdAt'];
      if (createdAt != null) {
        DateTime createdDateTime;
        if (createdAt is Timestamp) {
          createdDateTime = createdAt.toDate();
        } else if (createdAt is int) {
          createdDateTime = DateTime.fromMillisecondsSinceEpoch(createdAt);
        } else {
          createdDateTime = DateTime.tryParse(createdAt.toString()) ?? DateTime.now();
        }

        final diff = DateTime.now().difference(createdDateTime);
        if (diff.inMinutes > 90) { // 1.5 hours
          _shownAutoResolutionRides.add(orderId);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showAutoResolutionDialog(provider, t, order, isOrder: true);
          });
          return; // Show one at a time
        }
      }
    }

    // Scan accepted rides
    for (var ride in provider.myAcceptedRides) {
      final rideId = ride['id'];
      if (rideId == null || _shownAutoResolutionRides.contains(rideId)) continue;

      final createdAt = ride['createdAt'];
      if (createdAt != null) {
        DateTime createdDateTime;
        if (createdAt is Timestamp) {
          createdDateTime = createdAt.toDate();
        } else if (createdAt is int) {
          createdDateTime = DateTime.fromMillisecondsSinceEpoch(createdAt);
        } else {
          createdDateTime = DateTime.tryParse(createdAt.toString()) ?? DateTime.now();
        }

        final diff = DateTime.now().difference(createdDateTime);
        if (diff.inMinutes > 90) {
          _shownAutoResolutionRides.add(rideId);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showAutoResolutionDialog(provider, t, ride, isOrder: false);
          });
          return;
        }
      }
    }
  }

  void _showAutoResolutionDialog(TaxiProvider provider, TaxiTheme t, Map<String, dynamic> data, {required bool isOrder}) {
    final docId = data['id'] ?? '';
    final from = data['from'] ?? '';
    final to = data['to'] ?? '';
    final price = data['price'] ?? 0;
    
    final isDriverRole = data['driverId'] == FirebaseAuth.instance.currentUser?.uid;
        
    final otherName = isDriverRole
        ? (data['passengerName'] ?? data['name'] ?? 'Пассажир')
        : (data['driverName'] ?? 'Водитель');

    showDialog(
      context: context,
      barrierDismissible: false, // Force them to answer!
      builder: (ctx) => Dialog(
        backgroundColor: t.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF84CC16).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.directions_car_rounded, color: Color(0xFF84CC16), size: 36),
              ),
              const SizedBox(height: 20),
              Text(
                'Поездка состоялась? 🚙',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 20, color: t.text),
              ),
              const SizedBox(height: 12),
              Text(
                isDriverRole
                    ? 'Ранее вы связывали заказ из $from в $to с пассажиром $otherName за $price ₸.\n\nПодтвердите, доехали ли вы, чтобы мы корректно рассчитали вашу статистику!'
                    : 'Ранее вы связывали поездку из $from в $to с водителем $otherName за $price ₸.\n\nПодтвердите, доехали ли вы!',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: t.sub, fontSize: 13, height: 1.45),
              ),
              const SizedBox(height: 24),
              
              // Yes, we completed the trip!
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  HapticFeedback.heavyImpact();
                  if (isOrder) {
                    await provider.completeOrder(docId);
                  } else {
                    await provider.completeRide(docId);
                  }
                  if (mounted) {
                    NotificationService.notify(context, 'Успешно завершено!', 'Спасибо, поездка сохранена в статистике.', isSuccess: true);
                    _showFeedbackDialog(provider, t, isDriverRole ? (data['passengerId'] ?? 'demo_passenger_id') : (data['driverId'] ?? 'demo_driver_id'), otherName);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF84CC16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  minimumSize: const Size(double.infinity, 50),
                  elevation: 0,
                ),
                child: Text('Да, мы успешно доехали! ✅', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5)),
              ),
              const SizedBox(height: 10),
              
              // No, we didn't go!
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  HapticFeedback.mediumImpact();
                  if (isOrder) {
                    await provider.cancelOrder(docId);
                  } else {
                    await provider.cancelRide(docId);
                  }
                  if (mounted) {
                    NotificationService.notify(context, 'Поездка отменена', 'Связь успешно сброшена.', isSuccess: false);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.withValues(alpha: 0.1),
                  foregroundColor: Colors.red,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  minimumSize: const Size(double.infinity, 50),
                  elevation: 0,
                ),
                child: Text('Нет, поездка не состоялась ❌', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13.5)),
              ),
              const SizedBox(height: 10),
              
              // Still driving (keep active)
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  HapticFeedback.lightImpact();
                },
                child: Text('Еще едем в пути 🚙', style: GoogleFonts.inter(color: t.sub, fontWeight: FontWeight.bold, fontSize: 12.5)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPhoneBindingSheet(BuildContext context, TaxiProvider provider, TaxiTheme t, VoidCallback onSuccess) {
    final phoneMask = MaskTextInputFormatter(
      mask: '+7 (###) ###-##-##',
      filter: {"#": RegExp(r'[0-9]')},
      type: MaskAutoCompletionType.lazy,
    );

    final TextEditingController phoneC = TextEditingController();
    final TextEditingController otpC = TextEditingController();
    bool codeSent = false;
    String generatedCode = '';
    int secondsLeft = 60;
    Timer? timer;
    bool isVerifying = false;
    bool isOtpError = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (c, ss) {
          void startTimer() {
            secondsLeft = 60;
            timer?.cancel();
            timer = Timer.periodic(const Duration(seconds: 1), (tm) {
              if (secondsLeft > 0) {
                ss(() => secondsLeft--);
              } else {
                tm.cancel();
              }
            });
          }

          return Container(
            padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom, top: 24, left: 24, right: 24),
            decoration: BoxDecoration(
              color: t.bg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 25, offset: const Offset(0, -10))
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: t.border, borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 24),
                
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: t.accent.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.phone_iphone_rounded, color: t.accent, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            !codeSent ? 'Привязка номера' : 'Введите код подтверждения',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 18, color: t.text),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            !codeSent 
                              ? 'Для безопасности и звонков подтвердите телефон' 
                              : 'Отправили 6-значный OTP код на ваш номер',
                            style: GoogleFonts.inter(color: t.sub, fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                if (!codeSent) ...[
                  // Phone Number Input screen
                  Text(
                    'НОМЕР ТЕЛЕФОНА',
                    style: GoogleFonts.inter(color: t.sub, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: t.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: t.border),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '🇰🇿',
                          style: GoogleFonts.inter(fontSize: 16),
                        ),
                        const SizedBox(width: 12),
                        Container(width: 1, height: 24, color: t.border),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: phoneC,
                            inputFormatters: [phoneMask],
                            keyboardType: TextInputType.phone,
                            style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.w700, fontSize: 16),
                            onChanged: (v) {
                              // Sanitization: If user types "8...", replace with "+7" live!
                              if (v.startsWith('8') || v.startsWith('+8')) {
                                String clean = v.replaceAll(RegExp(r'\D'), '');
                                if (clean.startsWith('8')) {
                                  clean = '7' + clean.substring(1);
                                }
                                phoneC.text = phoneMask.maskText(clean);
                                phoneC.selection = TextSelection.fromPosition(
                                  TextPosition(offset: phoneC.text.length),
                                );
                                ss(() {});
                              }
                            },
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: '+7 (701) 000-00-00',
                              hintStyle: GoogleFonts.inter(color: t.sub.withValues(alpha: 0.4)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  GestureDetector(
                    onTap: () async {
                      final cleanNum = phoneMask.getUnmaskedText();
                      if (cleanNum.length != 10) {
                        NotificationService.notify(context, 'Ошибка ввода', 'Введите полный номер телефона', isSuccess: false);
                        return;
                      }
                      
                      HapticFeedback.mediumImpact();
                      ss(() => isVerifying = true);

                      // Generate secure random OTP code
                      generatedCode = List.generate(6, (_) => Random().nextInt(10)).join();
                      final formattedNum = phoneMask.getMaskedText();
                      
                      // Simulate SMS / Telegram dispatch
                      await Future.delayed(const Duration(milliseconds: 800));
                      
                      ss(() {
                        isVerifying = false;
                        codeSent = true;
                      });
                      startTimer();

                      // Show a premium mock SMS overlay or send it if bot is verified!
                      if (mounted) {
                        showDialog(
                          context: context,
                          builder: (cx) => AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            title: Row(
                              children: [
                                const Icon(Icons.sms_rounded, color: Color(0xFF4A80F0), size: 28),
                                const SizedBox(width: 12),
                                Text('SMS-Шлюз IQ-Market', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16)),
                              ],
                            ),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'На номер $formattedNum отправлено SMS с кодом подтверждения:',
                                  style: GoogleFonts.inter(color: Colors.grey[700], fontSize: 13, height: 1.4),
                                ),
                                const SizedBox(height: 16),
                                Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF4A80F0).withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: const Color(0xFF4A80F0).withValues(alpha: 0.15)),
                                    ),
                                    child: Text(
                                      generatedCode,
                                      style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w900, color: const Color(0xFF4A80F0), letterSpacing: 4),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(cx),
                                child: Text('Понятно', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [t.accent, t.accent.withValues(alpha: 0.85)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: t.accent.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 6)),
                        ],
                      ),
                      child: Center(
                        child: isVerifying 
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              'ОТПРАВИТЬ SMS КОД',
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5),
                            ),
                      ),
                    ),
                  ),
                ] else ...[
                  // OTP entry screen
                  Text(
                    'КОД ПОДТВЕРЖДЕНИЯ',
                    style: GoogleFonts.inter(color: t.sub, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: otpC,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 6,
                    style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 8, color: isOtpError ? Colors.red : t.text),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '••••••',
                      hintStyle: GoogleFonts.inter(color: t.sub.withValues(alpha: 0.2), fontSize: 32),
                      border: InputBorder.none,
                    ),
                    onChanged: (val) async {
                      if (val.length == 6) {
                        if (val == generatedCode) {
                          timer?.cancel();
                          ss(() => isVerifying = true);
                          
                          // Save formatted phone number to provider!
                          final String verifiedPhone = phoneMask.getMaskedText();
                          provider.updateProfile(provider.firstName, provider.lastName, verifiedPhone);
                          
                          await Future.delayed(const Duration(milliseconds: 600));
                          
                          if (mounted) {
                            Navigator.pop(ctx); // close bottom sheet
                            HapticFeedback.heavyImpact();
                            NotificationService.notify(context, 'Успешно', 'Телефон успешно подтвержден! ✅', isSuccess: true);
                            onSuccess(); // call action seamlessly!
                          }
                        } else {
                          HapticFeedback.vibrate();
                          ss(() {
                            isOtpError = true;
                            otpC.clear();
                          });
                          Future.delayed(const Duration(seconds: 1), () {
                            ss(() => isOtpError = false);
                          });
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  if (isOtpError)
                    Center(
                      child: Text(
                        'Неверный код. Попробуйте ещё раз!',
                        style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  const SizedBox(height: 20),
                  Center(
                    child: secondsLeft > 0 
                      ? Text(
                          'Повторный код через $secondsLeft сек',
                          style: GoogleFonts.inter(color: t.sub, fontSize: 13, fontWeight: FontWeight.w500),
                        )
                      : TextButton(
                          onPressed: () {
                            ss(() {
                              codeSent = false;
                              otpC.clear();
                            });
                          },
                          child: Text(
                            'Отправить код заново',
                            style: GoogleFonts.inter(color: t.accent, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                  ),
                ],
                const SizedBox(height: 35),
              ],
            ),
          );
        },
      ),
    );
  }

  void _handlePassengerCallOrChat(TaxiProvider provider, TaxiTheme t, Map<String, dynamic> d, {required bool isCall}) {
    if (provider.phone.isEmpty || provider.phone == "+7 701 000 11 22" || provider.phone == "87010001122") {
      _showPhoneBindingSheet(context, provider, t, () {
        _handlePassengerCallOrChat(provider, t, d, isCall: isCall);
      });
      return;
    }

    if (isCall) {
      launchUrl(Uri.parse('tel:${d['phone'] ?? ''}'));
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          _promptTripCompletion(provider, t, d['id'] ?? '', false, d['driverId'] ?? d['userId'] ?? '', d['name'] ?? 'Водитель');
        }
      });
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(ad: AdModel(
        id: 'taxi_${d['name']}_${DateTime.now().millisecondsSinceEpoch}',
        title: '${d['from'] ?? ''} → ${d['to'] ?? ''}',
        description: 'Taxi Trip',
        price: double.tryParse(d['price']?.toString() ?? '0') ?? 0.0,
        category: 'Taxi',
        images: d['img'] != null && d['img'].toString().isNotEmpty ? [d['img']] : [],
        userId: 'taxi_driver',
        userName: d['name'] ?? 'Водитель',
        userEmail: '',
        timestamp: DateTime.now(),
        location: d['from'] ?? '',
      )))).then((_) {
        _promptTripCompletion(provider, t, d['id'] ?? '', false, d['driverId'] ?? d['userId'] ?? '', d['name'] ?? 'Водитель');
      });
    }
  }

  void _handleDriverCallOrChat(TaxiProvider provider, TaxiTheme t, Map<String, dynamic> o, {required bool isCall}) async {
    // Progressive phone number bind check
    if (provider.phone.isEmpty || provider.phone == "+7 701 000 11 22" || provider.phone == "87010001122") {
      _showPhoneBindingSheet(context, provider, t, () {
        _handleDriverCallOrChat(provider, t, o, isCall: isCall);
      });
      return;
    }

    final String passengerPhone = o['phone'] ?? o['passengerPhone'] ?? '';
    final String passengerName = o['name'] ?? o['passengerName'] ?? 'Пассажир';
    final String orderId = o['id'] ?? '';
    final String passengerId = o['passengerId'] ?? o['userId'] ?? '';
    final int price = o['price'] ?? 0;

    if (isCall) {
      if (passengerPhone.isNotEmpty) {
        await launchUrl(Uri.parse('tel:$passengerPhone'));
      } else {
        NotificationService.notify(context, 'Нет номера', 'Телефон пассажира недоступен', isSuccess: false);
        return;
      }
    } else {
      // Open profile / chat view
      _showUserProfile(provider, t, passengerName, o['img'] ?? o['passengerImg'] ?? '', '', false, o['passengerId'] ?? o['userId'] ?? '');
    }

    // Now, after starting call/chat, show the gorgeous verbal handshake dialog!
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              const Icon(Icons.handshake_rounded, color: Color(0xFF84CC16), size: 28),
              const SizedBox(width: 12),
              Text('Договорились?', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 18)),
            ],
          ),
          content: Text(
            'Вы договорились о поездке по телефону с пассажиром $passengerName?\n\nСвяжите заказ в приложении, чтобы поездка отобразилась у обоих и засчиталась в ваш счетчик выполненных поездок после завершения!',
            style: GoogleFonts.inter(color: Colors.grey[700], fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Нет, отмена', style: GoogleFonts.inter(color: Colors.grey[500], fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                HapticFeedback.heavyImpact();
                
                await provider.linkDirectCallMatch(
                  orderId: orderId,
                  passengerId: passengerId,
                  price: price,
                );

                if (mounted) {
                  NotificationService.notify(
                    context, 
                    'Поездка связана! 🚙', 
                    'Связь успешно установлена. После поездки подтвердите прибытие для начисления +1 к завершенным!',
                    isSuccess: true,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF84CC16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: Text('Да, связать!', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      );
    });
  }

  void _showVerificationInfoDialog(BuildContext context, TaxiProvider provider, TaxiTheme t) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(TaxiTheme.radiusModal),
            topRight: Radius.circular(TaxiTheme.radiusModal),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: t.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            
            // Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.verified_user_rounded,
                color: Color(0xFF0284C7),
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            
            // Title
            Text(
              'Получите статус проверенного ✅',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: t.text,
              ),
            ),
            const SizedBox(height: 12),
            
            // Description
            Text(
              'Повысьте доверие к вашему аккаунту! Проверенные пользователи вызывают больше доверия у попутчиков и водителей, получая до 80% больше откликов на свои заказы и поездки.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: t.sub,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 28),
            
            // Buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(TaxiTheme.radiusButton),
                        side: BorderSide(color: t.border),
                      ),
                    ),
                    child: Text(
                      'Закрыть',
                      style: GoogleFonts.inter(
                        color: t.sub,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0088CC), Color(0xFF229ED9)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(TaxiTheme.radiusButton),
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        HapticFeedback.selectionClick();
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const DriverVerificationScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(TaxiTheme.radiusButton),
                        ),
                      ),
                      child: Text(
                        'Пройти верификацию',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _driverView(TaxiProvider provider, TaxiTheme t) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final myAssignedOrderAsDriver = provider.allPassengerOrders.firstWhere(
        (o) => o['driverId'] == currentUser.uid && o['status'] == 'accepted',
        orElse: () => <String, dynamic>{},
      );

      final myAssignedRideAsDriver = provider.allDrives.firstWhere(
        (d) => d['driverId'] == currentUser.uid && d['status'] == 'accepted',
        orElse: () => <String, dynamic>{},
      );

      if (myAssignedOrderAsDriver.isNotEmpty) {
        return _assignedPassengerView(provider, t, myAssignedOrderAsDriver, isOrder: true);
      } else if (myAssignedRideAsDriver.isNotEmpty) {
        return _assignedPassengerView(provider, t, myAssignedRideAsDriver, isOrder: false);
      }
    }

    final orders = provider.filteredOrders;
    
    final bool hasFilter = provider.driverFrom.isNotEmpty || 
                           provider.driverTo.isNotEmpty || 
                           (provider.selDate != 'date' && provider.selDate != 'time' && provider.selDate.isNotEmpty);

    final otherOrders = provider.allPassengerOrders.where((o) {
      if (o['status'] != 'active') return false;
      final bool isCurrentMatch = orders.any((element) => element['id'] == o['id']);
      return !isCurrentMatch;
    }).toList();
    
    return Column(
      children: [
        _activeBidsWidget(provider, t),
        _activeTripBanner(provider, t),
        _createRideButton(provider, t),
        const SizedBox(height: 16),
        _driverSearchForm(provider, t),
        const SizedBox(height: 16),

        _sectionHeader(t, '${provider.translate('orders')} 📦'),
        const SizedBox(height: 8),
        
        if (orders.isEmpty) ...[
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: t.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF4A80F0).withValues(alpha: 0.18), width: 1),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4A80F0).withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A80F0).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.info_outline_rounded, color: Color(0xFF4A80F0), size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'На этом маршруте пока нет заказов',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: t.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          ...orders.map((o) => TaxiOrderCard(
                provider: provider,
                t: t,
                name: o['passengerName'] ?? o['name'] ?? 'Пассажир',
                from: o['from'] ?? '',
                to: o['to'] ?? '',
                price: o['price'] ?? 0,
                seats: o['seats'] ?? 1,
                comment: o['comment'] ?? '',
                isNegotiated: o['isNegotiated'] ?? false,
                created: '${(o['date'] == 'today' || o['date'] == 'tomorrow' || o['date'] == 'yesterday') ? provider.translate(o['date'] ?? '') : (o['date'] ?? '')}${o['time'] == null || o['time'] == 'time' || o['time'].isEmpty ? '' : ', ' + o['time']}',
                img: o['passengerImg'] ?? o['img'] ?? '',
                phone: o['passengerPhone'] ?? o['phone'] ?? '',
                passengerId: o['passengerId'] ?? o['userId'] ?? '',
                onShowProfile: () => _showUserProfile(provider, t, o['passengerName'] ?? o['name'] ?? 'Пассажир', o['passengerImg'] ?? o['img'] ?? '', '', false, o['passengerId'] ?? o['userId'] ?? ''),
                onNegotiate: () {
                  _checkDriverActionGate(provider, t, o, () {
                    _showNegotiateDialog(provider, t, {
                      'price': o['price'] ?? 0,
                      'name': o['passengerName'] ?? o['name'] ?? 'Пассажир',
                      'targetId': o['id'] ?? '',
                      'targetType': 'order',
                      'receiverId': o['passengerId'] ?? o['userId'] ?? '',
                    });
                  });
                },
                onCall: () {
                  _checkDriverActionGate(provider, t, o, () {
                    _handleDriverCallOrChat(provider, t, o, isCall: true);
                  });
                },
                onChat: () {
                  _checkDriverActionGate(provider, t, o, () {
                    _handleDriverCallOrChat(provider, t, o, isCall: false);
                  });
                },
              )),
        ],

        // Always show other active orders from other cities/villages below!
        if (otherOrders.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 24, bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Другие активные заказы в сети:',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: const Color(0xFF64748B), letterSpacing: 0.5),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF64748B).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${otherOrders.length}',
                    style: GoogleFonts.inter(color: const Color(0xFF64748B), fontWeight: FontWeight.bold, fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
          ...otherOrders.take(10).map((o) => TaxiOrderCard(
                provider: provider,
                t: t,
                name: o['passengerName'] ?? o['name'] ?? 'Пассажир',
                from: o['from'] ?? '',
                to: o['to'] ?? '',
                price: o['price'] ?? 0,
                seats: o['seats'] ?? 1,
                comment: o['comment'] ?? '',
                isNegotiated: o['isNegotiated'] ?? false,
                created: '${(o['date'] == 'today' || o['date'] == 'tomorrow' || o['date'] == 'yesterday') ? provider.translate(o['date'] ?? '') : (o['date'] ?? '')}${o['time'] == null || o['time'] == 'time' || o['time'].isEmpty ? '' : ', ' + o['time']}',
                img: o['passengerImg'] ?? o['img'] ?? '',
                phone: o['passengerPhone'] ?? o['phone'] ?? '',
                passengerId: o['passengerId'] ?? o['userId'] ?? '',
                onShowProfile: () => _showUserProfile(provider, t, o['passengerName'] ?? o['name'] ?? 'Пассажир', o['passengerImg'] ?? o['img'] ?? '', '', false, o['passengerId'] ?? o['userId'] ?? ''),
                onNegotiate: () {
                  _checkDriverActionGate(provider, t, o, () {
                    _showNegotiateDialog(provider, t, {
                      'price': o['price'] ?? 0,
                      'name': o['passengerName'] ?? o['name'] ?? 'Пассажир',
                      'targetId': o['id'] ?? '',
                      'targetType': 'order',
                      'receiverId': o['passengerId'] ?? o['userId'] ?? '',
                    });
                  });
                },
                onCall: () {
                  _checkDriverActionGate(provider, t, o, () {
                    _handleDriverCallOrChat(provider, t, o, isCall: true);
                  });
                },
                onChat: () {
                  _checkDriverActionGate(provider, t, o, () {
                    _handleDriverCallOrChat(provider, t, o, isCall: false);
                  });
                },
              )),
        ],
        const SizedBox(height: 100)
      ],
    );
  }

  Widget _driverDashboard(TaxiProvider provider, TaxiTheme t) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: t.card, 
          borderRadius: BorderRadius.circular(28), 
          border: Border.all(color: t.border),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 5))]
        ),
        child: Column(children: [
          GestureDetector(
            onTap: () {
              if (!provider.isLoggedIn) {
                _navigateToLogin(provider);
              } else {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverVerificationScreen()));
              }
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: (provider.isLoggedIn && provider.isVehicleVerified)
                  ? LinearGradient(colors: [const Color(0xFF4A80F0).withValues(alpha: 0.12), const Color(0xFF4A80F0).withValues(alpha: 0.06)])
                  : LinearGradient(colors: [t.accent, t.accent.withValues(alpha: 0.8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(24),
                boxShadow: (provider.isLoggedIn && provider.isVehicleVerified) ? [] : [BoxShadow(color: t.accent.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))]
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: (provider.isLoggedIn && provider.isVehicleVerified) ? 0.0 : 0.2), shape: BoxShape.circle),
                  child: Icon((provider.isLoggedIn && provider.isVehicleVerified) ? Icons.verified_user_rounded : Icons.shield_outlined, 
                      color: (provider.isLoggedIn && provider.isVehicleVerified) ? const Color(0xFF4A80F0) : Colors.white, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                  if (provider.isLoggedIn)
                    Text(
                      provider.isVehicleVerified ? provider.translate('verif_ok') : provider.translate('verif_req'), 
                      style: GoogleFonts.inter(color: provider.isVehicleVerified ? const Color(0xFF4A80F0) : Colors.white, fontWeight: FontWeight.w600, fontSize: 13, letterSpacing: 0.5)
                    ),
                  Padding(
                    padding: EdgeInsets.only(top: provider.isLoggedIn ? 2 : 0),
                    child: Text(
                      !provider.isLoggedIn ? "Войдите, чтобы пройти верификацию" : (provider.isVehicleVerified ? provider.translate('verif_ok') : provider.translate('verif_sub')), 
                      style: GoogleFonts.inter(color: provider.isVehicleVerified ? const Color(0xFF4A80F0) : Colors.white.withValues(alpha: 0.8), fontSize: provider.isLoggedIn ? 10 : 13, fontWeight: FontWeight.bold)
                    ),
                  ),
                ])),
                Icon(Icons.arrow_forward_ios_rounded, color: (provider.isLoggedIn && provider.isVehicleVerified) ? const Color(0xFF4A80F0) : Colors.white, size: 14),
              ]),
            ),
          ),
        ]),
      );

  Widget _quickActions(TaxiTheme t) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Expanded(child: _qBtn(t, LineIcons.robot, 'IQ GPT', () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => TaxiSupportScreen(t: t)));
      })),
      const SizedBox(width: 8),
      Expanded(child: _qBtn(t, LineIcons.history, 'История', () {
         Navigator.push(context, MaterialPageRoute(builder: (_) => TaxiHistoryScreen(t: t)));
      })),
    ]),
  );

  Widget _qBtn(TaxiTheme t, IconData i, String l, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: t.card, 
        borderRadius: BorderRadius.circular(18), 
        border: Border.all(color: t.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))]
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(i, color: t.accent, size: 18),
        const SizedBox(width: 8),
        Text(l, style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.w800, fontSize: 13)),
      ]),
    ),
  );

  Widget _dashItem(TaxiTheme t, String l, String v, IconData i) => Column(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: t.accent.withValues(alpha: 0.08), shape: BoxShape.circle),
          child: Icon(i, color: t.accent, size: 20),
        ),
        const SizedBox(height: 8),
        Text(v, style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.w900, fontSize: 16)),
        const SizedBox(height: 2),
        Text(l.toUpperCase(), style: GoogleFonts.inter(color: t.sub, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1))
      ]);



  Widget _driverAuthRequired(TaxiProvider provider, TaxiTheme t) {
    return TaxiAuthForm(provider: provider, t: t, onSuccess: () => provider.setLoginStatus(true));
  }

  Widget _sectionHeader(TaxiTheme t, String title) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8, top: 12),
    child: Row(children: [
          Container(width: 4, height: 18, decoration: BoxDecoration(color: t.accent, borderRadius: BorderRadius.circular(4))),
          const SizedBox(width: 10),
          Expanded(
              child: Text(title.toUpperCase(),
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900, color: t.sub, letterSpacing: 0.5)))
        ]),
  );

  Widget _driverSearchForm(TaxiProvider provider, TaxiTheme t) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 20, offset: const Offset(0, 10))
        ],
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.6),
      ),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 21,
                  top: 30,
                  bottom: 30,
                  child: Container(
                    width: 1.5,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A80F0).withValues(alpha: 0.3),
                    ),
                  ),
                ),
                Column(children: [
                  _routeRow(t, provider.translate('from'), provider.driverFrom, true, provider, hasError: false, isDriver: true),
                  Padding(
                    padding: const EdgeInsets.only(left: 50, right: 10),
                    child: Divider(height: 1, color: const Color(0xFFE2E8F0)),
                  ),
                  _routeRow(t, provider.translate('to'), provider.driverTo, false, provider, hasError: false, isDriver: true),
                ]),
                Positioned(
                  right: 15,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFF1F5F9)),
                      ),
                      child: const Icon(Icons.swap_vert_rounded, color: Color(0xFF4A80F0), size: 20),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _miniBtn(t, Icons.calendar_today_rounded, 
            provider.selDate == 'date' || provider.selDate.isEmpty ? 'Дата' :
            provider.selDate == 'today' ? 'Сегодня' : 
            provider.selDate == 'tomorrow' ? 'Завтра' : 
            provider.selDate == 'yesterday' ? 'Вчера' : 
            provider.selDate, () => _pickDate(provider, t)),
          const SizedBox(height: 24),
          _actBtn(t, 'ПОИСК 🔍', const Color(0xFF4A80F0), () {
            HapticFeedback.heavyImpact();
            setState(() {
              _showFromError = false;
              _showToError = false;
              _showDateError = false;
            });
            NotificationService.notify(
              context, 
              'Поиск обновлен 🔍', 
              'Показаны заказы по выбранному направлению и все активные поездки Kazakhstana ниже!', 
              isSuccess: true
            );
          }),
        ],
      ),
    );
  }

  Widget _complexForm(TaxiProvider provider, TaxiTheme t) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 20, offset: const Offset(0, 10))
        ],
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.6),
      ),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 21,
                  top: 30,
                  bottom: 30,
                  child: Container(
                    width: 1.5,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A80F0).withValues(alpha: 0.3),
                    ),
                  ),
                ),
                Column(children: [
                  _routeRow(t, provider.translate('from'), provider.from, true, provider, hasError: _showFromError),
                  Padding(
                    padding: const EdgeInsets.only(left: 50, right: 10),
                    child: Divider(height: 1, color: const Color(0xFFE2E8F0)),
                  ),
                  _routeRow(t, provider.translate('to'), provider.to, false, provider, hasError: _showToError),
                ]),
                Positioned(
                  right: 15,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFF1F5F9)),
                      ),
                      child: const Icon(Icons.swap_vert_rounded, color: Color(0xFF4A80F0), size: 20),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _pickDateTimeSequential(provider, t);
                  },
                  child: Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: (_showDateError || _showTimeError) ? const Color(0xFFFFF1F2) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: (_showDateError || _showTimeError)
                            ? const Color(0xFFFDA4AF)
                            : const Color(0xFFE2E8F0),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          color: (_showDateError || _showTimeError) ? const Color(0xFFE11D48) : const Color(0xFF4A80F0),
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'ДАТА И ВРЕМЯ',
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  color: (_showDateError || _showTimeError) ? const Color(0xFFE11D48) : const Color(0xFF64748B),
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 1),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  (provider.selDate.isEmpty || provider.selDate == 'date')
                                      ? 'Выбрать...'
                                      : '${provider.selDate == 'today' ? 'Сегодня' : provider.selDate == 'tomorrow' ? 'Завтра' : provider.selDate}${provider.selTime == 'time' ? '' : ', ' + provider.selTime}',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: (provider.selDate.isEmpty || provider.selDate == 'date')
                                        ? const Color(0xFF94A3B8)
                                        : const Color(0xFF1E293B),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _pickPass(provider, t);
                  },
                  child: Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.group_rounded,
                          color: Color(0xFF4A80F0),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'МЕСТА',
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  color: const Color(0xFF64748B),
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                '${provider.passCnt}',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: const Color(0xFF1E293B),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // ── Сумма заказа / желаемая цена ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            height: 64, // slightly taller
            decoration: BoxDecoration(
              color: _showPriceError ? const Color(0xFFFFF1F2) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _showPriceError ? const Color(0xFFFDA4AF) : const Color(0xFFF1F5F9), width: 1.5),
            ),
            child: Row(
              children: [
                // Tenge symbol badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _showPriceError ? const Color(0xFFFFE4E6) : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '₸',
                    style: GoogleFonts.inter(
                      color: _showPriceError ? const Color(0xFFE11D48) : const Color(0xFF4A80F0),
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.inter(color: _showPriceError ? const Color(0xFFE11D48) : const Color(0xFF1E293B), fontWeight: FontWeight.w800, fontSize: 16),
                    onChanged: (v) {
                      final val = int.tryParse(v.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
                      provider.setMaxPrice(val);
                      if (val > 0) {
                        setState(() => _showPriceError = false);
                      }
                    },
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Сумма',
                      hintStyle: GoogleFonts.inter(color: _showPriceError ? const Color(0xFFFDA4AF) : const Color(0xFF94A3B8), fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                if (_showPriceError) ...[
                  const SizedBox(width: 4),
                  Text('*', style: GoogleFonts.inter(color: const Color(0xFFE11D48), fontWeight: FontWeight.bold, fontSize: 16)),
                ] else if (provider.maxPrice > 0)
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      provider.setMaxPrice(0);
                      _priceController.clear();
                    },
                    child: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 18),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            height: 54,
            decoration: BoxDecoration(
              color: _showPhoneError ? const Color(0xFFFFF1F2) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _showPhoneError ? const Color(0xFFFDA4AF) : const Color(0xFFF1F5F9), width: 1.5),
            ),
            child: Row(
              children: [
                Icon(Icons.phone_android_rounded, color: _showPhoneError ? const Color(0xFFE11D48) : const Color(0xFF4A80F0), size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _mainPhoneController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [_mainPhoneMask],
                    style: GoogleFonts.inter(color: _showPhoneError ? const Color(0xFFE11D48) : const Color(0xFF1E293B), fontSize: 14, fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Ваш номер телефона для связи...',
                      hintStyle: GoogleFonts.inter(color: _showPhoneError ? const Color(0xFFFDA4AF) : const Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w500),
                      counterText: '',
                    ),
                    onChanged: (val) {
                      provider.updateProfile(provider.firstName, provider.lastName, val);
                      final cleanVal = val.replaceAll(RegExp(r'\D'), '');
                      if (cleanVal.length == 11) {
                        setState(() => _showPhoneError = false);
                      }
                    },
                  ),
                ),
                if (_showPhoneError) ...[
                  const SizedBox(width: 4),
                  Text('*', style: GoogleFonts.inter(color: const Color(0xFFE11D48), fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          _actBtn(t, 'ПОЕХАЛИ!', const Color(0xFF4A80F0), () {
            HapticFeedback.heavyImpact();
            if (!provider.isLoggedIn) {
              _navigateToLogin(provider);
              return;
            }

            final String cleanPhone = _mainPhoneMask.getUnmaskedText();
            final bool isPhoneValid = cleanPhone.length == 10;

            setState(() {
              _showFromError = provider.from.isEmpty;
              _showToError = provider.to.isEmpty;
              _showDateError = provider.selDate == 'date' || provider.selDate.isEmpty;
              _showTimeError = provider.selTime == 'time' || provider.selTime.isEmpty;
              _showPhoneError = !isPhoneValid;
            });

            if (_showFromError || _showToError || _showDateError || _showTimeError || _showPhoneError) {
              NotificationService.notify(
                context, 
                'Заполните поездку ⚠️', 
                'Пожалуйста, укажите пункты отправления и назначения, дату, время и ваш номер телефона для публикации!', 
                isSuccess: false
              );
              return;
            }

            _showPassengerOrderConfirmation(provider, t);
          })
        ],
      ),
    );
  }


  Widget _routeRow(TaxiTheme t, String label, String val, bool isF, TaxiProvider provider, {bool hasError = false}) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _openPicker(t, isF, provider);
        setState(() {
          if (isF) _showFromError = false;
          else _showToError = false;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        color: Colors.transparent,
        child: Row(
          children: [
            // Breathtaking Premium Path Point Indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: hasError
                    ? const Color(0xFFFFF1F2)
                    : isF
                        ? const Color(0xFFEFF6FF)
                        : const Color(0xFFF0FDF4),
                shape: BoxShape.circle,
                border: Border.all(
                  color: hasError
                      ? const Color(0xFFFDA4AF)
                      : isF
                          ? const Color(0xFF3B82F6)
                          : const Color(0xFF22C55E),
                  width: 2.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (hasError
                            ? const Color(0xFFE11D48)
                            : isF
                                ? const Color(0xFF3B82F6)
                                : const Color(0xFF22C55E))
                        .withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: isF
                    ? Icon(
                        Icons.circle,
                        color: hasError
                            ? const Color(0xFFE11D48)
                            : const Color(0xFF3B82F6),
                        size: 6.5,
                      )
                    : Icon(
                        Icons.location_on_rounded,
                        color: hasError
                            ? const Color(0xFFE11D48)
                            : const Color(0xFF22C55E),
                        size: 10,
                      ),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: val.isEmpty
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isF ? 'Откуда' : 'Куда',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: hasError ? const Color(0xFFE11D48) : const Color(0xFF94A3B8),
                            letterSpacing: -0.3,
                          ),
                        ),
                        if (hasError)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF1F2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFFDA4AF), width: 0.8),
                            ),
                            child: Text(
                              'укажите',
                              style: GoogleFonts.inter(
                                color: const Color(0xFFE11D48),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isF ? 'ОТКУДА' : 'КУДА',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF94A3B8),
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          val,
                          style: GoogleFonts.inter(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1E293B),
                            letterSpacing: -0.4,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _miniBtn(TaxiTheme t, IconData i, String v, VoidCallback onTap, {double h = 44, bool hasError = false}) => GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
          height: h,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
              color: hasError ? const Color(0xFFFEF2F2) : Colors.white, 
              borderRadius: BorderRadius.circular(12), 
              border: Border.all(color: hasError ? Colors.redAccent.withValues(alpha: 0.6) : const Color(0xFFF1F5F9))),
          child: Row(mainAxisAlignment: MainAxisAlignment.start, children: [
            Icon(i, color: hasError ? Colors.redAccent : const Color(0xFF4A80F0), size: 16),
            const SizedBox(width: 8),
            Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(v,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(color: hasError ? Colors.redAccent : const Color(0xFF1E293B), fontWeight: FontWeight.w600, fontSize: 12)),
                    ),
                    if (hasError) ...[
                      const SizedBox(width: 2),
                      Text('*', style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ],
                ))
          ])));





  Widget _actBtn(TaxiTheme t, String l, Color c, VoidCallback onTap) => Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [c, c.withValues(alpha: 0.85)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: c.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Text(
            l.toUpperCase(),
            style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.5),
          ),
        ),
      );


  Future<void> _openPicker(TaxiTheme t, bool isF, TaxiProvider provider) async {
    String q = '';
    return await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: t.bg,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
        builder: (_) => StatefulBuilder(
            builder: (ctx, ss) => SizedBox(
                height: MediaQuery.of(context).size.height * 0.8,
                child: Column(children: [
                  const SizedBox(height: 12),
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: t.border, borderRadius: BorderRadius.circular(10))),
                  const SizedBox(height: 20),
                  Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: TextField(
                          onChanged: (v) => ss(() => q = v),
                          style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.w700),
                          decoration: InputDecoration(
                              hintText: provider.translate('search_hint'),
                              hintStyle: GoogleFonts.inter(color: t.sub.withValues(alpha: 0.5)),
                              prefixIcon: Icon(Icons.search_rounded, color: t.accent),
                              filled: true,
                              fillColor: t.card,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(vertical: 0)))),
                  const SizedBox(height: 10),
                  Expanded(
                      child: ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          children: () {
                            var all = KazakhstanLocations.hierarchy.entries
                                .expand((e) => e.value)
                                .where((c) => c.toLowerCase().contains(q.toLowerCase()))
                                .toList();
                            if (q.isEmpty) {
                              all.remove('Чунджа');
                              all.remove('Алматы');
                              all.insert(0, 'Чунджа');
                              all.insert(1, 'Алматы');
                            }
                            return all.map((city) =>
                                    ListTile(
                                        leading: const Icon(Icons.location_on_rounded, size: 20, color: Color(0xFF4A80F0)),
                                        title: Text(city, style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.w600)),
                                        onTap: () {
                                          if (isF) {
                                            provider.setFrom(city);
                                          } else {
                                            provider.setTo(city);
                                          }
                                          Navigator.pop(context);
                                        })).toList();
                          } ()))
                ]))));
  }


  Future<void> _pickDateTimeSequential(TaxiProvider provider, TaxiTheme t) async {
    final d = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 30)),
        builder: (ctx, child) => Theme(
            data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.dark(
                    primary: const Color(0xFF4A80F0), onPrimary: Colors.white, surface: t.card, onSurface: t.text)),
            child: child!));
    if (d != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final selected = DateTime(d.year, d.month, d.day);
      
      String dateStr = '';
      if (selected == today) {
        dateStr = 'today';
      } else if (selected == today.add(const Duration(days: 1))) {
        dateStr = 'tomorrow';
      } else {
        final months = [
          provider.translate('jan'), provider.translate('feb'), provider.translate('mar'), provider.translate('apr'),
          provider.translate('may'), provider.translate('jun'), provider.translate('jul'), provider.translate('aug'),
          provider.translate('sep'), provider.translate('oct'), provider.translate('nov'), provider.translate('dec')
        ];
        dateStr = '${d.day} ${months[d.month - 1]}';
      }
      provider.setDate(dateStr);
      setState(() => _showDateError = false);

      final tVal = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.now(),
          builder: (ctx, child) => Theme(
              data: Theme.of(context).copyWith(
                  colorScheme: ColorScheme.dark(
                      primary: const Color(0xFF4A80F0), onPrimary: Colors.white, surface: t.card, onSurface: t.text)),
              child: child!));
      if (tVal != null) {
        provider.setTime('${tVal.hour}:${tVal.minute.toString().padLeft(2, '0')}');
        setState(() => _showTimeError = false);
      }
    }
  }

  Future<void> _pickDate(TaxiProvider provider, TaxiTheme t) async {
    final d = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 30)),
        builder: (ctx, child) => Theme(
            data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.dark(
                    primary: t.accent, onPrimary: Colors.white, surface: t.card, onSurface: t.text)),
            child: child!));
    if (d != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final selected = DateTime(d.year, d.month, d.day);
      
      if (selected == today) {
        provider.setDate('today');
      } else if (selected == today.add(const Duration(days: 1))) {
        provider.setDate('tomorrow');
      } else {
        final months = [
          provider.translate('jan'), provider.translate('feb'), provider.translate('mar'), provider.translate('apr'),
          provider.translate('may'), provider.translate('jun'), provider.translate('jul'), provider.translate('aug'),
          provider.translate('sep'), provider.translate('oct'), provider.translate('nov'), provider.translate('dec')
        ];
        provider.setDate('${d.day} ${months[d.month - 1]}');
      }
      setState(() => _showDateError = false);
    }
  }

  Future<void> _pickTime(TaxiProvider provider, TaxiTheme t) async {
    final tVal = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        builder: (ctx, child) => Theme(
            data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.dark(
                    primary: t.accent, onPrimary: Colors.white, surface: t.card, onSurface: t.text)),
            child: child!));
    if (tVal != null) {
      provider.setTime('${tVal.hour}:${tVal.minute.toString().padLeft(2, '0')}');
      setState(() => _showTimeError = false);
    }
  }

  void _pickPass(TaxiProvider provider, TaxiTheme t) {
    showModalBottomSheet(
        context: context,
        backgroundColor: t.bg,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
        builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: 20),
              Text(provider.translate('sel_seats'), style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                    children: List.generate(
                        7,
                        (i) => GestureDetector(
                            onTap: () {
                              provider.setPassCnt(i + 1);
                              Navigator.pop(context);
                            },
                            child: Container(
                                width: 50,
                                height: 50,
                                margin: const EdgeInsets.symmetric(horizontal: 6),
                                decoration: BoxDecoration(
                                    color: provider.passCnt == i + 1 ? const Color(0xFF4A80F0) : t.card,
                                    borderRadius: BorderRadius.circular(15),
                                    border: Border.all(color: provider.passCnt == i + 1 ? const Color(0xFF4A80F0) : t.border)),
                                child: Center(
                                    child: Text('${i + 1}',
                                        style: GoogleFonts.inter(
                                            color: provider.passCnt == i + 1 ? Colors.white : t.text,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16))))))),
              ),
              const SizedBox(height: 40),
            ]));
  }

  void _showCommentDialog(TaxiProvider provider, TaxiTheme t) {
    final TextEditingController ctrl = TextEditingController(text: provider.comment);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: t.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 24, right: 24, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: t.border, borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 24),
            Text('Комментарий к заказу', style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: t.text, fontSize: 18)),
            const SizedBox(height: 8),
            Text('Напишите пожелания (например, чемодан, детское кресло)', style: GoogleFonts.inter(color: t.sub, fontSize: 13)),
            const SizedBox(height: 20),
            TextField(
              controller: ctrl,
              maxLength: 300,
              maxLines: 4,
              autofocus: true,
              style: GoogleFonts.inter(color: t.text),
              decoration: InputDecoration(
                filled: true,
                fillColor: t.card,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                hintText: 'Введите текст...',
                hintStyle: GoogleFonts.inter(color: t.sub.withValues(alpha: 0.5)),
              ),
            ),
            const SizedBox(height: 20),
            _actBtn(t, 'СОХРАНИТЬ', const Color(0xFF4A80F0), () {
              provider.setComment(ctrl.text);
              Navigator.pop(context);
            }),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  void _showNegotiateDialog(TaxiProvider provider, TaxiTheme t, Map<String, dynamic> d) {
    if (provider.phone.isEmpty || provider.phone == "+7 701 000 11 22" || provider.phone == "87010001122") {
      _showPhoneBindingSheet(context, provider, t, () {
        _showNegotiateDialog(provider, t, d);
      });
      return;
    }

    int myPrice = d['price'];
    final TextEditingController priceCtrl = TextEditingController(text: myPrice.toString());

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: t.bg,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
        builder: (ctx) => StatefulBuilder(
                builder: (c, ss) => SingleChildScrollView(
                  padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom, top: 20, left: 24, right: 24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 40, height: 4, decoration: BoxDecoration(color: t.border, borderRadius: BorderRadius.circular(10))),
                    const SizedBox(height: 24),
                    Text(provider.translate('suggest_price'),
                        style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: t.text, fontSize: 16)),
                    const SizedBox(height: 10),
                    Text('${provider.translate('driver_asks')} ${d['price']} ₸', style: GoogleFonts.inter(color: t.sub, fontSize: 13)),
                    const SizedBox(height: 30),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            if (myPrice > 100) {
                              ss(() {
                                myPrice -= 100;
                                priceCtrl.text = myPrice.toString();
                              });
                            }
                          },
                          child: _circleBtn(t, Icons.remove)),
                      const SizedBox(width: 20),
                      Container(
                        width: 140,
                        alignment: Alignment.center,
                        child: TextField(
                          controller: priceCtrl,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w900, color: t.text),
                          decoration: InputDecoration(
                            suffixText: ' ₸',
                            suffixStyle: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: t.text),
                            border: InputBorder.none,
                          ),
                          onChanged: (val) {
                            final valClean = val.replaceAll(RegExp(r'\D'), '');
                            if (valClean.isNotEmpty) {
                              myPrice = int.tryParse(valClean) ?? 0;
                            } else {
                              myPrice = 0;
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 20),
                      GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            ss(() {
                              myPrice += 100;
                              priceCtrl.text = myPrice.toString();
                            });
                          },
                          child: _circleBtn(t, Icons.add)),

                    ]),
                    const SizedBox(height: 40),
                    GestureDetector(
                      onTap: () async {
                        if (myPrice < 100) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Пожалуйста, укажите корректную стоимость поездки (минимум 100 ₸)! 💰',
                                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                              backgroundColor: const Color(0xFFEF4444),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            )
                          );
                          return;
                        }
                        Navigator.pop(context);
                        final targetId = d['targetId'] ?? '';
                        final targetType = d['targetType'] ?? '';
                        final receiverId = d['receiverId'] ?? '';
                        
                        if (targetId.isNotEmpty && receiverId.isNotEmpty) {
                          NotificationService.notify(context, 'Предложение отправлено', '${provider.translate('offer_sent')} ($myPrice ₸)', isSuccess: true);
                          await provider.sendBid(
                            targetId: targetId,
                            targetType: targetType,
                            receiverId: receiverId,
                            price: myPrice,
                          );
                        } else {
                          NotificationService.notify(context, 'Предложение отправлено', '${provider.translate('offer_sent')} ($myPrice ₸)', isSuccess: true);
                          await Future.delayed(const Duration(seconds: 3));
                          if (mounted) {
                            NotificationService.notify(context, 'Ответ водителя', '${d['name']} ${provider.translate('driver_agrees')} $myPrice ₸!', isSuccess: true);
                          }
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF84CC16), Color(0xFF4D7C0F)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(color: const Color(0xFF84CC16).withValues(alpha: 0.4), blurRadius: 15, offset: const Offset(0, 8)),
                          ],
                          border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.bolt_rounded, color: Colors.white, size: 24),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Text(provider.translate('send_offer').toUpperCase(), 
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.0)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ]),
                )));
  }

  void _showDriverVerificationGateDialog(TaxiProvider provider, TaxiTheme t, {String? customText}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: t.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: Text('ВЕРИФИКАЦИЯ ВОДИТЕЛЯ', style: GoogleFonts.inter(fontWeight: FontWeight.w900)),
        content: Text(
          customText ?? 'Для совершения этого действия необходимо пройти верификацию вашего автомобиля в профиле водителя.', 
          style: GoogleFonts.inter()
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ОТМЕНА', style: GoogleFonts.inter(color: t.sub)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverVerificationScreen()));
            },
            child: Text('ПРОЙТИ', style: GoogleFonts.inter(color: t.accent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _checkDriverActionGate(TaxiProvider provider, TaxiTheme t, Map<String, dynamic> order, VoidCallback onAuthorized) {
    if (!provider.isLoggedIn) {
      _navigateToLogin(provider);
      return;
    }

    final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final String orderFrom = order['from'] ?? '';
    final String orderTo = order['to'] ?? '';

    final bool hasActiveRide = provider.allDrives.any((drive) {
      final bool isMyDrive = drive['driverId'] == currentUserId;
      final bool isMatchingRoute = drive['from'].toString().trim().toLowerCase() == orderFrom.trim().toLowerCase() &&
                                   drive['to'].toString().trim().toLowerCase() == orderTo.trim().toLowerCase();
      
      final bool isActive = drive['status'] == 'active' || drive['status'] == 'accepted';

      bool isRecent = true;
      if (drive['createdAt'] != null) {
        try {
          final timestamp = drive['createdAt'];
          DateTime? createdDate;
          if (timestamp is Timestamp) {
            createdDate = timestamp.toDate();
          } else if (timestamp is String) {
            createdDate = DateTime.tryParse(timestamp);
          } else if (timestamp is int) {
            createdDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
          }
          if (createdDate != null) {
            final difference = DateTime.now().difference(createdDate);
            isRecent = difference.inHours <= 24;
          }
        } catch (_) {}
      }
      
      return isMyDrive && isMatchingRoute && isActive && isRecent;
    });

    if (provider.isVehicleVerified && hasActiveRide) {
      onAuthorized();
    } else {
      _showCreateDrivePromptSheet(provider, t, orderFrom, orderTo);
    }
  }

  void _showCreateDrivePromptSheet(TaxiProvider provider, TaxiTheme t, String from, String to) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 25,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: t.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFEFF6FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                color: Color(0xFF4A80F0),
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Доступ ограничен 🔒',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: t.text,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Создайте объявление о поездке, вы получите доступ к заказам по этому маршруту на 24ч',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14.5,
                color: t.sub,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: t.border),
                      ),
                    ),
                    child: Text(
                      'Назад',
                      style: GoogleFonts.inter(
                        color: t.sub,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      HapticFeedback.heavyImpact();
                      
                      provider.setFrom(from);
                      provider.setTo(to);
                      
                      if (provider.selDate == 'date' || provider.selDate.isEmpty) {
                        provider.setDate('today');
                      }
                      if (provider.selTime == 'time' || provider.selTime.isEmpty) {
                        provider.setTime('12:00');
                      }
                      
                      _showDriverRideConfirmation(provider, t);
                    },
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4A80F0), Color(0xFF2563EB)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4A80F0).withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          'Создать объявление',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _passengerDashboard(TaxiProvider provider, TaxiTheme t) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? "";
    final reviewCount = provider.getUserReviewCount(uid);
    final rating = provider.getUserRating(uid);
    final tripsCount = provider.passengerTripsCount;

    String ratingStr = reviewCount < 5 ? 'Новичок' : '${rating.toStringAsFixed(1)} ★';
    String tripsStr = tripsCount == 0 ? 'Первая!' : '$tripsCount пов.';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.border.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          // Rating
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                const SizedBox(width: 6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(ratingStr, style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.w900, fontSize: 13)),
                    Text(reviewCount < 5 ? 'Оценок: $reviewCount/5' : '$reviewCount отзывов', 
                      style: GoogleFonts.inter(color: t.sub, fontSize: 9, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
          Container(height: 24, width: 1, color: t.border.withValues(alpha: 0.4)),
          // Trips count
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LineIcons.car, color: t.accent, size: 18),
                const SizedBox(width: 6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(tripsStr, style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.w900, fontSize: 13)),
                    Text(tripsCount == 0 ? 'Начните путь' : 'Завершено', 
                      style: GoogleFonts.inter(color: t.sub, fontSize: 9, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
          Container(height: 24, width: 1, color: t.border.withValues(alpha: 0.4)),
          // History Button
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                Navigator.push(context, MaterialPageRoute(builder: (_) => TaxiHistoryScreen(t: t)));
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LineIcons.history, color: t.accent, size: 18),
                  const SizedBox(width: 6),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('ИСТОРИЯ', style: GoogleFonts.inter(color: t.accent, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5)),
                      Text('Все поездки', style: GoogleFonts.inter(color: t.sub, fontSize: 9, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showUserProfile(TaxiProvider provider, TaxiTheme t, String name, String img, String car, bool isDriver, String targetUserId, {bool isVerified = false}) {
    if (!provider.isLoggedIn) {
      _navigateToLogin(provider);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TaxiProfileViewScreen(
          user: {
            'id': targetUserId,
            'name': name,
            'img': img.isNotEmpty ? img : 'https://images.unsplash.com/photo-1633332755192-727a05c4013d?w=800',
            'car': car,
            'phone': '87001234567', // Mock phone
            'verified': isVerified,
          },
          isDriver: isDriver,
          theme: t,
          isCurrentUserVerified: provider.isVehicleVerified,
        ),
      ),
    );
  }

  Widget _circleBtn(TaxiTheme t, IconData i) => Container(
    width: 50, height: 50,
    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: t.border, width: 2)),
    child: Icon(i, color: t.lime),
  );

  Widget _ratingWidget(TaxiProvider provider, TaxiTheme t, String userId, {double size = 12}) {
    final int count = provider.getUserReviewCount(userId);
    final double rating = provider.getUserRating(userId);

    if (count < 5) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, color: Colors.amber.withValues(alpha: 0.35), size: size + 2),
          const SizedBox(width: 4),
          Text(
            'Новый (оценок: $count/5)',
            style: GoogleFonts.inter(fontSize: size - 1, color: t.sub, fontWeight: FontWeight.w600),
          ),
        ],
      );
    } else {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, color: Colors.amber, size: size + 2),
          const SizedBox(width: 4),
          Text(
            '$rating',
            style: GoogleFonts.inter(fontSize: size, fontWeight: FontWeight.bold, color: t.text),
          ),
          const SizedBox(width: 6),
          Text(
            '($count отзывов)',
            style: GoogleFonts.inter(fontSize: size - 1, color: t.sub, fontWeight: FontWeight.w500),
          ),
        ],
      );
    }
  }

  Widget _createRideButton(TaxiProvider provider, TaxiTheme t) {
    return GestureDetector(
      onTap: () {
        if (!provider.isLoggedIn) {
          _navigateToLogin(provider);
          return;
        }

        if (provider.phone.isEmpty || provider.phone == "+7 701 000 11 22" || provider.phone == "87010001122") {
          _showPhoneBindingSheet(context, provider, t, () {
            if (!provider.isVehicleVerified) {
              _showDriverVerificationGateDialog(
                provider, 
                t, 
                customText: 'Для создания собственных поездок необходимо пройти верификацию вашего автомобиля в профиле водителя.'
              );
            } else {
              _showDriverRideConfirmation(provider, t);
            }
          });
        } else if (!provider.isVehicleVerified) {
          _showDriverVerificationGateDialog(
            provider, 
            t, 
            customText: 'Для создания собственных поездок необходимо пройти верификацию вашего автомобиля в профиле водителя.'
          );
        } else {
          _showDriverRideConfirmation(provider, t);
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: t.accent.withValues(alpha: 0.15), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: t.accent.withValues(alpha: 0.04),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF84CC16), Color(0xFF65A30D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_road_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Создать поездку 🚗',
                    style: GoogleFonts.inter(
                      color: t.text,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Добавьте свой рейс для поиска пассажиров',
                    style: GoogleFonts.inter(
                      color: t.sub,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: t.sub.withValues(alpha: 0.5), size: 16),
          ],
        ),
      ),
    );
  }

  void _showPassengerOrderConfirmation(TaxiProvider provider, TaxiTheme t) {
    int price = provider.maxPrice > 0 ? provider.maxPrice : 3000;
    int seats = provider.passCnt;
    String comment = provider.comment;
    final TextEditingController commentC = TextEditingController(text: comment);
    final TextEditingController priceCtrl = TextEditingController(text: price.toString());
    bool isPublishing = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: t.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (ctx) => StatefulBuilder(
        builder: (c, ss) => SingleChildScrollView(
          padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom, top: 20, left: 24, right: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: t.border, borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 24),
              Text(
                'Подтверждение заказа 🚗',
                style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: t.text, fontSize: 18),
              ),
              const SizedBox(height: 16),
              
              // Destination card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.circle_rounded, color: Color(0xFF4A80F0), size: 12),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${provider.from} → ${provider.to}',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: t.text, fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _infoChip(Icons.calendar_today_rounded, provider.selDate == 'today' ? 'Сегодня' : (provider.selDate == 'tomorrow' ? 'Завтра' : provider.selDate), t),
                        _infoChip(Icons.access_time_rounded, provider.selTime == 'time' ? 'Время не указано' : provider.selTime, t),
                        _infoChip(Icons.group_rounded, '$seats мест', t),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              Text('Ваша цена за место (₸)', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: t.text, fontSize: 13, letterSpacing: 0.5)),
              const SizedBox(height: 10),
              // Price Card with elegant border
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        if (price > 100) {
                          ss(() {
                            price -= 100;
                            priceCtrl.text = price.toString();
                          });
                        }
                      },
                      child: _circleBtn(t, Icons.remove),
                    ),
                    const SizedBox(width: 20),
                    Container(
                      width: 140,
                      alignment: Alignment.center,
                      child: TextField(
                        controller: priceCtrl,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w900, color: t.text),
                        decoration: InputDecoration(
                          suffixText: ' ₸',
                          suffixStyle: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: t.text),
                          border: InputBorder.none,
                        ),
                        onChanged: (val) {
                          final valClean = val.replaceAll(RegExp(r'\D'), '');
                          if (valClean.isNotEmpty) {
                            price = int.tryParse(valClean) ?? 0;
                          } else {
                            price = 0;
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 20),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        ss(() {
                          price += 100;
                          priceCtrl.text = price.toString();
                        });
                      },
                      child: _circleBtn(t, Icons.add),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              Text('Комментарий к заказу', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: t.text, fontSize: 13, letterSpacing: 0.5)),
              const SizedBox(height: 10),
              // Comment Container with elegant border
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                ),
                child: TextField(
                  controller: commentC,
                  maxLength: 200,
                  style: GoogleFonts.inter(color: t.text, fontSize: 14),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Напишите пожелания водителям...',
                    hintStyle: GoogleFonts.inter(color: t.sub.withValues(alpha: 0.5), fontSize: 13),
                    counterText: '',
                  ),
                ),
              ),
              const SizedBox(height: 32),
              
              isPublishing
                ? const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()))
                : _actBtn(t, 'Опубликовать заказ', const Color(0xFF4A80F0), () async {
                    HapticFeedback.heavyImpact();
                    ss(() => isPublishing = true);
                    if (price < 100) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Пожалуйста, укажите корректную стоимость поездки (минимум 100 ₸)! 💰',
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: const Color(0xFFEF4444),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        )
                      );
                      ss(() => isPublishing = false);
                      return;
                    }
                    final cleanPhone = provider.phone.replaceAll(RegExp(r'\D'), '');
                    if (cleanPhone.length < 11) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.phone_android_rounded, color: Colors.white, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Для публикации поездки необходимо указать ваш номер телефона. Это поможет водителю быстро связаться с вами! 📞', 
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12, color: Colors.white, height: 1.3),
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: const Color(0xFFEF4444),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          duration: const Duration(seconds: 4),
                        ),
                      );
                      ss(() => isPublishing = false);
                      return;
                    }
                    try {
                      await provider.createPassengerOrder(
                        from: provider.from,
                        to: provider.to,
                        date: provider.selDate,
                        time: provider.selTime,
                        seats: seats,
                        price: price,
                        comment: commentC.text,
                      );
                      if (mounted) {
                        NotificationService.notify(
                          context,
                          'Заказ опубликован',
                          'Ваш заказ успешно добавлен и виден водителям!',
                          isSuccess: true,
                        );
                        Navigator.pop(context);
                      }
                    } catch (e) {
                      if (mounted) {
                        NotificationService.notify(
                          context,
                          'Ошибка',
                          'Не удалось создать заказ. Попробуйте еще раз.',
                          isSuccess: false,
                        );
                      }
                    } finally {
                      ss(() => isPublishing = false);
                    }
                  }),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  void _showDriverRideConfirmation(TaxiProvider provider, TaxiTheme t) {
    String localFrom = provider.from;
    String localTo = provider.to;
    String localDate = (provider.selDate == 'date' || provider.selDate.isEmpty) ? 'today' : provider.selDate;
    String localTime = (provider.selTime == 'time' || provider.selTime.isEmpty) ? '12:00' : provider.selTime;
    int price = provider.maxPrice > 0 ? provider.maxPrice : 3000;
    int seats = 4;
    
    final MaskTextInputFormatter sheetPhoneMask = MaskTextInputFormatter(
      mask: '+7 (###) ###-##-##',
      filter: {"#": RegExp(r'[0-9]')},
      type: MaskAutoCompletionType.lazy,
    );
    final TextEditingController phoneC = TextEditingController();
    final initialPhone = (provider.phone == "+7 701 000 11 22" || provider.phone == "87010001122") ? "" : provider.phone;
    if (initialPhone.isNotEmpty) {
      phoneC.text = initialPhone;
    }
    
    final TextEditingController commentC = TextEditingController();
    final TextEditingController priceCtrl = TextEditingController(text: price.toString());
    bool isPublishing = false;
    
    bool sFromError = false;
    bool sToError = false;
    bool sDateError = false;
    bool sTimeError = false;
    bool sPhoneError = false;
    bool sPriceError = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (c, ss) => SingleChildScrollView(
          padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom, top: 20, left: 24, right: 24),
          child: Container(
            padding: const EdgeInsets.only(top: 10, left: 20, right: 20, bottom: 30),
            decoration: BoxDecoration(
              color: t.bg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(35)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 25, offset: const Offset(0, -10))
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: t.border, borderRadius: BorderRadius.circular(10)))),
                const SizedBox(height: 24),
                
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF84CC16).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add_road_rounded, color: Color(0xFF84CC16), size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Создать поездку 🚗',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: t.text, fontSize: 18),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Пассажиры увидят ваш рейс в общем списке',
                            style: GoogleFonts.inter(color: t.sub, fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Route Picker Card inside sheet
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: (sFromError || sToError) ? const Color(0xFFFDA4AF) : const Color(0xFFE2E8F0), width: (sFromError || sToError) ? 1.5 : 1.0),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        left: 21,
                        top: 30,
                        bottom: 30,
                        child: Container(
                          width: 1.5,
                          decoration: BoxDecoration(
                            color: const Color(0xFF4A80F0).withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                      Column(children: [
                        // From Row
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            _openPicker(t, true, provider).then((_) {
                              ss(() {
                                localFrom = provider.from;
                                sFromError = false;
                              });
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                            color: Colors.transparent,
                            child: Row(children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: sFromError ? const Color(0xFFE11D48) : const Color(0xFF4A80F0),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: sFromError ? const Color(0xFFFDA4AF) : const Color(0xFF4A80F0), width: 2),
                                ),
                                child: const Center(child: Icon(Icons.circle, color: Colors.white, size: 6)),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('ОТКУДА', style: GoogleFonts.inter(fontSize: 10, color: sFromError ? const Color(0xFFE11D48) : const Color(0xFF94A3B8), fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 2),
                                  Text(
                                    localFrom.isEmpty ? 'Выберите город отправления' : localFrom,
                                    style: GoogleFonts.inter(color: localFrom.isEmpty ? const Color(0xFF94A3B8) : t.text, fontWeight: FontWeight.w800, fontSize: 14),
                                  ),
                                ]),
                              ),
                            ]),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 50, right: 10),
                          child: Divider(height: 1, color: const Color(0xFFE2E8F0)),
                        ),
                        // To Row
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            _openPicker(t, false, provider).then((_) {
                              ss(() {
                                localTo = provider.to;
                                sToError = false;
                              });
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                            color: Colors.transparent,
                            child: Row(children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: sToError ? const Color(0xFFFDA4AF) : const Color(0xFF4A80F0), width: 2),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('КУДА', style: GoogleFonts.inter(fontSize: 10, color: sToError ? const Color(0xFFE11D48) : const Color(0xFF94A3B8), fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 2),
                                  Text(
                                    localTo.isEmpty ? 'Выберите город прибытия' : localTo,
                                    style: GoogleFonts.inter(color: localTo.isEmpty ? const Color(0xFF94A3B8) : t.text, fontWeight: FontWeight.w800, fontSize: 14),
                                  ),
                                ]),
                              ),
                            ]),
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Date & Time Row inside sheet
                Row(children: [
                  Expanded(
                    child: _miniBtn(t, Icons.calendar_today_rounded, 
                      localDate == 'today' ? 'Сегодня' : 
                      localDate == 'tomorrow' ? 'Завтра' : 
                      localDate == 'yesterday' ? 'Вчера' : 
                      localDate.isEmpty || localDate == 'date' ? 'Дата' : localDate, 
                      () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 30)),
                          builder: (ctx, child) => Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: ColorScheme.dark(
                                primary: t.accent, onPrimary: Colors.white, surface: t.card, onSurface: t.text
                              )
                            ),
                            child: child!
                          )
                        );
                        if (d != null) {
                          final now = DateTime.now();
                          final today = DateTime(now.year, now.month, now.day);
                          final selected = DateTime(d.year, d.month, d.day);
                          ss(() {
                            if (selected == today) {
                              localDate = 'today';
                            } else if (selected == today.add(const Duration(days: 1))) {
                              localDate = 'tomorrow';
                            } else {
                              final months = [
                                'янв', 'фев', 'мар', 'апр', 'май', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'
                              ];
                              localDate = '${d.day} ${months[d.month - 1]}';
                            }
                            sDateError = false;
                          });
                        }
                      },
                      hasError: sDateError
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _miniBtn(t, Icons.access_time_rounded, 
                      localTime == 'time' ? 'Время' : localTime, 
                      () async {
                        final tVal = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                          builder: (ctx, child) => Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: ColorScheme.dark(
                                primary: t.accent, onPrimary: Colors.white, surface: t.card, onSurface: t.text
                              )
                            ),
                            child: child!
                          )
                        );
                        if (tVal != null) {
                          ss(() {
                            localTime = '${tVal.hour}:${tVal.minute.toString().padLeft(2, '0')}';
                            sTimeError = false;
                          });
                        }
                      },
                      hasError: sTimeError
                    ),
                  ),
                ]),
                const SizedBox(height: 16),

                // Phone Input inside sheet
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  height: 54,
                  decoration: BoxDecoration(
                    color: sPhoneError ? const Color(0xFFFFF1F2) : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: sPhoneError ? const Color(0xFFFDA4AF) : const Color(0xFFF1F5F9), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.phone_android_rounded, color: sPhoneError ? const Color(0xFFE11D48) : const Color(0xFF4A80F0), size: 18),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: phoneC,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [sheetPhoneMask],
                          style: GoogleFonts.inter(color: sPhoneError ? const Color(0xFFE11D48) : const Color(0xFF1E293B), fontSize: 14, fontWeight: FontWeight.w700),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Ваш номер телефона для связи...',
                            hintStyle: GoogleFonts.inter(color: sPhoneError ? const Color(0xFFFDA4AF) : t.sub.withValues(alpha: 0.5), fontSize: 13, fontWeight: FontWeight.w500),
                            counterText: '',
                          ),
                          onChanged: (val) {
                            final cleanVal = val.replaceAll(RegExp(r'\D'), '');
                            if (cleanVal.length == 10) {
                              ss(() => sPhoneError = false);
                            }
                          },
                        ),
                      ),
                      if (sPhoneError) ...[
                        const SizedBox(width: 4),
                        Text('*', style: GoogleFonts.inter(color: const Color(0xFFE11D48), fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                Text(
                  'ДОСТУПНО МЕСТ ДЛЯ ПОСАДКИ',
                  style: GoogleFonts.inter(color: t.sub, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                    8,
                    (i) => Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          ss(() => seats = i + 1);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: seats == i + 1 
                              ? const LinearGradient(colors: [Color(0xFF84CC16), Color(0xFF65A30D)])
                              : null,
                            color: seats == i + 1 ? null : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: seats == i + 1 ? const Color(0xFF84CC16) : const Color(0xFFE2E8F0),
                              width: 1.5,
                            ),
                            boxShadow: seats == i + 1 
                              ? [BoxShadow(color: const Color(0xFF84CC16).withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 4))]
                              : [],
                          ),
                          child: Center(
                            child: Text(
                              '${i + 1}',
                              style: GoogleFonts.inter(
                                  color: seats == i + 1 ? Colors.white : t.text,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  'ЦЕНА ЗА 1 МЕСТО',
                  style: GoogleFonts.inter(color: t.sub, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: sPriceError ? const Color(0xFFFFF1F2) : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: sPriceError ? const Color(0xFFFDA4AF) : const Color(0xFFF1F5F9), width: 1.5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          if (price > 100) {
                            ss(() {
                              price -= 100;
                              priceCtrl.text = price.toString();
                              sPriceError = false;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: const Icon(Icons.remove, color: Color(0xFF1E293B), size: 20),
                        ),
                      ),
                      Container(
                        width: 140,
                        alignment: Alignment.center,
                        child: TextField(
                          controller: priceCtrl,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w900, color: sPriceError ? const Color(0xFFE11D48) : t.text),
                          decoration: InputDecoration(
                            suffixText: ' ₸',
                            suffixStyle: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: sPriceError ? const Color(0xFFE11D48) : t.text),
                            border: InputBorder.none,
                          ),
                          onChanged: (val) {
                            final valClean = val.replaceAll(RegExp(r'\D'), '');
                            if (valClean.isNotEmpty) {
                              price = int.tryParse(valClean) ?? 0;
                            } else {
                              price = 0;
                            }
                            if (price >= 100) {
                              ss(() => sPriceError = false);
                            }
                          },
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          ss(() {
                            price += 100;
                            priceCtrl.text = price.toString();
                            sPriceError = false;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: const Icon(Icons.add, color: Color(0xFF1E293B), size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                Text(
                  'КОММЕНТАРИЙ К ПОЕЗДКЕ',
                  style: GoogleFonts.inter(color: t.sub, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: commentC,
                  maxLength: 200,
                  style: GoogleFonts.inter(color: t.text, fontSize: 14, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(color: Color(0xFFF1F5F9), width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(color: Color(0xFF84CC16), width: 1.5),
                    ),
                    hintText: 'Например: пустой багажник, выезд с автовокзала...',
                    hintStyle: GoogleFonts.inter(color: t.sub.withValues(alpha: 0.4), fontSize: 13),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 32),
                
                isPublishing
                  ? const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()))
                  : GestureDetector(
                      onTap: () async {
                        HapticFeedback.heavyImpact();
                        
                        final cleanPhone = phoneC.text.replaceAll(RegExp(r'\D'), '');
                        final bool isPhoneValid = cleanPhone.length == 11 || cleanPhone.length == 10;
                        
                        ss(() {
                          sFromError = localFrom.isEmpty;
                          sToError = localTo.isEmpty;
                          sDateError = localDate.isEmpty || localDate == 'date';
                          sTimeError = localTime.isEmpty || localTime == 'time';
                          sPhoneError = !isPhoneValid;
                          sPriceError = price < 100;
                        });
                        
                        if (sFromError || sToError || sDateError || sTimeError || sPhoneError || sPriceError) {
                          NotificationService.notify(
                            context,
                            'Заполните детали 📋',
                            'Пожалуйста, укажите пункты поездки, дату, время, сумму и телефон!',
                            isSuccess: false
                          );
                          return;
                        }

                        ss(() => isPublishing = true);
                        try {
                          // Update provider profile phone if it was modified
                          if (phoneC.text.isNotEmpty) {
                            provider.updateProfile(provider.firstName, provider.lastName, phoneC.text);
                          }

                          await provider.createDriverRide(
                            from: localFrom,
                            to: localTo,
                            date: localDate,
                            time: localTime,
                            seats: seats,
                            price: price,
                            comment: commentC.text,
                          );
                          if (mounted) {
                            NotificationService.notify(
                              context,
                              'Поездка создана 🎉',
                              'Ваш рейс успешно добавлен и виден пассажирам!',
                              isSuccess: true,
                            );
                            Navigator.pop(context);
                          }
                        } catch (e) {
                          if (mounted) {
                            NotificationService.notify(
                              context,
                              'Ошибка',
                              'Не удалось создать поездку. Попробуйте еще раз.',
                              isSuccess: false,
                            );
                          }
                        } finally {
                          ss(() => isPublishing = false);
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        height: 58,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4A80F0), Color(0xFF2563EB)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(color: const Color(0xFF4A80F0).withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 6)),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            'ПОЕХАЛИ!',
                            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5),
                          ),
                        ),
                      ),
                    ),
                const SizedBox(height: 15),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text, TaxiTheme t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF4A80F0), size: 13),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

}

class StableRadar extends StatefulWidget {
  final TaxiTheme theme;
  const StableRadar({super.key, required this.theme});

  @override
  State<StableRadar> createState() => _StableRadarState();
}

class _StableRadarState extends State<StableRadar> with SingleTickerProviderStateMixin {
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
            // Static glowing outer circle
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
            // High-status glassmorphic central badge
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
              child: const Icon(Icons.location_searching_rounded, color: Color(0xFF4A80F0), size: 30),
            ),
          ],
        ),
      ),
    );
  }
}
