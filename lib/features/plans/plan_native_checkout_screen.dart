import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:payu_checkoutpro_flutter/PayUConstantKeys.dart';
import 'package:payu_checkoutpro_flutter/payu_checkoutpro_flutter.dart';

import '../../core/api_client.dart';
import '../../core/api_error_text.dart';
import '../../core/app_language.dart';
import '../../core/app_strings.dart';
import 'plan_payment_result_screen.dart';

/// Confirm order + launch CheckoutPro (mockup pay-flow-02 / 03).
class PlanNativeCheckoutScreen extends StatefulWidget {
  const PlanNativeCheckoutScreen({
    super.key,
    required this.checkout,
  });

  final Map<String, dynamic> checkout;

  @override
  State<PlanNativeCheckoutScreen> createState() =>
      _PlanNativeCheckoutScreenState();
}

class _PlanNativeCheckoutScreenState extends State<PlanNativeCheckoutScreen>
    implements PayUCheckoutProProtocol {
  static const Color _brand = Color(0xFFDC2626);
  static const Color _surface = Color(0xFFFFF8F5);

  late final PayUCheckoutProFlutter _checkoutPro;
  bool _launching = false;
  bool _handlingCallback = false;
  bool _openingOverlay = false;
  String? _statusLine;

  Map<String, dynamic> get _payu {
    final raw = widget.checkout['payu'];
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{};
  }

  Map<String, dynamic> get _amount {
    final raw = widget.checkout['amount'];
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{};
  }

  String get _txnid => _string(_payu['txnid'] ?? widget.checkout['txnid']);

  String get _planName => _string(
        widget.checkout['plan_name'],
        fallback: AppStrings.plansTitle,
      );

  String get _couponCode => _string(widget.checkout['coupon_code']);

  @override
  void initState() {
    super.initState();
    _checkoutPro = PayUCheckoutProFlutter(this);
  }

  String _money(dynamic v) {
    if (v == null) return '—';
    if (v is num) {
      final s = v.toStringAsFixed(2);
      return s.endsWith('.00') ? v.toStringAsFixed(0) : s;
    }
    return v.toString();
  }

  Future<void> _startPayment() async {
    if (_launching || _handlingCallback) return;
    setState(() {
      _launching = true;
      _openingOverlay = true;
      _statusLine = currentAppLanguage == AppLanguage.marathi
          ? 'पेमेंट स्क्रीन उघडत आहे…'
          : 'Opening payment…';
    });

    try {
      final payu = _payu;
      final paymentParams = <String, dynamic>{
        PayUPaymentParamKey.key: _string(payu['key']),
        PayUPaymentParamKey.amount: _string(payu['amount']),
        PayUPaymentParamKey.productInfo: _string(payu['productinfo']),
        PayUPaymentParamKey.firstName: _string(payu['firstname']),
        PayUPaymentParamKey.email: _string(payu['email']),
        PayUPaymentParamKey.phone: _string(payu['phone']),
        PayUPaymentParamKey.android_surl: _string(payu['android_surl']),
        PayUPaymentParamKey.android_furl: _string(payu['android_furl']),
        PayUPaymentParamKey.ios_surl: _string(payu['ios_surl']),
        PayUPaymentParamKey.ios_furl: _string(payu['ios_furl']),
        PayUPaymentParamKey.environment: _string(
          payu['environment'],
          fallback: '0',
        ),
        PayUPaymentParamKey.userCredential: _string(payu['user_credential']),
        PayUPaymentParamKey.transactionId: _string(payu['txnid']),
        PayUPaymentParamKey.additionalParam: <String, dynamic>{
          PayUAdditionalParamKeys.udf1: _string(payu['udf1']),
          PayUAdditionalParamKeys.udf2: _string(payu['udf2']),
          PayUAdditionalParamKeys.udf3: _string(payu['udf3']),
          PayUAdditionalParamKeys.udf4: _string(payu['udf4']),
          PayUAdditionalParamKeys.udf5: _string(payu['udf5']),
        },
      };

      final config = <String, dynamic>{
        PayUCheckoutProConfigKeys.merchantName: 'Navri Mile Navryala',
        PayUCheckoutProConfigKeys.primaryColor: '#DC2626',
        PayUCheckoutProConfigKeys.secondaryColor: '#9F1239',
        PayUCheckoutProConfigKeys.showExitConfirmationOnCheckoutScreen: true,
        PayUCheckoutProConfigKeys.showExitConfirmationOnPaymentScreen: true,
        PayUCheckoutProConfigKeys.merchantResponseTimeout: 10000,
        PayUCheckoutProConfigKeys.cartDetails: <Map<String, String>>[
          {'Plan': _planName},
          {'Amount': '₹${_money(_amount['final_amount'] ?? payu['amount'])}'},
        ],
      };

      await _checkoutPro.openCheckoutScreen(
        payUPaymentParams: paymentParams,
        payUCheckoutProConfig: config,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _openingOverlay = false;
        _statusLine = failureText(
          currentAppLanguage == AppLanguage.marathi
              ? 'पेमेंट उघडता आले नाही.'
              : 'Could not open payment.',
          error,
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _launching = false;
        });
      }
    }
  }

  @override
  void generateHash(Map response) {
    () async {
      try {
        final hashName = _string(response[PayUHashConstantsKeys.hashName]);
        final hashString = _string(response[PayUHashConstantsKeys.hashString]);
        final hashType = response[PayUHashConstantsKeys.hashType]?.toString();
        final postSalt = response[PayUHashConstantsKeys.postSalt]?.toString();
        final txnid = _txnid;
        if (txnid.isEmpty) {
          throw StateError('Missing txnid for PayU hash request');
        }

        final api = await ApiClient.generatePayuHash(
          hashName: hashName,
          hashString: hashString,
          hashType: hashType,
          postSalt: postSalt,
          txnid: txnid,
        );

        Map<dynamic, dynamic> hashResponse = <dynamic, dynamic>{};
        final nested = api['hashResponse'];
        if (nested is Map) {
          hashResponse = Map<dynamic, dynamic>.from(nested);
        } else if (api['hash'] != null && hashName.isNotEmpty) {
          hashResponse = <dynamic, dynamic>{hashName: api['hash']};
        }

        if (hashResponse.isEmpty) {
          throw StateError('Empty hash response from server');
        }

        await _checkoutPro.hashGenerated(hash: hashResponse);
      } catch (error) {
        debugPrint('PayU generateHash failed: $error');
        if (!mounted) return;
        setState(() {
          _openingOverlay = false;
          _statusLine = currentAppLanguage == AppLanguage.marathi
              ? 'हॅश तयार करता आला नाही. पुन्हा प्रयत्न करा.'
              : 'Could not generate payment hash. Try again.';
        });
      }
    }();
  }

  @override
  void onPaymentSuccess(dynamic response) {
    _handleGatewayOutcome(outcome: 'success', response: response);
  }

  @override
  void onPaymentFailure(dynamic response) {
    _handleGatewayOutcome(outcome: 'failure', response: response);
  }

  @override
  void onPaymentCancel(Map? response) {
    _handleGatewayOutcome(outcome: 'cancelled', response: response);
  }

  @override
  void onError(Map? response) {
    _handleGatewayOutcome(outcome: 'error', response: response);
  }

  Future<void> _handleGatewayOutcome({
    required String outcome,
    required dynamic response,
  }) async {
    if (_handlingCallback) return;
    _handlingCallback = true;

    if (mounted) {
      setState(() {
        _openingOverlay = false;
        _statusLine = currentAppLanguage == AppLanguage.marathi
            ? 'परिणाम तपासत आहे…'
            : 'Confirming payment…';
      });
    }

    final map = _asStringKeyedMap(response);
    final txnid = _firstNonEmpty([
      map['txnid'],
      map['transactionId'],
      map['txnId'],
      _txnid,
    ]);

    PlanPaymentResult result;
    try {
      if (outcome == 'success') {
        final verify = await ApiClient.verifyPayuPayment(<String, dynamic>{
          'txnid': txnid,
          'outcome': 'success',
          'status': _string(map['status'], fallback: 'success'),
          'hash': _string(map['hash']),
          'amount': _string(map['amount']),
          'productinfo': _string(map['productinfo'] ?? map['productInfo']),
          'firstname': _string(map['firstname'] ?? map['firstName']),
          'email': _string(map['email']),
          'key': _string(map['key']),
          'udf1': _string(map['udf1']),
          'udf2': _string(map['udf2']),
          'udf3': _string(map['udf3']),
          'udf4': _string(map['udf4']),
          'udf5': _string(map['udf5']),
          'mihpayid': _string(map['mihpayid']),
          'mode': _string(map['mode']),
          'sdk_response': map,
        });

        final payment = verify['payment'];
        final activated = payment is Map && payment['activated'] == true;
        final ok = verify['success'] == true && activated;
        result = PlanPaymentResult(
          kind: ok
              ? PlanPaymentResultKind.success
              : PlanPaymentResultKind.failed,
          title: ok
              ? (currentAppLanguage == AppLanguage.marathi
                    ? 'पेमेंट यशस्वी'
                    : 'Payment successful')
              : (currentAppLanguage == AppLanguage.marathi
                    ? 'पेमेंट पूर्ण झाले, प्लॅन अद्याप सक्रिय नाही'
                    : 'Payment received, plan not active yet'),
          message: _string(
            verify['message'],
            fallback: ok
                ? (currentAppLanguage == AppLanguage.marathi
                      ? 'तुमची वर्गणी सक्रिय झाली आहे'
                      : 'Your subscription is now active')
                : (currentAppLanguage == AppLanguage.marathi
                      ? 'सपोर्टशी संपर्क करा. Txn: $txnid'
                      : 'Contact support. Txn: $txnid'),
          ),
          txnid: txnid,
          planName: _planName,
          amountLabel: '₹${_money(_amount['final_amount'] ?? _payu['amount'])}',
        );
      } else if (outcome == 'cancelled') {
        await ApiClient.verifyPayuPayment(<String, dynamic>{
          'txnid': txnid,
          'outcome': 'cancelled',
          'sdk_response': map,
        });
        result = PlanPaymentResult(
          kind: PlanPaymentResultKind.cancelled,
          title: currentAppLanguage == AppLanguage.marathi
              ? 'पेमेंट रद्द'
              : 'Payment cancelled',
          message: currentAppLanguage == AppLanguage.marathi
              ? 'तुम्ही पेमेंट रद्द केले. प्लॅन बदललेला नाही.'
              : 'You cancelled the payment. Plan was not changed.',
          txnid: txnid,
          planName: _planName,
        );
      } else {
        await ApiClient.verifyPayuPayment(<String, dynamic>{
          'txnid': txnid,
          'outcome': outcome == 'error' ? 'error' : 'failure',
          'status': _string(map['status'], fallback: 'failure'),
          'sdk_response': map,
        });
        result = PlanPaymentResult(
          kind: PlanPaymentResultKind.failed,
          title: currentAppLanguage == AppLanguage.marathi
              ? 'पेमेंट अयशस्वी'
              : 'Payment failed',
          message: _string(
            map['errorMsg'] ?? map['error_Message'] ?? map['field9'],
            fallback: currentAppLanguage == AppLanguage.marathi
                ? 'रक्कम कापली गेली नसेल. पुन्हा प्रयत्न करा.'
                : 'If money was not deducted, please try again.',
          ),
          txnid: txnid,
          planName: _planName,
        );
      }
    } catch (error) {
      result = PlanPaymentResult(
        kind: PlanPaymentResultKind.failed,
        title: currentAppLanguage == AppLanguage.marathi
            ? 'पुष्टी अयशस्वी'
            : 'Confirmation failed',
        message: failureText(
          currentAppLanguage == AppLanguage.marathi
              ? 'सर्व्हरवर पेमेंट तपासता आले नाही.'
              : 'Could not confirm payment with server.',
          error,
        ),
        txnid: txnid,
        planName: _planName,
      );
    }

    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => PlanPaymentResultScreen(result: result),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mr = currentAppLanguage == AppLanguage.marathi;
    final base = _amount['base_amount'];
    final finalAmt = _amount['final_amount'] ?? _payu['amount'];
    final discount = (_amount['coupon_discount'] as num?)?.toDouble() ?? 0;
    final days = widget.checkout['duration_days_total'] ??
        widget.checkout['duration_days'];

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        title: Text(mr ? 'पेमेंट पुष्टी' : 'Confirm payment'),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.receipt_long, color: _brand),
                          const SizedBox(width: 8),
                          Text(
                            mr ? 'ऑर्डर सारांश' : 'Order summary',
                            style: const TextStyle(
                              color: _brand,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _row(
                        Icons.workspace_premium_outlined,
                        mr ? 'प्लॅन' : 'Plan',
                        _planName,
                      ),
                      _row(
                        Icons.calendar_month_outlined,
                        mr ? 'कालावधी' : 'Duration',
                        days == null
                            ? '—'
                            : (mr ? '$days दिवस' : '$days days'),
                      ),
                      _row(
                        Icons.currency_rupee,
                        mr ? 'मूळ रक्कम' : 'Base amount',
                        '₹${_money(base)}',
                      ),
                      if (_couponCode.isNotEmpty)
                        _row(
                          Icons.local_offer_outlined,
                          mr ? 'कूपन' : 'Coupon',
                          _couponCode,
                        ),
                      if (discount > 0.004)
                        _row(
                          Icons.savings_outlined,
                          mr ? 'सवलत' : 'Discount',
                          '-₹${_money(discount)}',
                          valueColor: const Color(0xFF15803D),
                        ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Divider(height: 1),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              mr
                                  ? 'एकूण रक्कम (अंतिम)'
                                  : 'Total (final)',
                              style: TextStyle(
                                color: Colors.grey.shade800,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            '₹${_money(finalAmt)}',
                            style: const TextStyle(
                              color: Color(0xFF15803D),
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_txnid.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Txn: $_txnid',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
                if (_statusLine != null && !_openingOverlay) ...[
                  const SizedBox(height: 12),
                  Text(
                    _statusLine!,
                    style: TextStyle(color: Colors.grey.shade800),
                  ),
                ],
                const SizedBox(height: 28),
                FilledButton(
                  onPressed:
                      _launching || _handlingCallback ? null : _startPayment,
                  style: FilledButton.styleFrom(
                    backgroundColor: _brand,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    mr ? 'पेमेंट सुरू करा' : 'Start payment',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                TextButton(
                  onPressed: _launching || _handlingCallback
                      ? null
                      : () => Navigator.of(context).pop(false),
                  child: Text(
                    mr ? 'रद्द' : 'Cancel',
                    style: const TextStyle(color: _brand),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      mr
                          ? 'PayU द्वारे सुरक्षित पेमेंट'
                          : 'Secure payment by PayU',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_openingOverlay)
            ColoredBox(
              color: Colors.white.withValues(alpha: 0.92),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: _brand),
                      const SizedBox(height: 18),
                      Text(
                        mr
                            ? 'पेमेंट स्क्रीन उघडत आहे…'
                            : 'Opening payment…',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        mr
                            ? 'कृपया थांबा. ब्राउझर उघडणार नाही.'
                            : 'Please wait. No browser will open.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      if (_txnid.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Txn: $_txnid',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: _brand),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: TextStyle(color: Colors.grey.shade700)),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: valueColor ?? Colors.grey.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Map<String, dynamic> _asStringKeyedMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }
    if (value is String && value.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) {
          return decoded.map((key, val) => MapEntry(key.toString(), val));
        }
      } catch (_) {}
    }
    return <String, dynamic>{};
  }

  static String _string(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  static String _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      final text = _string(value);
      if (text.isNotEmpty) return text;
    }
    return '';
  }
}
