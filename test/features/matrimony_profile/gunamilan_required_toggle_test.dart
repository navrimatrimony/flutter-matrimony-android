import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_matrimony_android/core/api_client.dart';
import 'package:flutter_matrimony_android/core/app_language.dart';
import 'package:flutter_matrimony_android/core/app_storage.dart';
import 'package:flutter_matrimony_android/features/matrimony_profile/edit_full_profile_screen.dart';

/// "गुणमिलन जुळणे आवश्यक" is the only switch that can turn the gunamilan gate
/// on, and it is asked in the Horoscope section even though the value is stored
/// as a partner criterion on the server. Two things can silently break it:
///
///   * the payload map not carrying `gunamilan_required` at all — no error, the
///     server simply never sees the key and leaves the old value in place;
///   * `_sectionPayloadKeys(horoscope)` not listing it — that list is what makes
///     the section look dirty, so a missing entry lets the user flip the switch
///     and walk away without the unsaved-changes guard noticing.
///
/// So this test drives the real screen and inspects the bytes that actually
/// leave for `PUT /api/v1/matrimony-profile`.
void main() {
  late _RecordingHttpOverrides overrides;

  setUp(() {
    AppStorage.instance = AppStorage.memory();
    setAppLanguage(AppLanguage.english);
    ApiClient.authToken = 'test-token';
    ApiClient.currentUserProfile = null;

    overrides = _RecordingHttpOverrides();
    final previous = HttpOverrides.current;
    HttpOverrides.global = overrides;
    addTearDown(() => HttpOverrides.global = previous);
  });

  Future<void> pumpEditor(
    WidgetTester tester, {
    required bool savedValue,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EditFullProfileScreen(
          initialProfile: <String, dynamic>{
            'id': 1,
            // _validateRequiredFields() gates every save on these, section
            // save included, so a half-filled fixture never reaches the PUT.
            'full_name': 'Test Candidate',
            'gender_id': 2,
            'date_of_birth': '1997-03-12',
            'religion_id': 1,
            'caste_id': 1,
            'highest_education': 'BE',
            'location_id': 5,
            'gotra': 'Kashyap',
            'gunamilan_required': savedValue,
          },
          targetSection: EditProfileTargetSection.horoscope,
        ),
      ),
    );
    // initState defers the first load into a post-frame callback, and the
    // option loaders resolve a microtask later.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
  }

  Finder toggleFinder() => find.ancestor(
    of: find.text(appText.gunamilanRequired),
    matching: find.byType(Row),
  );

  Switch switchWidget(WidgetTester tester) => tester.widget<Switch>(
    find.descendant(of: toggleFinder().first, matching: find.byType(Switch)),
  );

  testWidgets('the toggle is present in the Horoscope section and defaults off', (
    WidgetTester tester,
  ) async {
    await pumpEditor(tester, savedValue: false);

    expect(
      find.text(appText.gunamilanRequired),
      findsOneWidget,
      reason: 'The kundali section must expose the gunamilan gate.',
    );
    expect(find.text(appText.gunamilanRequiredHelp), findsOneWidget);
    expect(
      switchWidget(tester).value,
      isFalse,
      reason: 'Gunamilan is opt-in — never on by default.',
    );
  });

  testWidgets('a saved true comes back on', (WidgetTester tester) async {
    await pumpEditor(tester, savedValue: true);

    expect(switchWidget(tester).value, isTrue);
  });

  testWidgets('turning it on sends gunamilan_required in the section save', (
    WidgetTester tester,
  ) async {
    await pumpEditor(tester, savedValue: false);

    final switchFinder = find.descendant(
      of: toggleFinder().first,
      matching: find.byType(Switch),
    );
    await tester.ensureVisible(switchFinder);
    await tester.pump();
    await tester.tap(switchFinder);
    await tester.pump();

    expect(switchWidget(tester).value, isTrue);

    final saveFinder = find.text('Save section');
    await tester.ensureVisible(saveFinder);
    await tester.pump();
    await tester.tap(saveFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final body = overrides.lastPutBody;
    expect(body, isNotNull, reason: 'Saving the section must PUT the profile.');

    final payload = jsonDecode(body!) as Map<String, dynamic>;
    expect(
      payload['gunamilan_required'],
      isTrue,
      reason: 'The kundali save must actually carry the flag to the server.',
    );
    // The same save must stay scoped to its own section — sending partner
    // preference keys from here is what wipes other sections.
    expect(payload.containsKey('preferred_age_min'), isFalse);
    expect(payload['gotra'], isNotNull);
  });
}

/// Captures request bodies and answers every call with a benign 200 so the
/// screen's option loaders resolve instead of erroring out.
class _RecordingHttpOverrides extends HttpOverrides {
  String? lastPutBody;

  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      _FakeHttpClient((method, body) {
        if (method == 'PUT') lastPutBody = body;
      });
}

class _FakeHttpClient implements HttpClient {
  _FakeHttpClient(this.onRequest);

  final void Function(String method, String body) onRequest;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _FakeHttpClientRequest(method, onRequest);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeHttpClientRequest implements HttpClientRequest {
  _FakeHttpClientRequest(this.method, this.onRequest);

  @override
  final String method;

  final void Function(String method, String body) onRequest;
  final List<int> _body = <int>[];

  @override
  final HttpHeaders headers = _FakeHttpHeaders();

  @override
  bool followRedirects = true;

  @override
  int maxRedirects = 5;

  @override
  int contentLength = -1;

  @override
  bool persistentConnection = true;

  @override
  void add(List<int> data) => _body.addAll(data);

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final chunk in stream) {
      _body.addAll(chunk);
    }
  }

  @override
  Future<HttpClientResponse> close() async {
    onRequest(method, utf8.decode(_body));

    return _FakeHttpClientResponse(
      jsonEncode(<String, dynamic>{'success': true, 'data': <dynamic>[]}),
    );
  }

  @override
  Future<HttpClientResponse> get done => close();

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeHttpClientResponse implements HttpClientResponse {
  _FakeHttpClientResponse(String body) : _bytes = utf8.encode(body);

  final List<int> _bytes;

  @override
  int get statusCode => 200;

  @override
  String get reasonPhrase => 'OK';

  @override
  int get contentLength => _bytes.length;

  @override
  bool get isRedirect => false;

  @override
  bool get persistentConnection => false;

  @override
  final HttpHeaders headers = _FakeHttpHeaders()
    ..set('content-type', 'application/json; charset=utf-8');

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.value(_bytes).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeHttpHeaders implements HttpHeaders {
  final Map<String, List<String>> _values = <String, List<String>>{};

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _values[name.toLowerCase()] = <String>[value.toString()];
  }

  @override
  List<String>? operator [](String name) => _values[name.toLowerCase()];

  @override
  void forEach(void Function(String name, List<String> values) action) =>
      _values.forEach(action);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
