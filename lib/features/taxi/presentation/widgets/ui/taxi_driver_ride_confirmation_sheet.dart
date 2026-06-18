import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iqmarket/providers/taxi_provider.dart';
import 'package:iqmarket/services/notification_service.dart';
import 'package:iqmarket/theme/taxi_theme.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

import 'driver_ride_components/taxi_driver_ride_route_selector.dart';
import 'driver_ride_components/taxi_driver_ride_datetime_seats.dart';
import 'driver_ride_components/taxi_driver_ride_form_fields.dart';

/// Боттомшит создания поездки для водителя.
void showTaxiDriverRideConfirmationSheet({
  required BuildContext context,
  required TaxiProvider provider,
  required TaxiTheme t,
  String? initialFrom,
  String? initialTo,
  String? initialDate,
  String? initialTime,
  int? initialPrice,
  int? initialSeats,
  String? initialComment,
  required Future<void> Function(bool isFrom, bool isDriver) onOpenPicker,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: t.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
    ),
    builder: (ctx) => _TaxiDriverRideConfirmationSheetContent(
      provider: provider,
      t: t,
      initialFrom: initialFrom,
      initialTo: initialTo,
      initialDate: initialDate,
      initialTime: initialTime,
      initialPrice: initialPrice,
      initialSeats: initialSeats,
      initialComment: initialComment,
      onOpenPicker: onOpenPicker,
    ),
  );
}

class _TaxiDriverRideConfirmationSheetContent extends StatefulWidget {
  final TaxiProvider provider;
  final TaxiTheme t;
  final String? initialFrom;
  final String? initialTo;
  final String? initialDate;
  final String? initialTime;
  final int? initialPrice;
  final int? initialSeats;
  final String? initialComment;
  final Future<void> Function(bool isFrom, bool isDriver) onOpenPicker;

  const _TaxiDriverRideConfirmationSheetContent({
    required this.provider,
    required this.t,
    this.initialFrom,
    this.initialTo,
    this.initialDate,
    this.initialTime,
    this.initialPrice,
    this.initialSeats,
    this.initialComment,
    required this.onOpenPicker,
  });

  @override
  State<_TaxiDriverRideConfirmationSheetContent> createState() =>
      _TaxiDriverRideConfirmationSheetContentState();
}

class _TaxiDriverRideConfirmationSheetContentState
    extends State<_TaxiDriverRideConfirmationSheetContent> {
  late String localFrom;
  late String localTo;
  late String localDate;
  late String localTime;
  late int price;
  late int seats;

  late final MaskTextInputFormatter phoneMask;
  late final TextEditingController phoneC;
  late final TextEditingController commentC;
  late final TextEditingController priceCtrl;

  bool isPublishing = false;
  bool sFromError = false;
  bool sToError = false;
  bool sDateError = false;
  bool sTimeError = false;
  bool sPhoneError = false;
  bool sPriceError = false;

  @override
  void initState() {
    super.initState();
    localFrom = widget.initialFrom ?? "";
    localTo = widget.initialTo ?? "";
    localDate = widget.initialDate ?? "";
    localTime = widget.initialTime ?? "";
    price = widget.initialPrice ?? 0;
    seats = widget.initialSeats ?? 4;

    phoneMask = MaskTextInputFormatter(
      mask: '+7 (###) ###-##-##',
      filter: {"#": RegExp(r'[0-9]')},
      type: MaskAutoCompletionType.lazy,
    );

    final initialPhone = widget.provider.phone;
    phoneC = TextEditingController(text: initialPhone);
    commentC = TextEditingController(text: widget.initialComment ?? "");
    priceCtrl = TextEditingController(text: price > 0 ? price.toString() : "");
  }

  @override
  void dispose() {
    phoneC.dispose();
    commentC.dispose();
    priceCtrl.dispose();
    super.dispose();
  }

  void _pickDriverSeats() {
    showModalBottomSheet(
      context: context,
      backgroundColor: widget.t.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 20),
          Text(
            widget.provider.translate('sel_seats'),
            style: GoogleFonts.inter(
              color: widget.t.text,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: List.generate(
                7,
                (i) => GestureDetector(
                  onTap: () {
                    setState(() {
                      seats = i + 1;
                    });
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 50,
                    height: 50,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: seats == i + 1
                          ? const Color(0xFF4A80F0)
                          : widget.t.card,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: seats == i + 1
                            ? const Color(0xFF4A80F0)
                            : widget.t.border,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${i + 1}',
                        style: GoogleFonts.inter(
                          color: seats == i + 1 ? Colors.white : widget.t.text,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Future<void> _pickDateTime() async {
    HapticFeedback.selectionClick();
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (ctx, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.dark(
            primary: const Color(0xFF4A80F0),
            onPrimary: Colors.white,
            surface: widget.t.card,
            onSurface: widget.t.text,
          ),
        ),
        child: child!,
      ),
    );

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
          widget.provider.translate('jan'),
          widget.provider.translate('feb'),
          widget.provider.translate('mar'),
          widget.provider.translate('apr'),
          widget.provider.translate('may'),
          widget.provider.translate('jun'),
          widget.provider.translate('jul'),
          widget.provider.translate('aug'),
          widget.provider.translate('sep'),
          widget.provider.translate('oct'),
          widget.provider.translate('nov'),
          widget.provider.translate('dec'),
        ];
        dateStr = '${d.day} ${months[d.month - 1]}';
      }

      setState(() {
        localDate = dateStr;
        sDateError = false;
      });

      if (!mounted) return;
      final tVal = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        builder: (ctx, child) => Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: const Color(0xFF4A80F0),
              onPrimary: Colors.white,
              surface: widget.t.card,
              onSurface: widget.t.text,
            ),
          ),
          child: child!,
        ),
      );

      if (tVal != null) {
        setState(() {
          localTime = '${tVal.hour}:${tVal.minute.toString().padLeft(2, '0')}';
          sTimeError = false;
        });
      }
    }
  }

  Future<void> _publishRide() async {
    if (isPublishing) return;
    HapticFeedback.heavyImpact();

    final cleanPhone = phoneC.text.replaceAll(RegExp(r'\D'), '');
    final bool isPhoneValid = cleanPhone.length == 11 || cleanPhone.length == 10;

    setState(() {
      sFromError = localFrom.isEmpty;
      sToError = localTo.isEmpty;
      sDateError = localDate.isEmpty || localDate == 'date';
      sTimeError = localTime.isEmpty || localTime == 'time';
      sPhoneError = !isPhoneValid;
      sPriceError = price < 100;
    });

    if (sFromError ||
        sToError ||
        sDateError ||
        sTimeError ||
        sPhoneError ||
        sPriceError) {
      NotificationService.notify(
        context,
        widget.provider.translate('fill_details_title'),
        widget.provider.translate('fill_details_desc'),
        isSuccess: false,
      );
      return;
    }

    setState(() => isPublishing = true);
    try {
      if (phoneC.text.isNotEmpty) {
        widget.provider.updateProfile(
          widget.provider.firstName,
          widget.provider.lastName,
          phoneC.text,
        );
      }

      await widget.provider.createDriverRide(
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
          widget.provider.translate('ride_created_success'),
          widget.provider.translate('ride_created_desc'),
          isSuccess: true,
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        NotificationService.notify(
          context,
          widget.provider.translate('error_label'),
          widget.provider.translate('ride_create_err'),
          isSuccess: false,
        );
      }
    } finally {
      if (mounted) {
        setState(() => isPublishing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 20,
        left: 24,
        right: 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: widget.t.border,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              widget.provider.translate('create_ride_btn'),
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w900,
                color: widget.t.text,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.provider.translate('create_ride_desc_driver'),
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w500,
                color: widget.t.sub,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: widget.t.border, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TaxiDriverRideRouteSelector(
                    t: widget.t,
                    localFrom: localFrom,
                    localTo: localTo,
                    sFromError: sFromError,
                    sToError: sToError,
                    onFromTap: () async {
                      await widget.onOpenPicker(true, true);
                      setState(() {
                        localFrom = widget.provider.driverFrom;
                        sFromError = false;
                      });
                    },
                    onToTap: () async {
                      await widget.onOpenPicker(false, true);
                      setState(() {
                        localTo = widget.provider.driverTo;
                        sToError = false;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TaxiDriverRideDatetimeSeats(
                    t: widget.t,
                    localDate: localDate,
                    localTime: localTime,
                    seats: seats,
                    sDateError: sDateError,
                    sTimeError: sTimeError,
                    onDateTimeTap: _pickDateTime,
                    onSeatsTap: _pickDriverSeats,
                  ),
                  const SizedBox(height: 16),
                  TaxiDriverRideFormFields(
                    t: widget.t,
                    phoneC: phoneC,
                    priceCtrl: priceCtrl,
                    commentC: commentC,
                    phoneMask: phoneMask,
                    sPhoneError: sPhoneError,
                    sPriceError: sPriceError,
                    onPriceDecrement: () {
                      HapticFeedback.lightImpact();
                      if (price > 100) {
                        setState(() {
                          price -= 100;
                          priceCtrl.text = price.toString();
                          sPriceError = false;
                        });
                      }
                    },
                    onPriceIncrement: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        price += 100;
                        priceCtrl.text = price.toString();
                        sPriceError = false;
                      });
                    },
                    onPhoneChanged: (val) {
                      final cleanVal = val.replaceAll(RegExp(r'\D'), '');
                      if (cleanVal.length == 10 && sPhoneError) {
                        setState(() => sPhoneError = false);
                      }
                    },
                    onPriceChanged: (val) {
                      final valClean = val.replaceAll(RegExp(r'\D'), '');
                      final newPrice = valClean.isNotEmpty
                          ? (int.tryParse(valClean) ?? 0)
                          : 0;
                      
                      // Only call setState if error state needs to change to avoid rebuilding on every keystroke
                      if (sPriceError && newPrice >= 100) {
                        setState(() {
                          price = newPrice;
                          sPriceError = false;
                        });
                      } else {
                        price = newPrice;
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            isPublishing
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : GestureDetector(
                    onTap: _publishRide,
                    child: Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4A80F0), Color(0xFF4A80F0)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4A80F0)
                                .withValues(alpha: 0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          widget.provider.translate('publish_ride_btn'),
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
