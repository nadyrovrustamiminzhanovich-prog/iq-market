import 'dart:io';

void main() async {
  final filePath = r'd:\iqmarket\lib\screens\taxi\taxi_service_screen.dart';
  var content = await File(filePath).readAsString();

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
    
    if (fullFunction.length > 25000) {
      print("Function too large: \$startPattern");
      return content;
    }

    print("Replaced: \$startPattern");
    return content.replaceFirst(fullFunction, newFunction);
  }
  
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
    "Widget _newHeader(TaxiProvider provider, TaxiTheme t) =>",
    ");",
    "// [STEP #18]\n  Widget _newHeader(TaxiProvider provider, TaxiTheme t) => TaxiHeader(t: t, provider: provider);"
  );

  content = replaceFunction(
    content,
    "void _showSosDialog(TaxiProvider provider, TaxiTheme t)",
    "// [STEP #17]\n  void _showSosDialog(TaxiProvider provider, TaxiTheme t) => showTaxiSosBottomSheet(context, provider, t);"
  );
  
  // Actually role selector is not a standalone function but an inline container in _passengerView maybe?
  // Let's replace _topBar arrow function
  content = replaceArrowFunction(
    content,
    "Widget _topBar(TaxiProvider provider, TaxiTheme t) =>",
    ");",
    "// [STEP #16]\n  Widget _topBar(TaxiProvider provider, TaxiTheme t) => TaxiTopBar(provider: provider, t: t);"
  );
  
  // DriverSearchForm
  content = replaceFunction(
    content,
    "Widget _driverSearchForm(TaxiProvider provider, TaxiTheme t)",
    "// [STEP #28]\n  Widget _driverSearchForm(TaxiProvider provider, TaxiTheme t) => TaxiDriverSearchForm(t: t, routeFrom: _routeRow(t, provider.translate('from'), provider.driverFrom, true, provider, hasError: false, isDriver: true), routeTo: _routeRow(t, provider.translate('to'), provider.driverTo, false, provider, hasError: false, isDriver: true), dateLabel: provider.selDate == 'date' || provider.selDate.isEmpty ? 'Дата' : provider.selDate == 'today' ? 'Сегодня' : provider.selDate == 'tomorrow' ? 'Завтра' : provider.selDate == 'yesterday' ? 'Вчера' : provider.selDate, onDateTap: () => _pickDate(provider, t), onSwapTap: () { final f = provider.driverFrom; provider.setDriverFrom(provider.driverTo); provider.setDriverTo(f); }, onSearchTap: () { setState(() {}); });"
  );

  // ComplexForm
  content = replaceFunction(
    content,
    "Widget _complexForm(TaxiProvider provider, TaxiTheme t)",
    "// [STEP #29]\n  Widget _complexForm(TaxiProvider provider, TaxiTheme t) => TaxiComplexForm(t: t, routeFrom: _routeRow(t, provider.translate('from'), provider.from, true, provider, hasError: _showFromError), routeTo: _routeRow(t, provider.translate('to'), provider.to, false, provider, hasError: _showToError), onSwapTap: () { final f = provider.from; provider.setFrom(provider.to); provider.setTo(f); }, hasDateError: _showDateError, hasTimeError: _showTimeError, dateText: provider.selDate, timeText: provider.selTime, onDateTimeTap: () => _pickDateTimeSequential(provider, t), passCnt: provider.passCnt, onPassTap: () => _pickPass(provider, t), priceController: _priceController, hasPriceError: _showPriceError, onPriceChanged: (v) { final val = int.tryParse(v.replaceAll(RegExp(r'[^\\d]'), '')) ?? 0; provider.setMaxPrice(val); }, onPriceClear: () { provider.setMaxPrice(0); _priceController.clear(); }, showPriceClear: provider.maxPrice > 0, commentController: _commentController, onCommentChanged: (v) { provider.setComment(v); }, onCommentClear: () { _commentController.clear(); provider.setComment(''); }, showCommentClear: _commentController.text.isNotEmpty, phoneController: _mainPhoneController, phoneFormatters: [_mainPhoneMask], hasPhoneError: _showPhoneError, onPhoneChanged: (v) {}, onOrderTap: () { _showPassengerOrderConfirmation(provider, t); });"
  );
  
  await File(filePath).writeAsString(content);
  print("Final wiring applied to \${filePath}");
}
