import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('GoogleSignIn constructor check', () {
    try {
      final googleSignIn = GoogleSignIn();
      print('GoogleSignIn() instantiation successful');
    } catch (e) {
      print('GoogleSignIn() failed: $e');
    }
  });
}
