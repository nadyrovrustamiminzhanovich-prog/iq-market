const fs = require('fs');
let content = fs.readFileSync('lib/screens/taxi/taxi_service_screen.dart', 'utf8');

const methodToInsert = `
  void _navigateToLogin(TaxiProvider provider) {
    String loginLang = 'Русский';
    if (provider.curLang == 'kz') {
      loginLang = 'Қазақша';
    } else if (provider.curLang == 'uyg') {
      loginLang = 'Уйғурчә';
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LoginScreen(lang: loginLang),
      ),
    );
  }
}
`;

const lastBraceIndex = content.lastIndexOf('}');
if (lastBraceIndex !== -1) {
  content = content.substring(0, lastBraceIndex) + methodToInsert;
  fs.writeFileSync('lib/screens/taxi/taxi_service_screen.dart', content);
  console.log('Successfully inserted _navigateToLogin');
}
