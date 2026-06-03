import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/user_model.dart';

class AuthService {
  Future<Map<String, dynamic>> login(String email, String password) async {
    final url = Uri.parse("${ApiConfig.baseUrl}/auth/login.php");

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "email": email.trim(),
        "password": password.trim(),
      }),
    );

    final result = jsonDecode(response.body);

    if (result["success"] == true) {
      final user = UserModel.fromJson(result["user"]);
      await saveUser(user);
    }

    return result;
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String role,
  }) async {
    final url = Uri.parse("${ApiConfig.baseUrl}/auth/register.php");

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "name": name.trim(),
        "email": email.trim(),
        "phone": phone.trim(),
        "password": password.trim(),
        "role": role,
      }),
    );

    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> loginWithGoogle({
    required String role,
  }) async {
    try {
      final GoogleSignInAccount googleUser =
          await GoogleSignIn.instance.authenticate();

      final GoogleSignInAuthentication googleAuth =
          googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      final firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        return {
          "success": false,
          "message": "Data akun Google tidak ditemukan",
        };
      }

      final url = Uri.parse("${ApiConfig.baseUrl}/auth/google_login.php");

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "name": firebaseUser.displayName ?? googleUser.displayName,
          "email": firebaseUser.email ?? googleUser.email,
          "google_uid": firebaseUser.uid,
          "role": role,
        }),
      );

      final result = jsonDecode(response.body);

      if (result["success"] == true) {
        final user = UserModel.fromJson(result["user"]);
        await saveUser(user);
      }

      return result;
    } on FirebaseAuthException catch (e) {
      return {
        "success": false,
        "message": e.message ?? "Login Firebase gagal",
      };
    } catch (e) {
      return {
        "success": false,
        "message": "Login Google gagal: $e",
      };
    }
  }

  Future<void> saveUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt("user_id", user.id);
    await prefs.setString("name", user.name);
    await prefs.setString("email", user.email);
    await prefs.setString("phone", user.phone);
    await prefs.setString("role", user.role);
  }

  Future<int> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt("user_id") ?? 0;
  }

  Future<String> getName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("name") ?? "";
  }

  Future<String> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("role") ?? "";
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt("user_id") != null;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();

    await FirebaseAuth.instance.signOut();
    await GoogleSignIn.instance.signOut();

    await prefs.clear();
  }
}