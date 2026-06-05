import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'notification_service.dart';

class FcmService {
  FcmService._internal();

  static final FcmService _instance = FcmService._internal();

  factory FcmService() => _instance;

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  Future<void> init() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final title = message.notification?.title ??
          message.data["title"]?.toString() ??
          "Londree";

      final body = message.notification?.body ??
          message.data["body"]?.toString() ??
          "Ada notifikasi baru";

      await NotificationService().showNotification(
        title: title,
        body: body,
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint("FCM notification dibuka: ${message.data}");
    });
  }

  Future<String?> getToken() async {
    try {
      final token = await _messaging.getToken();

      debugPrint("FCM Token: $token");

      return token;
    } catch (e) {
      debugPrint("Gagal mengambil FCM token: $e");
      return null;
    }
  }

  Future<void> saveTokenToServer(int userId) async {
    final token = await getToken();

    if (token == null || token.isEmpty) {
      debugPrint("FCM token kosong, tidak dikirim ke server");
      return;
    }

    try {
      final url = Uri.parse("${ApiConfig.baseUrl}/auth/update_fcm_token.php");

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": userId,
          "fcm_token": token,
        }),
      );

      debugPrint("Update FCM token response: ${response.body}");
    } catch (e) {
      debugPrint("Gagal menyimpan FCM token: $e");
    }
  }

  void listenTokenRefresh(int userId) {
    _messaging.onTokenRefresh.listen((newToken) async {
      try {
        final url = Uri.parse("${ApiConfig.baseUrl}/auth/update_fcm_token.php");

        final response = await http.post(
          url,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "user_id": userId,
            "fcm_token": newToken,
          }),
        );

        debugPrint("Refresh FCM token response: ${response.body}");
      } catch (e) {
        debugPrint("Gagal refresh FCM token: $e");
      }
    });
  }
}