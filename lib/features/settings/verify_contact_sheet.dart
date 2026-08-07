import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_client.dart';
import '../../core/app_language.dart';

/// Which contact detail is being claimed.
enum VerifiableContact { email, mobile }

/// Add or change an email or a mobile number — only by proving you hold it.
///
/// There is deliberately no "save" here. The member types the new value, the
/// server sends a code to THAT value, and only a correct code writes it to the
/// account. A number or address nobody proved is worth less than none at all:
/// it breaks password reset, it misroutes an OTP, and on a matrimony product it
/// can hand a stranger's phone number to a family.
///
/// Both flows are the same two steps, so they share one sheet. Only the API
/// pair and the keyboard differ.
class VerifyContactSheet extends StatefulWidget {
  const VerifyContactSheet({
    super.key,
    required this.contact,
    this.currentValue,
  });

  final VerifiableContact contact;
  final String? currentValue;

  static Future<bool?> show(
    BuildContext context, {
    required VerifiableContact contact,
    String? currentValue,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          VerifyContactSheet(contact: contact, currentValue: currentValue),
    );
  }

  @override
  State<VerifyContactSheet> createState() => _VerifyContactSheetState();
}

class _VerifyContactSheetState extends State<VerifyContactSheet> {
  static const Color _brand = Color(0xFFDC2626);

  final TextEditingController _valueController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  bool _sending = false;
  bool _verifying = false;
  String? _challengeId;
  String? _error;
  String? _notice;

  bool get _isEmail => widget.contact == VerifiableContact.email;
  bool get _mr => currentAppLanguage == AppLanguage.marathi;

  @override
  void initState() {
    super.initState();
    _valueController.text = widget.currentValue ?? '';
  }

  @override
  void dispose() {
    _valueController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  String get _title => _isEmail
      ? (_mr ? 'ईमेल जोडा किंवा बदला' : 'Add or change email')
      : (_mr ? 'मोबाइल नंबर बदला' : 'Change mobile number');

  String get _fieldLabel =>
      _isEmail ? (_mr ? 'ईमेल' : 'Email') : (_mr ? 'मोबाइल नंबर' : 'Mobile');

  String get _explainer => _isEmail
      ? (_mr
            ? 'या ईमेलवर 6 अंकी कोड पाठवला जाईल. कोड बरोबर आल्यावरच ईमेल खात्याला जोडला जाईल.'
            : 'A 6-digit code goes to this address. The email is saved only after the code checks out.')
      : (_mr
            ? 'या नंबरवर 6 अंकी कोड पाठवला जाईल. कोड बरोबर आल्यावरच नंबर बदलला जाईल.'
            : 'A 6-digit code goes to this number. The number changes only after the code checks out.');

  Future<void> _sendCode() async {
    final value = _valueController.text.trim();
    if (value.isEmpty) {
      setState(() => _error = _mr ? 'आधी भरा.' : 'Enter a value first.');
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
      _notice = null;
    });

    try {
      final response = _isEmail
          ? await ApiClient.sendEmailOtp(email: value)
          : await ApiClient.sendAccountMobileOtp(mobile: value);
      if (!mounted) return;

      // The two endpoint pairs disagree on shape: the mobile pair nests its
      // fields under `data`, the older email pair returns them flat. Read both
      // rather than reshaping a live API the onboarding flow already parses.
      final data = response['data'];
      final fields = data is Map ? data : response;
      final challengeId = fields['challenge_id']?.toString();
      if (response['success'] == true && challengeId != null) {
        // dev_show returns the code in the response while no provider is wired.
        final debugOtp = fields['debug_otp']?.toString();
        setState(() {
          _challengeId = challengeId;
          if (debugOtp != null && debugOtp.isNotEmpty) {
            _otpController.text = debugOtp;
            _notice = _mr ? 'कोड: $debugOtp' : 'Code: $debugOtp';
          }
        });
        return;
      }

      setState(() {
        _error =
            response['message']?.toString() ??
            (_mr ? 'कोड पाठवता आला नाही.' : 'Could not send the code.');
      });
    } catch (_) {
      if (!mounted) return;
      setState(
        () =>
            _error = _mr ? 'कोड पाठवता आला नाही.' : 'Could not send the code.',
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _verifyCode() async {
    final challengeId = _challengeId;
    final otp = _otpController.text.trim();
    if (challengeId == null || otp.isEmpty) return;

    setState(() {
      _verifying = true;
      _error = null;
    });

    try {
      final response = _isEmail
          ? await ApiClient.verifyEmailOtp(
              challengeId: challengeId,
              email: _valueController.text.trim(),
              otp: otp,
            )
          : await ApiClient.verifyAccountMobileOtp(
              challengeId: challengeId,
              otp: otp,
            );
      if (!mounted) return;

      if (response['success'] == true) {
        Navigator.of(context).pop(true);
        return;
      }
      setState(() {
        _error =
            response['message']?.toString() ??
            (_mr ? 'कोड जुळला नाही.' : 'That code did not match.');
      });
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _error = _mr ? 'कोड जुळला नाही.' : 'That code did not match.',
      );
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final awaitingCode = _challengeId != null;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              _explainer,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: Colors.black.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _valueController,
              enabled: !awaitingCode,
              keyboardType: _isEmail
                  ? TextInputType.emailAddress
                  : TextInputType.phone,
              inputFormatters: _isEmail
                  ? null
                  : [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
              decoration: InputDecoration(
                labelText: _fieldLabel,
                border: const OutlineInputBorder(),
                prefixIcon: Icon(_isEmail ? Icons.mail_outline : Icons.phone),
              ),
            ),
            if (awaitingCode) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: InputDecoration(
                  labelText: _mr ? '6 अंकी कोड' : '6-digit code',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock_outline),
                ),
              ),
            ],
            if (_notice != null) ...[
              const SizedBox(height: 10),
              Text(
                _notice!,
                style: const TextStyle(fontSize: 12, color: Color(0xFF15803D)),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(fontSize: 12, color: _brand),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brand,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _sending || _verifying
                    ? null
                    : (awaitingCode ? _verifyCode : _sendCode),
                child: _sending || _verifying
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        awaitingCode
                            ? (_mr ? 'पडताळून जतन करा' : 'Verify and save')
                            : (_mr ? 'कोड पाठवा' : 'Send code'),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            if (awaitingCode) ...[
              const SizedBox(height: 6),
              TextButton(
                onPressed: _sending
                    ? null
                    : () => setState(() {
                        _challengeId = null;
                        _otpController.clear();
                        _notice = null;
                        _error = null;
                      }),
                child: Text(_mr ? 'दुसरे भरा' : 'Use a different one'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
