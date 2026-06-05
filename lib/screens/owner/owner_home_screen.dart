import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/api_config.dart';
import '../../models/order_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';
import '../../services/laundry_service.dart';
import '../../services/notification_service.dart';
import '../../services/socket_service.dart';

class OwnerHomeScreen extends StatefulWidget {
  const OwnerHomeScreen({super.key});

  @override
  State<OwnerHomeScreen> createState() => _OwnerHomeScreenState();
}

class _OwnerHomeScreenState extends State<OwnerHomeScreen> {
  final LaundryService _laundryService = LaundryService();
  final SocketService _socketService = SocketService();

  // bool _socketConnected = false;

  bool _showWelcomeCard = false;

  String? _laundryName;
  String? _laundryPhotoUrl;

  Timer? _notificationTimer;

  final rupiah = NumberFormat.currency(
    locale: "id_ID",
    symbol: "Rp ",
    decimalDigits: 0,
  );

  final List<String> _statuses = [
    "pending",
    "accepted",
    "picked_up",
    "washing",
    "ready",
    "delivered",
    "rejected",
    "cancelled",
  ];

  @override
  void initState() {
    super.initState();
    _checkFirstTimeLogin();

    _loadHomeData().then((_) {
      _connectOwnerSocket();
      _startOrderNotificationWatcher();
    });
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadHomeData() async {
    await _loadLaundryData();
    await _loadOrders();
  }

  Future<void> _refreshHome() async {
    await _loadLaundryData();
    await _loadOrders();
  }

  Future<void> _connectOwnerSocket() async {
    try {
      final ownerId = await context.read<AuthProvider>().getCurrentUserId();

      _socketService.connect(
        serverUrl: ApiConfig.socketUrl,
        onOrderReceived: (data) async {
          debugPrint("Owner menerima event order:received => $data");

          await _loadOrders(showLoading: false, checkNewOrders: false);

          if (!mounted) return;

          _showNewOrderNotification(1);

          await NotificationService().showNotification(
            title: "Pesanan Baru",
            body: data["message"]?.toString() ?? "Ada pesanan baru masuk",
          );
        },
        onConnected: () {
          _socketService.joinOwnerRoom(ownerId: ownerId);
        },
        onDisconnected: () {
          debugPrint("Socket owner terputus");
        },
      );
    } catch (e) {
      debugPrint("Gagal connect socket owner: $e");
    }
  }

  void _startOrderNotificationWatcher() {
    _notificationTimer?.cancel();

    _notificationTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      _loadOrders(showLoading: false, checkNewOrders: true);
    });
  }

  String getFullPhotoUrl(String path) {
    if (path.startsWith("http")) {
      return path;
    }

    final baseUrl = ApiConfig.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final cleanPath = path.replaceAll(RegExp(r'^/+'), '');

    return "$baseUrl/$cleanPath";
  }

  Future<void> _checkFirstTimeLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final isFirstTime = prefs.getBool('is_first_login') ?? true;

    if (isFirstTime) {
      setState(() {
        _showWelcomeCard = true;
      });

      await prefs.setBool('is_first_login', false);
    }
  }

  Future<void> _loadLaundryData() async {
    try {
      final ownerId = await context.read<AuthProvider>().getCurrentUserId();
      final result = await _laundryService.getOwnerLaundry(ownerId);

      if (!mounted) return;

      if (result["success"] == true) {
        final laundry = result["laundry"];

        setState(() {
          if (laundry != null) {
            final name = laundry["name"]?.toString() ?? "";
            final photo = laundry["photo"]?.toString() ?? "";

            _laundryName = name.trim().isNotEmpty ? name : "Nama Laundry";

            if (photo.trim().isNotEmpty) {
              _laundryPhotoUrl = getFullPhotoUrl(photo);
            } else {
              _laundryPhotoUrl = null;
            }
          } else {
            _laundryName = "Nama Laundry";
            _laundryPhotoUrl = null;
          }
        });
      } else {
        setState(() {
          _laundryName = "Nama Laundry";
          _laundryPhotoUrl = null;
        });
      }
    } catch (e) {
      debugPrint("Error loading laundry data: $e");

      if (!mounted) return;

      setState(() {
        _laundryName = "Nama Laundry";
        _laundryPhotoUrl = null;
      });
    }
  }

  Future<void> _loadOrders({
    bool showLoading = true,
    bool checkNewOrders = false,
  }) async {
    try {
      final ownerId = await context.read<AuthProvider>().getCurrentUserId();

      final newOrderCount = await context.read<OrderProvider>().loadOwnerOrders(
        ownerId,
        showLoading: showLoading,
        checkNewOrders: checkNewOrders,
      );

      if (!mounted) return;

      if (newOrderCount > 0) {
        _showNewOrderNotification(newOrderCount);
      }
    } catch (e) {
      debugPrint("Error loading orders from provider: $e");
    }
  }

  void _showNewOrderNotification(int count) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          count == 1
              ? "Ada 1 pesanan baru masuk"
              : "Ada $count pesanan baru masuk",
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: SnackBarAction(
          label: "Lihat",
          onPressed: _showNotificationSheet,
        ),
      ),
    );
  }

  void _showNotificationSheet() {
    final pendingOrders = context.read<OrderProvider>().pendingOrders;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 45,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),

                const SizedBox(height: 18),

                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.notifications_active_rounded,
                        color: Colors.orange.shade700,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        "Notifikasi Pesanan Baru",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                if (pendingOrders.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: Column(
                      children: [
                        Icon(
                          Icons.notifications_none_rounded,
                          size: 54,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "Belum ada notifikasi baru",
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Pesanan baru dari customer akan muncul di sini",
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: pendingOrders.length,
                      itemBuilder: (context, index) {
                        final order = pendingOrders[index];

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.orange.shade100),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.orange.shade100,
                                child: Icon(
                                  Icons.receipt_long_rounded,
                                  color: Colors.orange.shade700,
                                ),
                              ),

                              const SizedBox(width: 12),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Pesanan #${order.id}",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      order.customerName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      "${order.serviceName} • ${order.weight} kg",
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  "Baru",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  // child: ElevatedButton.icon(
                  //   onPressed: () async {
                  //     Navigator.pop(bottomSheetContext);

                  //     await Navigator.pushNamed(
                  //       this.context,
                  //       "/order-manage",
                  //     );

                  //     if (!mounted) return;

                  //     await _loadOrders();
                  //   },
                  //   icon: const Icon(Icons.receipt_long_rounded),
                  //   label: const Text("Buka Halaman Pesanan Masuk"),
                  //   style: ElevatedButton.styleFrom(
                  //     backgroundColor: Colors.blue.shade700,
                  //     foregroundColor: Colors.white,
                  //     padding: const EdgeInsets.symmetric(vertical: 13),
                  //     shape: RoundedRectangleBorder(
                  //       borderRadius: BorderRadius.circular(14),
                  //     ),
                  //   ),
                  // ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _updateStatus(OrderModel order, String status) async {
    final ownerId = await context.read<AuthProvider>().getCurrentUserId();

    final result = await context.read<OrderProvider>().updateOwnerOrderStatus(
      ownerId: ownerId,
      orderId: order.id,
      status: status,
    );

    if (!mounted) return;

    if (result["success"] == true) {
      _socketService.sendStatusChanged(
        customerId: order.customerId,
        orderId: order.id,
        status: status,
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result["message"] ?? "Status berhasil diperbarui"),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> logout(BuildContext context) async {
    _socketService.disconnect();

    context.read<OrderProvider>().clearOrders();

    await context.read<AuthProvider>().logout();

    if (!context.mounted) return;

    Navigator.pushReplacementNamed(context, "/login");
  }

  Color getStatusColor(String status) {
    switch (status) {
      case "pending":
        return Colors.orange;
      case "accepted":
        return Colors.blue;
      case "picked_up":
        return Colors.purple;
      case "washing":
        return Colors.indigo;
      case "ready":
        return Colors.green;
      case "delivered":
        return Colors.teal;
      case "rejected":
        return Colors.red;
      case "cancelled":
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String getStatusText(String status) {
    switch (status) {
      case "pending":
        return "Menunggu";
      case "accepted":
        return "Diterima";
      case "picked_up":
        return "Pick Up";
      case "washing":
        return "Dicuci";
      case "ready":
        return "Siap";
      case "delivered":
        return "Terkirim";
      case "rejected":
        return "Ditolak";
      case "cancelled":
        return "Dibatalkan";
      default:
        return status;
    }
  }

  bool isFinalStatus(String status) {
    return status == "cancelled" ||
        status == "rejected" ||
        status == "delivered";
  }

  Widget _buildLaundryAvatar() {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.45), width: 1.8),
      ),
      child: ClipOval(
        child: _laundryPhotoUrl != null && _laundryPhotoUrl!.trim().isNotEmpty
            ? Image.network(
                _laundryPhotoUrl!,
                width: 58,
                height: 58,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.local_laundry_service_rounded,
                    color: Colors.white,
                    size: 31,
                  );
                },
              )
            : const Icon(
                Icons.local_laundry_service_rounded,
                color: Colors.white,
                size: 31,
              ),
      ),
    );
  }

  Widget _buildOwnerNavbar() {
    final orderProvider = context.watch<OrderProvider>();
    final unreadNotifications = orderProvider.unreadNotifications;

    return Container(
      height: 132,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.shade700,
            Colors.blue.shade600,
            Colors.blue.shade400,
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -35,
            top: -20,
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
            bottom: -50,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () async {
                      await Navigator.pushNamed(context, "/manage-laundry");

                      if (!mounted) return;

                      await _loadLaundryData();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          _buildLaundryAvatar(),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Profile Laundry",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.78),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        _laundryName ?? "Nama Laundry",
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: Colors.white.withOpacity(0.9),
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Stack(
                  children: [
                    _navIconButton(
                      icon: Icons.notifications_none_rounded,
                      onTap: _showNotificationSheet,
                    ),
                    if (unreadNotifications > 0)
                      Positioned(
                        right: 2,
                        top: 2,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 17,
                            minHeight: 17,
                          ),
                          child: Text(
                            unreadNotifications > 9
                                ? "9+"
                                : "$unreadNotifications",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 8),
                _navIconButton(
                  icon: Icons.logout_rounded,
                  onTap: () => logout(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _navIconButton({required IconData icon, required VoidCallback onTap}) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white, size: 26),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    if (!_showWelcomeCard) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.blue.shade600,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.celebration_rounded, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Selamat datang, ${_laundryName ?? "Pemilik Laundry"}",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _showWelcomeCard = false;
              });
            },
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ],
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
            value: "${orderProvider.totalOwnerOrders}",
            icon: Icons.receipt_long_rounded,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _summaryCard(
            title: "Menunggu",
            value: "${orderProvider.pendingOwnerOrders}",
            icon: Icons.pending_actions_rounded,
            color: Colors.orange,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _summaryCard(
            title: "Proses",
            value: "${orderProvider.processOwnerOrders}",
            icon: Icons.local_laundry_service_rounded,
            color: Colors.purple,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionSection() {
    return Row(
      children: [
        Expanded(
          child: _quickActionCard(
            icon: Icons.cleaning_services_rounded,
            title: "Kelola Layanan",
            subtitle: "Tambah atau edit layanan",
            color: Colors.green,
            onTap: () async {
              await Navigator.pushNamed(context, "/manage-services");

              if (!mounted) return;

              await _loadLaundryData();
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _quickActionCard(
            icon: Icons.analytics_outlined,
            title: "Laporan",
            subtitle: "Statistik penjualan",
            color: Colors.purple,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Fitur laporan sedang dalam pengembangan"),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _quickActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade100,
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  color: Colors.grey.shade600,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrdersSection() {
    final orderProvider = context.watch<OrderProvider>();
    final orders = orderProvider.ownerOrders;
    final loadingOrders = orderProvider.loadingOwnerOrders;

    return Container(
      padding: const EdgeInsets.all(16),
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
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.receipt_long_rounded,
                  color: Colors.orange.shade700,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Pesanan Masuk",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      "Kelola status pesanan customer",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  _loadOrders();
                },
                icon: Icon(Icons.refresh_rounded, color: Colors.blue.shade700),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (loadingOrders)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (orders.isEmpty)
            _emptyOrders()
          else
            Column(
              children: orders.map((order) {
                return _orderItem(order);
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _emptyOrders() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 34),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 54, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            "Belum ada pesanan",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Pesanan customer akan tampil di sini",
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _orderItem(OrderModel order) {
    final statusColor = getStatusColor(order.status);
    final finalStatus = isFinalStatus(order.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "#${order.id}",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
              ),
              const Spacer(),
              _statusBadge(order.status),
            ],
          ),
          const SizedBox(height: 12),
          _orderInfoRow(
            icon: Icons.person_outline_rounded,
            text: order.customerName,
            color: Colors.grey.shade700,
          ),
          const SizedBox(height: 7),
          _orderInfoRow(
            icon: Icons.phone_outlined,
            text: order.customerPhone,
            color: Colors.grey.shade700,
          ),
          const SizedBox(height: 7),
          _orderInfoRow(
            icon: Icons.local_laundry_service_rounded,
            text: "${order.serviceName} • ${order.weight} kg",
            color: Colors.blue.shade700,
          ),
          const SizedBox(height: 7),
          _orderInfoRow(
            icon: Icons.payments_outlined,
            text: rupiah.format(order.totalPrice),
            color: Colors.green.shade700,
            bold: true,
          ),
          const SizedBox(height: 7),
          _orderInfoRow(
            icon: Icons.location_on_outlined,
            text: order.pickupAddress,
            color: Colors.grey.shade700,
            maxLines: 2,
          ),
          const SizedBox(height: 14),
          finalStatus
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: statusColor.withOpacity(0.25)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        color: statusColor,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Status ${getStatusText(order.status)} tidak dapat diubah lagi",
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : DropdownButtonFormField<String>(
                  initialValue: _statuses.contains(order.status)
                      ? order.status
                      : null,
                  decoration: InputDecoration(
                    labelText: "Ubah Status",
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: Icon(Icons.sync_rounded, color: statusColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: statusColor, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  items: _statuses.map((status) {
                    return DropdownMenuItem(
                      value: status,
                      child: Row(
                        children: [
                          Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: getStatusColor(status),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(getStatusText(status)),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null && value != order.status) {
                      _updateStatus(order, value);
                    }
                  },
                ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    final color = getStatusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 6),
          Text(
            getStatusText(status),
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

  Widget _orderInfoRow({
    required IconData icon,
    required String text,
    required Color color,
    bool bold = false,
    int maxLines = 1,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.5,
              color: Colors.grey.shade800,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTipsCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade100),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb_outline_rounded, color: Colors.orange.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Update status pesanan secara berkala agar customer mengetahui perkembangan laundry.",
              style: TextStyle(
                fontSize: 12.5,
                color: Colors.orange.shade800,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Column(
          children: [
            _buildOwnerNavbar(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshHome,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                  children: [
                    _buildWelcomeCard(),
                    _buildSummarySection(),
                    const SizedBox(height: 18),
                    _buildQuickActionSection(),
                    const SizedBox(height: 18),
                    _buildOrdersSection(),
                    const SizedBox(height: 18),
                    _buildTipsCard(),
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
