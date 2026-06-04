import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/order_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';

class OrderManageScreen extends StatefulWidget {
  const OrderManageScreen({super.key});

  @override
  State<OrderManageScreen> createState() => _OrderManageScreenState();
}

class _OrderManageScreenState extends State<OrderManageScreen> {
  final rupiah = NumberFormat.currency(
    locale: "id_ID",
    symbol: "Rp ",
    decimalDigits: 0,
  );

  final statuses = [
    "pending",
    "accepted",
    "picked_up",
    "washing",
    "ready",
    "delivered",
    "rejected",
    "cancelled",
  ];

  // Status color mapping
  Color getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.blue;
      case 'picked_up':
        return Colors.purple;
      case 'washing':
        return Colors.indigo;
      case 'ready':
        return Colors.green;
      case 'delivered':
        return Colors.teal;
      case 'rejected':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Menunggu';
      case 'accepted':
        return 'Diterima';
      case 'picked_up':
        return 'Pick Up';
      case 'washing':
        return 'Dicuci';
      case 'ready':
        return 'Siap';
      case 'delivered':
        return 'Terkirim';
      case 'rejected':
        return 'Ditolak';
      case 'cancelled':
        return 'Dibatalkan';
      default:
        return status;
    }
  }

  @override
  void initState() {
    super.initState();
    loadOrders();
  }

  Future<void> loadOrders() async {
    final ownerId = await context.read<AuthProvider>().getCurrentUserId();

    await context.read<OrderProvider>().loadOwnerOrders(ownerId);
  }

  Future<void> updateStatus(OrderModel order, String status) async {
    final ownerId = await context.read<AuthProvider>().getCurrentUserId();

    final result = await context.read<OrderProvider>().updateOwnerOrderStatus(
      ownerId: ownerId,
      orderId: order.id,
      status: status,
    );

    showMsg(result["message"] ?? "Status berhasil diperbarui");
  }

  void showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget item(OrderModel order) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Colors.blue.shade50.withOpacity(0.3)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with Order ID and Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.receipt,
                          size: 16,
                          color: Colors.blue.shade800,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "#${order.id}",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: getStatusColor(order.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: getStatusColor(order.status).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.circle,
                          size: 8,
                          color: getStatusColor(order.status),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          getStatusText(order.status),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: getStatusColor(order.status),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Customer Info
              _buildInfoRow(Icons.person_outline, order.customerName),
              const SizedBox(height: 8),
              _buildInfoRow(Icons.phone_outlined, order.customerPhone),
              const SizedBox(height: 12),

              // Divider
              Divider(color: Colors.grey.shade200),
              const SizedBox(height: 8),

              // Service Details
              _buildServiceDetailRow(
                Icons.local_laundry_service,
                order.serviceName,
              ),
              const SizedBox(height: 8),
              _buildServiceDetailRow(
                Icons.fitness_center,
                "${order.weight} kg",
              ),
              const SizedBox(height: 8),
              _buildServiceDetailRow(
                Icons.payments_outlined,
                rupiah.format(order.totalPrice),
              ),
              const SizedBox(height: 8),
              _buildInfoRow(
                Icons.location_on_outlined,
                order.pickupAddress,
                maxLines: 2,
              ),

              const SizedBox(height: 16),

              // Status Update Section
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Update Status",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: order.status,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                        ),
                      ),
                      items: statuses.map((s) {
                        return DropdownMenuItem(
                          value: s,
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: getStatusColor(s),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(getStatusText(s)),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null && value != order.status) {
                          updateStatus(order, value);
                        }
                      },
                      icon: Icon(
                        Icons.arrow_drop_down,
                        color: Colors.blue.shade700,
                      ),
                      dropdownColor: Colors.white,
                      selectedItemBuilder: (context) {
                        return statuses.map((s) {
                          return Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: getStatusColor(s),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(getStatusText(s)),
                            ],
                          );
                        }).toList();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, {int maxLines = 1}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14),
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildServiceDetailRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.blue.shade600),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade800,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.watch<OrderProvider>();
    final orders = orderProvider.ownerOrders;
    final loading = orderProvider.loadingOwnerOrders;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          "Pesanan Masuk",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: loadOrders,
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh",
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: loadOrders,
        child: loading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text("Memuat pesanan..."),
                  ],
                ),
              )
            : orders.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 80,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Belum ada pesanan",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Pesanan akan muncul di sini",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: orders.length,
                itemBuilder: (context, index) => item(orders[index]),
              ),
      ),
    );
  }
}
