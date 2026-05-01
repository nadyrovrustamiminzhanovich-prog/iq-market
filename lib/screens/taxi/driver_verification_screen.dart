import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:iqmarket/providers/taxi_provider.dart';
import 'package:iqmarket/services/telegram_bot_service.dart';
import 'package:iqmarket/theme/taxi_theme.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DriverVerificationScreen extends StatefulWidget {
  const DriverVerificationScreen({super.key});
  @override
  State<DriverVerificationScreen> createState() => _DriverVerificationScreenState();
}

class _DriverVerificationScreenState extends State<DriverVerificationScreen>
    with TickerProviderStateMixin {
  int _step = 0;
  final _picker = ImagePicker();
  final _plateC = TextEditingController();
  final _carC   = TextEditingController();
  String? _selectedBrand;
  String? _selectedModel;
  final List<String> _carBrands = ['Toyota','Hyundai','Kia','Chevrolet','Lada (ВАЗ)','Mercedes-Benz','BMW','Audi','Volkswagen','Honda','Nissan','Mazda','Lexus','Subaru','Mitsubishi','Ford','Daewoo','Geely','Chery','Haval','BYD','Другая'];
  final Map<String,List<String>> _carModels = {
    'Toyota':['Camry','Corolla','Land Cruiser','RAV4','Prius','Highlander','Fortuner'],
    'Hyundai':['Sonata','Elantra','Tucson','Santa Fe','Accent','Creta'],
    'Kia':['Sportage','Cerato','K5','Sorento','Rio','Seltos'],
    'Chevrolet':['Spark','Nexia','Cobalt','Malibu','Captiva','Equinox'],
    'Lada (ВАЗ)':['Vesta','Granta','Niva','Priora','Kalina','2107'],
    'Mercedes-Benz':['E-Class','C-Class','S-Class','GLE','GLK','A-Class'],
    'BMW':['3 Series','5 Series','7 Series','X5','X6','X3'],
    'Audi':['A4','A6','Q7','Q5','A3','TT'],
    'Volkswagen':['Passat','Golf','Tiguan','Polo','Jetta'],
    'Honda':['Accord','Civic','CR-V','Pilot','Fit'],
    'Nissan':['Almera','X-Trail','Qashqai','Patrol','Tiida'],
    'Mazda':['Mazda3','Mazda6','CX-5','CX-9','MX-5'],
    'Lexus':['RX','LX','ES','GX','NX'],
    'Subaru':['Outback','Forester','Impreza','Legacy','XV'],
    'Mitsubishi':['Outlander','Pajero','Lancer','Eclipse Cross','ASX'],
    'Ford':['Focus','Mondeo','Explorer','Ranger','Escape'],
    'Daewoo':['Matiz','Nexia','Gentra','Lacetti'],
    'Geely':['Atlas','Coolray','Emgrand','Tugella'],
    'Chery':['Tiggo 7','Tiggo 4','Arrizo 5','Omoda 5'],
    'Haval':['F7','Jolion','H6','H9'],
    'BYD':['Han','Tang','Seal','Atto 3'],
    'Другая':[],
  };

  final _plateMask = MaskTextInputFormatter(
    mask: '### @@@ ##', 
    filter: { "#": RegExp(r'[0-9]'), "@": RegExp(r'[A-Za-z]') },
    type: MaskAutoCompletionType.lazy,
  );

  File? _licF, _licB, _techF, _techB, _selfie;
  bool _analyzing = false;
  bool _done = false;
  bool _needsManual = false;
  String _aiMsg = '';
  late AnimationController _dotCtrl;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _dotCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat(reverse: true);
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeInOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _dotCtrl.dispose(); _fadeCtrl.dispose();
    _plateC.dispose(); _carC.dispose();
    super.dispose();
  }

  // ── pick image ───────────────────────────────────────────────────────────────
  Future<void> _pick(String slot) async {
    final f = await _picker.pickImage(source: ImageSource.camera, imageQuality: 88);
    if (f == null) return;
    setState(() {
      switch (slot) {
        case 'lf': _licF  = File(f.path); break;
        case 'lb': _licB  = File(f.path); break;
        case 'tf': _techF = File(f.path); break;
        case 'tb': _techB = File(f.path); break;
        case 'se': _selfie = File(f.path); break;
      }
    });
  }

  // ── step validation ──────────────────────────────────────────────────────────
  bool get _canNext {
    switch (_step) {
      case 0: return _licF != null && _licB != null;
      case 1: return _techF != null && _techB != null;
      case 2: return _plateC.text.trim().length >= 5 && (_selectedBrand != null || _carC.text.trim().length >= 4);
      case 3: return _selfie != null;
      default: return false;
    }
  }

  // ── AI analysis ──────────────────────────────────────────────────────────────
  Future<void> _runAnalysis() async {
    setState(() { _analyzing = true; _aiMsg = 'Загружаем документы...'; });
    await _delay(900);
    setState(() => _aiMsg = 'Читаем текст на удостоверении...');
    await _delay(1100);
    setState(() => _aiMsg = 'Сверяем госномер с техпаспортом...');
    await _delay(1300);
    setState(() => _aiMsg = 'Финальная проверка...');
    await _delay(800);

    // Simulate: ~30% chance of needing manual review
    _needsManual = Random().nextInt(10) < 3;

    final provider = Provider.of<TaxiProvider>(context, listen: false);
    final prefs = await SharedPreferences.getInstance();
    final chatId = prefs.getString('telegram_chat_id') ?? '';
    final docId = '${provider.firstName}_${_plateC.text.trim()}_${DateTime.now().millisecondsSinceEpoch}';

    // Write verification request to Firestore
    await FirebaseFirestore.instance.collection('driver_verifications').doc(docId).set({
      'driver_name'    : '${provider.firstName} ${provider.lastName}',
      'plate'          : _plateC.text.trim().toUpperCase(),
      'car'            : _carC.text.trim(),
      'driver_chat_id' : chatId,
      'status'         : _needsManual ? 'pending_manual' : 'approved',
      'ai_quality'     : _needsManual ? 'low' : 'high',
      'submitted_at'   : FieldValue.serverTimestamp(),
    });

    if (_needsManual) {
      setState(() => _aiMsg = _t('ai_manual_msg'));
      await TelegramBotService.notifyAdminManualReview(
        driverName   : '${provider.firstName} ${provider.lastName}',
        plate        : _plateC.text.trim().toUpperCase(),
        carModel     : _carC.text.trim(),
        driverChatId : chatId,
        reviewDocId  : docId,
        reason       : 'Низкое качество фото (автоматический вывод ИИ)',
      );
    } else {
      provider.setVehicleVerified(true);
    }

    await _delay(600);
    setState(() { _analyzing = false; _done = true; });
  }

  Future<void> _delay(int ms) => Future.delayed(Duration(milliseconds: ms));

  void _next() {
    _fadeCtrl.reset();
    if (_step < 3) {
      setState(() => _step++);
      _fadeCtrl.forward();
    } else {
      _runAnalysis();
    }
  }

  String _t(String key) {
    return Provider.of<TaxiProvider>(context, listen: false).translate(key);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final p = Provider.of<TaxiProvider>(context);
    final t = p.theme;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(children: [
          _header(t),
          if (!_done && !_analyzing) _progressRow(t),
          Expanded(child: _body(t, p)),
          if (!_done && !_analyzing) _bottomBar(t),
        ]),
      ),
    );
  }

  // ── header ──────────────────────────────────────────────────────────────────
  Widget _header(TaxiTheme t) => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: [t.accent, t.accent.withValues(alpha: 0.75)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    ),
    padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 12, 16, 20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_t('driver_verif_title'), style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
          Text('${_t('step')} ${_step + 1} ${_t('of')} 4 — ${_t('security')}', style: GoogleFonts.inter(color: Colors.white70, fontSize: 11)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(24)),
          child: Text('${_step + 1}/4', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
        ),
      ]),
    ]),
  );

  // ── progress row ─────────────────────────────────────────────────────────────
  Widget _progressRow(TaxiTheme t) {
    final labels = [_t('licence_short'), _t('tech_short'), _t('car_short'), _t('selfie_short')];
    final icons  = [Icons.credit_card_rounded, Icons.article_rounded, Icons.directions_car_rounded, Icons.face_rounded];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
      child: Row(children: List.generate(4, (i) {
        final active = i == _step;
        final done   = i < _step;
        final color  = done ? Colors.green : (active ? t.accent : t.border);
        return Expanded(child: Row(children: [
          Expanded(child: i == 0 ? const SizedBox() : Container(height: 3, color: done ? Colors.green : t.border.withValues(alpha: 0.5))),
          Column(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: active ? 44 : 34, height: active ? 44 : 34,
              decoration: BoxDecoration(
                color: done ? Colors.green : (active ? t.accent.withValues(alpha: 0.1) : t.card),
                shape: BoxShape.circle,
                border: Border.all(color: color, width: active ? 2.5 : 1.5),
                boxShadow: active ? [BoxShadow(color: t.accent.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 3))] : [],
              ),
              child: Center(child: done
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                : Icon(icons[i], color: active ? t.accent : t.sub.withValues(alpha: 0.7), size: active ? 22 : 16)),
            ),
            const SizedBox(height: 6),
            Text(labels[i], style: GoogleFonts.inter(
              color: active ? t.accent : t.sub, 
              fontSize: active ? 12 : 11, 
              fontWeight: active ? FontWeight.w900 : FontWeight.w600,
              letterSpacing: -0.3
            )),
          ]),
          Expanded(child: i == 3 ? const SizedBox() : Container(height: 3, color: done ? Colors.green : t.border.withValues(alpha: 0.5))),
        ]));
      })),
    );
  }

  // ── body dispatcher ──────────────────────────────────────────────────────────
  Widget _body(TaxiTheme t, TaxiProvider p) {
    if (_analyzing) return _analyzingView(t);
    if (_done) return _doneView(t);
    return FadeTransition(
      opacity: _fadeAnim,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: [_licView, _techView, _carView, _selfieView][_step](t),
      ),
    );
  }

  // ── STEP 0: Driver licence ────────────────────────────────────────────────────
  Widget _licView(TaxiTheme t) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _sectionTitle(t, _t('licence_title'), _t('licence_sub')),
    const SizedBox(height: 20),
    _photoCard(t, _t('front_side'), _t('licence_front_sub'), _licF, () => _pick('lf')),
    const SizedBox(height: 16),
    _photoCard(t, _t('back_side'), _t('licence_back_sub'), _licB, () => _pick('lb')),
    const SizedBox(height: 24),
    _tipBox(t, _t('licence_tip')),
  ]);

  // ── STEP 1: Tech passport ─────────────────────────────────────────────────────
  Widget _techView(TaxiTheme t) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _sectionTitle(t, _t('tech_title'), _t('tech_sub')),
    const SizedBox(height: 20),
    _photoCard(t, _t('front_side'), _t('tech_front_sub'), _techF, () => _pick('tf')),
    const SizedBox(height: 16),
    _photoCard(t, _t('back_side'), _t('tech_back_sub'), _techB, () => _pick('tb')),
    const SizedBox(height: 24),
    _tipBox(t, _t('tech_tip')),
  ]);

  // ── STEP 2: Car info ──────────────────────────────────────────────────────────
  Widget _carView(TaxiTheme t) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _sectionTitle(t, _t('car_info_title'), _t('car_info_sub')),
    const SizedBox(height: 20),
    // Brand picker
    GestureDetector(
      onTap: () => _showBrandPicker(t),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: t.card, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _selectedBrand != null ? t.accent : t.border, width: _selectedBrand != null ? 2 : 1),
        ),
        child: Row(children: [
          Icon(Icons.directions_car_rounded, color: t.accent, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Text(_selectedBrand ?? _t('choose_brand'), style: GoogleFonts.inter(color: _selectedBrand != null ? t.text : t.sub, fontWeight: FontWeight.w700))),
          Icon(Icons.keyboard_arrow_down_rounded, color: t.sub),
        ]),
      ),
    ),
    const SizedBox(height: 12),
    // Model picker
    if (_selectedBrand != null && (_carModels[_selectedBrand!] ?? []).isNotEmpty)
      GestureDetector(
        onTap: () => _showModelPicker(t),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: t.card, borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _selectedModel != null ? t.accent : t.border, width: _selectedModel != null ? 2 : 1),
          ),
          child: Row(children: [
            Icon(Icons.list_rounded, color: t.accent, size: 22),
            const SizedBox(width: 12),
            Expanded(child: Text(_selectedModel ?? 'Выберите модель', style: GoogleFonts.inter(color: _selectedModel != null ? t.text : t.sub, fontWeight: FontWeight.w700))),
            Icon(Icons.keyboard_arrow_down_rounded, color: t.sub),
          ]),
        ),
      ),
    if (_selectedBrand != null && (_carModels[_selectedBrand!] ?? []).isEmpty)
      _field(t, _t('model'), _t('model_manual'), Icons.list_rounded, _carC),
    const SizedBox(height: 12),
    _field(t, _t('plate_label'), '777 AAA 05', Icons.pin_rounded, _plateC, textCaps: true, mask: _plateMask),
    const SizedBox(height: 20),
    _tipBox(t, _t('plate_tip')),
  ]);

  void _showBrandPicker(TaxiTheme t) {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(color: t.bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
        child: Column(children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: t.border, borderRadius: BorderRadius.circular(10))),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Text('Марка автомобиля', style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.w900, fontSize: 18))),
          const SizedBox(height: 12),
          Expanded(child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _carBrands.length,
            itemBuilder: (ctx, i) {
              final b = _carBrands[i];
              return GestureDetector(
                onTap: () { setState(() { _selectedBrand = b; _selectedModel = null; _carC.clear(); }); Navigator.pop(context); },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: _selectedBrand == b ? t.accent.withValues(alpha: 0.1) : t.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _selectedBrand == b ? t.accent : Colors.transparent, width: 1.5),
                  ),
                  child: Row(children: [
                    Icon(Icons.directions_car_filled_rounded, color: _selectedBrand == b ? t.accent : t.sub, size: 20),
                    const SizedBox(width: 12),
                    Text(b, style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    if (_selectedBrand == b) Icon(Icons.check_circle_rounded, color: t.accent, size: 18),
                  ]),
                ),
              );
            },
          )),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  void _showModelPicker(TaxiTheme t) {
    final models = _carModels[_selectedBrand!] ?? [];
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(color: t.bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
        child: Column(children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: t.border, borderRadius: BorderRadius.circular(10))),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Text('Модель $_selectedBrand', style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.w900, fontSize: 18))),
          const SizedBox(height: 12),
          Expanded(child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: models.length,
            itemBuilder: (ctx, i) {
              final m = models[i];
              return GestureDetector(
                onTap: () { setState(() { _selectedModel = m; _carC.text = '$_selectedBrand $m'; }); Navigator.pop(context); },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: _selectedModel == m ? t.accent.withValues(alpha: 0.1) : t.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _selectedModel == m ? t.accent : Colors.transparent, width: 1.5),
                  ),
                  child: Row(children: [
                    Text(m, style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    if (_selectedModel == m) Icon(Icons.check_circle_rounded, color: t.accent, size: 18),
                  ]),
                ),
              );
            },
          )),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  // ── STEP 3: Selfie ────────────────────────────────────────────────────────────
  Widget _selfieView(TaxiTheme t) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _sectionTitle(t, _t('selfie_title'), _t('selfie_sub')),
    const SizedBox(height: 24),
    GestureDetector(
      onTap: () => _pick('se'),
      child: Container(
        height: 240,
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _selfie != null ? Colors.green : t.border, width: 2),
        ),
        child: _selfie != null
          ? ClipRRect(borderRadius: BorderRadius.circular(22), child: Image.file(_selfie!, fit: BoxFit.cover, width: double.infinity))
          : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: t.accent.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: Icon(Icons.face_rounded, color: t.accent, size: 44)),
              const SizedBox(height: 16),
              Text(_t('tap_to_upload'), style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 6),
              Text(_t('selfie_hint'), style: GoogleFonts.inter(color: t.sub, fontSize: 12)),
            ]),
      ),
    ),
    const SizedBox(height: 20),
    _tipBox(t, _t('selfie_tip')),
  ]);

  // ── analyzing view ────────────────────────────────────────────────────────────
  Widget _analyzingView(TaxiTheme t) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    AnimatedBuilder(
      animation: _dotCtrl,
      builder: (_, __) => Container(
        width: 100, height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [
            t.accent.withValues(alpha: 0.3 + 0.4 * _dotCtrl.value),
            t.accent.withValues(alpha: 0.05),
          ]),
          boxShadow: [BoxShadow(color: t.accent.withValues(alpha: 0.4 * _dotCtrl.value), blurRadius: 30, spreadRadius: 10)],
        ),
        child: Icon(Icons.psychology_rounded, color: t.accent, size: 48),
      ),
    ),
    const SizedBox(height: 32),
    Text(_t('ai_analyzing'), style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.w900, fontSize: 20)),
    const SizedBox(height: 12),
    AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Text(_aiMsg, key: ValueKey(_aiMsg), textAlign: TextAlign.center,
        style: GoogleFonts.inter(color: t.sub, fontSize: 14)),
    ),
    const SizedBox(height: 32),
    SizedBox(width: 200, child: LinearProgressIndicator(color: t.accent, backgroundColor: t.border, borderRadius: BorderRadius.circular(4), minHeight: 6)),
  ]));

  // ── done view ─────────────────────────────────────────────────────────────────
  Widget _doneView(TaxiTheme t) => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 110, height: 110,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: (_needsManual ? Colors.orange : Colors.green).withValues(alpha: 0.12),
          border: Border.all(color: _needsManual ? Colors.orange : Colors.green, width: 3),
        ),
        child: Icon(_needsManual ? Icons.hourglass_top_rounded : Icons.verified_rounded,
          color: _needsManual ? Colors.orange : Colors.green, size: 56),
      ),
      const SizedBox(height: 28),
      Text(
        _needsManual ? _t('verif_manual_title') : _t('verif_done_title'),
        style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.w900, fontSize: 24),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 14),
      Text(
        _needsManual ? _t('verif_manual_desc') : _t('verif_done_desc'),
        style: GoogleFonts.inter(color: t.sub, fontSize: 13, height: 1.6),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 32),
      if (_needsManual)
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.orange.withValues(alpha: 0.2))),
          child: Row(children: [
            const Icon(Icons.telegram, color: Color(0xFF0088CC), size: 28),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_t('telegram_notif'), style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.w800, fontSize: 13)),
              Text(_t('telegram_bot_hint'), style: GoogleFonts.inter(color: t.sub, fontSize: 11)),
            ])),
          ]),
        ),
      const SizedBox(height: 28),
      SizedBox(width: double.infinity, height: 54,
        child: ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: _needsManual ? Colors.orange : Colors.green,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            elevation: 0,
          ),
          child: Text(_t('go_back'), style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
        ),
      ),
    ]),
  ));

  // ── bottom nav bar ────────────────────────────────────────────────────────────
  Widget _bottomBar(TaxiTheme t) => Container(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
    decoration: BoxDecoration(color: t.bg, border: Border(top: BorderSide(color: t.border))),
    child: Row(children: [
      if (_step > 0)
        GestureDetector(
          onTap: () { setState(() => _step--); _fadeCtrl.reset(); _fadeCtrl.forward(); },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: t.card, shape: BoxShape.circle, border: Border.all(color: t.border)),
            child: Icon(Icons.arrow_back_rounded, color: t.text, size: 22),
          ),
        ),
      if (_step > 0) const SizedBox(width: 12),
      Expanded(
        child: GestureDetector(
          onTap: _canNext ? _next : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 56,
            decoration: BoxDecoration(
              gradient: _canNext
                ? LinearGradient(colors: [t.accent, t.accent.withValues(alpha: 0.7)])
                : null,
              color: _canNext ? null : t.border,
              borderRadius: BorderRadius.circular(18),
              boxShadow: _canNext ? [BoxShadow(color: t.accent.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))] : [],
            ),
            child: Center(child: Text(
              _step == 3 ? _t('run_ai_btn') : '${_t('next')} →',
              style: GoogleFonts.inter(color: _canNext ? Colors.white : t.sub, fontWeight: FontWeight.w600, fontSize: 14, letterSpacing: 0.5),
            )),
          ),
        ),
      ),
    ]),
  );

  // ── reusable widgets ──────────────────────────────────────────────────────────
  Widget _sectionTitle(TaxiTheme t, String title, String sub) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5)),
    const SizedBox(height: 4),
    Text(sub, style: GoogleFonts.inter(color: t.sub, fontSize: 12)),
  ]);

  Widget _photoCard(TaxiTheme t, String title, String sub, File? file, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 130,
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: file != null ? Colors.green : t.border, width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: file != null
        ? ClipRRect(borderRadius: BorderRadius.circular(18), child: Stack(fit: StackFit.expand, children: [
            Image.file(file, fit: BoxFit.cover),
            Positioned(top: 8, right: 8, child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
              child: const Icon(Icons.check, color: Colors.white, size: 14),
            )),
          ]))
        : Row(children: [
            const SizedBox(width: 20),
            Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: t.accent.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(Icons.add_photo_alternate_rounded, color: t.accent, size: 28)),
            const SizedBox(width: 16),
            Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.w800, fontSize: 14)),
              const SizedBox(height: 4),
              Text(sub, style: GoogleFonts.inter(color: t.sub, fontSize: 11)),
              const SizedBox(height: 8),
              Text(_t('tap_to_upload'), style: GoogleFonts.inter(color: t.accent, fontSize: 11, fontWeight: FontWeight.w700)),
            ])),
          ]),
    ),
  );

  Widget _field(TaxiTheme t, String label, String hint, IconData icon, TextEditingController c, {bool textCaps = false, MaskTextInputFormatter? mask}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: GoogleFonts.inter(color: t.sub, fontSize: 12, fontWeight: FontWeight.w700)),
    const SizedBox(height: 8),
    TextField(
      controller: c,
      inputFormatters: mask != null ? [mask] : null,
      textCapitalization: textCaps ? TextCapitalization.characters : TextCapitalization.words,
      onChanged: (_) => setState(() {}),
      style: GoogleFonts.inter(color: t.text, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: t.sub.withValues(alpha: 0.5)),
        prefixIcon: Icon(icon, color: t.accent, size: 20),
        filled: true, fillColor: t.card,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: t.accent, width: 2)),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
      ),
    ),
  ]);

  Widget _tipBox(TaxiTheme t, String text) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: t.accent.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(14), border: Border.all(color: t.accent.withValues(alpha: 0.15))),
    child: Row(children: [
      Icon(Icons.info_outline_rounded, color: t.accent, size: 18),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: GoogleFonts.inter(color: t.sub, fontSize: 12, height: 1.4))),
    ]),
  );
}
