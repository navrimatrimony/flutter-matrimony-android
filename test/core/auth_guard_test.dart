import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_matrimony_android/core/api_client.dart';
import 'package:flutter_matrimony_android/core/app_language.dart';
import 'package:flutter_matrimony_android/core/app_storage.dart';
import 'package:flutter_matrimony_android/main.dart';

/// Reported from a real device: after logging out, every member screen was
/// still there. `pushReplacementNamed('/login')` swapped only the TOP route, so
/// a member who had reached Home from the match list was dropped back onto a
/// still-mounted match list — profiles, photos and all — the moment they
/// pressed Back, and could carry on opening screens from it.
///
/// Two invariants are locked in here:
///   1. signing out destroys the whole navigator stack, not just its top;
///   2. a member-only route refuses to paint anything without a session.
void main() {
  setUp(() {
    AppStorage.instance = AppStorage.memory();
    setAppLanguage(AppLanguage.english);
    ApiClient.authToken = null;
    ApiClient.currentUserProfile = null;
  });

  tearDown(() {
    ApiClient.authToken = null;
  });

  Widget harness({String initialRoute = '/matches'}) {
    return MaterialApp(
      initialRoute: initialRoute,
      routes: <String, WidgetBuilder>{
        '/matches': (_) =>
            const AuthenticatedRoute(child: _Screen('member-matches')),
        '/home': (_) => const AuthenticatedRoute(child: _Screen('member-home')),
        '/login': (_) => const _Screen('login'),
        '/landing': (_) => const _Screen('landing'),
      },
    );
  }

  testWidgets('signing out removes every member screen from the stack', (
    tester,
  ) async {
    ApiClient.authToken = 'test-token';

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    expect(find.text('member-matches'), findsOneWidget);

    // Exactly the real path: the match list pushes Home, and Home's drawer is
    // the only place the Logout button lives.
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    unawaitedPush(navigator, '/home');
    await tester.pumpAndSettle();
    expect(find.text('member-home'), findsOneWidget);

    await signOutAndReturnToLogin(navigator);
    await tester.pumpAndSettle();

    expect(find.text('login'), findsOneWidget);
    expect(find.text('member-home'), findsNothing);
    // The regression itself: nothing may be left underneath to go back to.
    expect(navigator.canPop(), isFalse);
    expect(ApiClient.authToken, isNull);
  });

  testWidgets('a member route paints nothing without a session', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    // Not merely "navigated away from" — the member widget must never build.
    expect(find.text('member-matches'), findsNothing);

    await tester.pumpAndSettle();
    expect(find.text('landing'), findsOneWidget);
  });

  testWidgets('a signed-out deep link cannot open a member route', (
    tester,
  ) async {
    await tester.pumpWidget(harness(initialRoute: '/login'));
    await tester.pumpAndSettle();

    // This is what a notification tap or a stale route name does.
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    unawaitedPush(navigator, '/home');
    await tester.pumpAndSettle();

    expect(find.text('member-home'), findsNothing);
    expect(find.text('landing'), findsOneWidget);
  });

  testWidgets('a member route still renders normally with a session', (
    tester,
  ) async {
    ApiClient.authToken = 'test-token';

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.text('member-matches'), findsOneWidget);
    expect(find.text('landing'), findsNothing);
  });
}

void unawaitedPush(NavigatorState navigator, String route) {
  navigator.pushNamed<void>(route);
}

class _Screen extends StatelessWidget {
  const _Screen(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text(label)));
  }
}
