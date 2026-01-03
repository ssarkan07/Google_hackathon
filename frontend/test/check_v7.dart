import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Check v7 API', () {
    // Uncommenting the line below causes compilation error if constructor is missing
    // final gs = GoogleSignIn();

    // Check if we can access .instance (if it exists)
    // We use dynamic to avoid static analysis blocking us if it doesn't exist,
    // but running it will tell us.
    // Actually, compilation will fail if I use it and it doesn't exist.
    // So I will try to assign it.

    try {
      // ignore: undefined_getter
      // var instance = GoogleSignIn.instance;
      // print('GoogleSignIn.instance found');
    } catch (e) {
      print('Error accessing instance: $e');
    }
  });
}
