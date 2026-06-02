import 'dart:io';

void main() async {
  final filePath = r'd:\iqmarket\lib\screens\taxi\taxi_service_screen.dart';
  var content = await File(filePath).readAsString();

  // 1. Add imports
  final imports = """
import 'package:iqmarket/widgets/taxi/taxi_ui_components.dart';
import 'package:iqmarket/widgets/auth/taxi_auth_form.dart';
import 'package:iqmarket/models/ad_model.dart';
import 'package:iqmarket/features/taxi/presentation/widgets/ui/taxi_loader_widget.dart';
import 'package:iqmarket/features/taxi/presentation/widgets/ui/taxi_top_bar_widget.dart';
import 'package:iqmarket/features/taxi/presentation/widgets/ui/taxi_header_widget.dart';
import 'package:iqmarket/features/taxi/presentation/widgets/ui/taxi_role_selector_widget.dart';
import 'package:iqmarket/features/taxi/presentation/widgets/ui/taxi_sos_bottom_sheet.dart';
import 'package:iqmarket/features/taxi/presentation/widgets/ui/taxi_side_menu_widget.dart';
import 'package:iqmarket/features/taxi/presentation/widgets/ui/taxi_active_bids_widget.dart';
import 'package:iqmarket/features/taxi/presentation/widgets/ui/taxi_rating_widget.dart';
import 'package:iqmarket/features/taxi/presentation/widgets/ui/taxi_route_row_widget.dart';
import 'package:iqmarket/features/taxi/presentation/widgets/ui/taxi_info_chips_widget.dart';
import 'package:iqmarket/features/taxi/presentation/widgets/ui/taxi_section_header_widget.dart';
import 'package:iqmarket/features/taxi/presentation/widgets/ui/taxi_create_ride_button.dart';
import 'package:iqmarket/features/taxi/presentation/widgets/ui/taxi_driver_search_form.dart';
import 'package:iqmarket/features/taxi/presentation/widgets/ui/taxi_complex_form.dart';
""";

  if (!content.contains('taxi_loader_widget.dart')) {
    content = content.replaceFirst(
      "import 'package:iqmarket/models/ad_model.dart';",
      imports
    );
  }

  // Replace function body with brace matching
  String replaceFunction(String content, String startPattern, String newFunction) {
    int startIndex = content.indexOf(startPattern);
    if (startIndex == -1) {
      print("Failed to find: \$startPattern");
      return content;
    }

    int braceStart = content.indexOf('{', startIndex);
    if (braceStart == -1) return content;

    int braceCount = 1;
    int endIndex = braceStart + 1;
    while (braceCount > 0 && endIndex < content.length) {
      if (content[endIndex] == '{') braceCount++;
      if (content[endIndex] == '}') braceCount--;
      endIndex++;
    }

    String fullFunction = content.substring(startIndex, endIndex);
    
    // Safety check: if function is too large, it might be an error
    if (fullFunction.length > 5000) {
      print("Function too large to replace safely: \$startPattern");
      return content;
    }

    print("Replaced: \$startPattern");
    return content.replaceFirst(fullFunction, newFunction);
  }
  
  // Also we need to replace arrow functions (like _loader)
  String replaceArrowFunction(String content, String startPattern, String arrowEndPattern, String newFunction) {
    int startIndex = content.indexOf(startPattern);
    if (startIndex == -1) return content;
    
    int endIndex = content.indexOf(arrowEndPattern, startIndex);
    if (endIndex == -1) return content;
    
    endIndex += arrowEndPattern.length;
    String fullFunction = content.substring(startIndex, endIndex);
    
    print("Replaced Arrow Function: \$startPattern");
    return content.replaceFirst(fullFunction, newFunction);
  }

  content = replaceArrowFunction(
    content, 
    "Widget _loader(TaxiTheme t) =>", 
    ");", 
    "Widget _loader(TaxiTheme t) => TaxiLoaderWidget(t: t);"
  );

  content = replaceFunction(
    content,
    "Widget _topBar(TaxiProvider provider, TaxiTheme t)",
    "// [STEP #16]\n  Widget _topBar(TaxiProvider provider, TaxiTheme t) => TaxiTopBar(provider: provider, t: t);"
  );

  content = replaceFunction(
    content,
    "Widget _header(TaxiTheme t, TaxiProvider provider)",
    "// [STEP #18]\n  Widget _header(TaxiTheme t, TaxiProvider provider) => TaxiHeader(t: t, provider: provider);"
  );

  content = replaceFunction(
    content,
    "Widget _roleSelector(TaxiProvider provider, TaxiTheme t)",
    "// [STEP #19]\n  Widget _roleSelector(TaxiProvider provider, TaxiTheme t) => TaxiRoleSelector(provider: provider, t: t);"
  );

  content = replaceFunction(
    content,
    "void _sosSheet(TaxiTheme t, TaxiProvider provider)",
    "// [STEP #17]\n  void _sosSheet(TaxiTheme t, TaxiProvider provider) => showTaxiSosBottomSheet(context, provider, t);"
  );

  content = replaceFunction(
    content,
    "Widget _sideMenu(TaxiProvider provider, TaxiTheme t)",
    "// [STEP #20]\n  Widget _sideMenu(TaxiProvider provider, TaxiTheme t) => TaxiSideMenu(provider: provider, t: t, scaffoldKey: _scaffoldKey);"
  );

  content = replaceFunction(
    content,
    "Widget _activeBids(TaxiProvider provider, TaxiTheme t, bool isDriver)",
    "// [STEP #22]\n  Widget _activeBids(TaxiProvider provider, TaxiTheme t, bool isDriver) => TaxiActiveBids(provider: provider, t: t, isDriver: isDriver, onCall: (bid) { _checkDriverActionGate(provider, t, bid, () => _handleDriverCallOrChat(provider, t, bid, isCall: true)); }, onChat: (bid) { _checkDriverActionGate(provider, t, bid, () => _handleDriverCallOrChat(provider, t, bid, isCall: false)); });"
  );

  content = replaceFunction(
    content,
    "Widget _ratingWidget(double rating, int count)",
    "// [STEP #25]\n  Widget _ratingWidget(double rating, int count) => TaxiRating(rating: rating, count: count);"
  );

  content = replaceFunction(
    content,
    "Widget _routeRow(TaxiTheme t, String label, String value, bool isFrom, TaxiProvider provider, {bool hasError = false, bool isDriver = false})",
    "// [STEP #26]\n  Widget _routeRow(TaxiTheme t, String label, String value, bool isFrom, TaxiProvider provider, {bool hasError = false, bool isDriver = false}) => TaxiRouteRow(t: t, label: label, value: value, isFrom: isFrom, provider: provider, hasError: hasError, isDriver: isDriver, onTap: () async { FocusScope.of(context).unfocus(); var r = await Navigator.push(context, MaterialPageRoute(builder: (_) => TaxiSearchCityScreen(title: label))); if (r != null) { if (isDriver) { if (isFrom) provider.setDriverFrom(r); else provider.setDriverTo(r); } else { if (isFrom) provider.setFrom(r); else provider.setTo(r); } } });"
  );

  content = replaceFunction(
    content,
    "Widget _infoChip(IconData icon, String text, TaxiTheme t)",
    "// [STEP #23]\n  Widget _infoChip(IconData icon, String text, TaxiTheme t) => TaxiInfoChip(icon: icon, text: text, t: t);"
  );

  content = replaceFunction(
    content,
    "Widget _blueInfoChip(IconData icon, String text)",
    "// [STEP #23]\n  Widget _blueInfoChip(IconData icon, String text) => TaxiBlueInfoChip(icon: icon, text: text);"
  );

  content = replaceFunction(
    content,
    "Widget _summaryItem(IconData icon, String value, TaxiTheme t)",
    "// [STEP #23]\n  Widget _summaryItem(IconData icon, String value, TaxiTheme t) => TaxiSummaryItem(icon: icon, value: value, t: t);"
  );

  content = replaceFunction(
    content,
    "Widget _sectionHeader(TaxiTheme t, String title)",
    "// [STEP #24]\n  Widget _sectionHeader(TaxiTheme t, String title) => TaxiSectionHeader(t: t, title: title);"
  );

  content = replaceFunction(
    content,
    "Widget _createRideButton(TaxiProvider provider, TaxiTheme t)",
    "// [STEP #27]\n  Widget _createRideButton(TaxiProvider provider, TaxiTheme t) => TaxiCreateRideButton(provider: provider, t: t, onTap: () => _showCreateDrivePromptSheet(provider, t));"
  );

  content = replaceFunction(
    content,
    "Widget _driverSearchForm(TaxiProvider provider, TaxiTheme t)",
    "// [STEP #28]\n  Widget _driverSearchForm(TaxiProvider provider, TaxiTheme t) => TaxiDriverSearchForm(t: t, routeFrom: _routeRow(t, provider.translate('from'), provider.driverFrom, true, provider, hasError: false, isDriver: true), routeTo: _routeRow(t, provider.translate('to'), provider.driverTo, false, provider, hasError: false, isDriver: true), dateLabel: provider.selDate == 'date' || provider.selDate.isEmpty ? 'Дата' : provider.selDate == 'today' ? 'Сегодня' : provider.selDate == 'tomorrow' ? 'Завтра' : provider.selDate == 'yesterday' ? 'Вчера' : provider.selDate, onDateTap: () => _pickDate(provider, t), onSwapTap: () { final f = provider.driverFrom; provider.setDriverFrom(provider.driverTo); provider.setDriverTo(f); }, onSearchTap: () { setState(() {}); });"
  );

  content = replaceFunction(
    content,
    "Widget _complexForm(TaxiProvider provider, TaxiTheme t)",
    "// [STEP #29]\n  Widget _complexForm(TaxiProvider provider, TaxiTheme t) => TaxiComplexForm(t: t, routeFrom: _routeRow(t, provider.translate('from'), provider.from, true, provider, hasError: _showFromError), routeTo: _routeRow(t, provider.translate('to'), provider.to, false, provider, hasError: _showToError), onSwapTap: () { final f = provider.from; provider.setFrom(provider.to); provider.setTo(f); }, hasDateError: _showDateError, hasTimeError: _showTimeError, dateText: provider.selDate, timeText: provider.selTime, onDateTimeTap: () => _pickDateTimeSequential(provider, t), passCnt: provider.passCnt, onPassTap: () => _pickPass(provider, t), priceController: _priceController, hasPriceError: _showPriceError, onPriceChanged: (v) { final val = int.tryParse(v.replaceAll(RegExp(r'[^\\\\d]'), '')) ?? 0; provider.setMaxPrice(val); }, onPriceClear: () { provider.setMaxPrice(0); _priceController.clear(); }, showPriceClear: provider.maxPrice > 0, commentController: _commentController, onCommentChanged: (v) { provider.setComment(v); }, onCommentClear: () { _commentController.clear(); provider.setComment(''); }, showCommentClear: _commentController.text.isNotEmpty, phoneController: _mainPhoneController, phoneFormatters: [_mainPhoneMask], hasPhoneError: _showPhoneError, onPhoneChanged: (v) {}, onOrderTap: () { _showPassengerOrderConfirmation(provider, t); });"
  );

  // Remove StableRadar correctly
  int radarIndex = content.indexOf("class StableRadar extends StatefulWidget {");
  if (radarIndex != -1) {
    int radarEndIndex = content.indexOf("}", radarIndex);
    if (radarEndIndex != -1) {
      radarEndIndex = content.indexOf("}", radarEndIndex + 1); // _StableRadarState end
      if (radarEndIndex != -1) {
        // Wait, just remove using simple substring if we know where it ends
      }
    }
    // Alternatively just use replaceAll with literal
  }
  
  content = content.replaceAll(RegExp(r"class StableRadar extends StatefulWidget \{[\s\S]*?class _StableRadarState extends State<StableRadar> with SingleTickerProviderStateMixin \{[\s\S]*?\}\n\}"), "// [STEP #21] StableRadar removed\n");

  await File(filePath).writeAsString(content);
  print("Wiring applied safely to \${filePath}");
}
