import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_matrimony_android/core/api_client.dart';
import 'package:flutter_matrimony_android/core/app_language.dart';
import 'package:flutter_matrimony_android/core/app_storage.dart';
import 'package:flutter_matrimony_android/features/chat/chat_screen.dart';

/// Read receipts are the one chat feature where being wrong is worse than
/// being absent, and they are also the one feature that only works if BOTH
/// apps play their part:
///
///   * the tick on an outgoing bubble is a claim about the other person's
///     behaviour — a ✓✓ on a message nobody opened is a lie the member acts on;
///   * `POST /chats/{id}/read` is the only thing that turns the OTHER side's ✓
///     into ✓✓, so a member app that never calls it silently freezes the Suchak
///     app's ticks on a single check forever.
///
/// Both halves were entirely missing here (the tick was never drawn, and
/// `ApiClient.markChatRead` was declared but never called from anywhere), so
/// these tests pin the exact behaviour rather than the implementation: what a
/// bubble renders for each `delivery_status`, and how many read calls one open
/// of a thread produces.
void main() {
  const conversationId = 7;

  late _ChatHttpOverrides overrides;

  setUp(() {
    AppStorage.instance = AppStorage.memory();
    setAppLanguage(AppLanguage.english);
    ApiClient.authToken = 'test-token';
    ApiClient.currentUserProfile = null;

    overrides = _ChatHttpOverrides(thread: _threadResponse());
    final previous = HttpOverrides.current;
    HttpOverrides.global = overrides;
    addTearDown(() => HttpOverrides.global = previous);
  });

  Future<void> openThread(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ChatScreen(initialConversationId: conversationId)),
    );
    // The thread fetch, then the read call it chains after itself.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('an outgoing message the other side read shows a double tick', (
    WidgetTester tester,
  ) async {
    await openThread(tester);

    expect(
      find.byIcon(Icons.done_all),
      findsOneWidget,
      reason:
          'delivery_status "read" is the only signal the member has that the '
          'other side opened the message.',
    );
  });

  testWidgets('an outgoing message that is only sent shows a single tick', (
    WidgetTester tester,
  ) async {
    await openThread(tester);

    expect(
      find.byIcon(Icons.check),
      findsOneWidget,
      reason: 'delivery_status "sent" must stay a single check.',
    );
  });

  testWidgets('an incoming message carries no tick at all', (
    WidgetTester tester,
  ) async {
    await openThread(tester);

    // The fixture's incoming message is deliberately delivery_status "read":
    // if the bubble read the field without checking is_mine, this would put a
    // second done_all on screen.
    expect(
      find.byIcon(Icons.done_all),
      findsOneWidget,
      reason:
          'A tick on an incoming bubble is meaningless — the reader IS the '
          'person who read it.',
    );
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('an outgoing message with no delivery_status shows no tick', (
    WidgetTester tester,
  ) async {
    // The fixture's last message omits the key entirely. If a missing status
    // fell through to a default, the counts above would grow.
    await openThread(tester);

    expect(
      find.byIcon(Icons.done_all),
      findsOneWidget,
      reason: 'A missing status must never be guessed as read.',
    );
    expect(
      find.byIcon(Icons.check),
      findsOneWidget,
      reason: 'A missing status must never be guessed as sent either.',
    );
  });

  testWidgets('opening the thread reports it read exactly once', (
    WidgetTester tester,
  ) async {
    await openThread(tester);

    expect(
      overrides.readCalls,
      <String>['/api/v1/chats/$conversationId/read'],
      reason:
          'Without this POST the person who wrote to this member never gets '
          'their double tick. Firing it more than once per open is wasted '
          'traffic on every inbox refresh.',
    );

    // A rebuild with nothing new must not re-report.
    await tester.pump(const Duration(milliseconds: 200));
    expect(overrides.readCalls, hasLength(1));
  });
}

/// Mirrors `GET /api/v1/chats/{conversation}` for a member viewer: top level,
/// no `data` wrapper, `delivery_status` alongside every message.
Map<String, dynamic> _threadResponse() {
  return <String, dynamic>{
    'success': true,
    'message': 'Chat loaded.',
    'conversation': <String, dynamic>{
      'id': 7,
      'unread_count': 0,
      'other_profile': <String, dynamic>{'id': 22, 'name': 'Other Member'},
    },
    'messages': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 101,
        'is_mine': true,
        'body_text': 'Mine, and they opened it',
        'delivery_status': 'read',
        'sent_at': '2026-07-27T09:00:00+05:30',
      },
      <String, dynamic>{
        'id': 102,
        'is_mine': true,
        'body_text': 'Mine, still unread',
        'delivery_status': 'sent',
        'sent_at': '2026-07-27T09:01:00+05:30',
      },
      <String, dynamic>{
        'id': 103,
        'is_mine': false,
        'body_text': 'Theirs',
        'delivery_status': 'read',
        'sent_at': '2026-07-27T09:02:00+05:30',
      },
      <String, dynamic>{
        'id': 104,
        'is_mine': true,
        'body_text': 'Mine, status withheld',
        'sent_at': '2026-07-27T09:03:00+05:30',
      },
    ],
    'last_id': 104,
    'unread_count': 0,
    'first_unread_message_id': null,
    'read_locked_for_incoming': false,
    'can_send': <String, dynamic>{'allowed': true, 'message': null},
  };
}

/// Answers the three calls one thread open makes (inbox, thread, read) and
/// records every read POST so the test can count them.
class _ChatHttpOverrides extends HttpOverrides {
  _ChatHttpOverrides({required this.thread});

  final Map<String, dynamic> thread;
  final List<String> readCalls = <String>[];

  String _respond(String method, Uri url) {
    if (method == 'POST' && url.path.endsWith('/read')) {
      readCalls.add(url.path);

      return jsonEncode(<String, dynamic>{
        'success': true,
        'message': 'Chat marked as read.',
        'read_locked_for_incoming': false,
        'unread_count': 0,
      });
    }

    if (method == 'GET' && RegExp(r'/chats/\d+$').hasMatch(url.path)) {
      return jsonEncode(thread);
    }

    // The inbox list the screen refreshes alongside the thread.
    return jsonEncode(<String, dynamic>{
      'success': true,
      'conversations': <dynamic>[],
      'unread_count': 0,
    });
  }

  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      _FakeHttpClient(_respond);
}

class _FakeHttpClient implements HttpClient {
  _FakeHttpClient(this.responder);

  final String Function(String method, Uri url) responder;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _FakeHttpClientRequest(method, url, responder);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeHttpClientRequest implements HttpClientRequest {
  _FakeHttpClientRequest(this.method, this.uri, this.responder);

  @override
  final String method;

  @override
  final Uri uri;

  final String Function(String method, Uri url) responder;

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
  void add(List<int> data) {}

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final _ in stream) {}
  }

  @override
  Future<HttpClientResponse> close() async =>
      _FakeHttpClientResponse(responder(method, uri));

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
  List<RedirectInfo> get redirects => const <RedirectInfo>[];

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
