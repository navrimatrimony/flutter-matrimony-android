import 'package:flutter/services.dart';

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
}
