import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iqmarket/theme/taxi_theme.dart';
import 'package:iqmarket/providers/taxi_provider.dart';
import 'package:iqmarket/widgets/taxi/taxi_ui_components.dart';
import 'package:iqmarket/widgets/auth/telegram_verification_dialog.dart';

class TaxiRoleSelector extends StatelessWidget {
  final TaxiProvider provider;
  final TaxiTheme t;
  final VoidCallback onRoleChanged;

  const TaxiRoleSelector({
    super.key,
    required this.provider,
    required this.t,
    required this.onRoleChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          TaxiRoleCard(
            label: provider.translate('pass'),
            icon: Icons.person_rounded,
            isSelected: provider.tab == 0,
            t: t,
            onTap: () {
              HapticFeedback.selectionClick();
              onRoleChanged();
              provider.setTab(0);
            },
          ),
          TaxiRoleCard(
            label: provider.translate('drive'),
            icon: Icons.directions_car_rounded,
            isSelected: provider.tab == 1,
            t: t,
            onTap: () async {
              HapticFeedback.selectionClick();
              
              // Verify Telegram authentication state
              final isVerified = await provider.checkUserTelegramVerification();
              
              if (!isVerified) {
                if (context.mounted) {
                  final success = await TelegramVerificationDialog.show(context, provider: provider);
                  if (success) {
                    onRoleChanged();
                    provider.setTab(1);
                  }
                }
              } else {
                onRoleChanged();
                provider.setTab(1);
              }
            },
          ),
        ],
      ),
    );
  }
}

