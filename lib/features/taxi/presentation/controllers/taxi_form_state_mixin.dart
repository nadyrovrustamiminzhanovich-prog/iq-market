import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

/// Mixin для управления состоянием полей формы заказа/поездки.
///
/// Содержит:
/// - Контроллеры текстовых полей (телефон, цена, комментарий)
/// - Маску ввода телефона +7 (###) ###-##-##
/// - Булевы флаги ошибок валидации
/// - Метод сброса ошибок при смене вкладки
///
/// Использование:
/// ```dart
/// class _MyScreenState extends State<MyScreen> with TaxiFormStateMixin {
///   @override
///   void dispose() {
///     disposeFormControllers();
///     super.dispose();
///   }
/// }
/// ```
mixin TaxiFormStateMixin<T extends StatefulWidget> on State<T> {
  // ─── Контроллеры полей ────────────────────────────────────────────────────

  final TextEditingController mainPhoneController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController activeOrderPriceController =
      TextEditingController();
  final TextEditingController commentController = TextEditingController();
  final FocusNode activeOrderPriceFocusNode = FocusNode();

  int? lastActiveOrderPrice;

  /// Маска ввода казахстанского номера телефона
  final MaskTextInputFormatter mainPhoneMask = MaskTextInputFormatter(
    mask: '+7 (###) ###-##-##',
    filter: {'#': RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );

  // ─── Флаги ошибок валидации ───────────────────────────────────────────────

  bool showFromError = false;
  bool showToError = false;
  bool showDateError = false;
  bool showTimeError = false;
  bool showPhoneError = false;
  bool showPriceError = false;

  // ─── Методы ──────────────────────────────────────────────────────────────

  /// Сбрасывает все ошибки формы.
  /// Вызывать при смене вкладки Пассажир/Водитель.
  void resetFormErrors() {
    setState(() {
      showFromError = false;
      showToError = false;
      showDateError = false;
      showTimeError = false;
      showPhoneError = false;
      showPriceError = false;
    });
  }

  /// Валидирует форму пассажира.
  /// Возвращает true если форма валидна.
  bool validatePassengerForm({
    required String from,
    required String to,
    required String date,
    required String time,
  }) {
    bool valid = true;
    setState(() {
      showFromError = from.isEmpty || from == 'from';
      showToError = to.isEmpty || to == 'to';
      showDateError = date.isEmpty || date == 'date';
      showTimeError = time.isEmpty || time == 'time';
      showPhoneError = mainPhoneController.text.length < 18;
      showPriceError = priceController.text.isEmpty;
    });
    if (showFromError || showToError || showDateError || showTimeError ||
        showPhoneError || showPriceError) {
      valid = false;
    }
    return valid;
  }

  /// Валидирует форму водителя.
  /// Возвращает true если форма валидна.
  bool validateDriverForm({
    required String from,
    required String to,
    required String date,
    required String time,
  }) {
    bool valid = true;
    setState(() {
      showFromError = from.isEmpty || from == 'from';
      showToError = to.isEmpty || to == 'to';
      showDateError = date.isEmpty || date == 'date';
      showTimeError = time.isEmpty || time == 'time';
      showPhoneError = mainPhoneController.text.length < 18;
      showPriceError = priceController.text.isEmpty;
    });
    if (showFromError || showToError || showDateError || showTimeError ||
        showPhoneError || showPriceError) {
      valid = false;
    }
    return valid;
  }

  /// Освобождает все ресурсы. Вызывать в dispose().
  void disposeFormControllers() {
    mainPhoneController.dispose();
    priceController.dispose();
    activeOrderPriceController.dispose();
    commentController.dispose();
    activeOrderPriceFocusNode.dispose();
  }
}
