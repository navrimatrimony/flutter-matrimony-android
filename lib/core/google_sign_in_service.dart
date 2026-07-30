import 'package:google_sign_in/google_sign_in.dart';

/// Wraps the Google account chooser.
///
/// Everything about "which Google account" stops here. The rest of the app only
/// ever sees the ID token this produces, and the server is what turns that into
/// a session — the app never decides who someone is.
class GoogleSignInService {
  GoogleSignInService._();

  /// The **web** OAuth client id, not the Android one.
  ///
  /// Google mints the ID token with this value as its audience, and the server
  /// rejects any token whose audience is not one of its own client ids. So this
  /// must stay equal to `GOOGLE_WEB_CLIENT_ID` in the Laravel `.env`; if the two
  /// drift apart, sign-in fails server-side with an audience error even though
  /// the account chooser worked.
  ///
  /// Not a secret — OAuth client ids ship inside every published app. The
  /// secret half of the pair lives only on the server and is never used here.
  static const String webClientId =
      '498783480915-f26vf8dvvku7ie5toqho95i5aflagseb.apps.googleusercontent.com';

  static bool _initialized = false;

  /// Returns the Google ID token, or `null` when the member backed out.
  ///
  /// A cancellation is not an error — the member closed the chooser on purpose,
  /// and the screen should go quiet rather than show a failure.
  static Future<String?> signIn() async {
    final signIn = GoogleSignIn.instance;

    if (!_initialized) {
      await signIn.initialize(serverClientId: webClientId);
      _initialized = true;
    }

    try {
      final account = await signIn.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const GoogleSignInFailure('missing_token');
      }
      return idToken;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        return null;
      }
      throw GoogleSignInFailure(error.code.name);
    }
  }

  /// Forgets the chosen account so the next tap shows the chooser again.
  ///
  /// Without this, signing out of the app leaves Google still holding the
  /// choice, and the next member on the same phone is silently handed the
  /// previous member's account.
  static Future<void> signOut() async {
    if (!_initialized) return;
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Losing the cached choice is best-effort; never block signing out.
    }
  }
}

class GoogleSignInFailure implements Exception {
  const GoogleSignInFailure(this.code);

  final String code;

  @override
  String toString() => 'GoogleSignInFailure($code)';
}
