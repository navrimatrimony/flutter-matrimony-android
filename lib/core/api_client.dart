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

  static const String _siteBaseUrl = 'https://navrimilenavryala.com';
  static const String _profilePhotoStoragePath = 'storage/matrimony_photos';

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
    for (final key in ['location_id', 'id', 'city_id']) {
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
  }) {
    if (profile == null) return null;

    for (final key in [
      'location',
      'location_label',
      'display_label',
      'current_location',
      'city',
      'city_name',
      'residence_location',
      'address_line',
    ]) {
      final label = safeDisplayLabel(profile[key]);
      if (label != null) return label;
    }

    final id = _intValue(profile['location_id']);
    return allowIdFallback && id != null ? 'Location ID: $id' : null;
  }

  static String? resolveProfilePhotoUrl(Map<String, dynamic>? profile) {
    if (profile == null) return null;

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
    String query,
  ) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return <Map<String, dynamic>>[];

    final url = Uri.parse(
      ApiRoutes.rootApiBaseUrl + ApiRoutes.locationSearch,
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
  }) async {
    if (authToken == null) {
      throw Exception('Auth token missing');
    }

    final trimmedQuery = query.trim();
    if (trimmedQuery.length < 2) return <Map<String, dynamic>>[];

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
      currentUserProfile = data['profile'] as Map<String, dynamic>?;
    }

    return data;
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final url = Uri.parse(ApiRoutes.baseUrl + ApiRoutes.login);

    final response = await http.post(
      url,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'email': email, 'password': password}),
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

  static Future<Map<String, dynamic>> hideProfile(int profileId) {
    return _profileActionPost(ApiRoutes.profileHide(profileId));
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
