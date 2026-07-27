import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// One HTTP stub for the whole test suite.
///
/// `gunamilan_required_toggle_test.dart` grew its own copy of this scaffolding
/// before there was a shared one; anything written after this file should route
/// through here rather than add a third copy.
///
/// Register handlers by path fragment. The LONGEST registered fragment the
/// request URI contains wins, so `'/suchak-requests'` and
/// `'/suchak-requests/501/decision'` can both be registered and each request
/// still reaches the handler meant for it, whatever order they were added in.
class FakeHttpOverrides extends HttpOverrides {
  FakeHttpOverrides({Map<String, FakeResponse Function(FakeRequest)>? handlers})
    : _handlers = handlers ?? <String, FakeResponse Function(FakeRequest)>{};

  final Map<String, FakeResponse Function(FakeRequest)> _handlers;

  /// Every request that reached the stub, in order.
  final List<FakeRequest> requests = <FakeRequest>[];

  void on(String pathFragment, FakeResponse Function(FakeRequest) handler) {
    _handlers[pathFragment] = handler;
  }

  void onJson(String pathFragment, Map<String, dynamic> body, {int status = 200}) {
    on(pathFragment, (_) => FakeResponse.json(body, status: status));
  }

  /// The first request whose URI contains [pathFragment] and whose method
  /// matches, or null when the screen never called it.
  FakeRequest? requestFor(String pathFragment, {String method = 'POST'}) {
    for (final request in requests) {
      if (request.method == method && request.uri.path.contains(pathFragment)) {
        return request;
      }
    }

    return null;
  }

  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      _FakeHttpClient(this);

  FakeResponse _respond(FakeRequest request) {
    requests.add(request);

    final matches = _handlers.keys
        .where(request.uri.path.contains)
        .toList(growable: false)
      ..sort((a, b) => b.length.compareTo(a.length));
    if (matches.isNotEmpty) return _handlers[matches.first]!(request);

    // Anything unregistered answers benignly so a screen's incidental loaders
    // resolve instead of throwing and hiding the assertion under test.
    return FakeResponse.json(<String, dynamic>{
      'success': true,
      'data': <dynamic>[],
    });
  }
}

class FakeRequest {
  const FakeRequest({
    required this.method,
    required this.uri,
    required this.body,
  });

  final String method;
  final Uri uri;
  final String body;

  Map<String, dynamic> get jsonBody {
    if (body.trim().isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(body);
    return decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
  }
}

class FakeResponse {
  const FakeResponse({required this.body, required this.status});

  factory FakeResponse.json(Map<String, dynamic> body, {int status = 200}) =>
      FakeResponse(body: jsonEncode(body), status: status);

  final String body;
  final int status;
}

class _FakeHttpClient implements HttpClient {
  _FakeHttpClient(this.overrides);

  final FakeHttpOverrides overrides;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _FakeHttpClientRequest(method, url, overrides);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeHttpClientRequest implements HttpClientRequest {
  _FakeHttpClientRequest(this.method, this.uri, this.overrides);

  @override
  final String method;

  @override
  final Uri uri;

  final FakeHttpOverrides overrides;
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
    final response = overrides._respond(
      FakeRequest(method: method, uri: uri, body: utf8.decode(_body)),
    );

    return _FakeHttpClientResponse(response);
  }

  @override
  Future<HttpClientResponse> get done => close();

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeHttpClientResponse implements HttpClientResponse {
  _FakeHttpClientResponse(FakeResponse response)
    : _bytes = utf8.encode(response.body),
      statusCode = response.status;

  final List<int> _bytes;

  @override
  final int statusCode;

  @override
  String get reasonPhrase => 'OK';

  @override
  int get contentLength => _bytes.length;

  @override
  bool get isRedirect => false;

  // package:http reads this on every response; a noSuchMethod null here fails
  // as "type 'Null' is not a subtype of type 'List<RedirectInfo>'" and every
  // call looks like a network error instead of the payload under test.
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
