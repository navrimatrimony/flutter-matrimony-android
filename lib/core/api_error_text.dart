import 'package:flutter/foundation.dart';

import 'app_strings.dart';

/// Turns an API reply into something a member can read.
///
/// Lifted out of `login_screen.dart` when the forgot-password flow needed the
/// same behaviour. Copying it would have been the duplicate that drifts: both
/// screens talk to the same Laravel app and must read the same two envelopes.
///
/// Laravel hands back two different failure shapes and both matter here:
///
/// * a business failure is `{"success": false, "message": "..."}` — this is
///   how `PasswordResetApiController` reports an unknown account, an expired
///   reset token, and its 60-second "Please wait before retrying" throttle;
/// * a validation failure is `{"message": "...", "errors": {"field": ["..."]}}`
///   with **no** `success` key, because this project has no exception handler
///   reshaping `ValidationException`.
///
/// The server's own wording wins wherever it exists — it is already localised
/// by `SetApiLocale` from the `Accept-Language` header `ApiClient` sends — and
/// [fallback] is used only when the reply carries no usable text at all.
String apiErrorText(Map<String, dynamic> data, String fallback) {
  final message = data['message']?.toString().trim();
  if (message != null && message.isNotEmpty) return message;

  final errors = data['errors'];
  if (errors is Map) {
    for (final value in errors.values) {
      if (value is List && value.isNotEmpty) {
        final first = value.first?.toString().trim();
        if (first != null && first.isNotEmpty) return first;
      }
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty) return text;
    }
  }

  return fallback;
}

/// A thrown request means the server was never reached — a dropped socket, a
/// timeout, no signal. The member gets told that in their own language; the raw
/// exception (`SocketException: Failed host lookup…`) is never useful to a
/// rural family and is not shown.
String networkErrorText(Object error, {String label = 'Request'}) {
  debugPrint('$label failed: $error');
  return AppStrings.loginNetworkError;
}
