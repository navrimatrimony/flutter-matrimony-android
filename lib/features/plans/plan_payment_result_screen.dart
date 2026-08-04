import 'package:flutter/material.dart';

import '../../core/app_language.dart';

enum PlanPaymentResultKind { success, failed, cancelled }

class PlanPaymentResult {
  const PlanPaymentResult({
    required this.kind,
    required this.title,
    required this.message,
    this.txnid = '',
    this.planName = '',
    this.amountLabel = '',
  });

  final PlanPaymentResultKind kind;
  final String title;
  final String message;
  final String txnid;
  final String planName;
  final String amountLabel;

  bool get success => kind == PlanPaymentResultKind.success;
}

class PlanPaymentResultScreen extends StatelessWidget {
  const PlanPaymentResultScreen({super.key, required this.result});

  final PlanPaymentResult result;

  static const Color _brand = Color(0xFFDC2626);
  static const Color _surface = Color(0xFFFFF8F5);

  @override
  Widget build(BuildContext context) {
    final mr = currentAppLanguage == AppLanguage.marathi;
    final icon = switch (result.kind) {
      PlanPaymentResultKind.success => Icons.check_circle_rounded,
      PlanPaymentResultKind.cancelled => Icons.remove_circle_outline,
      PlanPaymentResultKind.failed => Icons.error_rounded,
    };
    final color = switch (result.kind) {
      PlanPaymentResultKind.success => const Color(0xFF15803D),
      PlanPaymentResultKind.cancelled => const Color(0xFFB45309),
      PlanPaymentResultKind.failed => const Color(0xFFB91C1C),
    };

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        title: Text(mr ? 'पेमेंट' : 'Payment'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(icon, size: 78, color: color),
              const SizedBox(height: 16),
              Text(
                result.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                result.message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  color: Colors.grey.shade800,
                ),
              ),
              if (result.planName.isNotEmpty ||
                  result.amountLabel.isNotEmpty ||
                  result.txnid.isNotEmpty) ...[
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.all(16),
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
                  child: Column(
                    children: [
                      if (result.planName.isNotEmpty)
                        _meta(
                          mr ? 'प्लॅन' : 'Plan',
                          result.planName,
                        ),
                      if (result.amountLabel.isNotEmpty)
                        _meta(
                          mr ? 'रक्कम' : 'Amount',
                          result.amountLabel,
                        ),
                      if (result.kind == PlanPaymentResultKind.success)
                        _meta(
                          mr ? 'स्थिती' : 'Status',
                          mr ? 'सक्रिय' : 'Active',
                          valueColor: const Color(0xFF15803D),
                        ),
                      if (result.txnid.isNotEmpty)
                        _meta('Txn', result.txnid),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              if (result.kind != PlanPaymentResultKind.success) ...[
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: FilledButton.styleFrom(
                    backgroundColor: _brand,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    result.kind == PlanPaymentResultKind.cancelled
                        ? (mr ? 'पुन्हा पेमेंट करा' : 'Pay again')
                        : (mr ? 'पुन्हा प्रयत्न करा' : 'Try again'),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _brand,
                    side: const BorderSide(color: _brand),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(mr ? 'प्लॅन्सकडे परत' : 'Back to plans'),
                ),
              ] else
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: _brand,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(mr ? 'प्लॅन्सकडे परत' : 'Back to plans'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _meta(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(color: Colors.grey.shade700)),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: valueColor ?? Colors.grey.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
