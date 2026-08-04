import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_client.dart';
import '../../core/api_error_text.dart';
import '../../core/app_language.dart';
import '../../core/app_strings.dart';
import 'plan_native_checkout_screen.dart';

/// Optional coupon step before native PayU confirm (mockup pay-flow-01).
class PlanCouponScreen extends StatefulWidget {
  const PlanCouponScreen({
    super.key,
    required this.plan,
    this.planTermId,
  });

  final Map<String, dynamic> plan;
  final int? planTermId;

  @override
  State<PlanCouponScreen> createState() => _PlanCouponScreenState();
}

class _PlanCouponScreenState extends State<PlanCouponScreen> {
  static const Color _brand = Color(0xFFDC2626);
  static const Color _surface = Color(0xFFFFF8F5);

  final TextEditingController _couponCtrl = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _appliedCode;
  Map<String, dynamic>? _checkout;

  String get _planName {
    final v = widget.plan['display_name'] ?? widget.plan['name'];
    return (v?.toString().trim().isNotEmpty ?? false)
        ? v.toString().trim()
        : AppStrings.plansTitle;
  }

  @override
  void dispose() {
    _couponCtrl.dispose();
    super.dispose();
  }

  Future<void> _prepareCheckout({String? couponCode, required bool goConfirm}) async {
    final planId = widget.plan['id'];
    final id = planId is int ? planId : int.tryParse('$planId');
    if (id == null) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final code = (couponCode ?? '').trim();
      final response = await ApiClient.startPlanCheckoutNative(
        id,
        planTermId: widget.planTermId,
        couponCode: code.isEmpty ? null : code,
      );
      if (!mounted) return;

      if (response['success'] != true) {
        setState(() {
          _error = (response['message']?.toString().trim().isNotEmpty ?? false)
              ? response['message'].toString()
              : (currentAppLanguage == AppLanguage.marathi
                    ? 'कूपन लागू करता आले नाही.'
                    : 'Could not apply coupon.');
          _appliedCode = null;
          _checkout = null;
        });
        return;
      }

      final raw = response['checkout'];
      final checkout = raw is Map<String, dynamic>
          ? raw
          : (raw is Map ? Map<String, dynamic>.from(raw) : null);
      if (checkout == null || checkout['payu'] is! Map) {
        setState(() {
          _error = currentAppLanguage == AppLanguage.marathi
              ? 'नेटिव्ह चेकआउट तयार झाले नाही.'
              : 'Native checkout could not be prepared.';
        });
        return;
      }

      setState(() {
        _checkout = checkout;
        _appliedCode = (checkout['coupon_code']?.toString().trim().isNotEmpty ?? false)
            ? checkout['coupon_code'].toString().trim()
            : (code.isEmpty ? null : code);
      });

      if (goConfirm) {
        await _openConfirm(checkout);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = failureText(
          currentAppLanguage == AppLanguage.marathi
              ? 'कूपन तपासता आले नाही.'
              : 'Could not check coupon.',
          error,
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _openConfirm(Map<String, dynamic> checkout) async {
    final completed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PlanNativeCheckoutScreen(checkout: checkout),
      ),
    );
    if (!mounted) return;
    Navigator.of(context).pop(completed == true);
  }

  Map<String, dynamic> get _amount {
    final a = _checkout?['amount'];
    if (a is Map<String, dynamic>) return a;
    if (a is Map) return Map<String, dynamic>.from(a);
    return <String, dynamic>{};
  }

  String _fmt(dynamic v) {
    if (v == null) return '—';
    if (v is num) {
      return v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 2);
    }
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    final mr = currentAppLanguage == AppLanguage.marathi;
    final discount = (_amount['coupon_discount'] as num?)?.toDouble() ?? 0;
    final base = _amount['base_amount'];
    final finalAmt = _amount['final_amount'];
    final hasDeal = _checkout != null && discount > 0.004;

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        title: Text(mr ? 'कूपन कोड' : 'Coupon code'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
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
                children: [
                  Icon(Icons.local_offer_rounded, size: 48, color: _brand),
                  const SizedBox(height: 12),
                  Text(
                    mr ? 'सवलत लागू करा' : 'Apply discount',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    mr
                        ? 'असल्यास कूपन कोड टाका (पर्यायी)'
                        : 'Enter a coupon if you have one (optional)',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600, height: 1.35),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _planName,
                    style: TextStyle(
                      color: Colors.grey.shade800,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _couponCtrl,
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[A-Za-z0-9_\-]'),
                            ),
                          ],
                          decoration: InputDecoration(
                            labelText: mr ? 'कूपन कोड' : 'Coupon code',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: _brand,
                                width: 1.5,
                              ),
                            ),
                          ),
                          onSubmitted: (_) {
                            if (!_busy) {
                              _prepareCheckout(
                                couponCode: _couponCtrl.text,
                                goConfirm: false,
                              );
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 56,
                        child: OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () => _prepareCheckout(
                                  couponCode: _couponCtrl.text,
                                  goConfirm: false,
                                ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _brand,
                            side: const BorderSide(color: _brand),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(mr ? 'लागू करा' : 'Apply'),
                        ),
                      ),
                    ],
                  ),
                  if (hasDeal) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Color(0xFF15803D),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              mr
                                  ? '₹${_fmt(discount)} सवलत लागू'
                                  : '₹${_fmt(discount)} discount applied',
                              style: const TextStyle(
                                color: Color(0xFF15803D),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (_appliedCode != null)
                            Text(
                              _appliedCode!,
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (_checkout != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        mr
                            ? 'मूळ ₹${_fmt(base)}'
                            : 'Base ₹${_fmt(base)}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          decoration: hasDeal
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                    Container(width: 1, height: 28, color: Colors.grey.shade300),
                    Expanded(
                      child: Text(
                        mr
                            ? 'आता ₹${_fmt(finalAmt)}'
                            : 'Now ₹${_fmt(finalAmt)}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: Color(0xFFB91C1C)),
              ),
            ],
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _busy
                  ? null
                  : () {
                      if (_checkout != null) {
                        _openConfirm(_checkout!);
                      } else {
                        _prepareCheckout(
                          couponCode: _couponCtrl.text,
                          goConfirm: true,
                        );
                      }
                    },
              style: FilledButton.styleFrom(
                backgroundColor: _brand,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      mr ? 'पुढे जा — पेमेंट पुष्टी' : 'Next — Confirm payment',
                      style: const TextStyle(fontSize: 16),
                    ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => _prepareCheckout(couponCode: '', goConfirm: true),
              child: Text(
                mr ? 'कूपन नको, थेट पुढे' : 'Skip coupon, continue',
                style: const TextStyle(color: _brand),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(
                  mr ? 'PayU सुरक्षित पेमेंट' : 'Secure payment by PayU',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
