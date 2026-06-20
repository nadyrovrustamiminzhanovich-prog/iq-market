// ─────────────────────────────────────────────────────────────────────────────
// FILE: lib/features/taxi/presentation/widgets/ui/taxi_complex_form.dart
// STEP: #29 | СЛОЙ: widgets/ui
// ОТВЕЧАЕТ ЗА: Сборку компонентов формы создания заказа
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:iqmarket/theme/taxi_theme.dart';
import 'package:iqmarket/features/taxi/presentation/widgets/ui/taxi_section_header_widget.dart';
import 'package:iqmarket/features/taxi/presentation/widgets/ui/complex_form_components/taxi_route_input.dart';
import 'package:iqmarket/features/taxi/presentation/widgets/ui/complex_form_components/taxi_datetime_seats_input.dart';
import 'package:iqmarket/features/taxi/presentation/widgets/ui/complex_form_components/taxi_price_input.dart';
import 'package:iqmarket/features/taxi/presentation/widgets/ui/complex_form_components/taxi_comment_input.dart';
import 'package:iqmarket/features/taxi/presentation/widgets/ui/complex_form_components/taxi_form_phone_input.dart';
import 'package:provider/provider.dart';
import 'package:iqmarket/providers/taxi_provider.dart';

class TaxiComplexForm extends StatelessWidget {
  final TaxiTheme t;
  
  // Маршрут
  final Widget routeFrom;
  final Widget routeTo;
  final VoidCallback onSwapTap;
  
  // Дата и время
  final bool hasDateError;
  final bool hasTimeError;
  final String dateText;
  final String timeText;
  final VoidCallback onDateTimeTap;
  
  // Места
  final int passCnt;
  final VoidCallback onPassTap;
  
  // Цена
  final TextEditingController priceController;
  final bool hasPriceError;
  final Function(String) onPriceChanged;
  final VoidCallback onPriceClear;
  final bool showPriceClear;
  
  // Комментарий
  final TextEditingController commentController;
  final Function(String) onCommentChanged;
  final VoidCallback onCommentClear;
  final bool showCommentClear;
  
  // Телефон
  final TextEditingController phoneController;
  final List<TextInputFormatter> phoneFormatters;
  final bool hasPhoneError;
  final Function(String) onPhoneChanged;
  
  // Кнопка поиска
  final VoidCallback onSubmitTap;

  const TaxiComplexForm({
    super.key,
    required this.t,
    required this.routeFrom,
    required this.routeTo,
    required this.onSwapTap,
    required this.hasDateError,
    required this.hasTimeError,
    required this.dateText,
    required this.timeText,
    required this.onDateTimeTap,
    required this.passCnt,
    required this.onPassTap,
    required this.priceController,
    required this.hasPriceError,
    required this.onPriceChanged,
    required this.onPriceClear,
    required this.showPriceClear,
    required this.commentController,
    required this.onCommentChanged,
    required this.onCommentClear,
    required this.showCommentClear,
    required this.phoneController,
    required this.phoneFormatters,
    required this.hasPhoneError,
    required this.onPhoneChanged,
    required this.onSubmitTap,
  });

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TaxiProvider>(context);
    final isTelegramUser = provider.isTelegramVerified || FirebaseAuth.instance.currentUser?.uid.startsWith('telegram_') == true;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          TaxiRouteInputWidget(
            routeFrom: routeFrom,
            routeTo: routeTo,
            onSwapTap: onSwapTap,
          ),
          const SizedBox(height: 12),
          
          TaxiDateTimeSeatsInputWidget(
            hasDateError: hasDateError,
            hasTimeError: hasTimeError,
            dateText: dateText,
            timeText: timeText,
            onDateTimeTap: onDateTimeTap,
            passCnt: passCnt,
            onPassTap: onPassTap,
          ),
          const SizedBox(height: 12),
          
          TaxiPriceInputWidget(
            priceController: priceController,
            hasPriceError: hasPriceError,
            onPriceChanged: onPriceChanged,
            onPriceClear: onPriceClear,
            showPriceClear: showPriceClear,
          ),
          const SizedBox(height: 12),
          
          TaxiCommentInputWidget(
            commentController: commentController,
            onCommentChanged: onCommentChanged,
            onCommentClear: onCommentClear,
            showCommentClear: showCommentClear,
          ),
          if (!isTelegramUser) ...[
            const SizedBox(height: 12),
            TaxiFormPhoneInputWidget(
              phoneController: phoneController,
              phoneFormatters: phoneFormatters,
              hasPhoneError: hasPhoneError,
              onPhoneChanged: onPhoneChanged,
            ),
          ],
          const SizedBox(height: 20),

          TaxiActBtn(
            t: t,
            label: provider.translate('lets_go'),
            color: t.accent,
            onTap: onSubmitTap,
            height: 56,
            borderRadius: 18,
          ),
        ],
      ),
    );
  }
}
