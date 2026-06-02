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

  // Define replacements
  final Map<String, String> replacements = {
    // TopBar
    r"Widget _topBar\(TaxiProvider provider, TaxiTheme t\) \{([\s\S]*?)return Container\([\s\S]*?\n  \}": 
    "Widget _topBar(TaxiProvider provider, TaxiTheme t) => TaxiTopBar(provider: provider, t: t);",
    
    // Header
    r"Widget _header\(TaxiTheme t, TaxiProvider provider\) \{([\s\S]*?)return Container\([\s\S]*?\n  \}":
    "Widget _header(TaxiTheme t, TaxiProvider provider) => TaxiHeader(t: t, provider: provider);",
    
    // RoleSelector
    r"Widget _roleSelector\(TaxiProvider provider, TaxiTheme t\) \{([\s\S]*?)return Container\([\s\S]*?\n  \}":
    "Widget _roleSelector(TaxiProvider provider, TaxiTheme t) => TaxiRoleSelector(provider: provider, t: t);",

    // Loader
    r"Widget _loader\(TaxiTheme t\) => Center\(child: CircularProgressIndicator\(color: t.lime\)\);":
    "Widget _loader(TaxiTheme t) => TaxiLoaderWidget(t: t);",

    // SideMenu
    r"Widget _sideMenu\(TaxiProvider provider, TaxiTheme t\) \{([\s\S]*?)return Container\([\s\S]*?\n  \}":
    "Widget _sideMenu(TaxiProvider provider, TaxiTheme t) => TaxiSideMenu(provider: provider, t: t, scaffoldKey: _scaffoldKey);",

    // RatingWidget
    r"Widget _ratingWidget\(double rating, int count\) \{([\s\S]*?)return Container\([\s\S]*?\n  \}":
    "Widget _ratingWidget(double rating, int count) => TaxiRating(rating: rating, count: count);",

    // InfoChip
    r"Widget _infoChip\(IconData icon, String text, TaxiTheme t\) \{([\s\S]*?)return Container\([\s\S]*?\n  \}":
    "Widget _infoChip(IconData icon, String text, TaxiTheme t) => TaxiInfoChip(icon: icon, text: text, t: t);",

    // BlueInfoChip
    r"Widget _blueInfoChip\(IconData icon, String text\) \{([\s\S]*?)return Container\([\s\S]*?\n  \}":
    "Widget _blueInfoChip(IconData icon, String text) => TaxiBlueInfoChip(icon: icon, text: text);",

    // SummaryItem
    r"Widget _summaryItem\(IconData icon, String value, TaxiTheme t\) \{([\s\S]*?)return Container\([\s\S]*?\n  \}":
    "Widget _summaryItem(IconData icon, String value, TaxiTheme t) => TaxiSummaryItem(icon: icon, value: value, t: t);",
    
    // SectionHeader
    r"Widget _sectionHeader\(TaxiTheme t, String title\) \{([\s\S]*?)return Padding\([\s\S]*?\n  \}":
    "Widget _sectionHeader(TaxiTheme t, String title) => TaxiSectionHeader(t: t, title: title);",
    
    // CreateRideButton
    r"Widget _createRideButton\(TaxiProvider provider, TaxiTheme t\) \{([\s\S]*?)return Container\([\s\S]*?\n  \}":
    "Widget _createRideButton(TaxiProvider provider, TaxiTheme t) => TaxiCreateRideButton(provider: provider, t: t, onTap: () => _showCreateDrivePromptSheet(provider, t));",
  };

  for (final entry in replacements.entries) {
    final regExp = RegExp(entry.key);
    if (regExp.hasMatch(content)) {
      content = content.replaceFirst(regExp, entry.value);
      print("Replaced: \${entry.value}");
    } else {
      print("Failed to match: \${entry.value}");
    }
  }

  // Remove StableRadar
  final stableRadarRegExp = RegExp(r"class StableRadar extends StatefulWidget \{[\s\S]*?\}");
  if (stableRadarRegExp.hasMatch(content)) {
    content = content.replaceAll(stableRadarRegExp, "");
    print("Removed StableRadar");
  }

  await File(filePath).writeAsString(content);
  print("Wiring applied to \${filePath}");
}
