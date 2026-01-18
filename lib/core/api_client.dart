import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'api_routes.dart';

class ApiClient {
  static String? authToken;
  static Map<String, dynamic>? currentUserProfile;
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

  // 🚪 LOGOUT - Clear in-memory auth state
  static void logout() {
    authToken = null;
    currentUserProfile = null;
  }

}
