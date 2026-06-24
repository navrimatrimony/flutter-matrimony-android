import 'account_state.dart';

class MobileOtpSendResponse {
  const MobileOtpSendResponse({
    required this.success,
    this.challengeId,
    this.expiresIn,
    this.resendAfter,
    this.deliveryChannel,
    this.debugOtp,
    this.message,
    this.statusCode,
    this.raw = const <String, dynamic>{},
  });

  final bool success;
  final String? challengeId;
  final int? expiresIn;
  final int? resendAfter;
  final String? deliveryChannel;
  final String? debugOtp;
  final String? message;
  final int? statusCode;
  final Map<String, dynamic> raw;

  factory MobileOtpSendResponse.fromJson(Map<String, dynamic> json) {
    return MobileOtpSendResponse(
      success: _boolValue(json['success']) ?? false,
      challengeId: _stringValue(json['challenge_id']),
      expiresIn: _intValue(json['expires_in']),
      resendAfter: _intValue(json['resend_after']),
      deliveryChannel: _stringValue(json['delivery_channel']),
      debugOtp: _stringValue(json['debug_otp']),
      message: _stringValue(json['message']),
      statusCode: _intValue(json['statusCode']),
      raw: Map<String, dynamic>.from(json),
    );
  }
}

class MobileOtpVerifyResponse {
  const MobileOtpVerifyResponse({
    required this.success,
    this.token,
    this.tokenType,
    this.user = const <String, dynamic>{},
    this.accountState,
    this.message,
    this.statusCode,
    this.raw = const <String, dynamic>{},
  });

  final bool success;
  final String? token;
  final String? tokenType;
  final Map<String, dynamic> user;
  final AccountState? accountState;
  final String? message;
  final int? statusCode;
  final Map<String, dynamic> raw;

  factory MobileOtpVerifyResponse.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    return MobileOtpVerifyResponse(
      success: _boolValue(json['success']) ?? false,
      token: _stringValue(json['token']),
      tokenType: _stringValue(json['token_type']),
      user: user is Map ? Map<String, dynamic>.from(user) : <String, dynamic>{},
      accountState: AccountState.maybeFrom(json['account_state']),
      message: _stringValue(json['message']),
      statusCode: _intValue(json['statusCode']),
      raw: Map<String, dynamic>.from(json),
    );
  }
}

String? _stringValue(dynamic value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return null;
  return text;
}

int? _intValue(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

bool? _boolValue(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value?.toString().trim().toLowerCase();
  if (text == null || text.isEmpty) return null;
  if (text == '1' || text == 'true' || text == 'yes') return true;
  if (text == '0' || text == 'false' || text == 'no') return false;
  return null;
}
