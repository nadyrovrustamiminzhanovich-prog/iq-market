const fs = require('fs');

let content = fs.readFileSync('lib/screens/taxi/taxi_service_screen.dart', 'utf8');
let lines = content.split('\n');

const pvStart = 1664;
const pvEnd = 1949;

const pvReplacement = `  Widget _passengerView(TaxiProvider provider, TaxiTheme t) {
    return TaxiPassengerView(
      provider: provider,
      t: t,
      onHandlePassengerCallOrChat: (data, {required isCall}) => _handlePassengerCallOrChat(provider, t, data, isCall: isCall),
      onNavigateToLogin: () => _navigateToLogin(provider),
      onShowPhoneBinding: (callback) => _showPhoneBindingSheet(context, provider, t, callback),
      complexFormWidget: _complexForm(provider, t),
    );
  }`;

const dvStart = 3978;
const dvEnd = 4180;

const dvReplacement = `  Widget _driverView(TaxiProvider provider, TaxiTheme t) {
    return TaxiDriverView(
      provider: provider,
      t: t,
      onHandleDriverCallOrChat: (data, {required isCall}) => _handleDriverCallOrChat(provider, t, data, isCall: isCall),
      onCheckDriverActionGate: (data, action) => _checkDriverActionGate(provider, t, data, action),
      buildSectionHeader: (title) => Padding(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 24, bottom: 8),
        child: Text(
          title,
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B)),
        ),
      ),
      routeFrom: _routeRow(t, provider.translate('from'), provider.driverFrom, true, provider, hasError: false, isDriver: true),
      routeTo: _routeRow(t, provider.translate('to'), provider.driverTo, false, provider, hasError: false, isDriver: true),
      dateLabel: (provider.selDate.isEmpty || provider.selDate == 'date') 
          ? 'Любая дата' 
          : (provider.selDate == 'today' ? 'Сегодня' : provider.selDate == 'tomorrow' ? 'Завтра' : provider.selDate),
      onDateTap: () => _pickDate(provider, t),
      onSwapTap: () {
        final temp = provider.driverFrom;
        final tempLat = provider.driverFromLat;
        final tempLng = provider.driverFromLng;
        provider.setDriverFrom(provider.driverTo, provider.driverToLat, provider.driverToLng);
        provider.setDriverTo(temp, tempLat, tempLng);
      },
      onSearchTap: () {
        HapticFeedback.lightImpact();
        // Trigger search UI updates if any
      },
      onBidTap: (bid) {
        _showBidDetailsBottomSheet(context, bid, provider, t);
      },
      onCreateRideTap: () {
        if (!provider.isLoggedIn) {
          _navigateToLogin(provider);
          return;
        }

        if (provider.phone.isEmpty || provider.phone == '+7 701 000 11 22' || provider.phone == '87010001122') {
          _showPhoneBindingSheet(context, provider, t, () {
            if (!provider.isVehicleVerified) {
              _showDriverVerificationGateDialog(
                provider, 
                t, 
                customText: 'Для создания собственных поездок необходимо пройти верификацию вашего автомобиля в профиле водителя.'
              );
            } else {
              _showDriverRideConfirmation(provider, t);
            }
          });
        } else if (!provider.isVehicleVerified) {
          _showDriverVerificationGateDialog(
            provider, 
            t, 
            customText: 'Для создания собственных поездок необходимо пройти верификацию вашего автомобиля в профиле водителя.'
          );
        } else {
          _showDriverRideConfirmation(provider, t);
        }
      },
      onNavigateToLogin: () => _navigateToLogin(provider),
      onShowPhoneBinding: (callback) => _showPhoneBindingSheet(context, provider, t, callback),
    );
  }`;

// We must splice starting from the end to not mess up the indices
lines.splice(dvStart, dvEnd - dvStart + 1, dvReplacement);
lines.splice(pvStart, pvEnd - pvStart + 1, pvReplacement);

fs.writeFileSync('lib/screens/taxi/taxi_service_screen.dart', lines.join('\n'));
console.log('Replaced both views successfully!');
