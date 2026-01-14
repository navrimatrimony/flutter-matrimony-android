import 'dart:convert';
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

    final data = jsonDecode(response.body);

    if (data['success'] == true) {
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


}
