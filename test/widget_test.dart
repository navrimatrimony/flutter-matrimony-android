import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_matrimony_android/main.dart';

void main() {
  testWidgets('Landing screen appears', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Find Your Perfect Match'), findsOneWidget);
    expect(find.text('Trusted Matrimonial Platform'), findsOneWidget);
    expect(find.text('Register'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });
}
