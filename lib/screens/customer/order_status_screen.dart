import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/order_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';

class OrderStatusScreen extends StatefulWidget {
  const OrderStatusScreen({super.key});

  @override
  State<OrderStatusScreen> createState() => _OrderStatusScreenState();
}

class _OrderStatusScreenState extends State<OrderStatusScreen> {
  bool _isCancelling = false;

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
    try {
      final customerId = await context.read<AuthProvider>().getCurrentUserId();

      await context.read<OrderProvider>().loadCustomerOrders(customerId);
    } catch (e) {
      debugPrint("Error loading orders: $e");

      if (!mounted) return;

      showMsg("Gagal memuat pesanan: $e", success: false);
    }
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
        return Icons.pending_actions_rounded;
      case "accepted":
        return Icons.check_circle_outline_rounded;
      case "picked_up":
        return Icons.local_shipping_rounded;
      case "washing":
        return Icons.local_laundry_service_rounded;
      case "ready":
        return Icons.done_all_rounded;
      case "delivered":
        return Icons.check_circle_rounded;
      case "rejected":
        return Icons.cancel_rounded;
      case "cancelled":
        return Icons.remove_circle_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  bool canCancelOrder(String status) {
    return status == "pending";
  }

  bool isFinalStatus(String status) {
    return status == "delivered" ||
        status == "rejected" ||
        status == "cancelled";
  }

  void showMsg(String msg, {required bool success}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? Colors.green.shade700 : Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _cancelOrder(OrderModel order) async {
    setState(() {
      _isCancelling = true;
    });

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
              const CircularProgressIndicator(),
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
      final customerId = await context.read<AuthProvider>().getCurrentUserId();

      final result = await context.read<OrderProvider>().cancelCustomerOrder(
        customerId: customerId,
        orderId: order.id,
      );

      if (mounted) {
        Navigator.pop(context);
      }

      if (!mounted) return;

      if (result["success"] == true) {
        if (!mounted) return;

        showMsg("Pesanan berhasil dibatalkan", success: true);
      } else {
        showMsg(
          result["message"] ?? "Gagal membatalkan pesanan",
          success: false,
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
      }

      if (!mounted) return;

      showMsg("Gagal membatalkan pesanan: $e", success: false);
    }

    if (mounted) {
      setState(() {
        _isCancelling = false;
      });
    }
  }

  void _showCancelDialog(OrderModel order) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.red.shade700,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "Batalkan Pesanan",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Apakah Anda yakin ingin membatalkan pesanan ini?",
                style: TextStyle(
                  fontSize: 13.5,
                  color: Colors.grey.shade700,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
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
                    const SizedBox(height: 5),
                    Text(
                      "${order.serviceName} • ${order.weight} kg",
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      rupiah.format(order.totalPrice),
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Pesanan yang sudah dibatalkan tidak dapat dikembalikan.",
                style: TextStyle(fontSize: 12, color: Colors.red.shade400),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Kembali"),
            ),
            ElevatedButton(
              onPressed: _isCancelling
                  ? null
                  : () {
                      Navigator.pop(context);
                      _cancelOrder(order);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text("Ya, Batalkan"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 100,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.shade700,
            Colors.blue.shade600,
            Colors.blue.shade400,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -40,
            top: -35,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: 65,
            bottom: -60,
            child: Container(
              width: 145,
              height: 145,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Row(
              children: [
                _headerIconButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.pop(context),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Status Pesanan",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        "Pantau proses laundry Anda",
                        style: TextStyle(color: Colors.white70, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                _headerIconButton(
                  icon: Icons.refresh_rounded,
                  onTap: loadOrders,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  Widget _buildSummarySection() {
    final orderProvider = context.watch<OrderProvider>();

    return Row(
      children: [
        Expanded(
          child: _summaryCard(
            title: "Total",
            value: "${orderProvider.totalCustomerOrders}",
            icon: Icons.receipt_long_rounded,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _summaryCard(
            title: "Aktif",
            value: "${orderProvider.activeCustomerOrders}",
            icon: Icons.local_laundry_service_rounded,
            color: Colors.orange,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _summaryCard(
            title: "Selesai",
            value: "${orderProvider.finishedCustomerOrders}",
            icon: Icons.check_circle_rounded,
            color: Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _summaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle() {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(Icons.history_rounded, color: Colors.blue.shade700),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            "Riwayat Pesanan",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget orderCard(OrderModel order) {
    final color = statusColor(order.status);
    final canCancel = canCancelOrder(order.status);
    final finalStatus = isFinalStatus(order.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(statusIcon(order.status), color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.laundryName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    _statusBadge(order.status),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "#${order.id}",
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                _infoRow(
                  Icons.cleaning_services_rounded,
                  "Layanan",
                  order.serviceName,
                ),
                const SizedBox(height: 11),
                _infoRow(
                  Icons.monitor_weight_outlined,
                  "Berat",
                  "${order.weight} kg",
                ),
                const SizedBox(height: 11),
                _infoRow(
                  Icons.payments_rounded,
                  "Total",
                  rupiah.format(order.totalPrice),
                  isPrice: true,
                ),
                if (order.pickupAddress.trim().isNotEmpty) ...[
                  const SizedBox(height: 11),
                  _infoRow(
                    Icons.location_on_rounded,
                    "Alamat",
                    order.pickupAddress,
                    isMultiline: true,
                  ),
                ],
                if (order.note.trim().isNotEmpty) ...[
                  const SizedBox(height: 11),
                  _infoRow(
                    Icons.note_add_rounded,
                    "Catatan",
                    order.note,
                    isMultiline: true,
                  ),
                ],
              ],
            ),
          ),
          if (canCancel) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isCancelling
                    ? null
                    : () {
                        _showCancelDialog(order);
                      },
                icon: _isCancelling
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cancel_outlined),
                label: Text(
                  _isCancelling ? "Membatalkan..." : "Batalkan Pesanan",
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                  side: BorderSide(color: Colors.red.shade200),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ] else if (finalStatus) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withOpacity(0.18)),
              ),
              child: Row(
                children: [
                  Icon(statusIcon(order.status), color: color, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Pesanan ${statusText(order.status).toLowerCase()}",
                      style: TextStyle(
                        color: color,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    final color = statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon(status), size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            statusText(status),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(
    IconData icon,
    String label,
    String value, {
    bool isPrice = false,
    bool isMultiline = false,
  }) {
    return Row(
      crossAxisAlignment: isMultiline
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 17,
          color: isPrice ? Colors.green.shade700 : Colors.grey.shade600,
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 68,
          child: Text(
            label,
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            maxLines: isMultiline ? null : 1,
            overflow: isMultiline
                ? TextOverflow.visible
                : TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              fontWeight: isPrice ? FontWeight.bold : FontWeight.w500,
              color: isPrice ? Colors.green.shade700 : Colors.grey.shade800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _emptyOrderState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 44),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 70,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 14),
          Text(
            "Belum ada pesanan",
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Mulai buat pesanan laundry pertama Anda.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text("Buat Pesanan"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderList() {
    final orderProvider = context.watch<OrderProvider>();
    final orders = orderProvider.customerOrders;

    if (orderProvider.loadingCustomerOrders) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (orders.isEmpty) {
      return _emptyOrderState();
    }

    return Column(children: orders.map(orderCard).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: loadOrders,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                  children: [
                    _buildSummarySection(),
                    const SizedBox(height: 18),
                    _buildSectionTitle(),
                    const SizedBox(height: 14),
                    _buildOrderList(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
