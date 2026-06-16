import 'package:flutter/material.dart';
import 'package:iqmarket/providers/taxi_provider.dart';
import 'package:iqmarket/theme/taxi_theme.dart';
import 'package:iqmarket/screens/taxi/taxi_user_profile_view.dart' show TaxiProfileViewScreen;

// Imports for the extracted dialog widgets
import 'package:iqmarket/features/taxi/presentation/widgets/ui/taxi_feedback_dialog.dart';
import 'package:iqmarket/features/taxi/presentation/widgets/ui/taxi_cancel_survey_dialog.dart';
import 'package:iqmarket/features/taxi/presentation/widgets/ui/taxi_match_success_dialog.dart';
import 'package:iqmarket/features/taxi/presentation/widgets/ui/taxi_comment_dialog.dart';
import 'package:iqmarket/features/taxi/presentation/widgets/ui/taxi_negotiate_dialog.dart';

/// Делегат-класс для всех вспомогательных диалогов такси-сервиса.
/// Теперь работает как фасад для разделенных виджетов диалогов.
class TaxiDialogsController {
  const TaxiDialogsController._();

  static void showFeedbackDialog(
    BuildContext context,
    TaxiProvider provider,
    TaxiTheme t,
    String targetUserId,
    String targetUserName,
  ) {
    showTaxiFeedbackDialog(context, provider, t, targetUserId, targetUserName);
  }

  static void showCancelSurveyDialog(
    BuildContext context,
    TaxiProvider provider,
    TaxiTheme t,
    String orderId,
  ) {
    showTaxiCancelSurveyDialog(context, provider, t, orderId);
  }

  static void showMatchSuccessDialog({
    required BuildContext context,
    required TaxiProvider provider,
    required TaxiTheme t,
    required String driverName,
    required String driverPhone,
    required String driverImg,
    required String driverCar,
    required String driverPlate,
    required int price,
    required String bidId,
  }) {
    showTaxiMatchSuccessDialog(
      context: context,
      provider: provider,
      t: t,
      driverName: driverName,
      driverPhone: driverPhone,
      driverImg: driverImg,
      driverCar: driverCar,
      driverPlate: driverPlate,
      price: price,
      bidId: bidId,
    );
  }

  static void showCommentDialog(
    BuildContext context,
    TaxiProvider provider,
    TaxiTheme t,
  ) {
    showTaxiCommentDialog(context, provider, t);
  }

  static void showNegotiateDialog(
    BuildContext context,
    TaxiProvider provider,
    TaxiTheme t,
    Map<String, dynamic> d, {
    required void Function(BuildContext, TaxiProvider, TaxiTheme, VoidCallback)
        onShowPhoneBinding,
  }) {
    showTaxiNegotiateDialog(context, provider, t, d, onShowPhoneBinding: onShowPhoneBinding);
  }

  static void showUserProfile(
    BuildContext context,
    TaxiProvider provider,
    TaxiTheme t,
    String name,
    String img,
    String car,
    bool isDriver,
    String targetUserId, {
    bool isVerified = false,
    String phone = '',
    required VoidCallback onNavigateToLogin,
  }) {
    if (!provider.isLoggedIn) {
      onNavigateToLogin();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TaxiProfileViewScreen(
          user: {
            'id': targetUserId,
            'name': name,
            'img': img.isNotEmpty
                ? img
                : 'https://images.unsplash.com/photo-1633332755192-727a05c4013d?w=800',
            'car': car,
            'phone': phone,
            'verified': isVerified,
          },
          isDriver: isDriver,
          theme: t,
          isCurrentUserVerified: provider.isVehicleVerified,
        ),
      ),
    );
  }
}
