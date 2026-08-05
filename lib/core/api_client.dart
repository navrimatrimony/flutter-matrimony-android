import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'app_language.dart';
import 'app_storage.dart';
import 'api_cache.dart';
import 'api_routes.dart';
import 'notification_permission_service.dart';
import 'push_notification_service.dart';

class _CachedJsonFetch {
  const _CachedJsonFetch({required this.data, required this.metadata});

  final Map<String, dynamic> data;
  final Map<String, String> metadata;
}

class ApiClient {
  static String? authToken;
  static Map<String, dynamic>? currentUserProfile;
  static Set<int> sentInterestProfileIds = {};
  static final Map<String, List<Map<String, dynamic>>> _locationSearchCache =
      <String, List<Map<String, dynamic>>>{};
  static final Map<String, DateTime> _locationSearchCacheTimes =
      <String, DateTime>{};

  static const String _siteBaseUrl = 'https://navrimilenavryala.com';
  static const String _profilePhotoStoragePath = 'storage/matrimony_photos';
  /// Ceiling on a single request made through the shared JSON helpers below.
  ///
  /// Nothing here used to bound a request at all. A stalled socket held
  /// whatever screen started it on a spinner for as long as the OS took to give
  /// up, which is minutes — and the OTP screen blocks Back while it is loading,
  /// so a member whose token had already been stored could sit frozen in front
  /// of a session that was live the whole time. A request that has not answered
  /// in this long is a failure the caller should be told about, not waited on.
  static const Duration _requestTimeout = Duration(seconds: 30);
  static const Duration _locationSearchCacheTtl = Duration(minutes: 2);
  static const Duration _profileCacheTtl = Duration(seconds: 45);
  static const Duration _lookupCacheTtl = Duration(hours: 12);
  static const Duration _lookupSearchCacheTtl = Duration(minutes: 10);
  static const String _cacheTagProfile = 'profile';
  static const String _cacheTagProfilePhotos = 'profile_photos';
  static const String _cacheTagLookups = 'lookups';
  static const String _cacheTagAuth = 'auth';

  static String _cacheKey(
    String namespace, {
    bool authenticated = false,
    Map<String, dynamic>? query,
  }) {
    final parts = <String>[
      namespace,
      authenticated ? _authCacheScope() : 'public',
    ];
    final queryPart = _stableQueryPart(query);
    if (queryPart.isNotEmpty) parts.add(queryPart);
    return parts.join('|');
  }

  static String _authCacheScope() {
    final token = authToken;
    if (token == null || token.isEmpty) return 'auth:none';
    return 'auth:${token.hashCode}';
  }

  static String _stableQueryPart(Map<String, dynamic>? query) {
    final queryParameters = _queryParameters(query);
    if (queryParameters.isEmpty) return '';

    final keys = queryParameters.keys.toList()..sort();
    return keys.map((key) => '$key=${queryParameters[key]}').join('&');
  }

  static Map<String, dynamic> _cloneJsonMap(Map<String, dynamic> value) {
    final decoded = jsonDecode(jsonEncode(value));
    return decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
  }

  static List<Map<String, dynamic>> _cloneMapList(
    List<Map<String, dynamic>> rows,
  ) {
    return rows.map((row) => _cloneJsonMap(row)).toList();
  }

  static Map<String, List<Map<String, dynamic>>> _cloneOptionListMap(
    Map<String, List<Map<String, dynamic>>> value,
  ) {
    return value.map((key, rows) => MapEntry(key, _cloneMapList(rows)));
  }

  static bool _shouldCacheJsonResponse(Map<String, dynamic> data) {
    final statusCode = _intValue(data['statusCode']);
    if (statusCode != null && (statusCode < 200 || statusCode >= 300)) {
      return false;
    }

    return data['success'] != false;
  }

  static bool _isSuccessfulResponse(Map<String, dynamic> data) {
    return _shouldCacheJsonResponse(data);
  }

  static Future<Map<String, dynamic>> _getJsonCached(
    String route, {
    bool authenticated = false,
    Map<String, dynamic>? query,
    required Duration ttl,
    required Set<String> tags,
    bool forceRefresh = false,
  }) {
    final cacheKey = _cacheKey(
      route,
      authenticated: authenticated,
      query: query,
    );
    var cacheMetadata = const <String, String>{};

    return ApiCache.instance.remember<Map<String, dynamic>>(
      key: cacheKey,
      ttl: ttl,
      tags: tags,
      forceRefresh: forceRefresh,
      fetch: () async {
        final result = await _getJsonWithCacheValidators(
          route,
          cacheKey: cacheKey,
          authenticated: authenticated,
          query: query,
        );
        cacheMetadata = result.metadata;
        return result.data;
      },
      copy: _cloneJsonMap,
      shouldStore: _shouldCacheJsonResponse,
      metadata: (_) => cacheMetadata,
    );
  }

  static Future<List<Map<String, dynamic>>> _rememberMapList(
    String cacheKey, {
    required Future<List<Map<String, dynamic>>> Function() fetch,
    Duration ttl = _lookupCacheTtl,
    Set<String> tags = const <String>{_cacheTagLookups},
  }) {
    return ApiCache.instance.remember<List<Map<String, dynamic>>>(
      key: cacheKey,
      ttl: ttl,
      tags: tags,
      fetch: fetch,
      copy: _cloneMapList,
      shouldStore: (rows) => rows.isNotEmpty,
    );
  }

  static Future<Map<String, List<Map<String, dynamic>>>> _rememberOptionListMap(
    String cacheKey, {
    required Future<Map<String, List<Map<String, dynamic>>>> Function() fetch,
  }) {
    return ApiCache.instance.remember<Map<String, List<Map<String, dynamic>>>>(
      key: cacheKey,
      ttl: _lookupCacheTtl,
      tags: const <String>{_cacheTagLookups, _cacheTagAuth},
      fetch: fetch,
      copy: _cloneOptionListMap,
      shouldStore: (options) => options.isNotEmpty,
    );
  }

  static Future<Map<String, dynamic>> _rememberJsonMap(
    String cacheKey, {
    required Future<Map<String, dynamic>> Function() fetch,
    Duration ttl = _lookupCacheTtl,
    Set<String> tags = const <String>{_cacheTagLookups, _cacheTagAuth},
  }) {
    return ApiCache.instance.remember<Map<String, dynamic>>(
      key: cacheKey,
      ttl: ttl,
      tags: tags,
      fetch: fetch,
      copy: _cloneJsonMap,
      shouldStore: (value) => value.isNotEmpty,
    );
  }

  static void _invalidateProfileCache() {
    ApiCache.instance.invalidateTags(const <String>{
      _cacheTagProfile,
      _cacheTagProfilePhotos,
    });
  }

  static Map<String, dynamic> _decodeResponse(http.Response response) {
    Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        data = decoded;
      } else if (decoded is Map) {
        data = Map<String, dynamic>.from(decoded);
      } else {
        data = <String, dynamic>{};
      }
    } catch (_) {
      data = <String, dynamic>{};
    }
    data['statusCode'] = response.statusCode;
    return data;
  }

  static Map<String, String> _cacheMetadataFromResponse(
    http.Response response,
  ) {
    final metadata = <String, String>{};
    for (final key in const <String>[
      'etag',
      'cache-control',
      'x-mobile-cache-policy',
      'x-mobile-cache-ttl',
      'x-mobile-cache-stale-while-revalidate',
      'x-mobile-cache-tags',
    ]) {
      final value = response.headers[key];
      if (value != null && value.trim().isNotEmpty) {
        metadata[key] = value.trim();
      }
    }

    return metadata;
  }

  static String _requireAuthToken() {
    final token = authToken;
    if (token == null || token.isEmpty) {
      throw Exception('Auth token is missing. User not logged in.');
    }

    return token;
  }

  static Map<String, String> _jsonHeaders({bool authenticated = false}) {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Accept-Language': appLanguageCode(currentAppLanguage),
      'Content-Type': 'application/json',
      // See _acceptHeaders — the server labels its responses in this language.
      'Accept-Language': appLanguageCode(currentAppLanguage),
    };

    if (authenticated) {
      headers['Authorization'] = 'Bearer ${_requireAuthToken()}';
    }

    return headers;
  }

  static Map<String, String> _acceptHeaders({bool authenticated = false}) {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Accept-Language': appLanguageCode(currentAppLanguage),
      // Master-data labels come back in whatever language this header names.
      // Without it the backend reads the phone's OS language, which is not the
      // language the member chose in the app — a member who picked Marathi on
      // an English phone would get English caste/education/location labels.
      'Accept-Language': appLanguageCode(currentAppLanguage),
    };

    if (authenticated) {
      headers['Authorization'] = 'Bearer ${_requireAuthToken()}';
    }

    return headers;
  }

  static Map<String, String> _queryParameters(Map<String, dynamic>? source) {
    if (source == null || source.isEmpty) return <String, String>{};

    final query = <String, String>{};
    source.forEach((key, value) {
      if (value == null) return;
      final text = value.toString().trim();
      if (text.isEmpty) return;
      query[key] = text;
    });

    return query;
  }

  static Uri _apiUri(String route, {Map<String, dynamic>? query}) {
    final base = Uri.parse(ApiRoutes.baseUrl + route);
    final queryParameters = _queryParameters(query);
    if (queryParameters.isEmpty) return base;

    return base.replace(queryParameters: queryParameters);
  }

  static Uri _rootApiUri(String route, {Map<String, dynamic>? query}) {
    final base = Uri.parse(ApiRoutes.rootApiBaseUrl + route);
    final queryParameters = _queryParameters(query);
    if (queryParameters.isEmpty) return base;

    return base.replace(queryParameters: queryParameters);
  }

  static Map<String, dynamic> _compactBody(Map<String, dynamic> source) {
    final body = <String, dynamic>{};

    source.forEach((key, value) {
      if (value == null) return;
      if (value is String && value.trim().isEmpty) return;
      body[key] = value;
    });

    return body;
  }

  static Future<Map<String, dynamic>> _getJson(
    String route, {
    bool authenticated = false,
    Map<String, dynamic>? query,
  }) async {
    final response = await http
        .get(
          _apiUri(route, query: query),
          headers: _acceptHeaders(authenticated: authenticated),
        )
        .timeout(_requestTimeout);

    return _decodeResponse(response);
  }

  static Future<_CachedJsonFetch> _getJsonWithCacheValidators(
    String route, {
    required String cacheKey,
    bool authenticated = false,
    Map<String, dynamic>? query,
  }) async {
    final headers = _acceptHeaders(authenticated: authenticated);
    final cachedMetadata = ApiCache.instance.metadataForKey(cacheKey);
    final etag = cachedMetadata['etag'];
    if (etag != null && etag.isNotEmpty) {
      headers['If-None-Match'] = etag;
    }

    final response = await http
        .get(_apiUri(route, query: query), headers: headers)
        .timeout(_requestTimeout);

    final responseMetadata = _cacheMetadataFromResponse(response);
    if (response.statusCode == 304) {
      final cached = ApiCache.instance.valueForKey<Map<String, dynamic>>(
        cacheKey,
        copy: _cloneJsonMap,
      );
      if (cached != null) {
        return _CachedJsonFetch(
          data: cached,
          metadata: responseMetadata.isNotEmpty
              ? responseMetadata
              : cachedMetadata,
        );
      }
    }

    return _CachedJsonFetch(
      data: _decodeResponse(response),
      metadata: responseMetadata,
    );
  }

  static Future<Map<String, dynamic>> _getRootJson(
    String route, {
    Map<String, dynamic>? query,
  }) async {
    final response = await http
        .get(_rootApiUri(route, query: query), headers: _acceptHeaders())
        .timeout(_requestTimeout);

    return _decodeResponse(response);
  }

  static Future<Map<String, dynamic>> _postJson(
    String route,
    Map<String, dynamic> body, {
    bool authenticated = false,
    Map<String, dynamic>? query,
  }) async {
    final response = await http
        .post(
          _apiUri(route, query: query),
          headers: _jsonHeaders(authenticated: authenticated),
          body: jsonEncode(_compactBody(body)),
        )
        .timeout(_requestTimeout);

    return _decodeResponse(response);
  }

  static Future<Map<String, dynamic>> _putJson(
    String route,
    Map<String, dynamic> body, {
    bool authenticated = false,
    Map<String, dynamic>? query,
  }) async {
    final response = await http
        .put(
          _apiUri(route, query: query),
          headers: _jsonHeaders(authenticated: authenticated),
          body: jsonEncode(_compactBody(body)),
        )
        .timeout(_requestTimeout);

    return _decodeResponse(response);
  }

  static Future<Map<String, dynamic>> _patchJson(
    String route,
    Map<String, dynamic> body, {
    bool authenticated = false,
    Map<String, dynamic>? query,
  }) async {
    final response = await http
        .patch(
          _apiUri(route, query: query),
          headers: _jsonHeaders(authenticated: authenticated),
          body: jsonEncode(_compactBody(body)),
        )
        .timeout(_requestTimeout);

    return _decodeResponse(response);
  }

  static List<Map<String, dynamic>> _safeMapList(dynamic value) {
    final List<dynamic> rows;

    if (value is List) {
      rows = value;
    } else if (value is Map) {
      final nested = value['data'] ?? value['results'] ?? value['items'];
      rows = nested is List ? nested : <dynamic>[];
    } else {
      rows = <dynamic>[];
    }

    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  static List<Map<String, dynamic>> _safeOptionList(dynamic value) {
    if (value is Map) {
      final nested = value['data'] ?? value['results'] ?? value['items'];
      if (nested is List) {
        return _safeOptionList(nested);
      }
      if (value.containsKey('id') ||
          value.containsKey('key') ||
          value.containsKey('label')) {
        return <Map<String, dynamic>>[Map<String, dynamic>.from(value)];
      }

      return value.entries
          .map((entry) {
            final key = entry.key.toString().trim();
            final label = entry.value?.toString().trim();
            if (key.isEmpty || label == null || label.isEmpty) return null;

            return <String, dynamic>{'key': key, 'label': label};
          })
          .whereType<Map<String, dynamic>>()
          .toList();
    }

    if (value is! List) return <Map<String, dynamic>>[];

    return value
        .map((item) {
          if (item is Map) return Map<String, dynamic>.from(item);

          final label = item?.toString().trim();
          if (label == null || label.isEmpty) return null;

          return <String, dynamic>{'key': label, 'label': label};
        })
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  static String? _firstNonEmptyValue(
    Map<String, dynamic>? data,
    List<String> keys,
  ) {
    if (data == null) return null;

    for (final key in keys) {
      final value = data[key]?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }

    return null;
  }

  static int? _intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static bool? _boolValue(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;

    final normalized = value?.toString().trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return null;
    if (['1', 'true', 'yes', 'approved'].contains(normalized)) return true;
    if (['0', 'false', 'no', 'rejected', 'pending'].contains(normalized)) {
      return false;
    }

    return null;
  }

  static String? safeDisplayLabel(
    dynamic value, {
    bool allowIdFallback = false,
    String idPrefix = 'ID',
  }) {
    if (value == null) return null;

    if (value is Map) {
      final row = Map<String, dynamic>.from(value);
      final localizedLabel = localizedMapValue(row);
      if (localizedLabel != null) return localizedLabel;

      final label = _firstNonEmptyValue(row, const [
        'label_mr',
        'label',
        'label_en',
        'name',
        'title',
        'display_label',
        'location_label',
        'key',
      ]);
      if (label != null) return label;

      final id = _intValue(row['id'] ?? row['location_id']);
      return allowIdFallback && id != null ? '$idPrefix: $id' : null;
    }

    if (value is List) {
      final labels = value
          .map((item) => safeDisplayLabel(item))
          .whereType<String>()
          .where((label) => label.trim().isNotEmpty)
          .toList();
      return labels.isNotEmpty ? labels.join(' • ') : null;
    }

    final text = value.toString().trim();
    if (text.isEmpty) return null;
    if (text.startsWith('{') || text.startsWith('[')) return null;
    if (!allowIdFallback && RegExp(r'^\d+$').hasMatch(text)) return null;
    if (!allowIdFallback && text.toLowerCase().startsWith('location id:')) {
      return null;
    }

    return text;
  }

  static int? locationIdFrom(Map<String, dynamic> location) {
    for (final key in ['location_id', 'id']) {
      final id = _intValue(location[key]);
      if (id != null) return id;
    }
    return null;
  }

  static String locationSuggestionLabel(Map<String, dynamic> location) {
    final localizedLabel = localizedMapValue(location);
    if (localizedLabel != null) return localizedLabel;

    final label = _firstNonEmptyValue(location, [
      'display_label',
      'location_label',
      'name',
      'hierarchy',
    ]);
    if (label != null) return label;

    final id = locationIdFrom(location);
    return id != null ? 'Location ID: $id' : 'Unknown location';
  }

  static String? profileEducationLabel(Map<String, dynamic>? profile) {
    if (profile == null) return null;
    for (final key in ['highest_education', 'education']) {
      final label = safeDisplayLabel(profile[key]);
      if (label != null) return label;
    }
    return null;
  }

  static String? profileReligionLabel(Map<String, dynamic>? profile) {
    if (profile == null) return null;
    for (final key in ['religion', 'religion_label', 'religion_name']) {
      final label = safeDisplayLabel(profile[key]);
      if (label != null) return label;
    }
    return null;
  }

  static String? profileCasteLabel(Map<String, dynamic>? profile) {
    if (profile == null) return null;
    for (final key in ['caste', 'caste_label', 'caste_name']) {
      final label = safeDisplayLabel(profile[key]);
      if (label != null) return label;
    }
    return null;
  }

  static String? profileSubCasteLabel(Map<String, dynamic>? profile) {
    if (profile == null) return null;
    for (final key in [
      'sub_caste',
      'sub_caste_label',
      'sub_caste_name',
      'subcaste_label',
      'subcaste_name',
    ]) {
      final label = safeDisplayLabel(profile[key]);
      if (label != null) return label;
    }
    return null;
  }

  static String? profileCommunityLabel(Map<String, dynamic>? profile) {
    final parts = <String>[
      if (profileReligionLabel(profile) != null) profileReligionLabel(profile)!,
      if (profileCasteLabel(profile) != null) profileCasteLabel(profile)!,
      if (profileSubCasteLabel(profile) != null) profileSubCasteLabel(profile)!,
    ];
    return parts.isNotEmpty ? parts.join(' • ') : null;
  }

  static String? profileOccupationLabel(Map<String, dynamic>? profile) {
    if (profile == null) return null;
    for (final key in [
      'occupation',
      'occupation_title',
      'occupation_label',
      'occupation_name',
      'profession',
      'profession_label',
    ]) {
      final label = safeDisplayLabel(profile[key]);
      if (label != null) return label;
    }
    return null;
  }

  static String? profileHeightLabel(Map<String, dynamic>? profile) {
    if (profile == null) return null;

    final storedLabel =
        safeDisplayLabel(profile['height_label']) ??
        safeDisplayLabel(profile['height_text']) ??
        safeDisplayLabel(profile['height']);
    if (storedLabel != null) return storedLabel;

    final cm = _intValue(profile['height_cm'] ?? profile['height']);
    if (cm == null || cm <= 0) return null;

    final totalInches = (cm / 2.54).round();
    final feet = totalInches ~/ 12;
    final inches = totalInches % 12;
    if (feet <= 0) return '$cm cm';

    return "$feet' $inches\"";
  }

  static String? profileLocationLabel(
    Map<String, dynamic>? profile, {
    bool allowIdFallback = true,
    bool includeAddressLineFallback = true,
  }) {
    if (profile == null) return null;

    final display = profile['display'];
    if (display is Map) {
      final displayMap = Map<String, dynamic>.from(display);
      for (final key in ['location_label', 'location']) {
        final label = safeDisplayLabel(displayMap[key]);
        if (label != null) return label;
      }

      for (final sectionKey in ['hero', 'card']) {
        final section = displayMap[sectionKey];
        if (section is Map) {
          final sectionMap = Map<String, dynamic>.from(section);
          for (final key in ['location_label', 'location']) {
            final label = safeDisplayLabel(sectionMap[key]);
            if (label != null) return label;
          }
        }
      }
    }

    for (final key in [
      'location',
      'location_label',
      'display_label',
      'current_location',
      'city',
      'city_name',
      'residence_location',
    ]) {
      final label = safeDisplayLabel(profile[key]);
      if (label != null) return label;
    }

    final selfAddresses = profile['self_addresses'];
    if (selfAddresses is List) {
      Map<String, dynamic>? firstAddress;
      Map<String, dynamic>? currentAddress;
      for (final row in selfAddresses) {
        if (row is! Map) continue;
        final address = Map<String, dynamic>.from(row);
        firstAddress ??= address;
        final type = safeDisplayLabel(
          address['address_type_key'] ?? address['address_type'],
        )?.toLowerCase();
        if (type == 'current') {
          currentAddress = address;
          break;
        }
      }

      for (final address in [currentAddress, firstAddress]) {
        if (address == null) continue;
        for (final key in ['location_label', 'display', 'city_label']) {
          final label = safeDisplayLabel(address[key]);
          if (label != null) return label;
        }
      }
    }

    if (includeAddressLineFallback) {
      final addressLine = safeDisplayLabel(profile['address_line']);
      if (addressLine != null) return addressLine;
    }

    final id = _intValue(profile['location_id']);
    return allowIdFallback && id != null ? 'Location ID: $id' : null;
  }

  static String? resolveProfilePhotoUrl(Map<String, dynamic>? profile) {
    if (profile == null) return null;

    final approvedPhotoHint = _resolveApprovedPhotoHint(profile);
    if (approvedPhotoHint != null) return approvedPhotoHint;

    final directPhotoUrl = _resolvePhotoValueFromMap(profile, const [
      'profile_photo_url',
      'photo_url',
      'image_url',
      'avatar_url',
    ]);
    if (directPhotoUrl != null) return directPhotoUrl;

    final listPhotoUrl = _resolveBestPhotoFromLists(profile);
    if (listPhotoUrl != null) return listPhotoUrl;

    final profilePhotoUrl = _resolvePhotoValueFromMap(profile, const [
      'profile_photo',
    ]);
    if (profilePhotoUrl != null) return profilePhotoUrl;

    return _resolvePhotoValueFromMap(profile, const ['url', 'path']);
  }

  static String? _resolveApprovedPhotoHint(Map<String, dynamic> profile) {
    final directApproved = _resolvePhotoValueFromMap(profile, const [
      'approved_photo_url',
      'approved_profile_photo_url',
      'primary_photo_url',
    ], respectApproval: false);
    if (directApproved != null) return directApproved;

    final display = profile['display'];
    if (display is! Map) return null;

    final displayMap = Map<String, dynamic>.from(display);
    for (final key in const ['hero', 'card']) {
      final section = displayMap[key];
      if (section is! Map) continue;

      final sectionUrl = _resolvePhotoValueFromMap(
        Map<String, dynamic>.from(section),
        const ['primary_photo_url', 'photo_url', 'profile_photo_url'],
        respectApproval: false,
      );
      if (sectionUrl != null) return sectionUrl;
    }

    return _resolvePhotoValueFromMap(displayMap, const [
      'primary_photo_url',
      'photo_url',
      'profile_photo_url',
    ], respectApproval: false);
  }

  static String? normalizeProfilePhotoUrl(dynamic rawValue) {
    return _resolvePhotoValue(rawValue);
  }

  static String? _resolvePhotoValueFromMap(
    Map<String, dynamic> data,
    List<String> keys, {
    bool respectApproval = true,
  }) {
    if (respectApproval && !_photoMapAllowsDisplay(data)) return null;

    for (final key in keys) {
      final url = _resolvePhotoValue(data[key]);
      if (url != null) return url;
    }

    return null;
  }

  static String? _resolveBestPhotoFromLists(Map<String, dynamic> profile) {
    final candidates = <({int score, String url})>[];

    for (final key in ['photos', 'profile_photos']) {
      final rawList = profile[key];
      if (rawList is List) {
        for (final item in rawList) {
          if (item is Map) {
            final row = Map<String, dynamic>.from(item);
            final score = _photoMapScore(row);
            if (score < 0) continue;

            final url = _resolvePhotoValueFromMap(row, const [
              'profile_photo_url',
              'photo_url',
              'image_url',
              'avatar_url',
              'url',
              'path',
              'file_path',
              'profile_photo',
            ], respectApproval: false);
            if (url != null) {
              candidates.add((score: score, url: url));
            }
          } else {
            final url = _resolvePhotoValue(item);
            if (url != null) {
              candidates.add((score: 0, url: url));
            }
          }
        }
        continue;
      }

      final rows = _safeMapList(rawList);
      for (final row in rows) {
        final score = _photoMapScore(row);
        if (score < 0) continue;

        final url = _resolvePhotoValueFromMap(row, const [
          'profile_photo_url',
          'photo_url',
          'image_url',
          'avatar_url',
          'url',
          'path',
          'file_path',
          'profile_photo',
        ], respectApproval: false);
        if (url != null) {
          candidates.add((score: score, url: url));
        }
      }
    }

    if (candidates.isEmpty) return null;

    candidates.sort((a, b) => b.score.compareTo(a.score));
    return candidates.first.url;
  }

  static bool _photoMapAllowsDisplay(Map<String, dynamic> data) {
    for (final key in ['photo_approved', 'approved', 'is_approved']) {
      final value = _boolValue(data[key]);
      if (value == false) return false;
    }

    for (final key in [
      'status',
      'approval_status',
      'approved_status',
      'photo_status',
      'moderation_status',
      'admin_override_status',
    ]) {
      final normalized = data[key]?.toString().trim().toLowerCase();
      if (normalized == null || normalized.isEmpty) continue;
      if (normalized.contains('reject') ||
          normalized == 'pending' ||
          normalized == 'review' ||
          normalized == 'processing' ||
          normalized == 'error') {
        return false;
      }
    }

    return true;
  }

  static int _photoMapScore(Map<String, dynamic> data) {
    if (!_photoMapAllowsDisplay(data)) return -1;

    var score = 0;

    for (final key in ['photo_approved', 'approved', 'is_approved']) {
      if (_boolValue(data[key]) == true) score += 100;
    }

    for (final key in [
      'status',
      'approval_status',
      'approved_status',
      'photo_status',
      'moderation_status',
      'admin_override_status',
    ]) {
      final normalized = data[key]?.toString().trim().toLowerCase();
      if (normalized != null && normalized.contains('approved')) {
        score += 100;
      }
    }

    for (final key in [
      'is_primary',
      'primary',
      'is_profile',
      'is_current',
      'current',
      'is_showcase',
      'showcase',
    ]) {
      if (_boolValue(data[key]) == true) score += 20;
    }

    return score;
  }

  static String? _resolvePhotoValue(dynamic rawValue) {
    var value = rawValue?.toString().trim();
    if (value == null || value.isEmpty) return null;

    value = value.replaceAll('\\', '/');
    if (value.startsWith('file:')) return null;
    if (value.startsWith('//')) {
      return Uri.encodeFull('https:$value');
    }
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return Uri.encodeFull(_normalizeAbsolutePhotoUrl(value));
    }

    var path = value.replaceFirst(RegExp(r'^/+'), '');
    if (path.isEmpty || path.startsWith('pending/')) return null;
    if (path.contains('..')) return null;

    path = path.replaceFirst(RegExp(r'^app/public/'), '');
    path = path.replaceFirst(RegExp(r'^public/'), '');

    while (path.startsWith('storage/storage/')) {
      path = path.replaceFirst('storage/storage/', 'storage/');
    }
    if (path.startsWith('storage/uploads/')) {
      path = path.replaceFirst('storage/', '');
    }

    if (path.startsWith('storage/matrimony_photos/') ||
        path.startsWith('uploads/matrimony_photos/')) {
      return Uri.encodeFull('$_siteBaseUrl/$path');
    }
    if (path.startsWith('matrimony_photos/')) {
      return Uri.encodeFull('$_siteBaseUrl/storage/$path');
    }
    if (path.startsWith('storage/') || path.startsWith('uploads/')) {
      return Uri.encodeFull('$_siteBaseUrl/$path');
    }

    return Uri.encodeFull('$_siteBaseUrl/$_profilePhotoStoragePath/$path');
  }

  static String _normalizeAbsolutePhotoUrl(String value) {
    return value
        .replaceAll('/storage/storage/', '/storage/')
        .replaceAll('/storage/uploads/', '/uploads/');
  }

  static Future<List<Map<String, dynamic>>> searchLocations(
    String query, {
    int? preferredStateId,
    String? preferredStateName,
    int limit = 20,
    int page = 1,
    String? locale,
    String? type,
    bool useOnboardingEndpoint = false,
  }) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.length < 2) return <Map<String, dynamic>>[];

    if (useOnboardingEndpoint) {
      final data = await searchLocationsForOnboarding(
        query: trimmedQuery,
        page: page,
        limit: limit,
        locale: locale,
        preferredStateId: preferredStateId,
        type: type,
      );
      return _safeMapList(data);
    }

    final safeLimit = limit.clamp(1, 50);
    final normalizedPreferredName = preferredStateName?.trim();
    final cacheKey = [
      trimmedQuery.toLowerCase(),
      preferredStateId?.toString() ?? '',
      normalizedPreferredName?.toLowerCase() ?? '',
      safeLimit.toString(),
    ].join('|');
    final cachedAt = _locationSearchCacheTimes[cacheKey];
    final cached = _locationSearchCache[cacheKey];
    if (cachedAt != null &&
        cached != null &&
        DateTime.now().difference(cachedAt) < _locationSearchCacheTtl) {
      return cached.map((row) => Map<String, dynamic>.from(row)).toList();
    }

    final queryParameters = <String, String>{
      'q': trimmedQuery,
      'limit': safeLimit.toString(),
    };
    if (preferredStateId != null && preferredStateId > 0) {
      queryParameters['preferred_state_id'] = preferredStateId.toString();
    } else if (normalizedPreferredName != null &&
        normalizedPreferredName.isNotEmpty) {
      queryParameters['preferred_state_name'] = normalizedPreferredName;
    }

    final url = Uri.parse(
      ApiRoutes.rootApiBaseUrl + ApiRoutes.locationSearch,
    ).replace(queryParameters: queryParameters);

    final response = await http.get(
      url,
      headers: {
        'Accept': 'application/json',
        'Accept-Language': appLanguageCode(currentAppLanguage),
      },
    );

    try {
      final decoded = jsonDecode(response.body);
      final results = _safeMapList(decoded);
      _locationSearchCache[cacheKey] = results
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      _locationSearchCacheTimes[cacheKey] = DateTime.now();
      return results;
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  static Future<List<Map<String, dynamic>>> getReligions() {
    return _rememberMapList(
      _cacheKey(ApiRoutes.religions, authenticated: true),
      tags: const <String>{_cacheTagLookups, _cacheTagAuth},
      fetch: () async {
        if (authToken == null) {
          throw Exception('Auth token missing');
        }

        final url = Uri.parse(ApiRoutes.baseUrl + ApiRoutes.religions);

        final response = await http.get(
          url,
          headers: {
            'Accept': 'application/json',
            'Accept-Language': appLanguageCode(currentAppLanguage),
            'Authorization': 'Bearer $authToken',
          },
        );

        try {
          final decoded = jsonDecode(response.body);
          return _safeMapList(decoded);
        } catch (_) {
          return <Map<String, dynamic>>[];
        }
      },
    );
  }

  static Future<List<Map<String, dynamic>>> getGenders() {
    return _rememberMapList(
      _cacheKey(ApiRoutes.genders),
      fetch: () async {
        final url = Uri.parse(ApiRoutes.baseUrl + ApiRoutes.genders);
        final headers = <String, String>{
      'Accept': 'application/json',
      'Accept-Language': appLanguageCode(currentAppLanguage),
    };
        final token = authToken;
        if (token != null && token.isNotEmpty) {
          headers['Authorization'] = 'Bearer $token';
        }

        final response = await http.get(url, headers: headers);

        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw Exception(
            'Gender options load failed: HTTP ${response.statusCode}',
          );
        }

        try {
          final decoded = jsonDecode(response.body);
          final rows = _safeMapList(decoded);
          final options = rows
              .map((row) {
                final id = _intValue(row['id']);
                final key = row['key']?.toString().trim();
                final label = _firstNonEmptyValue(row, const [
                  'label',
                  'label_en',
                  'name',
                ]);
                final labelMr = row['label_mr']?.toString().trim();

                if (id == null || key == null || key.isEmpty) {
                  return null;
                }

                return <String, dynamic>{
                  'id': id,
                  'key': key,
                  'label': label ?? key,
                  'label_mr': labelMr?.isNotEmpty == true ? labelMr : null,
                };
              })
              .whereType<Map<String, dynamic>>()
              .toList();

          if (options.isEmpty) {
            throw Exception('Gender options are empty.');
          }

          return options;
        } on FormatException {
          throw Exception('Gender options response could not be read.');
        } catch (error) {
          if (error is Exception) rethrow;
          throw Exception('Gender options response could not be read.');
        }
      },
    );
  }

  static Future<Map<String, List<Map<String, dynamic>>>>
  getProfileBasicPhysicalOptions() {
    return _rememberOptionListMap(
      _cacheKey(ApiRoutes.profileBasicPhysicalOptions, authenticated: true),
      fetch: () async {
        if (authToken == null) {
          throw Exception('Auth token missing');
        }

        final url = Uri.parse(
          ApiRoutes.baseUrl + ApiRoutes.profileBasicPhysicalOptions,
        );

        final response = await http.get(
          url,
          headers: {
            'Accept': 'application/json',
            'Accept-Language': appLanguageCode(currentAppLanguage),
            'Authorization': 'Bearer $authToken',
          },
        );

        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw Exception(
            'Profile options load failed: HTTP ${response.statusCode}',
          );
        }

        final decoded = jsonDecode(response.body);
        final payload = decoded is Map
            ? decoded['data'] ?? decoded['options'] ?? decoded
            : null;
        final source = payload is Map
            ? Map<String, dynamic>.from(payload)
            : <String, dynamic>{};
        final options = <String, List<Map<String, dynamic>>>{};

        void addOptions(String key, List<String> aliases) {
          for (final alias in aliases) {
            final rows = _safeOptionList(source[alias]);
            if (rows.isNotEmpty) {
              options[key] = rows;
              return;
            }
          }
          options[key] = <Map<String, dynamic>>[];
        }

        addOptions('mother_tongues', const [
          'mother_tongues',
          'motherTongues',
          'mother_tongue',
        ]);
        addOptions('complexions', const ['complexions', 'complexion']);
        addOptions('blood_groups', const [
          'blood_groups',
          'bloodGroups',
          'blood_group',
        ]);
        addOptions('physical_builds', const [
          'physical_builds',
          'physicalBuilds',
          'physical_build',
        ]);
        addOptions('spectacles_lens', const [
          'spectacles_lens',
          'spectaclesLens',
          'spectacles_options',
          'spectacles',
        ]);
        addOptions('physical_conditions', const [
          'physical_conditions',
          'physicalConditions',
          'physical_condition',
        ]);

        return options;
      },
    );
  }

  static Future<Map<String, List<Map<String, dynamic>>>>
  getProfileEducationCareerOptions() {
    return _rememberOptionListMap(
      _cacheKey(ApiRoutes.profileEducationCareerOptions, authenticated: true),
      fetch: () async {
        if (authToken == null) {
          throw Exception('Auth token missing');
        }

        final url = Uri.parse(
          ApiRoutes.baseUrl + ApiRoutes.profileEducationCareerOptions,
        );

        final response = await http.get(
          url,
          headers: {
            'Accept': 'application/json',
            'Accept-Language': appLanguageCode(currentAppLanguage),
            'Authorization': 'Bearer $authToken',
          },
        );

        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw Exception(
            'Education career options load failed: HTTP ${response.statusCode}',
          );
        }

        final decoded = jsonDecode(response.body);
        final payload = decoded is Map
            ? decoded['data'] ?? decoded['options'] ?? decoded
            : null;
        final source = payload is Map
            ? Map<String, dynamic>.from(payload)
            : <String, dynamic>{};
        final options = <String, List<Map<String, dynamic>>>{};

        void addOptions(String key, List<String> aliases) {
          for (final alias in aliases) {
            final rows = _safeOptionList(source[alias]);
            if (rows.isNotEmpty) {
              options[key] = rows;
              return;
            }
          }
          options[key] = <Map<String, dynamic>>[];
        }

        addOptions('education_degrees', const [
          'education_degrees',
          'educationDegrees',
          'education',
          'degrees',
        ]);
        addOptions('occupation_categories', const [
          'occupation_categories',
          'occupationCategories',
        ]);
        addOptions('occupations', const [
          'occupations',
          'occupation_masters',
          'occupationMasters',
        ]);
        addOptions('custom_occupations', const [
          'custom_occupations',
          'customOccupations',
          'occupation_custom',
        ]);
        addOptions('currencies', const [
          'currencies',
          'income_currencies',
          'incomeCurrencies',
        ]);

        return options;
      },
    );
  }

  static Future<Map<String, List<Map<String, dynamic>>>>
  getProfileMaritalLifestyleOptions() {
    return _rememberOptionListMap(
      _cacheKey(ApiRoutes.profileMaritalLifestyleOptions, authenticated: true),
      fetch: () async {
        if (authToken == null) {
          throw Exception('Auth token missing');
        }

        final url = Uri.parse(
          ApiRoutes.baseUrl + ApiRoutes.profileMaritalLifestyleOptions,
        );

        final response = await http.get(
          url,
          headers: {
            'Accept': 'application/json',
            'Accept-Language': appLanguageCode(currentAppLanguage),
            'Authorization': 'Bearer $authToken',
          },
        );

        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw Exception(
            'Marital lifestyle options load failed: HTTP ${response.statusCode}',
          );
        }

        final decoded = jsonDecode(response.body);
        final payload = decoded is Map
            ? decoded['data'] ?? decoded['options'] ?? decoded
            : null;
        final source = payload is Map
            ? Map<String, dynamic>.from(payload)
            : <String, dynamic>{};
        final options = <String, List<Map<String, dynamic>>>{};

        void addOptions(String key, List<String> aliases) {
          for (final alias in aliases) {
            final rows = _safeOptionList(source[alias]);
            if (rows.isNotEmpty) {
              options[key] = rows;
              return;
            }
          }
          options[key] = <Map<String, dynamic>>[];
        }

        addOptions('marital_statuses', const [
          'marital_statuses',
          'maritalStatuses',
          'marital_status',
        ]);
        addOptions('child_living_with', const [
          'child_living_with',
          'childLivingWith',
          'child_living_with_options',
        ]);
        addOptions('diets', const ['diets', 'diet']);
        addOptions('smoking_statuses', const [
          'smoking_statuses',
          'smokingStatuses',
          'smoking_status',
        ]);
        addOptions('drinking_statuses', const [
          'drinking_statuses',
          'drinkingStatuses',
          'drinking_status',
        ]);

        return options;
      },
    );
  }

  static Future<Map<String, dynamic>> getProfileRemainingProfileOptions() {
    return _rememberJsonMap(
      _cacheKey(ApiRoutes.profileRemainingProfileOptions, authenticated: true),
      fetch: () async {
        if (authToken == null) {
          throw Exception('Auth token missing');
        }

        final url = Uri.parse(
          ApiRoutes.baseUrl + ApiRoutes.profileRemainingProfileOptions,
        );

        final response = await http.get(
          url,
          headers: {
            'Accept': 'application/json',
            'Accept-Language': appLanguageCode(currentAppLanguage),
            'Authorization': 'Bearer $authToken',
          },
        );

        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw Exception(
            'Remaining profile options load failed: HTTP ${response.statusCode}',
          );
        }

        final decoded = jsonDecode(response.body);
        final payload = decoded is Map
            ? decoded['data'] ?? decoded['options'] ?? decoded
            : null;
        final source = payload is Map
            ? Map<String, dynamic>.from(payload)
            : <String, dynamic>{};
        final options = <String, dynamic>{};

        void addOptions(String key, List<String> aliases) {
          for (final alias in aliases) {
            final rows = _safeOptionList(source[alias]);
            if (rows.isNotEmpty) {
              options[key] = rows;
              return;
            }
          }
          options[key] = <Map<String, dynamic>>[];
        }

        addOptions('family_types', const ['family_types', 'familyTypes']);
        addOptions('family_statuses', const [
          'family_statuses',
          'familyStatuses',
          'family_status',
        ]);
        addOptions('family_values', const [
          'family_values',
          'familyValues',
          'family_value',
        ]);
        addOptions('occupation_categories', const [
          'occupation_categories',
          'occupationCategories',
        ]);
        addOptions('occupations', const [
          'occupations',
          'occupation_masters',
          'occupationMasters',
        ]);
        addOptions('custom_occupations', const [
          'custom_occupations',
          'customOccupations',
          'occupation_custom',
        ]);
        addOptions('currencies', const [
          'currencies',
          'income_currencies',
          'incomeCurrencies',
        ]);
        addOptions('rashis', const ['rashis', 'rashi']);
        addOptions('nakshatras', const ['nakshatras', 'nakshatra']);
        addOptions('gans', const ['gans', 'gan']);
        addOptions('nadis', const ['nadis', 'nadi']);
        addOptions('yonis', const ['yonis', 'yoni']);
        addOptions('varnas', const ['varnas', 'varna']);
        addOptions('vashyas', const ['vashyas', 'vashya']);
        addOptions('rashi_lords', const ['rashi_lords', 'rashiLords']);
        addOptions('mangal_dosh_types', const [
          'mangal_dosh_types',
          'mangalDoshTypes',
          'mangal_dosh',
        ]);
        addOptions('birth_weekdays', const [
          'birth_weekdays',
          'birthWeekdays',
          'weekdays',
        ]);
        options['horoscope_rules'] = source['horoscope_rules'] is Map
            ? Map<String, dynamic>.from(source['horoscope_rules'])
            : <String, dynamic>{};
        options['rashi_ashtakoota'] = source['rashi_ashtakoota'] is Map
            ? Map<String, dynamic>.from(source['rashi_ashtakoota'])
            : <String, dynamic>{};

        return options;
      },
    );
  }

  static Future<Map<String, List<Map<String, dynamic>>>>
  getProfilePartnerPreferenceOptions() {
    return _rememberOptionListMap(
      _cacheKey(ApiRoutes.profilePartnerPreferenceOptions, authenticated: true),
      fetch: () async {
        if (authToken == null) {
          throw Exception('Auth token missing');
        }

        final url = Uri.parse(
          ApiRoutes.baseUrl + ApiRoutes.profilePartnerPreferenceOptions,
        );

        final response = await http.get(
          url,
          headers: {
            'Accept': 'application/json',
            'Accept-Language': appLanguageCode(currentAppLanguage),
            'Authorization': 'Bearer $authToken',
          },
        );

        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw Exception(
            'Partner preference options load failed: HTTP ${response.statusCode}',
          );
        }

        final decoded = jsonDecode(response.body);
        final payload = decoded is Map
            ? decoded['data'] ?? decoded['options'] ?? decoded
            : null;
        final source = payload is Map
            ? Map<String, dynamic>.from(payload)
            : <String, dynamic>{};
        final options = <String, List<Map<String, dynamic>>>{};

        void addOptions(String key, List<String> aliases) {
          for (final alias in aliases) {
            final rows = _safeOptionList(source[alias]);
            if (rows.isNotEmpty) {
              options[key] = rows;
              return;
            }
          }
          options[key] = <Map<String, dynamic>>[];
        }

        addOptions('marriage_type_preferences', const [
          'marriage_type_preferences',
          'marriageTypePreferences',
          'marriage_type_preference',
        ]);
        addOptions('marital_statuses', const [
          'marital_statuses',
          'maritalStatuses',
          'marital_status',
        ]);
        addOptions('partner_profile_with_children', const [
          'partner_profile_with_children',
          'partnerProfileWithChildren',
          'partner_profile_children',
        ]);
        addOptions('preferred_profile_managed_by', const [
          'preferred_profile_managed_by',
          'preferredProfileManagedBy',
          'profile_managed_by',
        ]);
        addOptions('diets', const ['diets', 'diet']);
        addOptions('mother_tongues', const [
          'mother_tongues',
          'motherTongues',
          'mother_tongue',
        ]);
        addOptions('religions', const ['religions', 'religion']);
        addOptions('castes', const ['castes', 'caste']);
        addOptions('education_degrees', const [
          'education_degrees',
          'educationDegrees',
          'educations',
          'education',
        ]);
        addOptions('occupation_categories', const [
          'occupation_categories',
          'occupationCategories',
        ]);
        addOptions('occupations', const ['occupations', 'occupation']);

        return options;
      },
    );
  }

  static Future<List<Map<String, dynamic>>> getCastes({
    required int religionId,
  }) {
    return _rememberMapList(
      _cacheKey(
        ApiRoutes.castes,
        authenticated: true,
        query: {'religion_id': religionId},
      ),
      tags: const <String>{_cacheTagLookups, _cacheTagAuth},
      fetch: () async {
        if (authToken == null) {
          throw Exception('Auth token missing');
        }

        final url = Uri.parse(
          ApiRoutes.baseUrl + ApiRoutes.castes,
        ).replace(queryParameters: {'religion_id': religionId.toString()});

        final response = await http.get(
          url,
          headers: {
            'Accept': 'application/json',
            'Accept-Language': appLanguageCode(currentAppLanguage),
            'Authorization': 'Bearer $authToken',
          },
        );

        try {
          final decoded = jsonDecode(response.body);
          return _safeMapList(decoded);
        } catch (_) {
          return <Map<String, dynamic>>[];
        }
      },
    );
  }

  static Future<List<Map<String, dynamic>>> searchSubCastes({
    required int casteId,
    required String query,
    int page = 1,
    int limit = 20,
    String? locale,
    bool useOnboardingEndpoint = false,
  }) async {
    if (authToken == null) {
      throw Exception('Auth token missing');
    }

    final trimmedQuery = query.trim();
    if (trimmedQuery.length < 2) return <Map<String, dynamic>>[];

    if (useOnboardingEndpoint) {
      final data = await searchSubCastesForOnboarding(
        casteId: casteId,
        query: trimmedQuery,
        page: page,
        limit: limit,
        locale: locale,
      );
      return _safeMapList(data);
    }

    final url = Uri.parse(ApiRoutes.baseUrl + ApiRoutes.subCastes).replace(
      queryParameters: {'caste_id': casteId.toString(), 'q': trimmedQuery},
    );

    final response = await http.get(
      url,
      headers: {
        'Accept': 'application/json',
        'Accept-Language': appLanguageCode(currentAppLanguage),
        'Authorization': 'Bearer $authToken',
      },
    );

    try {
      final decoded = jsonDecode(response.body);
      return _safeMapList(decoded);
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  static Future<List<Map<String, dynamic>>> searchEducationDegrees(
    String query,
  ) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return <Map<String, dynamic>>[];

    final url = Uri.parse(
      ApiRoutes.rootApiBaseUrl + ApiRoutes.educationDegreeSearch,
    ).replace(queryParameters: {'q': trimmedQuery});

    final response = await http.get(
      url,
      headers: {
        'Accept': 'application/json',
        'Accept-Language': appLanguageCode(currentAppLanguage),
      },
    );

    try {
      final decoded = jsonDecode(response.body);
      return _safeMapList(decoded);
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  static Future<Map<String, dynamic>> sendMobileOtp({
    required String mobile,
    required bool termsAccepted,
    required bool privacyAccepted,
    String? locale,
    String channel = 'sms',
    String purpose = 'login_or_register',
    String? termsVersion,
    String? privacyVersion,
    bool? whatsappAlertsOptIn,
  }) {
    return _postJson(ApiRoutes.mobileOtpSend, {
      'mobile': mobile,
      'locale': locale,
      'channel': channel,
      'purpose': purpose,
      'terms_accepted': termsAccepted,
      'privacy_accepted': privacyAccepted,
      'terms_version': termsVersion,
      'privacy_version': privacyVersion,
      'whatsapp_alerts_opt_in': whatsappAlertsOptIn,
    });
  }

  static Future<Map<String, dynamic>> verifyMobileOtp({
    required String challengeId,
    required String mobile,
    required String otp,
  }) async {
    // Sent authenticated whenever there IS a session, so the server can tell
    // "this member is verifying their own number" from "someone is signing in
    // with it". Without the header it only ever saw the second, and a member
    // finishing onboarding was moved onto a fresh empty account.
    final data = await _postJson(ApiRoutes.mobileOtpVerify, {
      'challenge_id': challengeId,
      'mobile': mobile,
      'otp': otp,
    }, authenticated: authToken != null && authToken!.isNotEmpty);

    final token =
        data['token']?.toString() ??
        ((data['data'] is Map) ? data['data']['token']?.toString() : null);
    if (data['statusCode'] == 200 && token != null && token.isNotEmpty) {
      ApiCache.instance.clear();
      currentUserProfile = null;
      sentInterestProfileIds.clear();
      authToken = token;
      await AppStorage.instance.saveAuthToken(token);
      // Two independent calls on purpose. The device token must reach the
      // server even when the member denies the notification dialog — a device
      // the server does not know can never be reached, not even after
      // notifications are switched on later.
      unawaited(PushNotificationService.instance.registerToken());
      unawaited(NotificationPermissionService.ensureRequested(force: true));
    }

    return data;
  }

  static Future<Map<String, dynamic>> updateAccountDetails({
    required String creatorName,
    String? email,
    String? locale,
    String? password,
    String? passwordConfirmation,
    bool? whatsappAlertsOptIn,
  }) {
    return _patchJson(ApiRoutes.accountDetails, {
      'creator_name': creatorName,
      'email': email,
      'locale': locale,
      'password': password,
      'password_confirmation': passwordConfirmation,
      'whatsapp_alerts_opt_in': whatsappAlertsOptIn,
    }, authenticated: true);
  }

  /// Where the member's account stands: `active`, `paused` or
  /// `deletion_pending`, plus how many days are left to cancel.
  static Future<Map<String, dynamic>> fetchAccountDeletionStatus() {
    return _getJson(ApiRoutes.accountDeletion, authenticated: true);
  }

  /// Starts the grace period. [confirmation] is the word the member typed and
  /// is checked again on the server, so this cannot be reached by a stray tap.
  static Future<Map<String, dynamic>> requestAccountDeletion({
    required String confirmation,
    required String reasonKey,
    String? reasonNote,
  }) {
    return _postJson(ApiRoutes.accountDeletion, {
      'confirmation': confirmation,
      'reason_key': reasonKey,
      'reason_note': reasonNote,
    }, authenticated: true);
  }

  static Future<Map<String, dynamic>> cancelAccountDeletion() {
    return _profileActionDelete(ApiRoutes.accountDeletion);
  }

  /// Hides the profile without scheduling anything — the softer option.
  static Future<Map<String, dynamic>> pauseAccount() {
    return _postJson(ApiRoutes.accountPause, const {}, authenticated: true);
  }

  static Future<Map<String, dynamic>> resumeAccount() {
    return _postJson(ApiRoutes.accountResume, const {}, authenticated: true);
  }

  static Future<Map<String, dynamic>> verifyGoogleEmail({
    required String email,
    required String idToken,
  }) {
    return _postJson(ApiRoutes.accountEmailGoogle, {
      'email': email,
      'id_token': idToken,
    }, authenticated: true);
  }

  static Future<Map<String, dynamic>> sendEmailOtp({required String email}) {
    return _postJson(ApiRoutes.accountEmailOtpSend, {
      'email': email,
    }, authenticated: true);
  }

  static Future<Map<String, dynamic>> verifyEmailOtp({
    required String challengeId,
    required String email,
    required String otp,
  }) {
    return _postJson(ApiRoutes.accountEmailOtpVerify, {
      'challenge_id': challengeId,
      'email': email,
      'otp': otp,
    }, authenticated: true);
  }

  static Future<Map<String, dynamic>> startOnboarding({
    required String profileForWhom,
    int? genderId,
    int? motherTongueId,
  }) {
    return _postJson(ApiRoutes.onboardingStart, {
      'profile_for_whom': profileForWhom,
      'gender_id': genderId,
      'mother_tongue_id': motherTongueId,
    }, authenticated: true);
  }

  static Future<List<Map<String, dynamic>>> getInternalLocationStates() async {
    return _safeMapList(await _getRootJson(ApiRoutes.internalLocationStates));
  }

  static Future<List<Map<String, dynamic>>> getInternalLocationDistricts({
    required int stateId,
  }) async {
    return _safeMapList(
      await _getRootJson(
        ApiRoutes.internalLocationDistricts,
        query: {'parent_id': stateId},
      ),
    );
  }

  static Future<List<Map<String, dynamic>>> getInternalLocationTalukas({
    required int districtId,
  }) async {
    return _safeMapList(
      await _getRootJson(
        ApiRoutes.internalLocationTalukas,
        query: {'parent_id': districtId},
      ),
    );
  }

  static Future<Map<String, dynamic>> getInternalLocationChildren({
    required int parentId,
    String? query,
    int page = 1,
    int limit = 20,
    String? locale,
    String? filter,
  }) {
    return _getRootJson(
      ApiRoutes.internalLocationChildren,
      query: {
        'parent_id': parentId,
        'q': query,
        'page': page,
        'limit': limit,
        'locale': locale,
        'filter': filter,
      },
    );
  }

  static Future<Map<String, dynamic>> getOnboardingStatus({String? locale}) {
    return _getJson(
      ApiRoutes.onboardingStatus,
      authenticated: true,
      query: {'locale': locale},
    );
  }

  static Future<Map<String, dynamic>> getOnboardingDraft({String? locale}) {
    return _getJson(
      ApiRoutes.onboardingDraft,
      authenticated: true,
      query: {'locale': locale},
    );
  }

  static Future<Map<String, dynamic>> saveOnboardingDraftStep({
    required String step,
    required Map<String, dynamic> data,
  }) {
    return _patchJson(ApiRoutes.onboardingDraftStep(step), {
      'data': data,
    }, authenticated: true);
  }

  static Future<Map<String, dynamic>> saveOnboardingProfileStep({
    required String step,
    required Map<String, dynamic> data,
  }) async {
    final response = await _postJson(ApiRoutes.onboardingProfileSaveStep, {
      'step': step,
      'data': data,
    }, authenticated: true);
    if (_isSuccessfulResponse(response)) {
      _invalidateProfileCache();
    }
    return response;
  }

  static Future<Map<String, dynamic>> getActivationChecklist({String? locale}) {
    return _getJson(
      ApiRoutes.onboardingActivationChecklist,
      authenticated: true,
      query: {'locale': locale},
    );
  }

  static Future<Map<String, dynamic>> getOnboardingBootstrap({String? locale}) {
    return _getJsonCached(
      ApiRoutes.onboardingLookupsBootstrap,
      authenticated: false,
      query: {'locale': locale},
      ttl: _lookupCacheTtl,
      tags: const <String>{_cacheTagLookups},
    );
  }

  static String _onboardingLookupRoute(String lookup) {
    switch (lookup) {
      case 'religions':
      case 'religion':
        return ApiRoutes.onboardingLookupsReligions;
      case 'castes':
      case 'caste':
        return ApiRoutes.onboardingLookupsCastes;
      case 'sub-castes':
      case 'sub_castes':
      case 'subCaste':
        return ApiRoutes.onboardingLookupsSubCastes;
      case 'locations':
      case 'location':
        return ApiRoutes.onboardingLookupsLocations;
      case 'education':
      case 'educations':
        return ApiRoutes.onboardingLookupsEducation;
      case 'working-with':
      case 'working_with':
        return ApiRoutes.onboardingLookupsWorkingWith;
      case 'occupations':
      case 'occupation':
        return ApiRoutes.onboardingLookupsOccupations;
      case 'income-options':
      case 'income_options':
        return ApiRoutes.onboardingLookupsIncomeOptions;
      case 'diet':
        return ApiRoutes.onboardingLookupsDiet;
      case 'smoking':
        return ApiRoutes.onboardingLookupsSmoking;
      case 'drinking':
        return ApiRoutes.onboardingLookupsDrinking;
      case 'physical-builds':
      case 'physical_builds':
      case 'physical-build':
      case 'physical_build':
        return ApiRoutes.onboardingLookupsPhysicalBuilds;
      case 'spectacles-lens':
      case 'spectacles_lens':
        return ApiRoutes.onboardingLookupsSpectaclesLens;
    }

    return lookup.startsWith('/') ? lookup : '/onboarding/lookups/$lookup';
  }

  static Future<Map<String, dynamic>> searchOnboardingLookup({
    required String lookup,
    String? query,
    int page = 1,
    int limit = 20,
    String? locale,
    Map<String, dynamic>? filters,
  }) {
    final route = _onboardingLookupRoute(lookup);
    final queryParams = <String, dynamic>{
      'q': query,
      'page': page,
      'limit': limit,
      'locale': locale,
      ...?filters,
    };
    final isSearch = (query?.trim().isNotEmpty ?? false) || page > 1;
    return _getJsonCached(
      route,
      authenticated: true,
      query: queryParams,
      ttl: isSearch ? _lookupSearchCacheTtl : _lookupCacheTtl,
      tags: const <String>{_cacheTagLookups, _cacheTagAuth},
    );
  }

  static Future<Map<String, dynamic>> searchReligions({
    String? query,
    int page = 1,
    int limit = 20,
    String? locale,
  }) {
    return searchOnboardingLookup(
      lookup: 'religions',
      query: query,
      page: page,
      limit: limit,
      locale: locale,
    );
  }

  static Future<Map<String, dynamic>> searchCastes({
    required int religionId,
    String? query,
    int page = 1,
    int limit = 20,
    String? locale,
  }) {
    return searchOnboardingLookup(
      lookup: 'castes',
      query: query,
      page: page,
      limit: limit,
      locale: locale,
      filters: {'religion_id': religionId},
    );
  }

  static Future<Map<String, dynamic>> searchSubCastesForOnboarding({
    required int casteId,
    String? query,
    int page = 1,
    int limit = 20,
    String? locale,
  }) {
    return searchOnboardingLookup(
      lookup: 'sub-castes',
      query: query,
      page: page,
      limit: limit,
      locale: locale,
      filters: {'caste_id': casteId},
    );
  }

  static Future<Map<String, dynamic>> searchLocationsForOnboarding({
    String? query,
    int page = 1,
    int limit = 20,
    String? locale,
    int? preferredStateId,
    String? type,
  }) {
    return searchOnboardingLookup(
      lookup: 'locations',
      query: query,
      page: page,
      limit: limit,
      locale: locale,
      filters: {'preferred_state_id': preferredStateId, 'type': type},
    );
  }

  static Future<Map<String, dynamic>> submitLocationSuggestion(
    Map<String, dynamic> body,
  ) {
    return _postJson(
      ApiRoutes.onboardingLocationSuggestions,
      body,
      authenticated: true,
    );
  }

  static Future<Map<String, dynamic>> searchEducation({
    String? query,
    int page = 1,
    int limit = 20,
    String? locale,
    int? categoryId,
  }) {
    return searchOnboardingLookup(
      lookup: 'education',
      query: query,
      page: page,
      limit: limit,
      locale: locale,
      filters: {'category_id': categoryId},
    );
  }

  static Future<Map<String, dynamic>> submitEducationSuggestion(
    Map<String, dynamic> body,
  ) {
    return _postJson(
      ApiRoutes.onboardingEducationSuggestions,
      body,
      authenticated: true,
    );
  }

  static Future<Map<String, dynamic>> getWorkingWithOptions({
    String? query,
    int page = 1,
    int limit = 20,
    String? locale,
  }) {
    return searchOnboardingLookup(
      lookup: 'working-with',
      query: query,
      page: page,
      limit: limit,
      locale: locale,
    );
  }

  static Future<Map<String, dynamic>> searchOccupations({
    String? query,
    int page = 1,
    int limit = 20,
    String? locale,
    int? workingWithId,
    int? categoryId,
  }) {
    return searchOnboardingLookup(
      lookup: 'occupations',
      query: query,
      page: page,
      limit: limit,
      locale: locale,
      filters: {'working_with_id': workingWithId, 'category_id': categoryId},
    );
  }

  static Future<Map<String, dynamic>> submitOccupationSuggestion(
    Map<String, dynamic> body,
  ) {
    return _postJson(
      ApiRoutes.onboardingOccupationSuggestions,
      body,
      authenticated: true,
    );
  }

  static Future<Map<String, dynamic>> getIncomeOptions({String? locale}) {
    return _getJsonCached(
      ApiRoutes.onboardingLookupsIncomeOptions,
      authenticated: true,
      query: {'locale': locale},
      ttl: _lookupCacheTtl,
      tags: const <String>{_cacheTagLookups, _cacheTagAuth},
    );
  }

  static Future<Map<String, dynamic>> getLifestyleLookup({
    required String type,
    String? query,
    int page = 1,
    int limit = 20,
    String? locale,
  }) {
    return searchOnboardingLookup(
      lookup: type,
      query: query,
      page: page,
      limit: limit,
      locale: locale,
    );
  }

  static Future<Map<String, dynamic>> previewAutoPreferenceDraft({
    String? locale,
  }) {
    return _getJson(
      ApiRoutes.onboardingPreferenceAutoDraftPreview,
      authenticated: true,
      query: {'locale': locale},
    );
  }

  static Future<Map<String, dynamic>> generateAutoPreferenceDraft({
    bool forceRegenerate = false,
  }) {
    return _postJson(ApiRoutes.onboardingPreferenceAutoDraft, {
      'force_regenerate': forceRegenerate,
    }, authenticated: true);
  }

  static Future<Map<String, dynamic>> getAutoPreferenceDraftStatus({
    String? locale,
  }) {
    return _getJson(
      ApiRoutes.onboardingPreferenceAutoDraftStatus,
      authenticated: true,
      query: {'locale': locale},
    );
  }

  static Future<Map<String, dynamic>> getMyProfile({
    bool forceRefresh = false,
  }) async {
    if (authToken == null) {
      throw Exception('Auth token missing');
    }

    final data = await _getJsonCached(
      ApiRoutes.matrimonyProfile,
      authenticated: true,
      ttl: _profileCacheTtl,
      tags: const <String>{_cacheTagProfile, _cacheTagAuth},
      forceRefresh: forceRefresh,
    );

    _applyMyProfileResponse(data);
    return data;
  }

  static void _applyMyProfileResponse(Map<String, dynamic> data) {
    if (data['statusCode'] == 200 && data['success'] == true) {
      final profile = data['profile'];
      if (profile is Map) {
        final normalizedProfile = Map<String, dynamic>.from(profile);
        final display = data['display'];
        if (display is Map) {
          normalizedProfile['display'] = Map<String, dynamic>.from(display);
          final displayPhotoUrl = _resolveApprovedPhotoHint(normalizedProfile);
          if (displayPhotoUrl != null) {
            normalizedProfile['profile_photo_url'] = displayPhotoUrl;
          }
        }
        currentUserProfile = normalizedProfile;
      }
    }
  }

  static Future<Map<String, dynamic>> login({
    String? login,
    String? email,
    required String password,
  }) async {
    final url = Uri.parse(ApiRoutes.baseUrl + ApiRoutes.login);
    final loginValue = (login ?? email ?? '').trim();

    final response = await http.post(
      url,
      headers: {
        'Accept': 'application/json',
        'Accept-Language': appLanguageCode(currentAppLanguage),
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'login': loginValue, 'password': password}),
    );

    final data = _decodeResponse(response);

    if (response.statusCode != 200) {
      data['message'] ??= 'Login failed: HTTP ${response.statusCode}';
      return data;
    }

    if (await _adoptSession(data)) {
      return data;
    }

    data['message'] ??= 'Login failed: No token received';
    return data;
  }

  /// Takes over the session a sign-in response carries, if it carries one.
  ///
  /// Every door into the app — password, mobile OTP, Google — ends here, so the
  /// stale-state clearing and the push registration happen exactly once and
  /// identically. A member who signs in with Google must be as reachable by
  /// push as one who typed a password; that only stays true while there is one
  /// implementation of this.
  static Future<bool> _adoptSession(Map<String, dynamic> data) async {
    final token = data['token']?.toString();
    if (token == null || token.isEmpty) {
      return false;
    }

    ApiCache.instance.clear();
    currentUserProfile = null;
    sentInterestProfileIds.clear();
    authToken = token;
    await AppStorage.instance.saveAuthToken(token);
    // Two independent calls on purpose. The device token must reach the
    // server even when the member denies the notification dialog — a device
    // the server does not know can never be reached, not even after
    // notifications are switched on later.
    unawaited(PushNotificationService.instance.registerToken());
    unawaited(NotificationPermissionService.ensureRequested(force: true));

    return true;
  }

  /// Signs in — or signs up — with a Google ID token.
  ///
  /// The token is the whole request. The email is deliberately not sent
  /// alongside it: the server reads the address out of the token it verified
  /// with Google, so there is no caller-supplied address for it to have to
  /// trust. The reply carries `is_new_user` for wording, but routing afterwards
  /// is the ordinary profile check, exactly as after a password login.
  static Future<Map<String, dynamic>> signInWithGoogle({
    required String idToken,
  }) async {
    final data = await _postJson(ApiRoutes.authGoogle, {'id_token': idToken});

    if (await _adoptSession(data)) {
      return data;
    }

    data['message'] ??= 'Google sign-in failed.';
    data['success'] = false;
    return data;
  }

  /// Asks the server to email a password reset link.
  ///
  /// `login` takes a mobile number, an email address or a username —
  /// `PasswordResetApiController::forgot` resolves all three down to the
  /// account's email, and the link is always delivered by email. There is no
  /// SMS path and no OTP: the reply carries no challenge id or correlation
  /// key, only `success` and `message`.
  static Future<Map<String, dynamic>> sendPasswordResetLink({
    required String login,
  }) {
    return _postJson(ApiRoutes.passwordForgot, {'login': login.trim()});
  }

  /// Consumes the emailed reset token and sets a new password.
  ///
  /// Deliberately does not touch [authToken]: the server issues no session
  /// here (`reset` returns only `success` and `message`), so a member always
  /// signs in again afterwards. `email` must be the real email address — this
  /// endpoint does not accept a mobile number, which is why the flow reads it
  /// back out of the emailed link.
  static Future<Map<String, dynamic>> resetPassword({
    required String token,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) {
    return _postJson(ApiRoutes.passwordReset, {
      'token': token.trim(),
      'email': email.trim(),
      'password': password,
      'password_confirmation': passwordConfirmation,
    });
  }

  /// Sets a new password for the signed-in member.
  ///
  /// `POST /api/v1/account/password` (`auth:sanctum`, declared in
  /// `routes/api/member.php`). `MemberPasswordApiController::update` validates
  /// `['password' => ['required', 'confirmed', Rules\Password::defaults()]]`
  /// and returns `{success, message}`; a rejected password comes back as a
  /// stock 422 with `errors.password`.
  ///
  /// **No `current_password` field, deliberately.** A member reaches this
  /// screen because she could not remember the old one — see the decision
  /// recorded on `App\Services\Account\MemberPasswordService`.
  ///
  /// [authToken] is left alone on purpose: the server revokes every OTHER
  /// Sanctum token but keeps the caller's own, so this device stays signed in
  /// and must not throw its still-valid token away.
  static Future<Map<String, dynamic>> changeAccountPassword({
    required String password,
    required String passwordConfirmation,
  }) {
    return _postJson(ApiRoutes.accountPassword, {
      'password': password,
      'password_confirmation': passwordConfirmation,
    }, authenticated: true);
  }

  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    final url = Uri.parse(ApiRoutes.baseUrl + ApiRoutes.register);

    final response = await http.post(
      url,
      headers: {
        'Accept': 'application/json',
        'Accept-Language': appLanguageCode(currentAppLanguage),
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        'password_confirmation': passwordConfirmation,
      }),
    );

    final data = _decodeResponse(response);

    if (response.statusCode != 200) {
      data['message'] ??= 'Registration failed: HTTP ${response.statusCode}';
      return data;
    }

    final token = data['token']?.toString();
    if (token != null && token.isNotEmpty) {
      ApiCache.instance.clear();
      currentUserProfile = null;
      sentInterestProfileIds.clear();
      authToken = token;
      await AppStorage.instance.saveAuthToken(token);
      // Two independent calls on purpose. The device token must reach the
      // server even when the member denies the notification dialog — a device
      // the server does not know can never be reached, not even after
      // notifications are switched on later.
      unawaited(PushNotificationService.instance.registerToken());
      unawaited(NotificationPermissionService.ensureRequested(force: true));
      return data;
    }

    data['message'] ??= 'Registration failed: No token received';
    return data;
  }

  static Future<Map<String, dynamic>> createMatrimonyProfile(
    Map<String, dynamic> body,
  ) async {
    if (authToken == null) {
      throw Exception('Auth token is missing. User not logged in.');
    }

    final url = Uri.parse(ApiRoutes.baseUrl + ApiRoutes.matrimonyProfile);

    final response = await http.post(
      url,
      headers: {
        'Accept': 'application/json',
        'Accept-Language': appLanguageCode(currentAppLanguage),
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
      body: jsonEncode(body),
    );

    final data = _decodeResponse(response);

    if (data['success'] == true) {
      _invalidateProfileCache();
      currentUserProfile = data['profile'] as Map<String, dynamic>?;
    }

    return data;
  }

  static Future<Map<String, dynamic>> updateMatrimonyProfile(
    Map<String, dynamic> body,
  ) async {
    if (authToken == null) {
      throw Exception('Auth token is missing. User not logged in.');
    }

    final url = Uri.parse(ApiRoutes.baseUrl + ApiRoutes.matrimonyProfile);

    final response = await http.put(
      url,
      headers: {
        'Accept': 'application/json',
        'Accept-Language': appLanguageCode(currentAppLanguage),
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
      body: jsonEncode(body),
    );

    final data = _decodeResponse(response);

    if (data['success'] == true) {
      _invalidateProfileCache();
      currentUserProfile = data['profile'] as Map<String, dynamic>?;
    }

    return data;
  }

  static Future<Map<String, dynamic>> getProfilePhotos() {
    return _getJson(ApiRoutes.profilePhotos, authenticated: true);
  }

  static Future<Map<String, dynamic>> uploadProfilePhotos(
    List<File> imageFiles,
  ) async {
    if (authToken == null) {
      throw Exception('Auth token is missing. User not logged in.');
    }
    if (imageFiles.isEmpty) {
      throw Exception('No photo selected.');
    }

    final url = Uri.parse(ApiRoutes.baseUrl + ApiRoutes.profilePhotoUpload);
    final request = http.MultipartRequest('POST', url);
    request.headers['Accept'] = 'application/json';
    request.headers['Authorization'] = 'Bearer $authToken';

    for (var i = 0; i < imageFiles.length; i++) {
      request.files.add(
        await http.MultipartFile.fromPath(
          i == 0 ? 'profile_photo' : 'profile_photos[]',
          imageFiles[i].path,
        ),
      );
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    final data = _decodeResponse(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      _mergeProfilePhotoSummary(data);
      _invalidateProfileCache();
    }

    return data;
  }

  static Future<Map<String, dynamic>> setPrimaryProfilePhoto(
    int photoId,
  ) async {
    final data = await _postJson(
      ApiRoutes.profilePhotoPrimary(photoId),
      <String, dynamic>{},
      authenticated: true,
    );
    _mergeProfilePhotoSummary(data);
    if (_isSuccessfulResponse(data)) {
      _invalidateProfileCache();
    }
    return data;
  }

  static Future<Map<String, dynamic>> deleteProfilePhoto(int photoId) async {
    final data = await _profileActionDelete(
      ApiRoutes.profilePhotoDelete(photoId),
    );
    _mergeProfilePhotoSummary(data);
    if (_isSuccessfulResponse(data)) {
      _invalidateProfileCache();
    }
    return data;
  }

  static Future<Map<String, dynamic>> reorderProfilePhotos(
    List<int> photoIds,
  ) async {
    final data = await _putJson(
      ApiRoutes.profilePhotoReorder,
      <String, dynamic>{'photo_ids': photoIds},
      authenticated: true,
    );
    _mergeProfilePhotoSummary(data);
    if (_isSuccessfulResponse(data)) {
      _invalidateProfileCache();
    }
    return data;
  }

  static Future<Map<String, dynamic>> getProfileVerificationStatus() {
    return _getJson(ApiRoutes.profileVerificationStatus, authenticated: true);
  }

  static void _mergeProfilePhotoSummary(Map<String, dynamic> data) {
    final summary = data['profile'];
    if (summary is! Map) return;

    final profile = currentUserProfile ??= <String, dynamic>{};
    profile.addAll(Map<String, dynamic>.from(summary));
    final photoUrl = resolveProfilePhotoUrl(profile);
    if (photoUrl != null) {
      profile['profile_photo_url'] = photoUrl;
    }
  }

  static Future<Map<String, dynamic>> getProfileList({
    int? ageFrom,
    int? ageTo,
    int? heightFromCm,
    int? heightToCm,
    int? religionId,
    int? casteId,
    String? caste,
    int? countryId,
    int? stateId,
    int? districtId,
    int? locationId,
    bool? photoAvailable,
    bool? verifiedPhoto,
    bool? recentlyActive,
    int? educationId,
    int? occupationId,
    int? maritalStatusId,
    String? feed,
    int? page,
    int? perPage,
  }) async {
    if (authToken == null) {
      throw Exception('Auth token is missing. User not logged in.');
    }

    final queryParams = <String, String>{};
    if (ageFrom != null) {
      queryParams['age_from'] = ageFrom.toString();
    }
    if (ageTo != null) {
      queryParams['age_to'] = ageTo.toString();
    }
    if (heightFromCm != null) {
      queryParams['height_from_cm'] = heightFromCm.toString();
    }
    if (heightToCm != null) {
      queryParams['height_to_cm'] = heightToCm.toString();
    }
    if (religionId != null) {
      queryParams['religion_id'] = religionId.toString();
    }
    if (casteId != null) {
      queryParams['caste_id'] = casteId.toString();
    }
    if (caste != null && caste.isNotEmpty) {
      queryParams['caste'] = caste;
    }
    if (countryId != null) {
      queryParams['country_id'] = countryId.toString();
    }
    if (stateId != null) {
      queryParams['state_id'] = stateId.toString();
    }
    if (districtId != null) {
      queryParams['district_id'] = districtId.toString();
    }
    if (locationId != null) {
      queryParams['location_id'] = locationId.toString();
    }
    if (photoAvailable == true) {
      queryParams['photo_available'] = '1';
    }
    if (verifiedPhoto == true) {
      queryParams['verified_photo'] = '1';
    }
    if (recentlyActive == true) {
      queryParams['recently_active'] = '1';
    }
    if (educationId != null) {
      queryParams['education_id'] = educationId.toString();
    }
    if (occupationId != null) {
      queryParams['occupation_id'] = occupationId.toString();
    }
    if (maritalStatusId != null) {
      queryParams['marital_status_id'] = maritalStatusId.toString();
    }
    if (feed != null && feed.isNotEmpty) {
      queryParams['feed'] = feed;
    }
    // Only the nearby feed paginates today; the response carries a `pagination`
    // object when it does. Other feeds ignore these and return their full list.
    if (page != null) {
      queryParams['page'] = page.toString();
    }
    if (perPage != null) {
      queryParams['per_page'] = perPage.toString();
    }

    final baseUrl = ApiRoutes.baseUrl + ApiRoutes.matrimonyProfiles;
    final url = queryParams.isEmpty
        ? Uri.parse(baseUrl)
        : Uri.parse(baseUrl).replace(queryParameters: queryParams);

    final response = await http.get(
      url,
      headers: {
        'Accept': 'application/json',
        'Accept-Language': appLanguageCode(currentAppLanguage),
        'Authorization': 'Bearer $authToken',
      },
    );

    return _decodeResponse(response);
  }

  static Future<Map<String, dynamic>> getMoreMatchSections() async {
    if (authToken == null) {
      return <String, dynamic>{
        'success': false,
        'statusCode': 401,
        'sections': <dynamic>[],
      };
    }

    try {
      final response = await http.get(
        Uri.parse(
          '${ApiRoutes.baseUrl}${ApiRoutes.matrimonyProfileMoreSections}',
        ),
        headers: {
          'Accept': 'application/json',
          'Accept-Language': appLanguageCode(currentAppLanguage),
          'Authorization': 'Bearer $authToken',
        },
      );

      return _decodeResponse(response);
    } catch (_) {
      return <String, dynamic>{
        'success': false,
        'statusCode': 0,
        'sections': <dynamic>[],
      };
    }
  }

  static Future<Map<String, dynamic>> getProfileDetail(int profileId) async {
    if (authToken == null) {
      throw Exception('Auth token is missing. User not logged in.');
    }

    final url = Uri.parse(
      '${ApiRoutes.baseUrl}${ApiRoutes.matrimonyProfiles}/$profileId',
    );

    final response = await http.get(
      url,
      headers: {
        'Accept': 'application/json',
        'Accept-Language': appLanguageCode(currentAppLanguage),
        'Authorization': 'Bearer $authToken',
      },
    );

    return _decodeResponse(response);
  }

  static Future<void> restoreSessionFromStorage() async {
    final token = await AppStorage.instance.readAuthToken();
    ApiCache.instance.clear();
    authToken = token != null && token.isNotEmpty ? token : null;
    currentUserProfile = null;
    sentInterestProfileIds.clear();

    if (authToken != null) {
      unawaited(PushNotificationService.instance.registerToken());
    }
  }

  static Future<void> logout() async {
    // The server drops the device token while the session is still valid — the
    // DELETE is an authenticated call, so it cannot run after the clear below.
    await PushNotificationService.instance.unregisterToken();
    ApiCache.instance.clear();
    authToken = null;
    currentUserProfile = null;
    sentInterestProfileIds.clear();
    await AppStorage.instance.clearSessionButKeepLanguage();
  }

  /// Registers this device's FCM token against the signed-in member.
  static Future<Map<String, dynamic>> registerDeviceToken({
    required String token,
    String platform = 'android',
    String app = 'member',
  }) {
    return _postJson(ApiRoutes.deviceTokens, {
      'token': token,
      'platform': platform,
      'app': app,
    }, authenticated: true);
  }

  /// The member's push categories and quiet hours, as the server defines them.
  static Future<Map<String, dynamic>> getNotificationPreferences() {
    return _getJson(ApiRoutes.notificationPreferences, authenticated: true);
  }

  /// Saves one or more category switches and/or the quiet-hours switch.
  static Future<Map<String, dynamic>> updateNotificationPreferences({
    Map<String, bool>? categories,
    bool? quietHoursEnabled,
  }) {
    return _putJson(ApiRoutes.notificationPreferences, {
      if (categories != null && categories.isNotEmpty) 'categories': categories,
      if (quietHoursEnabled != null) 'quiet_hours_enabled': quietHoursEnabled,
    }, authenticated: true);
  }

  /// Drops this device's FCM token so the member stops receiving pushes here.
  static Future<Map<String, dynamic>> deleteDeviceToken({
    required String token,
  }) async {
    final response = await http.delete(
      _apiUri(ApiRoutes.deviceTokens),
      headers: _jsonHeaders(authenticated: true),
      body: jsonEncode({'token': token}),
    );

    return _decodeResponse(response);
  }

  static Future<Map<String, dynamic>> sendInterest(
    int receiverProfileId,
  ) async {
    if (authToken == null) {
      throw Exception('Auth token is missing. User not logged in.');
    }

    final url = Uri.parse(ApiRoutes.baseUrl + ApiRoutes.interests);

    final response = await http.post(
      url,
      headers: {
        'Accept': 'application/json',
        'Accept-Language': appLanguageCode(currentAppLanguage),
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
      body: jsonEncode({'receiver_profile_id': receiverProfileId}),
    );

    final data = _decodeResponse(response);

    if (data['statusCode'] == 200 || data['statusCode'] == 409) {
      sentInterestProfileIds.add(receiverProfileId);
    }

    return data;
  }

  static Future<Map<String, dynamic>> reportProfile({
    required int profileId,
    required String reason,
  }) async {
    if (authToken == null) {
      throw Exception('Auth token is missing. User not logged in.');
    }

    final url = Uri.parse(
      '${ApiRoutes.baseUrl}${ApiRoutes.abuseReports}/$profileId',
    );

    final response = await http.post(
      url,
      headers: {
        'Accept': 'application/json',
        'Accept-Language': appLanguageCode(currentAppLanguage),
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
      body: jsonEncode({'reason': reason}),
    );

    return _decodeResponse(response);
  }

  static Future<Map<String, dynamic>> shortlistProfile(int profileId) {
    return _profileActionPost(ApiRoutes.profileShortlist(profileId));
  }

  static Future<Map<String, dynamic>> unshortlistProfile(int profileId) {
    return _profileActionDelete(ApiRoutes.profileShortlist(profileId));
  }

  static Future<Map<String, dynamic>> revealProfileContact(
    int profileId, {
    int? representationId,
  }) {
    if (representationId == null) {
      return _profileActionPost(ApiRoutes.profileContactReveal(profileId));
    }

    return _postJson(
      ApiRoutes.profileContactReveal(profileId),
      <String, dynamic>{'representation_id': representationId},
      authenticated: true,
    );
  }

  static Future<Map<String, dynamic>> sendContactRequest({
    required int profileId,
    required String reason,
    required List<String> requestedScopes,
    String? otherReasonText,
  }) {
    return _postJson(
      ApiRoutes.profileContactRequests(profileId),
      <String, dynamic>{
        'reason': reason,
        'requested_scopes': requestedScopes,
        'other_reason_text': otherReasonText,
      },
      authenticated: true,
    );
  }

  static Future<Map<String, dynamic>> getContactInbox() {
    return _getJson(ApiRoutes.contactInbox, authenticated: true);
  }

  static Future<Map<String, dynamic>> sendSuchakRequest({
    required int profileId,
    int? representationId,
    String? requestReason,
    String? message,
  }) {
    return _postJson(
      ApiRoutes.profileSuchakRequests(profileId),
      <String, dynamic>{
        'representation_id': representationId,
        'request_reason': requestReason,
        'message': message,
      },
      authenticated: true,
    );
  }

  /// Both halves for this member: requests they sent, and — when a Suchak
  /// represents them — requests waiting on their own answer.
  static Future<Map<String, dynamic>> getSuchakRequests() {
    return _getJson(ApiRoutes.suchakRequests, authenticated: true);
  }

  /// The candidate answering for themselves. The Suchak may answer the same
  /// request, so a 200 can still come back as `already_answered` — that is the
  /// race being settled server-side, not a failure.
  static Future<Map<String, dynamic>> decideSuchakRequest({
    required int requestId,
    required String decision,
    String? note,
  }) {
    return _postJson(
      ApiRoutes.suchakRequestDecision(requestId),
      <String, dynamic>{'decision': decision, 'note': note},
      authenticated: true,
    );
  }

  static Future<Map<String, dynamic>> approveContactRequest({
    required int requestId,
    required List<String> grantedScopes,
    required String durationKey,
  }) {
    return _postJson(
      ApiRoutes.contactRequestApprove(requestId),
      <String, dynamic>{
        'granted_scopes': grantedScopes,
        'duration_key': durationKey,
      },
      authenticated: true,
    );
  }

  static Future<Map<String, dynamic>> rejectContactRequest(int requestId) {
    return _postJson(
      ApiRoutes.contactRequestReject(requestId),
      <String, dynamic>{},
      authenticated: true,
    );
  }

  static Future<Map<String, dynamic>> getCurrentPlan() {
    return _getJson(ApiRoutes.plansCurrent, authenticated: true);
  }

  static Future<Map<String, dynamic>> getPlans() {
    return _getJson(ApiRoutes.plans, authenticated: true);
  }

  static Future<Map<String, dynamic>> startPlanCheckout(
    int planId, {
    int? planTermId,
  }) {
    return _postJson(ApiRoutes.planCheckout(planId), <String, dynamic>{
      'plan_term_id': planTermId,
    }, authenticated: true);
  }

  static Future<Map<String, dynamic>> startPlanCheckoutNative(
    int planId, {
    int? planTermId,
    String? couponCode,
  }) {
    return _postJson(ApiRoutes.planCheckoutNative(planId), <String, dynamic>{
      'plan_term_id': planTermId,
      if (couponCode != null && couponCode.trim().isNotEmpty)
        'coupon_code': couponCode.trim(),
    }, authenticated: true);
  }

  static Future<Map<String, dynamic>> generatePayuHash({
    required String hashName,
    required String hashString,
    String? hashType,
    String? postSalt,
    String? txnid,
  }) {
    return _postJson(ApiRoutes.payuHash, <String, dynamic>{
      'hashName': hashName,
      'hashString': hashString,
      if (hashType != null && hashType.isNotEmpty) 'hashType': hashType,
      if (postSalt != null && postSalt.isNotEmpty) 'postSalt': postSalt,
      if (txnid != null && txnid.isNotEmpty) 'txnid': txnid,
    }, authenticated: true);
  }

  static Future<Map<String, dynamic>> verifyPayuPayment(
    Map<String, dynamic> payload,
  ) {
    return _postJson(ApiRoutes.payuVerify, payload, authenticated: true);
  }

  static Future<Map<String, dynamic>> getBiodataExportOptions({
    String? locale,
  }) {
    return _getJson(
      ApiRoutes.biodataExportOptions,
      authenticated: true,
      query: {'locale': locale ?? appLanguageCode(currentAppLanguage)},
    );
  }

  static Future<Map<String, dynamic>> exportBiodata({
    required String format,
    String? template,
    String? locale,
  }) {
    return _postJson(
      ApiRoutes.biodataExport,
      <String, dynamic>{'format': format, 'template': template},
      authenticated: true,
      query: {'locale': locale ?? appLanguageCode(currentAppLanguage)},
    );
  }

  static Future<Map<String, dynamic>> createBiodataIntakeFromText({
    required String rawText,
    bool parseNow = true,
  }) {
    return _postJson(ApiRoutes.biodataIntakes, <String, dynamic>{
      'raw_text': rawText,
      'parse_now': parseNow,
    }, authenticated: true);
  }

  static Future<Map<String, dynamic>> createBiodataIntakeFromFile({
    required File file,
    bool parseNow = true,
    String? mlKitRawText,
    List<Map<String, dynamic>>? mlKitLinesJson,
    List<Map<String, dynamic>>? mlKitBlocksJson,
  }) async {
    final url = Uri.parse(ApiRoutes.baseUrl + ApiRoutes.biodataIntakes);
    final request = http.MultipartRequest('POST', url);
    request.headers.addAll(_acceptHeaders(authenticated: true));
    request.fields['parse_now'] = parseNow ? '1' : '0';
    if (mlKitRawText != null && mlKitRawText.trim().isNotEmpty) {
      request.fields['ml_kit_raw_text'] = mlKitRawText.trim();
    }
    if (mlKitLinesJson != null && mlKitLinesJson.isNotEmpty) {
      request.fields['ml_kit_lines_json'] = jsonEncode(mlKitLinesJson);
    }
    if (mlKitBlocksJson != null && mlKitBlocksJson.isNotEmpty) {
      request.fields['ml_kit_blocks_json'] = jsonEncode(mlKitBlocksJson);
    }
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    return _decodeResponse(response);
  }

  static Future<Map<String, dynamic>> getBiodataIntakes() {
    return _getJson(ApiRoutes.biodataIntakes, authenticated: true);
  }

  static Future<Map<String, dynamic>> getBiodataIntakePreview(int intakeId) {
    return _getJson(
      ApiRoutes.biodataIntakePreview(intakeId),
      authenticated: true,
    );
  }

  static Future<Map<String, dynamic>> approveBiodataIntake({
    required int intakeId,
    required Map<String, dynamic> snapshot,
  }) async {
    final response = await _postJson(
      ApiRoutes.biodataIntakeApprove(intakeId),
      <String, dynamic>{'snapshot': snapshot},
      authenticated: true,
    );
    if (_isSuccessfulResponse(response)) {
      _invalidateProfileCache();
    }
    return response;
  }

  static Future<Map<String, dynamic>> reviewBiodataIntakeSnapshot({
    required int intakeId,
    required Map<String, dynamic> reviewedSnapshot,
  }) {
    return _patchJson(
      ApiRoutes.biodataIntakeReviewSnapshot(intakeId),
      <String, dynamic>{'reviewed_snapshot': reviewedSnapshot},
      authenticated: true,
    );
  }

  static Future<Map<String, dynamic>> getNotifications() {
    return _getJson(ApiRoutes.notifications, authenticated: true);
  }

  static Future<Map<String, dynamic>> getNotificationUnreadCount() {
    return _getJson(ApiRoutes.notificationUnreadCount, authenticated: true);
  }

  static Future<Map<String, dynamic>> markNotificationRead(String id) {
    return _postJson(
      ApiRoutes.notificationRead(id),
      <String, dynamic>{},
      authenticated: true,
    );
  }

  static Future<Map<String, dynamic>> markAllNotificationsRead() {
    return _postJson(
      ApiRoutes.notificationsReadAll,
      <String, dynamic>{},
      authenticated: true,
    );
  }

  static Future<Map<String, dynamic>> getChats({String? tab}) {
    return _getJson(
      ApiRoutes.chats,
      authenticated: true,
      query: <String, dynamic>{'tab': tab},
    );
  }

  static Future<Map<String, dynamic>> getChatUnreadCount() {
    return _getJson(ApiRoutes.chatUnreadCount, authenticated: true);
  }

  static Future<Map<String, dynamic>> startProfileChat(int profileId) {
    return _postJson(
      ApiRoutes.profileChatStart(profileId),
      <String, dynamic>{},
      authenticated: true,
    );
  }

  static Future<Map<String, dynamic>> getChatThread(
    int conversationId, {
    int? sinceId,
  }) {
    return _getJson(
      ApiRoutes.chatThread(conversationId),
      authenticated: true,
      query: <String, dynamic>{'since_id': sinceId},
    );
  }

  static Future<Map<String, dynamic>> sendChatText({
    required int conversationId,
    required String bodyText,
  }) {
    return _postJson(ApiRoutes.chatMessages(conversationId), <String, dynamic>{
      'body_text': bodyText,
    }, authenticated: true);
  }

  static Future<Map<String, dynamic>> markChatRead(int conversationId) {
    return _postJson(
      ApiRoutes.chatRead(conversationId),
      <String, dynamic>{},
      authenticated: true,
    );
  }

  static Future<Map<String, dynamic>> getSettings() {
    return _getJson(ApiRoutes.settings, authenticated: true);
  }

  static Future<Map<String, dynamic>> updatePrivacySettings(
    Map<String, dynamic> values,
  ) {
    return _putJson(ApiRoutes.settingsPrivacy, values, authenticated: true);
  }

  static Future<Map<String, dynamic>> updateNotificationSettings(
    Map<String, dynamic> values,
  ) {
    return _putJson(
      ApiRoutes.settingsNotifications,
      values,
      authenticated: true,
    );
  }

  static Future<Map<String, dynamic>> updateCommunicationSettings(
    Map<String, dynamic> values,
  ) {
    return _putJson(
      ApiRoutes.settingsCommunication,
      values,
      authenticated: true,
    );
  }

  static Future<Map<String, dynamic>> getShortlistedProfiles() {
    return _getJson(ApiRoutes.shortlistedProfiles, authenticated: true);
  }

  static Future<Map<String, dynamic>> getBlockedProfiles() {
    return _getJson(ApiRoutes.blockedProfiles, authenticated: true);
  }

  static Future<Map<String, dynamic>> getHiddenProfiles() {
    return _getJson(ApiRoutes.hiddenProfiles, authenticated: true);
  }

  static Future<Map<String, dynamic>> removeShortlist(int profileId) {
    return unshortlistProfile(profileId);
  }

  static Future<Map<String, dynamic>> hideProfile(int profileId) {
    return _profileActionPost(ApiRoutes.profileHide(profileId));
  }

  static Future<Map<String, dynamic>> unhideProfile(int profileId) {
    return _profileActionDelete(ApiRoutes.profileUnhide(profileId));
  }

  static Future<Map<String, dynamic>> blockProfile(int profileId) {
    return _profileActionPost(ApiRoutes.profileBlock(profileId));
  }

  static Future<Map<String, dynamic>> unblockProfile(int profileId) {
    return _profileActionDelete(ApiRoutes.profileBlock(profileId));
  }

  static Future<Map<String, dynamic>> _profileActionPost(String route) async {
    if (authToken == null) {
      throw Exception('Auth token is missing. User not logged in.');
    }

    final url = Uri.parse(ApiRoutes.baseUrl + route);

    final response = await http.post(
      url,
      headers: {
        'Accept': 'application/json',
        'Accept-Language': appLanguageCode(currentAppLanguage),
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
    );

    return _decodeResponse(response);
  }

  static Future<Map<String, dynamic>> _profileActionDelete(String route) async {
    if (authToken == null) {
      throw Exception('Auth token is missing. User not logged in.');
    }

    final url = Uri.parse(ApiRoutes.baseUrl + route);

    final response = await http.delete(
      url,
      headers: {
        'Accept': 'application/json',
        'Accept-Language': appLanguageCode(currentAppLanguage),
        'Authorization': 'Bearer $authToken',
      },
    );

    return _decodeResponse(response);
  }

  static Future<Map<String, dynamic>> getSentInterests() async {
    if (authToken == null) {
      throw Exception('Auth token is missing. User not logged in.');
    }

    final url = Uri.parse(ApiRoutes.baseUrl + ApiRoutes.interestsSent);

    final response = await http.get(
      url,
      headers: {
        'Accept': 'application/json',
        'Accept-Language': appLanguageCode(currentAppLanguage),
        'Authorization': 'Bearer $authToken',
      },
    );

    final data = _decodeResponse(response);

    if (response.statusCode == 200 &&
        data['success'] == true &&
        data['data'] != null) {
      final responseData = data['data'] as Map<String, dynamic>;
      final sentList = responseData['sent'] as List?;
      if (sentList != null) {
        sentInterestProfileIds.clear();
        for (final interest in sentList) {
          final interestMap = interest as Map<String, dynamic>;
          final receiverProfile =
              interestMap['receiver_profile'] as Map<String, dynamic>?;
          final receiverProfileId = receiverProfile?['id'] as int?;
          if (receiverProfileId != null) {
            sentInterestProfileIds.add(receiverProfileId);
          }
        }
      }
    }

    return data;
  }

  static Future<Map<String, dynamic>> getReceivedInterests() async {
    if (authToken == null) {
      throw Exception('Auth token is missing. User not logged in.');
    }

    final url = Uri.parse(ApiRoutes.baseUrl + ApiRoutes.interestsReceived);

    final response = await http.get(
      url,
      headers: {
        'Accept': 'application/json',
        'Accept-Language': appLanguageCode(currentAppLanguage),
        'Authorization': 'Bearer $authToken',
      },
    );

    return _decodeResponse(response);
  }

  static Future<Map<String, dynamic>> acceptInterest(int interestId) async {
    if (authToken == null) {
      throw Exception('Auth token is missing. User not logged in.');
    }

    final url = Uri.parse(
      '${ApiRoutes.baseUrl}${ApiRoutes.interests}/$interestId/accept',
    );

    final response = await http.post(
      url,
      headers: {
        'Accept': 'application/json',
        'Accept-Language': appLanguageCode(currentAppLanguage),
        'Authorization': 'Bearer $authToken',
      },
    );

    return _decodeResponse(response);
  }

  static Future<Map<String, dynamic>> rejectInterest(int interestId) async {
    if (authToken == null) {
      throw Exception('Auth token is missing. User not logged in.');
    }

    final url = Uri.parse(
      '${ApiRoutes.baseUrl}${ApiRoutes.interests}/$interestId/reject',
    );

    final response = await http.post(
      url,
      headers: {
        'Accept': 'application/json',
        'Accept-Language': appLanguageCode(currentAppLanguage),
        'Authorization': 'Bearer $authToken',
      },
    );

    return _decodeResponse(response);
  }

  static Future<Map<String, dynamic>> withdrawInterest(int interestId) async {
    if (authToken == null) {
      throw Exception('Auth token is missing. User not logged in.');
    }

    final url = Uri.parse(
      '${ApiRoutes.baseUrl}${ApiRoutes.interests}/$interestId/withdraw',
    );

    final response = await http.post(
      url,
      headers: {
        'Accept': 'application/json',
        'Accept-Language': appLanguageCode(currentAppLanguage),
        'Authorization': 'Bearer $authToken',
      },
    );

    return _decodeResponse(response);
  }
}
