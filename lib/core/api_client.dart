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

  static String? resolveProfilePhotoUrl(Map<String, dynamic>? profile) {
    if (profile == null) return null;

    for (final key in ['profile_photo_url', 'url', 'photo_url']) {
      final value = profile[key]?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }

    var filename = profile['profile_photo']?.toString().trim();
    if (filename == null || filename.isEmpty) return null;

    filename = filename.replaceAll('\\', '/').replaceFirst(RegExp(r'^/+'), '');
    if (filename.startsWith('http://') || filename.startsWith('https://')) {
      return filename;
    }
    if (filename.startsWith('pending/')) {
      return null;
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

    return Uri.encodeFull('$_profilePhotoBaseUrl/$filename');
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
    String? location,
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
    if (location != null && location.isNotEmpty) {
      queryParams['location'] = location;
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
