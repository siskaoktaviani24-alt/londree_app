import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  int? _userId;
  String _name = "";

  bool get isLoading => _isLoading;
  int? get userId => _userId;

  String get name {
    if (_name.trim().isEmpty) {
      return "Pengguna";
    }

    return _name;
  }

  bool get isLoggedIn {
    return _userId != null && _userId! > 0;
  }

  Future<void> loadSession() async {
    _isLoading = true;
    notifyListeners();

    try {
      final id = await _authService.getUserId();
      final savedName = await _authService.getName();

      _userId = id > 0 ? id : null;
      _name = savedName;
    } catch (e) {
      debugPrint("Gagal memuat session: $e");

      _userId = null;
      _name = "";
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<int> getCurrentUserId() async {
    if (_userId != null && _userId! > 0) {
      return _userId!;
    }

    final id = await _authService.getUserId();

    _userId = id > 0 ? id : null;
    notifyListeners();

    return id;
  }

  Future<void> refreshUser() async {
    await loadSession();
  }

  Future<void> logout() async {
    await _authService.logout();

    _userId = null;
    _name = "";

    notifyListeners();
  }
}