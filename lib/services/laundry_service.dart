import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/laundry_model.dart';

class LaundryService {
  Future<List<LaundryModel>> getLaundries(double lat, double lng) async {
    final url = Uri.parse(
      "${ApiConfig.baseUrl}/laundry/get_laundries.php?lat=$lat&lng=$lng",
    );

    final response = await http.get(url);
    final result = jsonDecode(response.body);

    if (result["success"] == true) {
      final List data = result["data"];
      return data.map((e) => LaundryModel.fromJson(e)).toList();
    }

    throw Exception(result["message"]);
  }

  Future<Map<String, dynamic>> getLaundryDetail(int laundryId) async {
    final url = Uri.parse(
      "${ApiConfig.baseUrl}/laundry/get_laundry_detail.php?laundry_id=$laundryId",
    );

    final response = await http.get(url);
    final result = jsonDecode(response.body);

    return result;
  }

  Future<Map<String, dynamic>> addLaundry({
    required int ownerId,
    required String name,
    required String description,
    required String address,
    required double latitude,
    required double longitude,
  }) async {
    final url = Uri.parse("${ApiConfig.baseUrl}/laundry/add_laundry.php");

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "owner_id": ownerId,
        "name": name,
        "description": description,
        "address": address,
        "latitude": latitude,
        "longitude": longitude,
        "is_open": 1,
      }),
    );

    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> addService({
    required int ownerId,
    required String serviceName,
    required double pricePerKg,
    required String estimatedTime,
  }) async {
    final url = Uri.parse("${ApiConfig.baseUrl}/service/add_service.php");

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "owner_id": ownerId,
        "service_name": serviceName,
        "price_per_kg": pricePerKg,
        "estimated_time": estimatedTime,
      }),
    );

    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> getOwnerLaundry(int ownerId) async {
    final url = Uri.parse(
      "${ApiConfig.baseUrl}/laundry/get_owner_laundry.php?owner_id=$ownerId",
    );

    final response = await http.get(url);
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> updateService({
    required int ownerId,
    required int serviceId,
    required String serviceName,
    required double pricePerKg,
    required String estimatedTime,
  }) async {
    final url = Uri.parse("${ApiConfig.baseUrl}/service/update_service.php");

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "owner_id": ownerId,
        "service_id": serviceId,
        "service_name": serviceName,
        "price_per_kg": pricePerKg,
        "estimated_time": estimatedTime,
      }),
    );

    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> deleteService({
    required int ownerId,
    required int serviceId,
  }) async {
    final url = Uri.parse("${ApiConfig.baseUrl}/service/delete_service.php");

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "owner_id": ownerId,
        "service_id": serviceId,
      }),
    );

    return jsonDecode(response.body);
  }
}