import 'package:flutter/material.dart';

/// The "G" that marks a Google button.
///
/// Shared by the sign-up and sign-in screens so the two doors look like the
/// same door — a member who recognises it on one should recognise it on the
/// other.
class GoogleBrandMark extends StatelessWidget {
  const GoogleBrandMark({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text(
      'G',
      style: TextStyle(
        color: Color(0xFF4285F4),
        fontSize: 22,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
    );
  }
}
