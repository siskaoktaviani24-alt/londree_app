import 'package:flutter/material.dart';

import '../models/order_model.dart';
import '../services/order_service.dart';

class OrderProvider extends ChangeNotifier {
  final OrderService _orderService = OrderService();

  List<OrderModel> _ownerOrders = [];
  List<OrderModel> _customerOrders = [];

  bool _loadingOwnerOrders = false;
  bool _loadingCustomerOrders = false;

  String _errorMessage = "";

  final Set<int> _knownPendingOrderIds = {};
  bool _notificationReady = false;

  List<OrderModel> get ownerOrders => _ownerOrders;
  List<OrderModel> get customerOrders => _customerOrders;

  bool get loadingOwnerOrders => _loadingOwnerOrders;
  bool get loadingCustomerOrders => _loadingCustomerOrders;

  String get errorMessage => _errorMessage;

  int get unreadNotifications {
    return _ownerOrders.where((order) => order.status == "pending").length;
  }

  int get totalOwnerOrders {
    return _ownerOrders.length;
  }

  int get pendingOwnerOrders {
    return _ownerOrders.where((order) => order.status == "pending").length;
  }

  int get processOwnerOrders {
    return _ownerOrders.where((order) {
      return [
        "accepted",
        "picked_up",
        "washing",
        "ready",
      ].contains(order.status);
    }).length;
  }

  int get doneOwnerOrders {
    return _ownerOrders.where((order) => order.status == "delivered").length;
  }

  int get totalCustomerOrders {
    return _customerOrders.length;
  }

  int get activeCustomerOrders {
    return _customerOrders.where((order) {
      return [
        "pending",
        "accepted",
        "picked_up",
        "washing",
        "ready",
      ].contains(order.status);
    }).length;
  }

  int get finishedCustomerOrders {
    return _customerOrders.where((order) {
      return order.status == "delivered";
    }).length;
  }

  List<OrderModel> get pendingOrders {
    return _ownerOrders.where((order) => order.status == "pending").toList();
  }

  Future<int> loadOwnerOrders(
    int ownerId, {
    bool showLoading = true,
    bool checkNewOrders = false,
  }) async {
    if (showLoading) {
      _loadingOwnerOrders = true;
      notifyListeners();
    }

    int newOrderCount = 0;

    try {
      final data = await _orderService.getOwnerOrders(ownerId);

      data.sort((a, b) => b.id.compareTo(a.id));

      final pending = data.where((order) {
        return order.status == "pending";
      }).toList();

      final latestPendingIds = pending.map((order) => order.id).toSet();

      final newOrders = pending.where((order) {
        return !_knownPendingOrderIds.contains(order.id);
      }).toList();

      if (checkNewOrders && _notificationReady && newOrders.isNotEmpty) {
        newOrderCount = newOrders.length;
      }

      _ownerOrders = data;
      _errorMessage = "";

      _knownPendingOrderIds
        ..clear()
        ..addAll(latestPendingIds);

      _notificationReady = true;
    } catch (e) {
      _ownerOrders = [];
      _errorMessage = "Gagal memuat pesanan owner: $e";
      debugPrint(_errorMessage);
    }

    if (showLoading) {
      _loadingOwnerOrders = false;
    }

    notifyListeners();

    return newOrderCount;
  }

  Future<void> loadCustomerOrders(
    int customerId, {
    bool showLoading = true,
  }) async {
    if (showLoading) {
      _loadingCustomerOrders = true;
      notifyListeners();
    }

    try {
      final data = await _orderService.getCustomerOrders(customerId);

      data.sort((a, b) => b.id.compareTo(a.id));

      _customerOrders = data;
      _errorMessage = "";
    } catch (e) {
      _customerOrders = [];
      _errorMessage = "Gagal memuat pesanan customer: $e";
      debugPrint(_errorMessage);
    }

    if (showLoading) {
      _loadingCustomerOrders = false;
    }

    notifyListeners();
  }

  Future<Map<String, dynamic>> updateOwnerOrderStatus({
    required int ownerId,
    required int orderId,
    required String status,
  }) async {
    final result = await _orderService.updateStatus(orderId, status);

    if (result["success"] == true) {
      await loadOwnerOrders(
        ownerId,
        showLoading: false,
      );
    }

    return result;
  }

  Future<Map<String, dynamic>> cancelCustomerOrder({
    required int customerId,
    required int orderId,
  }) async {
    final result = await _orderService.cancelOrder(orderId);

    if (result["success"] == true) {
      await loadCustomerOrders(
        customerId,
        showLoading: false,
      );
    }

    return result;
  }

  void clearOrders() {
    _ownerOrders = [];
    _customerOrders = [];
    _knownPendingOrderIds.clear();
    _notificationReady = false;
    _errorMessage = "";
    notifyListeners();
  }
}