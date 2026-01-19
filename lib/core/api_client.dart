import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'api_routes.dart';

class ApiClient {
  static String? authToken;
  static Map<String, dynamic>? currentUserProfile;
  static Set<int> sentInterestProfileIds = {};
// 👤 GET LOGGED-IN USER PROFILE
  static Future<Map<String, dynamic>> getMyProfile() async {
    if (authToken == null) {
      throw Exception('Auth token missing');
    }

    final url = Uri.parse(
      ApiRoutes.baseUrl + ApiRoutes.matrimonyProfile,
    );

    final response = await http.get(
      url,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
    );

    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      data = <String, dynamic>{};
    }
    data['statusCode'] = response.statusCode;

    if (response.statusCode == 200 && data['success'] == true) {
      currentUserProfile = data['profile'];
    }

    return data;
  }

  // 🔐 LOGIN
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
    print("LOGIN STATUS CODE => ${response.statusCode}");
    print("LOGIN RAW BODY => ${response.body}");

    final data = jsonDecode(response.body);
    authToken = data['token'];
    return data;

  }

  // 📝 REGISTER
  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    required String gender,
  })
  async {
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

    final data = jsonDecode(response.body);
    authToken = data['token'];
    return data;

  }
// 🧾 CREATE MATRIMONY PROFILE (AUTH REQUIRED)
  static Future<Map<String, dynamic>> createMatrimonyProfile(
      Map<String, dynamic> body,
      ) async {

    if (authToken == null) {
      throw Exception('Auth token is missing. User not logged in.');
    }

    final url = Uri.parse(
      ApiRoutes.baseUrl + ApiRoutes.matrimonyProfile,
    );

    final response = await http.post(
      url,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
      body: jsonEncode(body),
    );

    final data = jsonDecode(response.body);

    if (data['success'] == true) {
      currentUserProfile = data['profile'];
    }

    return data;

  }

// ✏️ UPDATE MATRIMONY PROFILE (AUTH REQUIRED)
  static Future<Map<String, dynamic>> updateMatrimonyProfile(
      Map<String, dynamic> body,
      ) async {
    if (authToken == null) {
      throw Exception('Auth token is missing. User not logged in.');
    }

    final url = Uri.parse(
      ApiRoutes.baseUrl + ApiRoutes.matrimonyProfile,
    );

    final response = await http.put(
      url,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
      body: jsonEncode(body),
    );

    final data = jsonDecode(response.body);

    if (data['success'] == true) {
      currentUserProfile = data['profile'];
    }

    return data;
  }

  // 📷 UPLOAD PROFILE PHOTO (AUTH REQUIRED)
  static Future<Map<String, dynamic>> uploadProfilePhoto(File imageFile) async {
    if (authToken == null) {
      throw Exception('Auth token is missing. User not logged in.');
    }

    final url = Uri.parse(
      ApiRoutes.baseUrl + ApiRoutes.matrimonyProfilePhoto,
    );

    // Debug print - Upload start
    print('=== UPLOAD PHOTO DEBUG ===');
    print('URL: $url');
    print('Token exists: ${authToken != null}');
    print('Token preview: ${authToken?.substring(0, 20)}...');
    print('File Path: ${imageFile.path}');
    print('File exists: ${await imageFile.exists()}');
    print('Current Profile: ${currentUserProfile != null ? "Exists" : "Null"}');
    if (currentUserProfile != null) {
      print('Profile ID: ${currentUserProfile!['id'] ?? "N/A"}');
    }
    print('========================');

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

    // Debug print - Response received
    print('=== UPLOAD PHOTO RESPONSE ===');
    print('Status Code: ${response.statusCode}');
    print('Response Body: ${response.body}');
    print('Response Headers: ${response.headers}');
    print('============================');

    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      data = <String, dynamic>{};
    }
    data['statusCode'] = response.statusCode;

    if (response.statusCode == 200 && data['success'] == true) {
      final uploadData = data['data'] as Map<String, dynamic>?;
      if (uploadData != null) {
        currentUserProfile ??= <String, dynamic>{};
        currentUserProfile!['profile_photo'] = uploadData['profile_photo'];
        if (uploadData['url'] != null) {
          currentUserProfile!['profile_photo_url'] = uploadData['url'];
        }
      }
    }

    return data;
  }

  // 📋 GET PROFILE LIST (AUTH REQUIRED)
  // Optional search filters: age_from, age_to, caste, location
  static Future<Map<String, dynamic>> getProfileList({
    int? ageFrom,
    int? ageTo,
    String? caste,
    String? location,
  }) async {
    if (authToken == null) {
      throw Exception('Auth token is missing. User not logged in.');
    }

    // Build query parameters dynamically (only include non-null values)
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

    // Build URL with query parameters
    final baseUrl = ApiRoutes.baseUrl + ApiRoutes.matrimonyProfiles;
    final url = queryParams.isEmpty
        ? Uri.parse(baseUrl)
        : Uri.parse(baseUrl).replace(queryParameters: queryParams);

    // >>>>> DEBUG: REQUEST INFO <<<<<
    print('=== GET PROFILE LIST - REQUEST ===');
    print('Full URL: $url');
    print('Base URL: ${ApiRoutes.baseUrl}');
    print('Endpoint: ${ApiRoutes.matrimonyProfiles}');
    print('Query Parameters: $queryParams');
    print('Token exists: ${authToken != null}');
    print('Token preview: ${authToken?.substring(0, authToken!.length > 20 ? 20 : authToken!.length)}...');
    print('==================================');

    final response = await http.get(
      url,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
    );

    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      data = <String, dynamic>{};
    }
    data['statusCode'] = response.statusCode;

    // >>>>> DEBUG: RESPONSE INFO <<<<<
    print('=== GET PROFILE LIST - RESPONSE ===');
    print('HTTP Status Code: ${response.statusCode}');
    print('Response Body Length: ${response.body.length}');
    print('Raw Response Body: ${response.body}');
    print('Parsed Data Keys: ${data.keys.toList()}');
    print('Has "success" key: ${data.containsKey('success')}');
    print('success value: ${data['success']}');
    print('success type: ${data['success']?.runtimeType}');
    print('Has "profiles" key: ${data.containsKey('profiles')}');
    print('profiles value: ${data['profiles']}');
    print('profiles type: ${data['profiles']?.runtimeType}');
    if (data['profiles'] is List) {
      print('profiles is List: YES');
      print('profiles length: ${(data['profiles'] as List).length}');
    } else {
      print('profiles is List: NO');
    }
    print('Has "data" key: ${data.containsKey('data')}');
    print('data value: ${data['data']}');
    print('Has "message" key: ${data.containsKey('message')}');
    print('message value: ${data['message']}');
    print('Return statusCode: ${data['statusCode']}');
    print('===================================');

    return data;
  }

  // 👤 GET PROFILE DETAIL BY ID (AUTH REQUIRED)
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

    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      data = <String, dynamic>{};
    }
    data['statusCode'] = response.statusCode;

    return data;
  }

  // 🚪 LOGOUT - Clear in-memory auth state
  static void logout() {
    authToken = null;
    currentUserProfile = null;
    sentInterestProfileIds.clear();
  }

  // 💌 SEND INTEREST (AUTH REQUIRED)
  static Future<Map<String, dynamic>> sendInterest(int receiverProfileId) async {
    if (authToken == null) {
      throw Exception('Auth token is missing. User not logged in.');
    }

    final url = Uri.parse(
      ApiRoutes.baseUrl + ApiRoutes.interests,
    );

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

    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      data = <String, dynamic>{};
    }
    data['statusCode'] = response.statusCode;

    // Track profileId if interest was sent successfully or already exists
    if (data['statusCode'] == 200 || data['statusCode'] == 409) {
      sentInterestProfileIds.add(receiverProfileId);
    }

    return data;
  }

  // 📤 GET SENT INTERESTS (AUTH REQUIRED)
  static Future<Map<String, dynamic>> getSentInterests() async {
    if (authToken == null) {
      throw Exception('Auth token is missing. User not logged in.');
    }

    final url = Uri.parse(
      ApiRoutes.baseUrl + ApiRoutes.interestsSent,
    );

    final response = await http.get(
      url,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
    );

    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      data = <String, dynamic>{};
    }
    data['statusCode'] = response.statusCode;

    // Populate sentInterestProfileIds from the response
    if (response.statusCode == 200 && data['success'] == true && data['data'] != null) {
      final responseData = data['data'] as Map<String, dynamic>;
      final sentList = responseData['sent'] as List?;
      if (sentList != null) {
        sentInterestProfileIds.clear();
        for (final interest in sentList) {
          final interestMap = interest as Map<String, dynamic>;
          final receiverProfile = interestMap['receiver_profile'] as Map<String, dynamic>?;
          if (receiverProfile != null) {
            final receiverProfileId = receiverProfile['id'] as int?;
            if (receiverProfileId != null) {
              sentInterestProfileIds.add(receiverProfileId);
            }
          }
        }
      }
    }

    return data;
  }

  // 📥 GET RECEIVED INTERESTS (AUTH REQUIRED)
  static Future<Map<String, dynamic>> getReceivedInterests() async {
    if (authToken == null) {
      throw Exception('Auth token is missing. User not logged in.');
    }

    final url = Uri.parse(
      ApiRoutes.baseUrl + ApiRoutes.interestsReceived,
    );

    final response = await http.get(
      url,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
    );

    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      data = <String, dynamic>{};
    }
    data['statusCode'] = response.statusCode;

    return data;
  }

  // ✅ ACCEPT INTEREST (AUTH REQUIRED)
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

    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      data = <String, dynamic>{};
    }
    data['statusCode'] = response.statusCode;

    return data;
  }

  // ❌ REJECT INTEREST (AUTH REQUIRED)
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

    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      data = <String, dynamic>{};
    }
    data['statusCode'] = response.statusCode;

    return data;
  }

  // 🔙 WITHDRAW INTEREST (AUTH REQUIRED)
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

    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      data = <String, dynamic>{};
    }
    data['statusCode'] = response.statusCode;

    return data;
  }

}
