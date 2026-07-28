import 'package:flutter/material.dart';
import 'package:iqmarket/screens/taxi/driver_onboarding_wizard.dart';

export 'package:iqmarket/screens/taxi/driver_onboarding_wizard.dart';

/// Совместимая обертка над [DriverOnboardingWizard].
class DriverVerificationScreen extends StatelessWidget {
  const DriverVerificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DriverOnboardingWizard();
  }
}
