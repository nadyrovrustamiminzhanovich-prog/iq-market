import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iqmarket/providers/taxi_provider.dart';
import 'package:iqmarket/services/notification_service.dart';
import 'package:iqmarket/theme/taxi_theme.dart';

class TaxiActiveOrderPriceControl extends StatefulWidget {
  final int currentPrice;
  final String orderId;
  final TaxiProvider provider;
  final TaxiTheme t;

  const TaxiActiveOrderPriceControl({
    super.key,
    required this.currentPrice,
    required this.orderId,
    required this.provider,
    required this.t,
  });

  @override
  State<TaxiActiveOrderPriceControl> createState() => _TaxiActiveOrderPriceControlState();
}

class _TaxiActiveOrderPriceControlState extends State<TaxiActiveOrderPriceControl> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  int _typedPrice = 0;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentPrice.toString());
    _focusNode = FocusNode();
    _typedPrice = widget.currentPrice;
  }

  @override
  void didUpdateWidget(covariant TaxiActiveOrderPriceControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentPrice != oldWidget.currentPrice) {
      if (!_focusNode.hasFocus) {
        _typedPrice = widget.currentPrice;
        _controller.text = widget.currentPrice.toString();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 15,
              offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        children: [
          Text(
            'Предложить новую стоимость',
            style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF1E293B),
                fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    if (_typedPrice > 100) {
                      _typedPrice -= 100;
                      _controller.text = _typedPrice.toString();
                    }
                  });
                },
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: t.border, width: 2),
                  ),
                  child: Icon(Icons.remove, color: t.lime),
                ),
              ),
              const SizedBox(width: 15),
              Container(
                width: 130,
                alignment: Alignment.center,
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 24, fontWeight: FontWeight.w900, color: t.text),
                  decoration: InputDecoration(
                    suffixText: ' ₸',
                    suffixStyle: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: t.text),
                    border: InputBorder.none,
                  ),
                  onChanged: (val) {
                    final valClean = val.replaceAll(RegExp(r'\D'), '');
                    setState(() {
                      if (valClean.isNotEmpty) {
                        _typedPrice = int.tryParse(valClean) ?? widget.currentPrice;
                      } else {
                        _typedPrice = widget.currentPrice;
                      }
                    });
                  },
                ),
              ),
              const SizedBox(width: 15),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _typedPrice += 100;
                    _controller.text = _typedPrice.toString();
                  });
                },
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: t.border, width: 2),
                  ),
                  child: Icon(Icons.add, color: t.lime),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _typedPrice < 100
                ? null
                : () async {
                    _focusNode.unfocus();
                    HapticFeedback.heavyImpact();
                    await widget.provider.updateOrderPrice(widget.orderId, _typedPrice);
                    if (context.mounted) {
                      NotificationService.notify(
                          context,
                          'Цена обновлена',
                          'Новая цена: $_typedPrice ₸',
                          isSuccess: true);
                    }
                  },
            child: Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                gradient: _typedPrice < 100
                    ? null
                    : const LinearGradient(
                        colors: [Color(0xFF4A80F0), Color(0xFF1D4ED8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                color: _typedPrice < 100 ? const Color(0xFFE2E8F0) : null,
                borderRadius: BorderRadius.circular(16),
                boxShadow: _typedPrice < 100
                    ? null
                    : [
                        BoxShadow(
                          color: const Color(0xFF4A80F0).withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        )
                      ],
              ),
              child: Center(
                child: Text(
                  _typedPrice < 100 ? 'ВВЕДИТЕ СУММУ' : 'ПРЕДЛОЖИТЬ $_typedPrice ₸',
                  style: GoogleFonts.inter(
                    color: _typedPrice < 100 ? const Color(0xFF94A3B8) : Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
