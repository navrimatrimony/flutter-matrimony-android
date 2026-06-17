import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_matrimony_android/core/app_language.dart';
import 'package:flutter_matrimony_android/core/app_strings.dart';
import 'package:flutter_matrimony_android/main.dart';

void main() {
  testWidgets('Language choice appears before landing screen', (
    WidgetTester tester,
  ) async {
    appLanguage.value = null;

    await tester.pumpWidget(const MyApp());

    expect(find.text(AppStrings.chooseLanguage), findsOneWidget);
    expect(find.text(AppStrings.marathi), findsOneWidget);
    expect(find.text(AppStrings.english), findsOneWidget);

    await tester.tap(find.text(AppStrings.english));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.landingHeadline), findsOneWidget);
    expect(find.text(AppStrings.register), findsOneWidget);
    expect(find.text(AppStrings.login), findsOneWidget);
  });
}
