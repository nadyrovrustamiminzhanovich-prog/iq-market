import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iqmarket/providers/taxi_provider.dart';
import 'package:iqmarket/services/notification_service.dart';
import 'package:iqmarket/theme/taxi_theme.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:iqmarket/data/car_data.dart';

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
    backgroundColor: const Color(0xFFF8FAFC),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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

  // Car Selection State
  late String selectedBrand;
  late String selectedModel;
  late int selectedYear;
  late String selectedColor;
  late final TextEditingController plateC;
  late final MaskTextInputFormatter plateMask;

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
    localFrom = widget.initialFrom ?? widget.provider.driverFrom;
    localTo = widget.initialTo ?? widget.provider.driverTo;
    localDate = widget.initialDate ?? (widget.provider.selDate == 'date' ? "" : widget.provider.selDate);
    localTime = widget.initialTime ?? (widget.provider.selTime == 'time' ? "" : widget.provider.selTime);
    price = widget.initialPrice ?? 0;
    seats = widget.initialSeats ?? 4;

    // Parser for existing car info
    final String curCar = widget.provider.driverCar;
    selectedBrand = 'Toyota';
    selectedModel = 'Camry';
    selectedYear = 2022;
    selectedColor = 'Белый';
    
    try {
      if (curCar.isNotEmpty && curCar != "Toyota Camry 70") {
        if (curCar.contains('(') && curCar.contains(')')) {
          final parts = curCar.split('(');
          final name = parts[0].trim();
          final meta = parts[1].replaceAll(')', '').split(',');
          
          final nameParts = name.split(' ');
          if (nameParts.isNotEmpty) {
            selectedBrand = nameParts[0];
            selectedModel = nameParts.sublist(1).join(' ');
          }
          if (meta.isNotEmpty) selectedColor = meta[0].trim();
          if (meta.length > 1) {
            selectedYear = int.tryParse(meta[1].replaceAll(RegExp(r'\D'), '').trim()) ?? 2022;
          }
        } else if (curCar.contains(',')) {
          final parts = curCar.split(',');
          final name = parts[0].trim();
          final nameParts = name.split(' ');
          if (nameParts.isNotEmpty) {
            selectedBrand = nameParts[0];
            selectedModel = nameParts.sublist(1).join(' ');
          }
          if (parts.length > 1) {
            selectedYear = int.tryParse(parts[1].replaceAll(RegExp(r'\D'), '').trim()) ?? 2022;
          }
          if (parts.length > 2) {
            selectedColor = parts[2].trim();
          }
        } else {
          final nameParts = curCar.split(' ');
          if (nameParts.isNotEmpty) {
            selectedBrand = nameParts[0];
            selectedModel = nameParts.sublist(1).join(' ');
          }
        }
      }
    } catch (e) {
      debugPrint('[Car Parser] Error: $e');
    }

    plateC = TextEditingController(text: widget.provider.driverPlate);
    plateMask = MaskTextInputFormatter(
      mask: '### @@@ ##',
      filter: { "#": RegExp(r'[0-9]'), "@": RegExp(r'[A-Za-z]') },
      type: MaskAutoCompletionType.lazy,
    );

    // Sync provider driverFrom/driverTo so that picker cancels don't reset fields to empty
    if (localFrom.isNotEmpty) {
      widget.provider.setDriverFrom(localFrom);
    }
    if (localTo.isNotEmpty) {
      widget.provider.setDriverTo(localTo);
    }

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
    plateC.dispose();
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

      // Update provider's car info with the new selected details!
      final String formattedCar = '$selectedBrand $selectedModel ($selectedColor, $selectedYear)';
      widget.provider.updateCarInfo(formattedCar, plateC.text.toUpperCase());

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
        setState(() => isPublishing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rawBtnText = widget.provider.translate('publish_ride_btn');
    final btnText = rawBtnText.replaceAll('🚀', '').trim().toUpperCase();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        top: 12,
        left: 16,
        right: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

            // Route Selector (FROM & TO Cards)
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

            const SizedBox(height: 12),

            // Date & Time + Seats Row Cards
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

            const SizedBox(height: 12),

            // Car Selection Card
            _buildCarSelectionCard(),

            const SizedBox(height: 12),

            // Form Fields Cards (Phone, Price, Comment)
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
                if (price < 1000000) {
                  setState(() {
                    price = (price + 100).clamp(0, 1000000);
                    priceCtrl.text = price.toString();
                    sPriceError = false;
                  });
                }
              },
              onPhoneChanged: (val) {
                final cleanVal = val.replaceAll(RegExp(r'\D'), '');
                if (cleanVal.length == 10 && sPhoneError) {
                  setState(() => sPhoneError = false);
                }
              },
              onPriceChanged: (val) {
                final valClean = val.replaceAll(RegExp(r'\D'), '');
                int newPrice = valClean.isNotEmpty
                    ? (int.tryParse(valClean) ?? 0)
                    : 0;
                if (newPrice > 1000000) {
                  newPrice = 1000000;
                  priceCtrl.text = '1000000';
                  priceCtrl.selection = TextSelection.fromPosition(
                    TextPosition(offset: priceCtrl.text.length),
                  );
                }
                
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

            const SizedBox(height: 20),

            // Submit Button (WITHOUT ROCKET ICON!)
            isPublishing
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(12.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : GestureDetector(
                    onTap: _publishRide,
                    child: Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF3B82F6).withValues(alpha: 0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          btnText,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ),
                  ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildCarSelectionCard() {
    final hasCar = selectedBrand.isNotEmpty && selectedModel.isNotEmpty;
    final displayCarName = hasCar ? '$selectedBrand $selectedModel' : 'Выберите Ваш автомобиль';
    final displayMeta = '$selectedColor • $selectedYear г.';
    final displayPlate = plateC.text.isNotEmpty ? plateC.text.toUpperCase() : '677 AEY 05';

    return InkWell(
      onTap: _showCarSelectionBottomSheet,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.directions_car_outlined,
                      color: Color(0xFF2563EB),
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.provider.translate('carBrandLabel').toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: const Color(0xFF94A3B8),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        displayCarName,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0F172A),
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        displayMeta,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF64748B),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.edit_outlined, size: 14, color: Color(0xFF2563EB)),
                      const SizedBox(width: 4),
                      Text(
                        'Изменить',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF2563EB),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Stylized KZ License Plate Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF000000), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00A3E0),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        const Text('🇰🇿', style: TextStyle(fontSize: 10)),
                        const SizedBox(width: 3),
                        Text(
                          'KZ',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    displayPlate,
                    style: GoogleFonts.firaCode(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF000000),
                      letterSpacing: 2.0,
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

  void _showCarSelectionBottomSheet() {
    String tempBrand = selectedBrand;
    String tempModel = selectedModel;
    int tempYear = selectedYear;
    String tempColor = selectedColor;
    final tempPlateC = TextEditingController(text: plateC.text);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final keyboardPadding = MediaQuery.of(ctx).viewInsets.bottom;
          return AnimatedPadding(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.only(bottom: keyboardPadding),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              decoration: BoxDecoration(
                color: widget.t.bg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(color: widget.t.border, borderRadius: BorderRadius.circular(2)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Text(
                    'ДАННЫЕ АВТОМОБИЛЯ',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: widget.t.text, fontSize: 16),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      _buildSelectorRow(
                        title: widget.provider.translate('carBrandLabel'),
                        value: tempBrand.isNotEmpty ? tempBrand : 'Выберите марку',
                        icon: Icons.directions_car_rounded,
                        onTap: () => _showBrandSelectionList(setSheetState, (brand) {
                          setSheetState(() {
                            tempBrand = brand;
                            tempModel = '';
                          });
                        }),
                      ),
                      const SizedBox(height: 16),

                      _buildSelectorRow(
                        title: widget.provider.translate('carModelLabel'),
                        value: tempModel.isNotEmpty ? tempModel : 'Выберите модель',
                        icon: Icons.format_list_bulleted_rounded,
                        disabled: tempBrand.isEmpty,
                        onTap: () => _showModelSelectionList(setSheetState, tempBrand, (model) {
                          setSheetState(() {
                            tempModel = model;
                          });
                        }),
                      ),
                      const SizedBox(height: 16),

                      _buildSelectorRow(
                        title: widget.provider.translate('carYearLabel'),
                        value: '$tempYear г.',
                        icon: Icons.calendar_month_rounded,
                        onTap: () => _showYearSelectionList(setSheetState, (year) {
                          setSheetState(() {
                            tempYear = year;
                          });
                        }),
                      ),
                      const SizedBox(height: 16),

                      Text(
                        'Цвет автомобиля',
                        style: GoogleFonts.inter(color: widget.t.sub, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: carColors.map((colorMap) {
                          final isSelected = tempColor == colorMap['name'];
                          return GestureDetector(
                            onTap: () => setSheetState(() => tempColor = colorMap['name']),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF4A80F0).withValues(alpha: 0.1) : widget.t.card,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF4A80F0) : widget.t.border,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: Color(colorMap['color']),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Color(colorMap['border']), width: 1),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    colorMap['name'],
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.bold,
                                      color: widget.t.text,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),

                      Text(
                        'Госномер автомобиля',
                        style: GoogleFonts.inter(color: widget.t.sub, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: widget.t.border),
                        ),
                        child: TextField(
                          controller: tempPlateC,
                          scrollPadding: const EdgeInsets.only(bottom: 140),
                          style: GoogleFonts.firaCode(fontWeight: FontWeight.bold, color: widget.t.text),
                          inputFormatters: [plateMask, UpperCaseTextFormatter()],
                          decoration: InputDecoration(
                            hintText: '777 AAA 05',
                            hintStyle: GoogleFonts.firaCode(color: widget.t.sub.withValues(alpha: 0.4)),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: (tempBrand.isEmpty || tempModel.isEmpty || tempColor.isEmpty || tempPlateC.text.trim().length < 5)
                          ? null
                          : () {
                              setState(() {
                                selectedBrand = tempBrand;
                                selectedModel = tempModel;
                                selectedYear = tempYear;
                                selectedColor = tempColor;
                                plateC.text = tempPlateC.text;
                              });
                              Navigator.pop(ctx);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4A80F0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        'СОХРАНИТЬ',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
  }

  Widget _buildSelectorRow({
    required String title,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
    bool disabled = false,
  }) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: disabled ? widget.t.border.withValues(alpha: 0.1) : widget.t.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: widget.t.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: disabled ? widget.t.sub.withValues(alpha: 0.3) : const Color(0xFF4A80F0), size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.inter(color: widget.t.sub, fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: GoogleFonts.inter(
                      color: disabled ? widget.t.sub.withValues(alpha: 0.5) : widget.t.text,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.keyboard_arrow_right_rounded, color: widget.t.sub),
          ],
        ),
      ),
    );
  }

  void _showBrandSelectionList(StateSetter setSheetState, ValueChanged<String> onSelected) {
    String q = '';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) {
          final filteredBrands = carBrands
              .where((b) => b.toLowerCase().contains(q.toLowerCase()))
              .toList();

          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: BoxDecoration(
              color: widget.t.bg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(color: widget.t.border, borderRadius: BorderRadius.circular(2)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(widget.provider.translate('selectBrandTitle'), style: GoogleFonts.inter(color: widget.t.text, fontWeight: FontWeight.w900, fontSize: 16)),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    onChanged: (v) => setLocalState(() => q = v),
                    style: GoogleFonts.inter(color: widget.t.text, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: widget.provider.translate('searchBrandHint'),
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF4A80F0)),
                      filled: true,
                      fillColor: widget.t.card,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: filteredBrands.length,
                    itemBuilder: (ctx, i) {
                      final b = filteredBrands[i];
                      return ListTile(
                        onTap: () {
                          onSelected(b);
                          Navigator.pop(ctx);
                        },
                        leading: const Icon(Icons.directions_car_filled_rounded, color: Color(0xFF4A80F0)),
                        title: Text(b, style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: widget.t.text)),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showModelSelectionList(StateSetter setSheetState, String brand, ValueChanged<String> onSelected) {
    final models = carModels[brand] ?? [];
    if (models.isEmpty) {
      final controller = TextEditingController();
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: widget.t.bg,
          title: Text(widget.provider.translate('enterModelTitle'), style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: widget.t.text)),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: GoogleFonts.inter(color: widget.t.text, fontWeight: FontWeight.bold),
            decoration: InputDecoration(hintText: widget.provider.translate('exampleLoganHint')),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(widget.provider.translate('cancelBtnCap'))),
            TextButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  onSelected(controller.text.trim());
                }
                Navigator.pop(ctx);
              },
              child: Text(widget.provider.translate('okBtnCap')),
            ),
          ],
        ),
      );
      return;
    }

    String q = '';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) {
          final filteredModels = models
              .where((m) => m.toLowerCase().contains(q.toLowerCase()))
              .toList();

          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: BoxDecoration(
              color: widget.t.bg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(color: widget.t.border, borderRadius: BorderRadius.circular(2)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(widget.provider.translate('selectModelTitle').replaceAll('{brand}', brand), style: GoogleFonts.inter(color: widget.t.text, fontWeight: FontWeight.w900, fontSize: 16)),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    onChanged: (v) => setLocalState(() => q = v),
                    style: GoogleFonts.inter(color: widget.t.text, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: widget.provider.translate('searchModelHint'),
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF4A80F0)),
                      filled: true,
                      fillColor: widget.t.card,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: filteredModels.length,
                    itemBuilder: (ctx, i) {
                      final m = filteredModels[i];
                      return ListTile(
                        onTap: () {
                          onSelected(m);
                          Navigator.pop(ctx);
                        },
                        title: Text(m, style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: widget.t.text)),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showYearSelectionList(StateSetter setSheetState, ValueChanged<int> onSelected) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.45,
        decoration: BoxDecoration(
          color: widget.t.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: widget.t.border, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(widget.provider.translate('selectYearTitle'), style: GoogleFonts.inter(color: widget.t.text, fontWeight: FontWeight.w900, fontSize: 16)),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: carYears.length,
                itemBuilder: (ctx, i) {
                  final y = carYears[i];
                  return ListTile(
                    onTap: () {
                      onSelected(y);
                      Navigator.pop(ctx);
                    },
                    title: Text(widget.provider.translate('yearLabelFormat').replaceAll('{year}', y.toString()), textAlign: TextAlign.center, style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: widget.t.text)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
