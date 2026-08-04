import 'package:flutter/material.dart';

import '../../core/app_language.dart';
import '../../core/app_strings.dart';

class PlanPaymentResult {
  const PlanPaymentResult({
    required this.success,
    required this.title,
    required this.message,
    this.txnid = '',
  });

  final bool success;
  final String title;
  final String message;
  final String txnid;
}

class PlanPaymentResultScreen extends StatelessWidget {
  const PlanPaymentResultScreen({super.key, required this.result});

  final PlanPaymentResult result;

  @override
  Widget build(BuildContext context) {
    final color = result.success ? const Color(0xFF15803D) : const Color(0xFFB91C1C);

    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF7),
      appBar: AppBar(
        title: Text(AppStrings.plansTitle),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(
                result.success ? Icons.check_circle_rounded : Icons.cancel_rounded,
                size: 72,
                color: color,
              ),
              const SizedBox(height: 16),
              Text(
                result.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                result.message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  color: Colors.grey.shade800,
                ),
              ),
              if (result.txnid.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Txn: ${result.txnid}',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
              const Spacer(),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(result.success),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  currentAppLanguage == AppLanguage.marathi
                      ? 'प्लॅन्सकडे परत'
                      : 'Back to plans',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
