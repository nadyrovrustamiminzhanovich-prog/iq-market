// FILE: lib/features/taxi/presentation/widgets/ui/call_agreement_dialog.dart
// ОТВЕЧАЕТ ЗА: диалог «Вы договорились?» — появляется при возврате из звонка.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iqmarket/providers/taxi_provider.dart';
import 'package:iqmarket/services/notification_service.dart';
import 'package:iqmarket/theme/taxi_theme.dart';

void showCallAgreementDialog({
  required BuildContext context,
  required TaxiProvider provider,
  required TaxiTheme t,
  required String targetId,
  required String targetType,
  required String counterpartName,
  required String counterpartPhone,
  required String counterpartImg,
  required int suggestedPrice,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    enableDrag: false,
    builder: (ctx) => _CallAgreementSheet(
      provider: provider,
      t: t,
      targetId: targetId,
      targetType: targetType,
      counterpartName: counterpartName,
      counterpartPhone: counterpartPhone,
      counterpartImg: counterpartImg,
      suggestedPrice: suggestedPrice,
    ),
  );
}

class _CallAgreementSheet extends StatefulWidget {
  final TaxiProvider provider;
  final TaxiTheme t;
  final String targetId;
  final String targetType;
  final String counterpartName;
  final String counterpartPhone;
  final String counterpartImg;
  final int suggestedPrice;

  const _CallAgreementSheet({
    required this.provider,
    required this.t,
    required this.targetId,
    required this.targetType,
    required this.counterpartName,
    required this.counterpartPhone,
    required this.counterpartImg,
    required this.suggestedPrice,
  });

  @override
  State<_CallAgreementSheet> createState() => _CallAgreementSheetState();
}

class _CallAgreementSheetState extends State<_CallAgreementSheet>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _priceController;
  late final AnimationController _animController;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  bool _isProcessing = false;
  bool? _agreed; // null=не выбрано, true=да, false=нет

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(
      text: widget.suggestedPrice > 0 ? widget.suggestedPrice.toString() : '',
    );
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _scaleAnim = CurvedAnimation(parent: _animController, curve: Curves.elasticOut);
    _fadeAnim  = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _animController.forward();
  }

  @override
  void dispose() {
    _priceController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _confirmAgreement() async {
    if (_isProcessing) return;
    final priceText = _priceController.text.replaceAll(RegExp(r'\D'), '');
    final int price = int.tryParse(priceText) ?? widget.suggestedPrice;
    HapticFeedback.heavyImpact();
    setState(() => _isProcessing = true);
    try {
      await widget.provider.recordDirectCallTrip(
        targetId: widget.targetId,
        targetType: widget.targetType,
        agreedPrice: price,
      );
      if (!mounted) return;
      NotificationService.notify(
        context,
        'Поездка записана ✅',
        'Поездка за $price ₸ с ${widget.counterpartName} добавлена в историю',
        isSuccess: true,
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().contains('завершена')
          ? 'Эта поездка уже была записана ранее'
          : 'Не удалось записать поездку. Попробуйте снова.';
      NotificationService.notify(context, widget.provider.translate('errorTitle'), msg, isSuccess: false);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final bool isPassenger = widget.targetType == 'drive';
    final String roleLabel = isPassenger ? 'с водителем' : 'с пассажиром';

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Container(
            decoration: BoxDecoration(
              color: t.bg,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(32),
                topRight: Radius.circular(32),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 30,
                  offset: const Offset(0, -8),
                ),
              ],
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(color: t.border, borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Иконка
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4A80F0), Color(0xFF6366F1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: const Color(0xFF4A80F0).withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
                    ),
                    child: const Icon(Icons.phone_in_talk_rounded, color: Colors.white, size: 34),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Вы договорились?',
                    style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: t.text),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Вы только что позвонили $roleLabel.\nЕсли договорились — запишем поездку в историю.',
                    style: GoogleFonts.inter(fontSize: 13, color: t.sub, fontWeight: FontWeight.w500, height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  // Карточка контрагента
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: t.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: t.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52, height: 52,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(colors: [Color(0xFF4A80F0), Color(0xFF6366F1)]),
                          ),
                          child: ClipOval(
                            child: widget.counterpartImg.isNotEmpty && widget.counterpartImg.startsWith('http')
                                ? Image.network(widget.counterpartImg, fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.white, size: 26))
                                : const Icon(Icons.person, color: Colors.white, size: 26),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.counterpartName,
                                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: t.text)),
                              const SizedBox(height: 3),
                              Row(children: [
                                Icon(Icons.phone_rounded, size: 13, color: t.sub),
                                const SizedBox(width: 4),
                                Text(widget.counterpartPhone,
                                    style: GoogleFonts.inter(fontSize: 12, color: t.sub, fontWeight: FontWeight.w500)),
                              ]),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isPassenger
                                      ? const Color(0xFF4A80F0).withValues(alpha: 0.12)
                                      : const Color(0xFF84CC16).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  isPassenger ? '🚗 Водитель' : '🧍 Пассажир',
                                  style: GoogleFonts.inter(
                                    fontSize: 11, fontWeight: FontWeight.w700,
                                    color: isPassenger ? const Color(0xFF4A80F0) : const Color(0xFF4D7C0F),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Поле цены (только если согласились)
                  if (_agreed == true) ...[
                    const SizedBox(height: 20),
                    Text(widget.provider.translate('ridePriceLabel'), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: t.sub, letterSpacing: 0.8)),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: t.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF4A80F0).withValues(alpha: 0.4), width: 1.5),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: _priceController,
                              keyboardType: TextInputType.number,
                              autofocus: true,
                              style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: t.text),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: '0',
                                hintStyle: GoogleFonts.inter(color: t.sub),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: Text('₸', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: const Color(0xFF4A80F0))),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  // Кнопка ДА
                  if (_agreed != false) ...[
                    _isProcessing && _agreed == true
                        ? const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 16), child: CircularProgressIndicator()))
                        : SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: GestureDetector(
                              onTap: () async {
                                if (_agreed != true) {
                                  HapticFeedback.mediumImpact();
                                  setState(() => _agreed = true);
                                } else {
                                  await _confirmAgreement();
                                }
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF84CC16), Color(0xFF4D7C0F)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: [BoxShadow(color: const Color(0xFF84CC16).withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
                                    const SizedBox(width: 10),
                                    Text(
                                      _agreed == true ? 'Записать поездку в историю' : 'Да, уехали вместе ✓',
                                      style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                    const SizedBox(height: 12),
                  ],
                  // Кнопка НЕТ
                  if (_agreed != true)
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: GestureDetector(
                        onTap: () { HapticFeedback.lightImpact(); Navigator.pop(context); },
                        child: Container(
                          decoration: BoxDecoration(
                            color: t.card,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: t.border, width: 1.5),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_rounded, color: t.sub, size: 20),
                              const SizedBox(width: 8),
                              Text(widget.provider.translate('continueSearchBtn'),
                                  style: GoogleFonts.inter(color: t.sub, fontWeight: FontWeight.w700, fontSize: 14)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (_agreed == true) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () { HapticFeedback.lightImpact(); setState(() => _agreed = null); },
                      child: Text(widget.provider.translate('backBtn'), style: GoogleFonts.inter(color: t.sub, fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
