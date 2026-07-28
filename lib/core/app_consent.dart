/// The consent version stamped on every mobile-OTP challenge.
///
/// `POST /auth/mobile-otp/send` requires `terms_version` and `privacy_version`,
/// and `MobileOtpService::persistConsents()` writes a `user_consents` row for
/// each one at verify time. Every screen that can start an OTP challenge —
/// registration and login alike — must therefore stamp the *same* version, or
/// the consent ledger records two different agreements for one document.
class AppConsent {
  const AppConsent._();

  /// Bump this when the T&C / Privacy Policy text itself changes.
  static const String version = '2026-06-24';
}
