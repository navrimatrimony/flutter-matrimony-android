import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'api_routes.dart';

class ApiClient {
  static String? authToken;
  static Map<String, dynamic>? currentUserProfile;
  static Set<int> sentInterestProfileIds = {};

  static const String _profilePhotoBaseUrl =
      'https://freelovemarriage.com/storage/matrimony_photos';

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

  static int? locationIdFrom(Map<String, dynamic> location) {
    for (final key in ['location_id', 'id', 'city_id']) {
      final id = _intValue(location[key]);
      if (id != null) return id;
    }
    return null;
  }

  static String locationSuggestionLabel(Map<String, dynamic> location) {
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
    return _firstNonEmptyValue(profile, ['highest_education', 'education']);
  }

  static String? profileLocationLabel(Map<String, dynamic>? profile) {
    final label = _firstNonEmptyValue(profile, [
      'location_label',
      'display_label',
      'name',
    ]);
    if (label != null) return label;

    final id = _intValue(profile?['location_id']);
    return id != null ? 'Location ID: $id' : null;
  }

  static String? resolveProfilePhotoUrl(Map<String, dynamic>? profile) {
    if (profile == null) return null;

    for (final key in ['profile_photo_url', 'url', 'photo_url']) {
      final value = profile[key]?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }

    final rawFilename = profile['profile_photo'];
    if (rawFilename == null) return null;

    var filename = rawFilename.toString().trim();
    if (filename.isEmpty) return null;

    filename = filename.replaceAll('\\', '/').replaceFirst(RegExp(r'^/+'), '');
    if (filename.startsWith('http://') || filename.startsWith('https://')) {
      return filename;
    }

    for (final prefix in [
      'storage/matrimony_photos/',
      'uploads/matrimony_photos/',
      'matrimony_photos/',
    ]) {
      if (filename.startsWith(prefix)) {
        filename = filename.substring(prefix.length);
      }
    }

    if (filename.isEmpty) return null;
    if (filename.startsWith('pending/')) return null;

    return Uri.encodeFull('$_profilePhotoBaseUrl/$filename');
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
      headers: {
        'Accept': 'application/json',
      },
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
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    final data = _decodeResponse(response);

    if (response.statusCode != 200) {
      data['message'] ??= 'Login failed: HTTP ${response.statusCode}';
      return data;
    }

    final token = data['token']?.toString();
    if (token != null && token.isNotEmpty) {
      authToken = token;
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
    required String gender,
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
        'gender': gender,
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
      await http.MultipartFile.fromPath(
        'profile_photo',
        imageFile.path,
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    final data = _decodeResponse(response);

    if (response.statusCode == 200 && data['success'] == true) {
      final uploadData = data['data'];
      if (uploadData is Map) {
        currentUserProfile ??= <String, dynamic>{};
        currentUserProfile!['profile_photo'] = uploadData['profile_photo'];
        final photoUrl = resolveProfilePhotoUrl(currentUserProfile);
        if (photoUrl != null) {
          currentUserProfile!['profile_photo_url'] = photoUrl;
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

  static void logout() {
    authToken = null;
    currentUserProfile = null;
    sentInterestProfileIds.clear();
  }

  static Future<Map<String, dynamic>> sendInterest(int receiverProfileId) async {
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
      body: jsonEncode({
        'receiver_profile_id': receiverProfileId,
      }),
    );

    final data = _decodeResponse(response);

    if (data['statusCode'] == 200 || data['statusCode'] == 409) {
      sentInterestProfileIds.add(receiverProfileId);
    }

    return data;
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
