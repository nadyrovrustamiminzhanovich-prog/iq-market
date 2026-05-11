import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:line_icons/line_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';

import 'package:provider/provider.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:iqmarket/services/telegram_bot_service.dart';
import 'package:iqmarket/services/auth_service.dart';
import 'package:iqmarket/data/kazakhstan_locations.dart';
import 'package:iqmarket/screens/chat_screen.dart';
import 'package:iqmarket/providers/taxi_provider.dart';
import 'package:iqmarket/utils/taxi_constants.dart';
import 'package:iqmarket/theme/taxi_theme.dart';
import 'package:iqmarket/services/notification_service.dart';

// Import newly extracted screens
import 'package:iqmarket/screens/taxi/taxi_settings_screen.dart';
import 'package:iqmarket/screens/taxi/taxi_profile_screen.dart';
import 'package:iqmarket/screens/taxi/taxi_history_screen.dart';
import 'package:iqmarket/screens/taxi/taxi_support_screen.dart';
import 'package:iqmarket/screens/taxi/taxi_user_profile_view.dart';
import 'package:iqmarket/screens/taxi/driver_verification_screen.dart';
import 'package:iqmarket/widgets/taxi/taxi_order_card.dart';
import 'package:iqmarket/widgets/taxi/taxi_driver_card.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:iqmarket/widgets/taxi/taxi_ui_components.dart';
import 'package:iqmarket/widgets/auth/taxi_auth_form.dart';
import 'package:iqmarket/models/ad_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TaxiServiceScreen extends StatefulWidget {
  final String lang;
  const TaxiServiceScreen({super.key, required this.lang});

  @override
  State<TaxiServiceScreen> createState() => _TaxiServiceScreenState();
}

class _TaxiServiceScreenState extends State<TaxiServiceScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ImagePicker _picker = ImagePicker();
  final _phC = TextEditingController(text: '+7 ');
  final _codeC = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Schedule language setting if it's different from the default
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<TaxiProvider>(context, listen: false);
      if (provider.curLang != widget.lang) {
        provider.setLanguage(widget.lang);
      }
    });
  }

  @override
  void dispose() {
    _phC.dispose();
    _codeC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final taxiProvider = Provider.of<TaxiProvider>(context);
    final t = taxiProvider.theme;

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
            _topBar(t),
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

  Widget _topBar(TaxiTheme t) => AppBar(
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
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            color: const Color(0xFF1E293B),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 8),
        ],
      );

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

  Future<void> _pickImage(TaxiProvider provider, ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(source: source, imageQuality: 50);
      if (pickedFile != null) {
        provider.setProfileImage(File(pickedFile.path));
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  void _showVerifyDialog(TaxiProvider provider, TaxiTheme t) {
    int step = 0; // 0: Choice, 1: Telegram Link, 2: OTP
    bool isReq = false;
    String? sessionToken;
    String? capturedChatId;
    String? serverOtp;
    StreamSubscription? sessionSub;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) {
          return AlertDialog(
            backgroundColor: t.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
            contentPadding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (step == 0) ...[
                  Text('Выберите способ входа', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: t.text)),
                  const SizedBox(height: 12),
                  Text('Для использования сервиса такси необходима авторизация', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 13, color: t.sub, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _authMethodBtn(t, 'Google', Icons.g_mobiledata_rounded, Colors.redAccent, () {
                        ss(() => isReq = true);
                        AuthService.signInWithGoogle().then((user) {
                          if (user != null) {
                            provider.setLoginStatus(true);
                            Navigator.pop(ctx);
                          }
                          if (ctx.mounted) ss(() => isReq = false);
                        });
                      }),
                      _authMethodBtn(t, 'Telegram', LineIcons.telegram, const Color(0xFF24A1DE), () async {
                        ss(() => isReq = true);
                        sessionToken = await TelegramBotService.startAuthSession();
                        ss(() {
                          step = 1;
                          isReq = false;
                        });
                        // Start listening for chat_id linkage
                        sessionSub = TelegramBotService.watchSession(sessionToken!).listen((snap) {
                          if (!snap.exists) return;
                          final data = snap.data();
                          if (data != null && data['chat_id'] != null) {
                            capturedChatId = data['chat_id'];
                            serverOtp = data['otp'];
                            if (ctx.mounted) {
                              ss(() => step = 2);
                            }
                          }
                        });
                      }),
                    ],
                  ),
                ] else if (step == 1) ...[
                  const Icon(LineIcons.telegram, size: 64, color: Color(0xFF24A1DE)),
                  const SizedBox(height: 24),
                  Text('Свяжите аккаунт', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: t.text)),
                  const SizedBox(height: 12),
                  Text('Мы открыли наш бот в Telegram. Нажмите «Старт», чтобы получить код подтверждения.', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 13, color: t.sub, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(strokeWidth: 2),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () => launchUrl(Uri.parse('https://t.me/iq_market_bot?start=$sessionToken')),
                    child: Text('ОТКРЫТЬ ТЕЛЕГРАМ ЕЩЕ РАЗ', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 12, color: const Color(0xFF24A1DE))),
                  ),
                ] else if (step == 2) ...[
                  Text('Введите код', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: t.text)),
                  const SizedBox(height: 8),
                  Text('Бот отправил вам секретный код', style: GoogleFonts.inter(fontSize: 13, color: t.sub, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _codeC,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 8, color: t.accent),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: t.border)),
                      counterText: "",
                      hintText: "••••••",
                      hintStyle: TextStyle(color: t.sub.withValues(alpha: 0.3)),
                    ),
                    onChanged: (val) {
                      if (val.length == 6) {
                        if (val == serverOtp) {
                          sessionSub?.cancel();
                          provider.setTelegramAuth(capturedChatId!);
                          Navigator.pop(ctx);
                        } else {
                          HapticFeedback.vibrate();
                          _codeC.clear();
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  Text('Код из 6 цифр', style: GoogleFonts.inter(fontSize: 12, color: t.sub, fontWeight: FontWeight.bold)),
                ],
                if (isReq) const Padding(padding: EdgeInsets.only(top: 24), child: LinearProgressIndicator()),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  sessionSub?.cancel();
                  Navigator.pop(ctx);
                },
                child: Text('ОТМЕНА', style: GoogleFonts.inter(color: t.sub, fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _authMethodBtn(TaxiTheme t, String label, IconData icon, Color color, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Column(
      children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.2), width: 2),
          ),
          child: Icon(icon, color: color, size: 36),
        ),
        const SizedBox(height: 12),
        Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: t.text)),
      ],
    ),
  );

  Widget _socialAuthBtn(TaxiTheme t, String url, String l, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Column(children: [
          Container(
              width: 70,
              height: 70,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: t.accent.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, 8))
                  ],
                  border: Border.all(color: t.border.withValues(alpha: 0.3), width: 1)),
              child: CachedNetworkImage(
                imageUrl: url, 
                placeholder: (c, u) => const CircularProgressIndicator(strokeWidth: 2),
                errorWidget: (c, u, e) => Icon(Icons.login_rounded, color: Colors.blue),
              )),
          const SizedBox(height: 8),
          Text(l, style: GoogleFonts.inter(color: t.text.withValues(alpha: 0.6), fontSize: 11, fontWeight: FontWeight.bold))
        ]),
      );

  Widget _passengerView(TaxiProvider provider, TaxiTheme t) {
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
                GestureDetector(
                  onTap: () {},
                  child: Text(
                    'Смотреть все',
                    style: GoogleFonts.inter(color: const Color(0xFF4A80F0), fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          if (drivers.isEmpty)
            Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), border: Border.all(color: const Color(0xFFF1F5F9))),
                child: Column(children: [
                  Icon(LineIcons.car, color: const Color(0xFF4A80F0).withValues(alpha: 0.5), size: 48),
                  const SizedBox(height: 16),
                  Text(provider.translate('no_drivers'),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 15, fontWeight: FontWeight.w600)),
                ]))
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: drivers.map((d) => TaxiDriverCard(
                  provider: provider,
                  t: t,
                  driver: d,
                  onShowProfile: () => _showUserProfile(provider, t, d['name'] ?? 'Водитель', d['img'] ?? '', d['car'] ?? '', true),
                  onCall: () => launchUrl(Uri.parse('tel:${d['phone'] ?? ''}')),
                  onChat: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(ad: AdModel(
                    id: 'taxi_${d['name']}_${DateTime.now().millisecondsSinceEpoch}',
                    title: '${d['from'] ?? ''} → ${d['to'] ?? ''}',
                    description: 'Taxi Trip',
                    price: '${d['price'] ?? 0} ₸',
                    category: 'Taxi',
                    images: d['img'] != null && d['img'].toString().isNotEmpty ? [d['img']] : [],
                    userId: 'taxi_driver',
                    userName: d['name'] ?? 'Водитель',
                    userEmail: '',
                    timestamp: DateTime.now(),
                    location: d['from'] ?? '',
                  )))),
                  onNegotiate: () => _showNegotiateDialog(provider, t, {'price': d['price'] ?? 0, 'name': d['name'] ?? 'Водитель'}),
                )).toList(),
              ),
            ),
          const SizedBox(height: 100)
        ]);
  }


  Widget _driverView(TaxiProvider provider, TaxiTheme t) {
    final orders = provider.filteredOrders;
    
    return ListView(physics: const BouncingScrollPhysics(), padding: const EdgeInsets.symmetric(horizontal: 10), children: [
      _driverDashboard(provider, t),
      const SizedBox(height: 16),
      _complexForm(provider, t),
      const SizedBox(height: 16),
      _quickActions(t),
      const SizedBox(height: 16),
      _sectionHeader(t, '${provider.translate('orders')} 📦'),
      const SizedBox(height: 8),
      
 if (orders.isEmpty)
        Container(
          padding: const EdgeInsets.all(40),
          child: Column(children: [
            Icon(LineIcons.search, color: t.sub.withValues(alpha: 0.3), size: 50),
            const SizedBox(height: 16),
            Text('Заказов на этот маршрут/дату пока нет', textAlign: TextAlign.center, style: GoogleFonts.inter(color: t.sub, fontWeight: FontWeight.w600)),
          ]),
        )
      else
        ...orders.map((o) => TaxiOrderCard(
              provider: provider,
              t: t,
              name: o['name'] ?? 'Пассажир',
              from: o['from'] ?? '',
              to: o['to'] ?? '',
              price: o['price'] ?? 0,
              seats: o['seats'] ?? 1,
              comment: o['comment'] ?? '',
              isNegotiated: o['isNegotiated'] ?? false,
              created: '${provider.translate(o['date'] ?? '')}, ${o['created'] ?? ''}',
              img: o['img'] ?? '',
              phone: o['phone'] ?? '',
              onShowProfile: () => _showUserProfile(provider, t, o['name'] ?? 'Пассажир', o['img'] ?? '', '', false),
              onNegotiate: () {
                if (!provider.isLoggedIn) return _showVerifyDialog(provider, t);
                _showNegotiateDialog(provider, t, {'price': o['price'] ?? 0, 'name': o['name'] ?? 'Пассажир'});
              },
              onDecline: () {
                if (!provider.isLoggedIn) return _showVerifyDialog(provider, t);
                NotificationService.notify(context, 'Отказ', provider.translate('offer_declined'), isSuccess: false);
              },
              onAccept: () {
                if (!provider.isLoggedIn) return _showVerifyDialog(provider, t);
                NotificationService.notify(context, 'Принято', provider.translate('order_accepted'), isSuccess: true);
              },
            )),
      const SizedBox(height: 100)
    ]);
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
                _showVerifyDialog(provider, t);
              } else {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverVerificationScreen()));
              }
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: (provider.isLoggedIn && provider.isVehicleVerified)
                  ? LinearGradient(colors: [Colors.green.withValues(alpha: 0.1), Colors.green.withValues(alpha: 0.05)])
                  : LinearGradient(colors: [t.accent, t.accent.withValues(alpha: 0.8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(24),
                boxShadow: (provider.isLoggedIn && provider.isVehicleVerified) ? [] : [BoxShadow(color: t.accent.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))]
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: (provider.isLoggedIn && provider.isVehicleVerified) ? 0.0 : 0.2), shape: BoxShape.circle),
                  child: Icon((provider.isLoggedIn && provider.isVehicleVerified) ? Icons.verified_user_rounded : Icons.shield_outlined, 
                      color: (provider.isLoggedIn && provider.isVehicleVerified) ? Colors.green : Colors.white, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                  if (provider.isLoggedIn)
                    Text(
                      provider.isVehicleVerified ? provider.translate('verif_ok') : provider.translate('verif_req'), 
                      style: GoogleFonts.inter(color: provider.isVehicleVerified ? Colors.green : Colors.white, fontWeight: FontWeight.w600, fontSize: 13, letterSpacing: 0.5)
                    ),
                  Padding(
                    padding: EdgeInsets.only(top: provider.isLoggedIn ? 2 : 0),
                    child: Text(
                      !provider.isLoggedIn ? "Войдите, чтобы пройти верификацию" : (provider.isVehicleVerified ? provider.translate('verif_ok') : provider.translate('verif_sub')), 
                      style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.8), fontSize: provider.isLoggedIn ? 10 : 13, fontWeight: FontWeight.bold)
                    ),
                  ),
                ])),
                Icon(Icons.arrow_forward_ios_rounded, color: (provider.isLoggedIn && provider.isVehicleVerified) ? Colors.green : Colors.white, size: 14),
              ]),
            ),
          ),
          if (provider.isLoggedIn) ...[
            const SizedBox(height: 24),
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _dashItem(t, provider.translate('bal'), '14,500 ₸', LineIcons.wallet),
              _dashItem(t, provider.translate('rate'), '4.95', Icons.star_rounded),
              _dashItem(t, provider.translate('tasks'), '12', LineIcons.checkCircle),
            ]),
          ],
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
        border: Border.all(color: const Color(0xFFF1F5F9)),
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
                  _routeRow(t, provider.translate('from'), provider.from, true, provider),
                  Padding(
                    padding: const EdgeInsets.only(left: 50, right: 10),
                    child: Divider(height: 1, color: const Color(0xFFE2E8F0)),
                  ),
                  _routeRow(t, provider.translate('to'), provider.to, false, provider),
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
          Row(children: [
            Expanded(child: _miniBtn(t, Icons.calendar_today_rounded, 
              provider.selDate == 'today' ? 'Дата' : 
              provider.selDate == 'tomorrow' ? provider.translate('tomorrow') : 
              provider.selDate == 'yesterday' ? provider.translate('yesterday') : 
              provider.selDate, () => _pickDate(provider, t))),

            const SizedBox(width: 8),
            Expanded(child: _miniBtn(t, Icons.access_time_rounded, provider.selTime == 'time' ? provider.translate('time') : provider.selTime, () => _pickTime(provider, t))),
            if (provider.tab == 0) ...[
              const SizedBox(width: 8),
              Expanded(child: _miniBtn(t, Icons.group_rounded, 'Место', () => _pickPass(provider, t))),
            ],
          ]),
          const SizedBox(height: 16),
          _miniBtn(t, Icons.chat_bubble_outline_rounded, provider.comment.isEmpty ? 'Комментарий к заказу' : provider.comment, () => _showCommentDialog(provider, t), h: 54),

          const SizedBox(height: 24),

          _actBtn(t, 'ПОЕХАЛИ!', const Color(0xFF4A80F0), () {
            HapticFeedback.heavyImpact();
          })
        ],
      ),
    );
  }


  Widget _routeRow(TaxiTheme t, String label, String val, bool isF, TaxiProvider provider) => GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _openPicker(t, isF, provider);
      },
      child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          color: Colors.transparent,
          child: Row(children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: isF ? const Color(0xFF4A80F0) : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF4A80F0), width: 2),
              ),
              child: isF ? const Center(child: Icon(Icons.circle, color: Colors.white, size: 6)) : null,
            ),
            const SizedBox(width: 16),
            Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(val, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)))
            ])),
          ])));


  Widget _miniBtn(TaxiTheme t, IconData i, String v, VoidCallback onTap, {double h = 44}) => GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
          height: h,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
              color: Colors.white, 
              borderRadius: BorderRadius.circular(12), 
              border: Border.all(color: const Color(0xFFF1F5F9))),
          child: Row(mainAxisAlignment: MainAxisAlignment.start, children: [
            Icon(i, color: const Color(0xFF4A80F0), size: 16),
            const SizedBox(width: 8),
            Flexible(
                child: Text(v,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(color: const Color(0xFF1E293B), fontWeight: FontWeight.w600, fontSize: 12)))
          ])));



  Widget _priceInputField(TaxiTheme t, TaxiProvider provider) => Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
          color: t.card2.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(18), border: Border.all(color: t.border)),
      child: Row(children: [
        Icon(LineIcons.coins, color: t.accent, size: 22),
        const SizedBox(width: 12),
        Expanded(
            child: TextField(
                keyboardType: TextInputType.number,
                style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.w800, fontSize: 17),
                onChanged: (v) {
                  final val = int.tryParse(v.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
                  provider.setMaxPrice(val);
                },
                decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    hintText: provider.maxPrice > 0 ? 'До ${provider.maxPrice} ₸' : 'Цена',
                    hintStyle: GoogleFonts.inter(color: t.sub.withValues(alpha: 0.4), fontSize: 14, fontWeight: FontWeight.w500)))),
        if (provider.maxPrice > 0)
          GestureDetector(
            onTap: () => provider.setMaxPrice(0),
            child: Icon(Icons.close_rounded, color: t.sub, size: 18),
          )
        else
          Text('₸', style: GoogleFonts.inter(color: t.accent, fontWeight: FontWeight.w900, fontSize: 20)),
      ]));

  Widget _actBtn(TaxiTheme t, String l, Color c, VoidCallback onTap) => SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4A80F0),
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


  void _openPicker(TaxiTheme t, bool isF, TaxiProvider provider) {
    String q = '';
    showModalBottomSheet(
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
              Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(
                      4,
                      (i) => GestureDetector(
                          onTap: () {
                            provider.setPassCnt(i + 1);
                            Navigator.pop(context);
                          },
                          child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                  color: provider.passCnt == i + 1 ? t.accent : t.card,
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(color: t.border)),
                              child: Center(
                                  child: Text('${i + 1}',
                                      style: GoogleFonts.inter(
                                          color: provider.passCnt == i + 1 ? Colors.white : t.text,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18))))))),
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

    int myPrice = d['price'] - 500;
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
                            ss(() => myPrice -= 100);
                          },
                          child: _circleBtn(t, Icons.remove)),
                      const SizedBox(width: 30),
                      Text('$myPrice',
                          style: GoogleFonts.inter(fontSize: 42, fontWeight: FontWeight.w900, color: t.text)),
                      const SizedBox(width: 30),
                      GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            ss(() => myPrice += 100);
                          },
                          child: _circleBtn(t, Icons.add)),

                    ]),
                    const SizedBox(height: 40),
                    GestureDetector(
                      onTap: () async {
                        Navigator.pop(context);
                        NotificationService.notify(context, 'Предложение отправлено', '${provider.translate('offer_sent')} ($myPrice ₸)', isSuccess: true);
                        
                        await Future.delayed(const Duration(seconds: 3));
                        if (mounted) {
                          NotificationService.notify(context, 'Ответ водителя', '${d['name']} ${provider.translate('driver_agrees')} $myPrice ₸!', isSuccess: true);
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

  void _showUserProfile(TaxiProvider provider, TaxiTheme t, String name, String img, String car, bool isDriver) {
    if (!isDriver && !provider.isVehicleVerified) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: t.bg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          title: Text('ДОСТУП ОГРАНИЧЕН', style: GoogleFonts.inter(fontWeight: FontWeight.w900)),
          content: Text('Для просмотра профилей пассажиров необходимо зарегистрироваться как водитель.', style: GoogleFonts.inter()),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('ОК', style: GoogleFonts.inter(color: t.accent, fontWeight: FontWeight.bold))),
          ],
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TaxiProfileViewScreen(
          user: {
            'name': name,
            'img': img.isNotEmpty ? img : 'https://images.unsplash.com/photo-1633332755192-727a05c4013d?w=800',
            'car': car,
            'phone': '87001234567', // Mock phone
          },
          isDriver: isDriver,
          theme: t,
        ),
      ),
    );

  }

  Widget _circleBtn(TaxiTheme t, IconData i) => Container(
    width: 50, height: 50,
    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: t.border, width: 2)),
    child: Icon(i, color: t.lime),
  );

}

