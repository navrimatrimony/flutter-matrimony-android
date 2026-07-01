import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'app_language.dart';
import 'app_storage.dart';
import 'api_routes.dart';

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
  static const Duration _locationSearchCacheTtl = Duration(minutes: 2);

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
      'Content-Type': 'application/json',
    };

    if (authenticated) {
      headers['Authorization'] = 'Bearer ${_requireAuthToken()}';
    }

    return headers;
  }

  static Map<String, String> _acceptHeaders({bool authenticated = false}) {
    final headers = <String, String>{'Accept': 'application/json'};

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
    final response = await http.get(
      _apiUri(route, query: query),
      headers: _acceptHeaders(authenticated: authenticated),
    );

    return _decodeResponse(response);
  }

  static Future<Map<String, dynamic>> _getRootJson(
    String route, {
    Map<String, dynamic>? query,
  }) async {
    final response = await http.get(
      _rootApiUri(route, query: query),
      headers: _acceptHeaders(),
    );

    return _decodeResponse(response);
  }

  static Future<Map<String, dynamic>> _postJson(
    String route,
    Map<String, dynamic> body, {
    bool authenticated = false,
    Map<String, dynamic>? query,
  }) async {
    final response = await http.post(
      _apiUri(route, query: query),
      headers: _jsonHeaders(authenticated: authenticated),
      body: jsonEncode(_compactBody(body)),
    );

    return _decodeResponse(response);
  }

  static Future<Map<String, dynamic>> _putJson(
    String route,
    Map<String, dynamic> body, {
    bool authenticated = false,
    Map<String, dynamic>? query,
  }) async {
    final response = await http.put(
      _apiUri(route, query: query),
      headers: _jsonHeaders(authenticated: authenticated),
      body: jsonEncode(_compactBody(body)),
    );

    return _decodeResponse(response);
  }

  static Future<Map<String, dynamic>> _patchJson(
    String route,
    Map<String, dynamic> body, {
    bool authenticated = false,
    Map<String, dynamic>? query,
  }) async {
    final response = await http.patch(
      _apiUri(route, query: query),
      headers: _jsonHeaders(authenticated: authenticated),
      body: jsonEncode(_compactBody(body)),
    );

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
      headers: {'Accept': 'application/json'},
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

  static Future<List<Map<String, dynamic>>> getReligions() async {
    if (authToken == null) {
      throw Exception('Auth token missing');
    }

    final url = Uri.parse(ApiRoutes.baseUrl + ApiRoutes.religions);

    final response = await http.get(
      url,
      headers: {
        'Accept': 'application/json',
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

  static Future<List<Map<String, dynamic>>> getGenders() async {
    final url = Uri.parse(ApiRoutes.baseUrl + ApiRoutes.genders);
    final headers = <String, String>{'Accept': 'application/json'};
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
  }

  static Future<Map<String, List<Map<String, dynamic>>>>
  getProfileBasicPhysicalOptions() async {
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
  }

  static Future<Map<String, List<Map<String, dynamic>>>>
  getProfileEducationCareerOptions() async {
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
  }

  static Future<Map<String, List<Map<String, dynamic>>>>
  getProfileMaritalLifestyleOptions() async {
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
  }

  static Future<Map<String, dynamic>>
  getProfileRemainingProfileOptions() async {
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
  }

  static Future<Map<String, List<Map<String, dynamic>>>>
  getProfilePartnerPreferenceOptions() async {
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
  }

  static Future<List<Map<String, dynamic>>> getCastes({
    required int religionId,
  }) async {
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
      headers: {'Accept': 'application/json'},
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
    final data = await _postJson(ApiRoutes.mobileOtpVerify, {
      'challenge_id': challengeId,
      'mobile': mobile,
      'otp': otp,
    });

    final token =
        data['token']?.toString() ??
        ((data['data'] is Map) ? data['data']['token']?.toString() : null);
    if (data['statusCode'] == 200 && token != null && token.isNotEmpty) {
      authToken = token;
      await AppStorage.instance.saveAuthToken(token);
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
  }) {
    return _postJson(ApiRoutes.onboardingProfileSaveStep, {
      'step': step,
      'data': data,
    }, authenticated: true);
  }

  static Future<Map<String, dynamic>> getActivationChecklist({String? locale}) {
    return _getJson(
      ApiRoutes.onboardingActivationChecklist,
      authenticated: true,
      query: {'locale': locale},
    );
  }

  static Future<Map<String, dynamic>> getOnboardingBootstrap({String? locale}) {
    return _getJson(
      ApiRoutes.onboardingLookupsBootstrap,
      authenticated: false,
      query: {'locale': locale},
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
    return _getJson(
      _onboardingLookupRoute(lookup),
      authenticated: true,
      query: <String, dynamic>{
        'q': query,
        'page': page,
        'limit': limit,
        'locale': locale,
        ...?filters,
      },
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
    return _getJson(
      ApiRoutes.onboardingLookupsIncomeOptions,
      authenticated: true,
      query: {'locale': locale},
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

  static Future<Map<String, dynamic>> getMyProfile() async {
    if (authToken == null) {
      throw Exception('Auth token missing');
    }

    final url = Uri.parse(ApiRoutes.baseUrl + ApiRoutes.matrimonyProfile);

    final response = await http.get(
      url,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
    );

    final data = _decodeResponse(response);

    if (response.statusCode == 200 && data['success'] == true) {
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

    return data;
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
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'login': loginValue, 'password': password}),
    );

    final data = _decodeResponse(response);

    if (response.statusCode != 200) {
      data['message'] ??= 'Login failed: HTTP ${response.statusCode}';
      return data;
    }

    final token = data['token']?.toString();
    if (token != null && token.isNotEmpty) {
      authToken = token;
      await AppStorage.instance.saveAuthToken(token);
      return data;
    }

    data['message'] ??= 'Login failed: No token received';
    return data;
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
      authToken = token;
      await AppStorage.instance.saveAuthToken(token);
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
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
      body: jsonEncode(body),
    );

    final data = _decodeResponse(response);

    if (data['success'] == true) {
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
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
      body: jsonEncode(body),
    );

    final data = _decodeResponse(response);

    if (data['success'] == true) {
      currentUserProfile = data['profile'] as Map<String, dynamic>?;
    }

    return data;
  }

  static Future<Map<String, dynamic>> uploadProfilePhoto(File imageFile) async {
    if (authToken == null) {
      throw Exception('Auth token is missing. User not logged in.');
    }

    final url = Uri.parse(ApiRoutes.baseUrl + ApiRoutes.matrimonyProfilePhoto);

    final request = http.MultipartRequest('POST', url);
    request.headers['Accept'] = 'application/json';
    request.headers['Authorization'] = 'Bearer $authToken';

    request.files.add(
      await http.MultipartFile.fromPath('profile_photo', imageFile.path),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    final data = _decodeResponse(response);

    if (response.statusCode == 200 && data['success'] == true) {
      final uploadData = data['data'];
      if (uploadData is Map) {
        final profile = currentUserProfile ??= <String, dynamic>{};
        profile['profile_photo'] = uploadData['profile_photo'];
        final photoUrl = resolveProfilePhotoUrl(profile);
        if (photoUrl != null) {
          profile['profile_photo_url'] = photoUrl;
        }
      }
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
    return data;
  }

  static Future<Map<String, dynamic>> deleteProfilePhoto(int photoId) async {
    final data = await _profileActionDelete(
      ApiRoutes.profilePhotoDelete(photoId),
    );
    _mergeProfilePhotoSummary(data);
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
    String? caste,
    int? locationId,
    String? feed,
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
    if (caste != null && caste.isNotEmpty) {
      queryParams['caste'] = caste;
    }
    if (locationId != null) {
      queryParams['location_id'] = locationId.toString();
    }
    if (feed != null && feed.isNotEmpty) {
      queryParams['feed'] = feed;
    }

    final baseUrl = ApiRoutes.baseUrl + ApiRoutes.matrimonyProfiles;
    final url = queryParams.isEmpty
        ? Uri.parse(baseUrl)
        : Uri.parse(baseUrl).replace(queryParameters: queryParams);

    final response = await http.get(
      url,
      headers: {
        'Accept': 'application/json',
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
        'Authorization': 'Bearer $authToken',
      },
    );

    return _decodeResponse(response);
  }

  static Future<void> restoreSessionFromStorage() async {
    final token = await AppStorage.instance.readAuthToken();
    authToken = token != null && token.isNotEmpty ? token : null;
    currentUserProfile = null;
    sentInterestProfileIds.clear();
  }

  static Future<void> logout() async {
    authToken = null;
    currentUserProfile = null;
    sentInterestProfileIds.clear();
    await AppStorage.instance.clearSessionButKeepLanguage();
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

  static Future<Map<String, dynamic>> revealProfileContact(int profileId) {
    return _profileActionPost(ApiRoutes.profileContactReveal(profileId));
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

  static Future<Map<String, dynamic>> getBiodataExportOptions() {
    return _getJson(ApiRoutes.biodataExportOptions, authenticated: true);
  }

  static Future<Map<String, dynamic>> exportBiodata({
    required String format,
    String? template,
  }) {
    return _postJson(ApiRoutes.biodataExport, <String, dynamic>{
      'format': format,
      'template': template,
    }, authenticated: true);
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
  }) {
    return _postJson(
      ApiRoutes.biodataIntakeApprove(intakeId),
      <String, dynamic>{'snapshot': snapshot},
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
        'Authorization': 'Bearer $authToken',
      },
    );

    return _decodeResponse(response);
  }
}
