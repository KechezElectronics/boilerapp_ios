import 'package:firebase_auth/firebase_auth.dart';

/// Customers never create an account. The app signs in to Firebase silently
/// (anonymously) the first time it runs; Firebase keeps that session on the
/// phone. The customer's only "login" is the device ID + claim code they enter
/// when adding a boiler (see DeviceStore.addDevice and database.rules.json).
///
/// Consequence: the silent session belongs to this app install. If the app is
/// uninstalled or its data is cleared, the customer simply adds their boilers
/// again with the same ID and claim code.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Emits the current user immediately, then whenever the session changes.
  Stream<User?> get authChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  /// Makes sure there is a session, creating the silent one if needed.
  /// Returns null on success, or a short message if it could not (usually no
  /// internet on first launch).
  Future<String?> ensureSignedIn() async {
    if (_auth.currentUser != null) return null;
    try {
      await _auth.signInAnonymously();
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'network-request-failed') {
        return 'No connection. Check your internet and try again.';
      }
      if (e.code == 'operation-not-allowed') {
        return 'Anonymous sign-in is switched off in the Firebase console (Authentication > Sign-in method).';
      }
      return 'Could not connect (${e.code}).';
    } catch (_) {
      return 'Could not connect. Please try again.';
    }
  }
}
