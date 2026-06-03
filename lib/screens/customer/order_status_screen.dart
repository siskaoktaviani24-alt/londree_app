import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/order_model.dart';
import '../../services/auth_service.dart';
import '../../services/order_service.dart';

class OrderStatusScreen extends StatefulWidget {
  const OrderStatusScreen({super.key});

  @override
  State<OrderStatusScreen> createState() => _OrderStatusScreenState();
}

class _OrderStatusScreenState extends State<OrderStatusScreen> {
  final orderService = OrderService();
  final auth = AuthService();

  List<OrderModel> orders = [];
  bool loading = true;
  bool _isCancelling = false; // Tambahkan ini

  final rupiah = NumberFormat.currency(
    locale: "id_ID",
    symbol: "Rp ",
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    loadOrders();
  }

  Future<void> loadOrders() async {
    setState(() => loading = true);

    try {
      final id = await auth.getUserId();
      if (id != null) {
        orders = await orderService.getCustomerOrders(id);
      }
    } catch (e) {
      print('Error loading orders: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat pesanan: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    if (mounted) setState(() => loading = false);
  }

  String statusText(String status) {
    switch (status) {
      case "pending":
        return "Menunggu Konfirmasi";
      case "accepted":
        return "Diterima";
      case "picked_up":
        return "Sudah Dijemput";
      case "washing":
        return "Sedang Dicuci";
      case "ready":
        return "Siap Diambil";
      case "delivered":
        return "Selesai";
      case "rejected":
        return "Ditolak";
      case "cancelled":
        return "Dibatalkan";
      default:
        return status;
    }
  }

  Color statusColor(String status) {
    switch (status) {
      case "pending":
        return Colors.orange;
      case "accepted":
        return Colors.blue;
      case "picked_up":
        return Colors.cyan;
      case "washing":
        return Colors.purple;
      case "ready":
        return Colors.green;
      case "delivered":
        return Colors.green.shade700;
      case "rejected":
        return Colors.red;
      case "cancelled":
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData statusIcon(String status) {
    switch (status) {
      case "pending":
        return Icons.pending_actions;
      case "accepted":
        return Icons.check_circle_outline;
      case "picked_up":
        return Icons.local_shipping;
      case "washing":
        return Icons.cleaning_services;
      case "ready":
        return Icons.done_all;
      case "delivered":
        return Icons.check_circle;
      case "rejected":
        return Icons.cancel;
      case "cancelled":
        return Icons.remove_circle;
      default:
        return Icons.info;
    }
  }

  // ** METHOD UNTUK CANCEL ORDER **
  Future<void> _cancelOrder(OrderModel order) async {
    setState(() {
      _isCancelling = true;
    });

    // Tampilkan loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.blue),
              const SizedBox(height: 16),
              Text(
                "Membatalkan pesanan...",
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
          ),
        );
      },
    );

    try {
      // Panggil API cancel order
      final result = await orderService.cancelOrder(order.id);

      // Tutup loading dialog
      if (mounted) Navigator.pop(context);

      if (!mounted) return;

      if (result['success'] == true) {
        // Refresh daftar pesanan
        await loadOrders();
        
        // Tampilkan pesan sukses
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Expanded(child: Text("Pesanan berhasil dibatalkan")),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        // Tampilkan pesan error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    result['message'] ?? 'Gagal membatalkan pesanan',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // Tutup loading dialog jika error
      if (mounted) Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    setState(() {
      _isCancelling = false;
    });
  }

  // ** DIALOG KONFIRMASI CANCEL **
  void _showCancelDialog(OrderModel order) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, 
                color: Colors.red.shade700,
                size: 28,
              ),
              const SizedBox(width: 12),
              const Text(
                "Batalkan Pesanan",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Apakah Anda yakin ingin membatalkan pesanan ini?",
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.laundryName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${order.serviceName} • ${order.weight} kg",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      rupiah.format(order.totalPrice),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Pesanan yang dibatalkan tidak dapat dikembalikan.",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red.shade400,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade600,
              ),
              child: const Text("Kembali"),
            ),
            ElevatedButton(
              onPressed: _isCancelling
                  ? null
                  : () {
                      Navigator.pop(context); // Tutup dialog
                      _cancelOrder(order); // Panggil cancel
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text("Ya, Batalkan"),
            ),
          ],
        );
      },
    );
  }

  Widget orderCard(OrderModel order) {
    final bool canCancel = order.status == "pending";
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.grey.shade100),
        ),
        child: InkWell(
          onTap: () {
            // Optional: Navigate to order detail
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Nama Laundry dan Status
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade100, Colors.blue.shade50],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.local_laundry_service, 
                        color: Colors.blue.shade700, 
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.laundryName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor(order.status).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  statusIcon(order.status),
                                  size: 12,
                                  color: statusColor(order.status),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  statusText(order.status),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: statusColor(order.status),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Menu button (optional)
                    IconButton(
                      onPressed: () {
                        // Add more options if needed
                      },
                      icon: Icon(Icons.more_vert, 
                        color: Colors.grey.shade400,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Detail Pesanan
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _infoRow(
                        Icons.cleaning_services,
                        "Layanan",
                        order.serviceName,
                      ),
                      const SizedBox(height: 12),
                      _infoRow(
                        Icons.fitness_center,
                        "Berat",
                        "${order.weight} kg",
                      ),
                      const SizedBox(height: 12),
                      _infoRow(
                        Icons.receipt,
                        "Total Harga",
                        rupiah.format(order.totalPrice),
                        isPrice: true,
                      ),
                      if (order.pickupAddress.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _infoRow(
                          Icons.location_on,
                          "Alamat Pickup",
                          order.pickupAddress,
                          isMultiline: true,
                        ),
                      ],
                      if (order.note != null && order.note!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _infoRow(
                          Icons.note_add,
                          "Catatan",
                          order.note!,
                          isMultiline: true,
                        ),
                      ],
                    ],
                  ),
                ),
                // Tombol Aksi (jika status pending)
                if (order.status == "pending") ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isCancelling ? null : () => _showCancelDialog(order),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red.shade700,
                            side: BorderSide(color: Colors.red.shade700),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: _isCancelling 
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.red,
                                  ),
                                )
                              : const Text("Batalkan"),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            // Track order or contact laundry
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text("Lacak Pesanan"),
                        ),
                      ),
                    ],
                  ),
                ],
                // Tombol untuk status selesai
                if (order.status == "delivered") ...[
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () {
                      // Show rating dialog
                    },
                    icon: const Icon(Icons.star_border),
                    label: const Text("Beri Rating"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.amber.shade700,
                      side: BorderSide(color: Colors.amber.shade700),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ],
                // Status cancelled indicator
                if (order.status == "cancelled") ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.info_outline, size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 8),
                        Text(
                          "Pesanan ini telah dibatalkan",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, {
    bool isPrice = false,
    bool isMultiline = false,
  }) {
    return Row(
      crossAxisAlignment: isMultiline 
          ? CrossAxisAlignment.start 
          : CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade500),
        const SizedBox(width: 8),
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isPrice ? FontWeight.bold : FontWeight.normal,
              color: isPrice ? Colors.green.shade700 : Colors.grey.shade800,
            ),
            maxLines: isMultiline ? null : 1,
            overflow: isMultiline ? TextOverflow.visible : TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          "Status Pesanan",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back, size: 20),
          ),
        ),
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
        color: Colors.blue,
        child: loading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.blue),
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
                        Icon(Icons.receipt_long, 
                          size: 80, 
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Belum ada pesanan",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Mulai buat pesanan laundry pertama Anda",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade400,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.add),
                          label: const Text("Buat Pesanan"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: orders.length,
                    itemBuilder: (context, index) => orderCard(orders[index]),
                  ),
      ),
    );
  }
}