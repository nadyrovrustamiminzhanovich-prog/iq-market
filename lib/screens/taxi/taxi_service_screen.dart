import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:line_icons/line_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:iqmarket/widgets/offline_banner.dart';
import 'package:iqmarket/screens/chat_screen.dart';
import 'package:iqmarket/providers/taxi_provider.dart';
import 'package:iqmarket/theme/taxi_theme.dart';
import 'package:iqmarket/services/notification_service.dart';
import 'package:iqmarket/models/ad_model.dart';

import 'package:iqmarket/widgets/auth_gate_bottom_sheet.dart';
import 'package:iqmarket/services/translation_service.dart';

// ── Screens ──────────────────────────────────────────────────────────────────
import 'package:iqmarket/screens/taxi/taxi_settings_screen.dart';
import 'package:iqmarket/screens/taxi/taxi_profile_screen.dart';
import 'package:iqmarket/screens/taxi/taxi_history_screen.dart';
import 'package:iqmarket/screens/taxi/taxi_support_screen.dart';
import 'package:iqmarket/screens/taxi/taxi_user_profile_view.dart';

import 'package:iqmarket/widgets/auth/telegram_verification_dialog.dart';

// ── Legacy shared UI components (TaxiRoleCard etc.) ──────────────────────────


// ── Features: extracted widgets ───────────────────────────────────────────────
import 'package:iqmarket/features/taxi/presentation/widgets/ui/taxi_passenger_view.dart';
import 'package:iqmarket/features/taxi/presentation/widgets/ui/taxi_driver_view.dart';
import 'package:iqmarket/features/taxi/presentation/widgets/ui/taxi_complex_form.dart';
import 'package:iqmarket/features/taxi/presentation/widgets/ui/taxi_top_bar_widget.dart';
import 'package:iqmarket/features/taxi/presentation/widgets/ui/taxi_sos_bottom_sheet.dart';
import 'package:iqmarket/features/taxi/presentation/widgets/ui/taxi_side_menu_widget.dart';
import 'package:iqmarket/features/taxi/presentation/widgets/ui/taxi_location_picker_sheet.dart';
import 'package:iqmarket/features/taxi/presentation/widgets/ui/taxi_phone_binding_sheet.dart';
import 'package:iqmarket/features/taxi/presentation/widgets/ui/taxi_bid_details_sheet.dart';
import 'package:iqmarket/features/taxi/presentation/widgets/ui/taxi_passenger_order_confirmation_sheet.dart';
import 'package:iqmarket/features/taxi/presentation/widgets/ui/taxi_driver_ride_confirmation_sheet.dart';
import 'package:iqmarket/features/taxi/presentation/widgets/ui/service_components/taxi_service_header.dart';
import 'package:iqmarket/features/taxi/presentation/widgets/ui/service_components/taxi_role_selector.dart';
import 'package:iqmarket/features/taxi/presentation/widgets/ui/service_components/taxi_route_builder.dart';
import 'package:iqmarket/features/taxi/presentation/widgets/ui/service_components/taxi_pickers_controller.dart';

// ── Features: controllers ─────────────────────────────────────────────────────
import 'package:iqmarket/features/taxi/presentation/controllers/taxi_action_gate_controller.dart';
import 'package:iqmarket/features/taxi/presentation/controllers/taxi_auto_resolution_controller.dart';

/// Главный экран такси-сервиса.
///
/// Этот файл является «оркестратором» — связывает провайдер с UI-виджетами
/// из `lib/features/taxi/presentation/`. Вся бизнес-логика диалогов,
/// шитов и проверок делегирована в соответствующие контроллеры.
class TaxiServiceScreen extends StatefulWidget {
  final String lang;
  const TaxiServiceScreen({super.key, required this.lang});

  @override
  State<TaxiServiceScreen> createState() => _TaxiServiceScreenState();
}

class _TaxiServiceScreenState extends State<TaxiServiceScreen> {
  // ── Scaffold ─────────────────────────────────────────────────────────────
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // ── Форма пассажира (passenger form state) ────────────────────────────────
  final TextEditingController _mainPhoneController = TextEditingController();
  final MaskTextInputFormatter _mainPhoneMask = MaskTextInputFormatter(
    mask: '+7 (###) ###-##-##',
    filter: {'#': RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();

  // ── Флаги валидации ───────────────────────────────────────────────────────
  bool _showFromError = false;
  bool _showToError = false;
  bool _showDateError = false;
  bool _showTimeError = false;
  bool _showPhoneError = false;
  bool _showPriceError = false;

  // ── Сеть ─────────────────────────────────────────────────────────────────
  bool _isOffline = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // ── Провайдер (для dispose) ───────────────────────────────────────────────
  late TaxiProvider _taxiProvider;

  // ── Auto-resolution: отслеживаем изменения, не спамим build() ────────────
  Set<String> _lastCheckedRideIds = {};

  // ─────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) {
      setState(() {
        _isOffline = results.isEmpty ||
            results.every((r) => r == ConnectivityResult.none);
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _taxiProvider = Provider.of<TaxiProvider>(context, listen: false);
      _taxiProvider.resumeFirebaseSync();
      
      // Defensive check for Telegram verification if in Driver mode (tab 1)
      if (_taxiProvider.tab == 1) {
        _taxiProvider.checkUserTelegramVerification().then((verified) {
          if (!verified && mounted) {
            _taxiProvider.setTab(0);
            TelegramVerificationDialog.show(context, provider: _taxiProvider);
          }
        });
      }

      String mappedIso = 'ru';
      if (widget.lang == 'Қазақша') mappedIso = 'kz';
      else if (widget.lang == 'Уйғурчә') mappedIso = 'uyg';

      if (_taxiProvider.curLang != mappedIso) {
        _taxiProvider.setLanguage(widget.lang);
      }
      // Предзаполняем контроллеры из сохранённого состояния провайдера
      final phone = (_taxiProvider.phone == '+7 701 000 11 22' ||
              _taxiProvider.phone == '87010001122')
          ? ''
          : _taxiProvider.phone;
      if (_mainPhoneController.text.isEmpty && phone.isNotEmpty) {
        _mainPhoneController.text = phone;
      }
      final price =
          _taxiProvider.maxPrice > 0 ? _taxiProvider.maxPrice.toString() : '';
      if (_priceController.text.isEmpty && price.isNotEmpty) {
        _priceController.text = price;
      }
      if (_commentController.text.isEmpty &&
          _taxiProvider.comment.isNotEmpty) {
        _commentController.text = _taxiProvider.comment;
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Вызываем авто-резолюцию только при реальном изменении набора поездок,
    // чтобы не вызывать side-effects в методе build().
    final provider = Provider.of<TaxiProvider>(context, listen: false);
    final currentIds = {
      ...provider.myAcceptedOrders.map((o) => o['id']?.toString() ?? ''),
      ...provider.myAcceptedRides.map((r) => r['id']?.toString() ?? ''),
    };
    if (currentIds != _lastCheckedRideIds) {
      _lastCheckedRideIds = currentIds;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final p = Provider.of<TaxiProvider>(context, listen: false);
        TaxiAutoResolutionController.checkAndShowPendingRidesDialog(
            context, p, p.theme);
      });
    }
  }

  @override
  void dispose() {
    _taxiProvider.pauseFirebaseSync();
    _connectivitySubscription?.cancel();
    _mainPhoneController.dispose();
    _priceController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Connectivity
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _checkConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    if (mounted) {
      setState(() {
        _isOffline = results.isEmpty ||
            results.every((r) => r == ConnectivityResult.none);
      });
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TaxiProvider>(context);
    final t = provider.theme;

    // ✅ W-04 FIX: Removed dead PopScope handler.
    // canPop:true + if(didPop) return = handler never ran. Pure overhead removed.
    return AnnotatedRegion<SystemUiOverlayStyle>(
        value: provider.isDarkGlobal
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        child: Scaffold(
          key: _scaffoldKey,
          backgroundColor: t.bg,
          drawer: TaxiSideMenuWidget(
            t: t,
            firstName: provider.firstName,
            lastName: provider.lastName,
            phone: provider.phone,
            profileImage: provider.profileImage,
            items: [
              TaxiDrawerItem(
                icon: LineIcons.user,
                label: provider.translate('profile'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => TaxiProfileScreen(t: t)));
                },
              ),
              TaxiDrawerItem(
                icon: LineIcons.history,
                label: provider.translate('history_full'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => TaxiHistoryScreen(t: t)));
                },
              ),
              TaxiDrawerItem(
                icon: LineIcons.headset,
                label: provider.translate('support_full'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => TaxiSupportScreen(t: t)));
                },
              ),
              TaxiDrawerItem(
                icon: LineIcons.cog,
                label: provider.translate('settings'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => const TaxiSettingsScreen()));
                },
              ),
            ],
          ),
          body: Stack(
            children: [
              Column(
                children: [
                  TaxiTopBarWidget(
                    t: t,
                    onMenuTap: () =>
                        _scaffoldKey.currentState?.openDrawer(),
                    onSosTap: () => TaxiSosBottomSheet.show(context, t),
                    onBackTap: () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(
                    child: provider.loading
                        ? _loader(t)
                        : ListView(
                            padding: EdgeInsets.zero,
                            physics: const BouncingScrollPhysics(),
                            children: [
                              const TaxiServiceHeader(),
                              TaxiRoleSelector(
                                provider: provider,
                                t: t,
                                onRoleChanged: _resetErrors,
                              ),
                              provider.tab == 0
                                  ? _passengerView(provider, t)
                                  : _driverView(provider, t),
                            ],
                          ),
                  ),
                ],
              ),
              OfflineBanner(isOffline: _isOffline),
            ],
          ),
        ),
      );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Header / Selector
  // ─────────────────────────────────────────────────────────────────────────

  Widget _loader(TaxiTheme t) =>
      Center(child: CircularProgressIndicator(color: t.lime));

  void _resetErrors() {
    setState(() {
      _showFromError = false;
      _showToError = false;
      _showDateError = false;
      _showTimeError = false;
      _showPhoneError = false;
      _showPriceError = false;
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Passenger view
  // ─────────────────────────────────────────────────────────────────────────

  Widget _passengerView(TaxiProvider provider, TaxiTheme t) {
    return TaxiPassengerView(
      provider: provider,
      t: t,
      onHandlePassengerCallOrChat: (data, {required isCall}) =>
          _handlePassengerCallOrChat(provider, t, data, isCall: isCall),
      onNavigateToLogin: () => _navigateToLogin(provider, 'auth_taxi_order_prompt'),
      onShowPhoneBinding: (callback) =>
          showTaxiPhoneBindingSheet(context, provider, t, callback),
      complexFormWidget: TaxiComplexForm(
        t: t,
        routeFrom: TaxiRouteBuilder(
          context: context,
          t: t,
          provider: provider,
          isFrom: true,
          hasError: _showFromError,
          onClearError: () => setState(() => _showFromError = false),
        ),
        routeTo: TaxiRouteBuilder(
          context: context,
          t: t,
          provider: provider,
          isFrom: false,
          hasError: _showToError,
          onClearError: () => setState(() => _showToError = false),
        ),
        onSwapTap: () {
          final temp = provider.from;
          provider.setFrom(provider.to);
          provider.setTo(temp);
        },
        hasDateError: _showDateError,
        hasTimeError: _showTimeError,
        dateText: provider.selDate,
        timeText: provider.selTime,
        onDateTimeTap: () => TaxiPickersController.pickDateTimeSequential(
          context: context,
          provider: provider,
          t: t,
          onDatePicked: () => setState(() => _showDateError = false),
          onTimePicked: () => setState(() => _showTimeError = false),
        ),
        passCnt: provider.passCnt,
        onPassTap: () => TaxiPickersController.pickPass(context: context, provider: provider, t: t),
        priceController: _priceController,
        hasPriceError: _showPriceError,
        onPriceChanged: (v) {
          final val =
              int.tryParse(v.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
          provider.setMaxPrice(val);
          if (val > 0) setState(() => _showPriceError = false);
        },
        onPriceClear: () {
          provider.setMaxPrice(0);
          _priceController.clear();
        },
        showPriceClear: provider.maxPrice > 0,
        commentController: _commentController,
        onCommentChanged: (v) => provider.setComment(v),
        onCommentClear: () {
          _commentController.clear();
          provider.setComment('');
          setState(() {});
        },
        showCommentClear: _commentController.text.isNotEmpty,
        phoneController: _mainPhoneController,
        phoneFormatters: [_mainPhoneMask],
        hasPhoneError: _showPhoneError,
        onPhoneChanged: (val) {
          provider.updateProfile(provider.firstName, provider.lastName, val);
          final clean = val.replaceAll(RegExp(r'\D'), '');
          if (clean.length == 11) setState(() => _showPhoneError = false);
        },
        onSubmitTap: () {
          HapticFeedback.heavyImpact();
          if (!provider.isLoggedIn) {
            _navigateToLogin(provider, 'auth_taxi_order_prompt');
            return;
          }
          // ✅ ISSUE-07 FIX: Use the single authoritative getter instead of inline check
          final isTelegramUser = provider.isFullyTelegramVerified;
          final cleanPhone = _mainPhoneMask.getUnmaskedText();
          setState(() {
            _showFromError = provider.from.isEmpty;
            _showToError = provider.to.isEmpty;
            _showDateError =
                provider.selDate == 'date' || provider.selDate.isEmpty;
            _showTimeError =
                provider.selTime == 'time' || provider.selTime.isEmpty;
            _showPhoneError = !isTelegramUser && cleanPhone.length != 10;
            _showPriceError = provider.maxPrice < 100;
          });
          if (_showFromError ||
              _showToError ||
              _showDateError ||
              _showTimeError ||
              (!isTelegramUser && _showPhoneError) ||
              _showPriceError) {
            NotificationService.notify(
              context,
              'Заполните поездку ⚠️',
              isTelegramUser
                  ? 'Пожалуйста, заполните все обязательные поля, включая сумму (минимум 100 ₸)!'
                  : 'Пожалуйста, заполните все обязательные поля, включая сумму (минимум 100 ₸) и телефон!',
              isSuccess: false,
            );
            return;
          }
          showTaxiPassengerOrderConfirmationSheet(
            context: context,
            provider: provider,
            theme: t,
            price: provider.maxPrice > 0
                ? provider.maxPrice
                : (int.tryParse(
                        _priceController.text.replaceAll(RegExp(r'\D'), '')) ??
                    1000),
            comment: _commentController.text.trim(),
            phone: _mainPhoneController.text.trim(),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Driver view
  // ─────────────────────────────────────────────────────────────────────────

  Widget _driverView(TaxiProvider provider, TaxiTheme t) {
    return TaxiDriverView(
      provider: provider,
      t: t,
      onHandleDriverCallOrChat: (data, {required isCall}) =>
          _handleDriverCallOrChat(provider, t, data, isCall: isCall),
      onCheckDriverActionGate: (data, action) =>
          TaxiActionGateController.checkDriverActionGate(
            context,
            provider,
            t,
            data,
            action,
            onNavigateToLogin: () => _navigateToLogin(provider, 'auth_taxi_create_prompt'),
            onShowPhoneBinding: (ctx, p, theme, cb) =>
                showTaxiPhoneBindingSheet(ctx, p, theme, cb),
            onShowVerificationGate: (p, theme, {customText}) =>
                TaxiActionGateController.showDriverVerificationGateDialog(
                    context, p, theme,
                    customText: customText),
            onShowDriverRideConfirmation: (p, theme, from, to) =>
                showTaxiDriverRideConfirmationSheet(
              context: context,
              provider: p,
              t: theme,
              initialFrom: from,
              initialTo: to,
              onOpenPicker: (isFrom, isDriver) =>
                  showTaxiLocationPickerSheet(
                context: context,
                t: theme,
                isFrom: isFrom,
                provider: p,
                isDriver: isDriver,
              ),
            ),
          ),
      buildSectionHeader: (title) => Padding(
        padding:
            const EdgeInsets.only(left: 20, right: 20, top: 24, bottom: 8),
        child: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1E293B),
          ),
        ),
      ),
      routeFrom: TaxiRouteBuilder(
        context: context,
        t: t,
        provider: provider,
        isFrom: true,
        isDriver: true,
        hasError: false,
        onClearError: () {},
      ),
      routeTo: TaxiRouteBuilder(
        context: context,
        t: t,
        provider: provider,
        isFrom: false,
        isDriver: true,
        hasError: false,
        onClearError: () {},
      ),
      dateLabel: (provider.selDate.isEmpty || provider.selDate == 'date')
          ? 'Любая дата'
          : (provider.selDate == 'today'
              ? 'Сегодня'
              : provider.selDate == 'tomorrow'
                  ? 'Завтра'
                  : provider.selDate),
      onDateTap: () => TaxiPickersController.pickDate(context: context, provider: provider, t: t),
      onSwapTap: () {
        final temp = provider.driverFrom;
        provider.setDriverFrom(provider.driverTo);
        provider.setDriverTo(temp);
      },
      onSearchTap: () => HapticFeedback.lightImpact(),
      onBidTap: (bid) => showTaxiBidDetailsSheet(
        context: context,
        bid: bid,
        provider: provider,
        t: t,
        onShowUserProfile: (name, img, isDriverRole, uid) =>
            _showUserProfile(provider, t, name, img, '', isDriverRole, uid),
      ),
      onCreateRideTap: () {
        if (!provider.isLoggedIn) {
          _navigateToLogin(provider, 'auth_taxi_create_prompt');
          return;
        }
        // ✅ ISSUE-07 FIX: Use the single authoritative getter
        final isTelegramUser = provider.isFullyTelegramVerified;
        final hasPhone = isTelegramUser || (provider.phone.isNotEmpty &&
            provider.phone != '+7 701 000 11 22' &&
            provider.phone != '87010001122');
        if (!hasPhone) {
          showTaxiPhoneBindingSheet(context, provider, t, () {
            if (!provider.isVehicleVerified) {
              TaxiActionGateController.showDriverVerificationGateDialog(
                  context, provider, t,
                  customText:
                      'Для создания поездок необходимо пройти верификацию автомобиля в профиле водителя.');
            } else {
              _openDriverRideSheet(provider, t);
            }
          });
        } else if (!provider.isVehicleVerified) {
          TaxiActionGateController.showDriverVerificationGateDialog(
              context, provider, t,
              customText:
                  'Для создания поездок необходимо пройти верификацию автомобиля в профиле водителя.');
        } else {
          _openDriverRideSheet(provider, t);
        }
      },
      onNavigateToLogin: () => _navigateToLogin(provider, 'auth_taxi_order_prompt'),
      onShowPhoneBinding: (callback) =>
          showTaxiPhoneBindingSheet(context, provider, t, callback),
    );
  }

  void _openDriverRideSheet(TaxiProvider provider, TaxiTheme t) {
    showTaxiDriverRideConfirmationSheet(
      context: context,
      provider: provider,
      t: t,
      onOpenPicker: (isFrom, isDriver) => showTaxiLocationPickerSheet(
        context: context,
        t: t,
        isFrom: isFrom,
        provider: provider,
        isDriver: isDriver,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Navigation helpers
  // ─────────────────────────────────────────────────────────────────────────

  String _getCurrentLang(TaxiProvider provider) {
    if (provider.curLang == 'ru') return 'Русский';
    if (provider.curLang == 'kz') return 'Қазақша';
    if (provider.curLang == 'uyg') return 'Уйғурчә';
    return 'Русский';
  }

  void _navigateToLogin(TaxiProvider provider, String messageKey) async {
    final curLang = _getCurrentLang(provider);
    await AuthGateBottomSheet.show(
      context,
      message: TranslationService.t(messageKey, curLang),
    );
  }

  void _showUserProfile(
    TaxiProvider provider,
    TaxiTheme t,
    String name,
    String img,
    String car,
    bool isDriver,
    String targetUserId, {
    bool isVerified = false,
    String phone = '',
  }) {
    if (!provider.isLoggedIn) {
      _navigateToLogin(provider, 'auth_taxi_profile_prompt');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TaxiProfileViewScreen(
          user: {
            'id': targetUserId,
            'name': name,
            'img': img.isNotEmpty
                ? img
                : 'https://images.unsplash.com/photo-1633332755192-727a05c4013d?w=800',
            'car': car,
            // ✅ ISSUE-04 FIX: Pass empty string instead of fake phone number.
            // The profile screen handles empty phone gracefully with a SnackBar.
            'phone': phone,
            'verified': isVerified,
          },
          isDriver: isDriver,
          theme: t,
          isCurrentUserVerified: provider.isVehicleVerified,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Call / Chat handlers
  // ─────────────────────────────────────────────────────────────────────────

  void _handlePassengerCallOrChat(
    TaxiProvider provider,
    TaxiTheme t,
    Map<String, dynamic> d, {
    required bool isCall,
  }) {
    if (!provider.isLoggedIn) {
      _navigateToLogin(provider, isCall ? 'auth_call_prompt' : 'auth_chat_prompt');
      return;
    }
    // ✅ ISSUE-07 FIX: Use the single authoritative getter
    final isTelegramUser = provider.isFullyTelegramVerified;
    if (!isTelegramUser && (provider.phone.isEmpty ||
        provider.phone == '+7 701 000 11 22' ||
        provider.phone == '87010001122')) {
      showTaxiPhoneBindingSheet(context, provider, t, () {
        _handlePassengerCallOrChat(provider, t, d, isCall: isCall);
      });
      return;
    }
    if (isCall) {
      launchUrl(Uri.parse('tel:${d['phone'] ?? ''}'));
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            ad: AdModel(
              id: 'taxi_${d['driverName'] ?? d['name']}_'
                  '${DateTime.now().millisecondsSinceEpoch}',
              title: '${d['from'] ?? ''} → ${d['to'] ?? ''}',
              description: 'Taxi Trip',
              price:
                  double.tryParse(d['price']?.toString() ?? '0') ?? 0.0,
              category: 'Taxi',
              images: (d['img'] != null && d['img'].toString().isNotEmpty)
                  ? [d['img']]
                  : [],
              userId: d['driverId'] ?? 'taxi_driver',
              userName: d['driverName'] ?? d['name'] ?? 'Водитель',
              userEmail: '',
              timestamp: DateTime.now(),
              location: d['from'] ?? '',
            ),
          ),
        ),
      );
    }
  }

  void _handleDriverCallOrChat(
    TaxiProvider provider,
    TaxiTheme t,
    Map<String, dynamic> o, {
    required bool isCall,
  }) async {
    if (!provider.isLoggedIn) {
      _navigateToLogin(provider, isCall ? 'auth_call_prompt' : 'auth_chat_prompt');
      return;
    }
    // ✅ ISSUE-07 FIX: Use the single authoritative getter
    final isTelegramUser = provider.isFullyTelegramVerified;
    if (!isTelegramUser && (provider.phone.isEmpty ||
        provider.phone == '+7 701 000 11 22' ||
        provider.phone == '87010001122')) {
      showTaxiPhoneBindingSheet(context, provider, t, () {
        _handleDriverCallOrChat(provider, t, o, isCall: isCall);
      });
      return;
    }

    final passengerPhone = o['phone'] ?? o['passengerPhone'] ?? '';
    final passengerName = o['name'] ?? o['passengerName'] ?? 'Пассажир';

    if (isCall) {
      if (passengerPhone.isNotEmpty) {
        await launchUrl(Uri.parse('tel:$passengerPhone'));
      } else {
        NotificationService.notify(context, 'Нет номера',
            'Телефон пассажира недоступен',
            isSuccess: false);
      }
    } else {
      _showUserProfile(
        provider,
        t,
        passengerName,
        o['img'] ?? o['passengerImg'] ?? '',
        '',
        false,
        o['passengerId'] ?? o['userId'] ?? '',
        phone: o['passengerPhone'] ?? o['phone'] ?? '',
      );
    }
  }
}
