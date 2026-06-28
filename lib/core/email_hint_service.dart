import 'package:flutter/services.dart';

class GoogleEmailCredential {
  const GoogleEmailCredential({
    required this.email,
    this.idToken,
    this.googleAccount = true,
  });

  final String email;
  final String? idToken;
  final bool googleAccount;

  static String? _text(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  factory GoogleEmailCredential.fromMap(Map<dynamic, dynamic> source) {
    return GoogleEmailCredential(
      email: _text(source['email']) ?? '',
      idToken: _text(source['id_token'] ?? source['idToken']),
      googleAccount: source['is_google_account'] != false,
    );
  }
}

class EmailHintService {
  EmailHintService._();

  static const MethodChannel _channel = MethodChannel(
    'navri_matrimony/email_hint',
  );

  static Future<String?> requestEmailHint() async {
    try {
      final value = await _channel.invokeMethod<String>('requestEmailHint');
      final text = value?.trim();
      return text == null || text.isEmpty ? null : text;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  static Future<GoogleEmailCredential?> requestGoogleEmailVerification() async {
    try {
      final value = await _channel.invokeMethod<dynamic>(
        'requestGoogleEmailVerification',
      );
      if (value is Map) {
        final account = GoogleEmailCredential.fromMap(value);
        return account.email.isEmpty ? null : account;
      }
      final email = value?.toString().trim();
      if (email == null || email.isEmpty) return null;
      return GoogleEmailCredential(email: email);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
