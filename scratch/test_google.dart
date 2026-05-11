import 'package:google_sign_in/google_sign_in.dart';

void main() {
  try {
    final gsi = GoogleSignIn(serverClientId: 'test');
    print('Success: ${gsi.runtimeType}');
  } catch (e) {
    print('Error: $e');
  }
}
