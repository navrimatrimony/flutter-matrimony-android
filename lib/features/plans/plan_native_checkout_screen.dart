import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:payu_checkoutpro_flutter/PayUConstantKeys.dart';
import 'package:payu_checkoutpro_flutter/payu_checkoutpro_flutter.dart';

import '../../core/api_client.dart';
import '../../core/api_error_text.dart';
import '../../core/app_language.dart';
import '../../core/app_strings.dart';
import 'plan_payment_result_screen.dart';

/// Confirm + launch PayU CheckoutPro, then verify on Laravel.
class PlanNativeCheckoutScreen extends StatefulWidget {
  const PlanNativeCheckoutScreen({
    super.key,
    required this.checkout,
  });

  /// Body of `POST /plans/{id}/checkout/native` → `checkout` object.
  final Map<String, dynamic> checkout;

  @override
  State<PlanNativeCheckoutScreen> createState() =>
      _PlanNativeCheckoutScreenState();
}

class _PlanNativeCheckoutScreenState extends State<PlanNativeCheckoutScreen>
    implements PayUCheckoutProProtocol {
  static const Color _brand = Color(0xFFDC2626);

  late final PayUCheckoutProFlutter _checkoutPro;
  bool _launching = false;
  bool _handlingCallback = false;
  String? _statusLine;

  Map<String, dynamic> get _payu {
    final raw = widget.checkout['payu'];
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{};
  }

  String get _txnid => _string(_payu['txnid'] ?? widget.checkout['txnid']);

  String get _planName => _string(
        widget.checkout['plan_name'],
        fallback: AppStrings.plansTitle,
      );

  String get _amountLabel {
    final amount = widget.checkout['amount'];
    if (amount is Map) {
      final finalAmount = amount['final_amount'] ?? amount['amount_string'];
      if (finalAmount != null) {
        return '₹$finalAmount';
      }
    }
    final payuAmount = _payu['amount'];
    if (payuAmount != null) return '₹$payuAmount';
    return '—';
  }

  @override
  void initState() {
    super.initState();
    _checkoutPro = PayUCheckoutProFlutter(this);
  }

  Future<void> _startPayment() async {
    if (_launching || _handlingCallback) return;
    setState(() {
      _launching = true;
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
          {'Amount': _amountLabel},
        ],
      };

      await _checkoutPro.openCheckoutScreen(
        payUPaymentParams: paymentParams,
        payUCheckoutProConfig: config,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
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
          success: ok,
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
                ? AppStrings.plansActiveSubscription
                : (currentAppLanguage == AppLanguage.marathi
                      ? 'सपोर्टशी संपर्क करा. Txn: $txnid'
                      : 'Contact support. Txn: $txnid'),
          ),
          txnid: txnid,
        );
      } else if (outcome == 'cancelled') {
        await ApiClient.verifyPayuPayment(<String, dynamic>{
          'txnid': txnid,
          'outcome': 'cancelled',
          'sdk_response': map,
        });
        result = PlanPaymentResult(
          success: false,
          title: currentAppLanguage == AppLanguage.marathi
              ? 'पेमेंट रद्द'
              : 'Payment cancelled',
          message: currentAppLanguage == AppLanguage.marathi
              ? 'तुम्ही पेमेंट रद्द केले.'
              : 'You cancelled the payment.',
          txnid: txnid,
        );
      } else {
        await ApiClient.verifyPayuPayment(<String, dynamic>{
          'txnid': txnid,
          'outcome': outcome == 'error' ? 'error' : 'failure',
          'status': _string(map['status'], fallback: 'failure'),
          'sdk_response': map,
        });
        result = PlanPaymentResult(
          success: false,
          title: currentAppLanguage == AppLanguage.marathi
              ? 'पेमेंट अयशस्वी'
              : 'Payment failed',
          message: _string(
            map['errorMsg'] ?? map['error_Message'] ?? map['field9'],
            fallback: currentAppLanguage == AppLanguage.marathi
                ? 'पेमेंट पूर्ण झाले नाही. पुन्हा प्रयत्न करा.'
                : 'Payment was not completed. Please try again.',
          ),
          txnid: txnid,
        );
      }
    } catch (error) {
      result = PlanPaymentResult(
        success: false,
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
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF7),
      appBar: AppBar(
        title: Text(
          currentAppLanguage == AppLanguage.marathi
              ? 'पेमेंट पुष्टी'
              : 'Confirm payment',
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _planName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                currentAppLanguage == AppLanguage.marathi
                    ? 'रक्कम: $_amountLabel'
                    : 'Amount: $_amountLabel',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Text(
                currentAppLanguage == AppLanguage.marathi
                    ? 'पेमेंट अॅपमध्येच पूर्ण होईल. ब्राउझर उघडणार नाही.'
                    : 'Payment completes inside the app. No browser.',
                style: TextStyle(color: Colors.grey.shade700, height: 1.35),
              ),
              if (_txnid.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Txn: $_txnid',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
              const Spacer(),
              if (_statusLine != null) ...[
                Text(
                  _statusLine!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade800),
                ),
                const SizedBox(height: 12),
              ],
              FilledButton(
                onPressed: _launching || _handlingCallback ? null : _startPayment,
                style: FilledButton.styleFrom(
                  backgroundColor: _brand,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _launching
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        currentAppLanguage == AppLanguage.marathi
                            ? 'पेमेंट सुरू करा'
                            : 'Pay now',
                        style: const TextStyle(fontSize: 16),
                      ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _launching || _handlingCallback
                    ? null
                    : () => Navigator.of(context).pop(false),
                child: Text(
                  currentAppLanguage == AppLanguage.marathi ? 'मागे' : 'Back',
                ),
              ),
            ],
          ),
        ),
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
