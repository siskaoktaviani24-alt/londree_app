import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/order_model.dart';

class OrderService {
  Future<Map<String, dynamic>> createOrder({
    required int customerId,
    required int laundryId,
    required int serviceId,
    required double weight,
    required String customerPhone,
    required String pickupAddress,
    required String note,
  }) async {
    final url = Uri.parse("${ApiConfig.baseUrl}/order/create_order.php");

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "customer_id": customerId,
        "laundry_id": laundryId,
        "service_id": serviceId,
        "weight": weight,
        "customer_phone": customerPhone,
        "pickup_address": pickupAddress,
        "note": note,
      }),
    );

    return jsonDecode(response.body);
  }

  Future<List<OrderModel>> getCustomerOrders(int customerId) async {
    final url = Uri.parse(
      "${ApiConfig.baseUrl}/order/get_customer_orders.php?customer_id=$customerId",
    );

    final response = await http.get(url);
    final result = jsonDecode(response.body);

    if (result["success"] == true) {
      final List data = result["data"];
      return data.map((e) => OrderModel.fromJson(e)).toList();
    }

    throw Exception(result["message"]);
  }

  Future<List<OrderModel>> getOwnerOrders(int ownerId) async {
    final url = Uri.parse(
      "${ApiConfig.baseUrl}/order/get_owner_orders.php?owner_id=$ownerId",
    );

    final response = await http.get(url);
    final result = jsonDecode(response.body);

    if (result["success"] == true) {
      final List data = result["data"];
      return data.map((e) => OrderModel.fromJson(e)).toList();
    }

    throw Exception(result["message"]);
  }

  Future<Map<String, dynamic>> updateStatus(int orderId, String status) async {
    final url = Uri.parse("${ApiConfig.baseUrl}/order/update_status.php");

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"order_id": orderId, "status": status}),
    );

    return jsonDecode(response.body);
  }

  // ** NEW METHOD: Cancel Order (menggunakan updateStatus) **
  Future<Map<String, dynamic>> cancelOrder(int orderId) async {
    // Gunakan updateStatus dengan status "cancelled"
    return await updateStatus(orderId, "cancelled");
  }
}
