import 'package:flutter/material.dart';

import 'api_client.dart';
import 'api_error_text.dart';
import 'app_language.dart';
import 'google_sign_in_service.dart';
import 'post_auth_router.dart';

/// The whole "tap Google, end up inside the app" journey, in one place.
///
/// Sign-up and sign-in run the identical sequence — chooser, server, profile
/// check — because from the moment Google hands over a token they *are* the
/// same journey. Only the server knows whether this address is new, and it
/// answers that itself. Keeping one implementation means a member cannot get a
/// different outcome depending on which screen they happened to start from.
///
/// Returns `true` once the member has been sent onwards, `false` if they backed
/// out of the chooser or the attempt failed (in which case the failure has
/// already been shown).
Future<bool> runGoogleAuthFlow(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final failureText = appText.googleSignInFailed;

  String? idToken;
  try {
    idToken = await GoogleSignInService.signIn();
  } catch (_) {
    // Includes a missing Android OAuth client, which is a setup fault rather
    // than the member's. Either way the honest thing to say is that it did not
    // go through and there are other doors.
    _show(messenger, failureText);
    return false;
  }

  // Null means the member closed the chooser. That is a decision, not a
  // failure, so the screen stays quiet and simply waits.
  if (idToken == null) return false;

  Map<String, dynamic> result;
  try {
    result = await ApiClient.signInWithGoogle(idToken: idToken);
  } catch (error) {
    _show(messenger, networkErrorText(error, label: 'Google sign-in'));
    return false;
  }

  if (result['token'] == null || result['token'].toString().trim().isEmpty) {
    // The chooser worked but the server refused the token. Do not leave Google
    // holding the account choice, or the next tap silently repeats the same
    // rejection with no chooser shown and no way for the member to pick again.
    await GoogleSignInService.signOut();
    _show(messenger, apiErrorText(result, failureText));
    return false;
  }

  final outcome = await resolvePostAuthDestination();
  if (!context.mounted) return false;

  if (outcome.destination == PostAuthDestination.failed) {
    _show(messenger, outcome.failureMessage ?? failureText);
    return false;
  }

  navigateAfterAuth(context, outcome.route!);
  return true;
}

void _show(ScaffoldMessengerState messenger, String message) {
  messenger.showSnackBar(
    SnackBar(content: Text(message), backgroundColor: Colors.red),
  );
}
