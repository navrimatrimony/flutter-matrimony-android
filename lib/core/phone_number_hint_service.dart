import 'package:flutter/services.dart';

class PhoneNumberHintService {
  PhoneNumberHintService._();

  static const MethodChannel _channel = MethodChannel(
    'navri_matrimony/phone_number_hint',
  );

  static Future<String?> requestPhoneNumberHint() async {
    try {
      final value = await _channel.invokeMethod<String>(
        'requestPhoneNumberHint',
      );
      final text = value?.trim();
      return text == null || text.isEmpty ? null : text;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
