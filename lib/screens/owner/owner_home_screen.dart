import 'dart:async';
import 'dart:convert';

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

  List<Map<String, dynamic>> _ownerNotifications = [];
  final Set<String> _readNotificationKeys = {};

  int get _unreadOwnerNotificationCount {
    return _ownerNotifications.where((notification) {
      final key = notification["key"]?.toString() ?? "";
      return !_readNotificationKeys.contains(key);
    }).length;
  }

  String _selectedStatusFilter = "all";

  final List<String> _statusFilters = [
    "all",
    "pending",
    "accepted",
    "picked_up",
    "washing",
    "ready",
    "delivered",
    "rejected",
    "cancelled",
  ];

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
  ];

  @override
  void initState() {
    super.initState();
    _checkFirstTimeLogin();
    _loadSavedNotifications();

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

  String _notificationKey({required String type, required int orderId}) {
    return "$type-$orderId";
  }

  Future<void> _loadSavedNotifications() async {
    final prefs = await SharedPreferences.getInstance();

    final savedNotifications = prefs.getStringList("owner_notifications") ?? [];

    final savedReadKeys =
        prefs.getStringList("owner_read_notification_keys") ?? [];

    final loadedNotifications = <Map<String, dynamic>>[];

    for (final item in savedNotifications) {
      try {
        final decoded = jsonDecode(item);

        if (decoded is Map) {
          loadedNotifications.add(Map<String, dynamic>.from(decoded));
        }
      } catch (_) {}
    }

    if (!mounted) return;

    setState(() {
      _ownerNotifications = loadedNotifications;
      _readNotificationKeys
        ..clear()
        ..addAll(savedReadKeys);
    });
  }

  Future<void> _saveNotifications() async {
    final prefs = await SharedPreferences.getInstance();

    final encodedNotifications = _ownerNotifications.map((item) {
      return jsonEncode(item);
    }).toList();

    await prefs.setStringList("owner_notifications", encodedNotifications);
    await prefs.setStringList(
      "owner_read_notification_keys",
      _readNotificationKeys.toList(),
    );
  }

  Future<void> _addOwnerNotification({
    required String type,
    required String title,
    required String body,
    required int orderId,
  }) async {
    if (orderId <= 0) return;

    final key = _notificationKey(type: type, orderId: orderId);

    final notification = {
      "key": key,
      "type": type,
      "title": title,
      "body": body,
      "order_id": orderId,
      "created_at": DateTime.now().toIso8601String(),
    };

    setState(() {
      _ownerNotifications.removeWhere((item) {
        return item["key"]?.toString() == key;
      });

      _ownerNotifications.insert(0, notification);

      if (_ownerNotifications.length > 40) {
        _ownerNotifications = _ownerNotifications.take(40).toList();
      }
    });

    await _saveNotifications();
  }

  Future<void> _syncNotificationsFromOrders(List<OrderModel> orders) async {
    bool changed = false;

    final existingKeys = _ownerNotifications.map((item) {
      return item["key"]?.toString() ?? "";
    }).toSet();

    for (final order in orders) {
      String? type;
      String? title;
      String? body;

      if (order.status == "pending") {
        type = "new_order";
        title = "Pesanan Baru";
        body = "Pesanan #${order.id} dari ${order.customerName}";
      } else if (order.status == "cancelled") {
        type = "cancelled_order";
        title = "Pesanan Dibatalkan";
        body = "Pesanan #${order.id} dibatalkan oleh customer";
      }

      if (type == null || title == null || body == null) continue;

      final key = _notificationKey(type: type, orderId: order.id);

      if (existingKeys.contains(key)) continue;

      _ownerNotifications.insert(0, {
        "key": key,
        "type": type,
        "title": title,
        "body": body,
        "order_id": order.id,
        "created_at": DateTime.now().toIso8601String(),
      });

      existingKeys.add(key);
      changed = true;
    }

    if (_ownerNotifications.length > 40) {
      _ownerNotifications = _ownerNotifications.take(40).toList();
      changed = true;
    }

    if (changed) {
      if (mounted) {
        setState(() {});
      }

      await _saveNotifications();
    }
  }

  Future<void> _markNotificationAsRead(String key) async {
    if (key.trim().isEmpty) return;

    setState(() {
      _readNotificationKeys.add(key);
    });

    await _saveNotifications();
  }

  Future<void> _markAllNotificationsAsRead() async {
    setState(() {
      for (final notification in _ownerNotifications) {
        final key = notification["key"]?.toString() ?? "";

        if (key.isNotEmpty) {
          _readNotificationKeys.add(key);
        }
      }
    });

    await _saveNotifications();
  }

  String _formatNotificationTime(String value) {
    final date = DateTime.tryParse(value);

    if (date == null) return "";

    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return "Baru saja";
    if (diff.inMinutes < 60) return "${diff.inMinutes} menit lalu";
    if (diff.inHours < 24) return "${diff.inHours} jam lalu";

    return "${date.day}/${date.month}/${date.year}";
  }

  Future<void> _openOrderFromNotification(
    Map<String, dynamic> notification, {
    BuildContext? bottomSheetContext,
  }) async {
    final key = notification["key"]?.toString() ?? "";
    final orderId =
        int.tryParse(notification["order_id"]?.toString() ?? "0") ?? 0;

    await _markNotificationAsRead(key);

    if (bottomSheetContext != null && Navigator.canPop(bottomSheetContext)) {
      Navigator.pop(bottomSheetContext);
    }

    if (orderId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("ID pesanan tidak ditemukan"),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    await _loadOrders(showLoading: false, checkNewOrders: false);

    if (!mounted) return;

    final orders = context.read<OrderProvider>().ownerOrders;

    OrderModel? selectedOrder;

    for (final order in orders) {
      if (order.id == orderId) {
        selectedOrder = order;
        break;
      }
    }

    if (selectedOrder == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Pesanan #$orderId tidak ditemukan"),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    _showOrderDetailDialog(selectedOrder);
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

          final orderId = int.tryParse(data["orderId"]?.toString() ?? "0") ?? 0;
          final body = data["message"]?.toString() ?? "Ada pesanan baru masuk";

          await _addOwnerNotification(
            type: "new_order",
            title: "Pesanan Baru",
            body: body,
            orderId: orderId,
          );

          _showNewOrderNotification(1);

          await NotificationService().showNotification(
            title: "Pesanan Baru",
            body: body,
          );
        },
        onOrderCancelled: (data) async {
          debugPrint("Owner menerima event order:cancelled_received => $data");

          await _loadOrders(showLoading: false, checkNewOrders: false);

          if (!mounted) return;

          final orderId = int.tryParse(data["orderId"]?.toString() ?? "0") ?? 0;

          final body = orderId > 0
              ? "Pesanan #$orderId dibatalkan oleh customer"
              : "Ada pesanan yang dibatalkan oleh customer";

          await _addOwnerNotification(
            type: "cancelled_order",
            title: "Pesanan Dibatalkan",
            body: body,
            orderId: orderId,
          );

          await NotificationService().showNotification(
            title: "Pesanan Dibatalkan",
            body: body,
          );

          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(body),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
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

      final orders = context.read<OrderProvider>().ownerOrders;
      await _syncNotificationsFromOrders(orders);

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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final unreadCount = _unreadOwnerNotificationCount;

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
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.notifications_active_rounded,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            "Notifikasi Pesanan",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (unreadCount > 0)
                          TextButton(
                            onPressed: () async {
                              await _markAllNotificationsAsRead();
                              setSheetState(() {});
                            },
                            child: const Text("Tandai dibaca"),
                          ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    if (_ownerNotifications.isEmpty)
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
                              "Belum ada notifikasi",
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Notifikasi pesanan akan muncul di sini",
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
                          itemCount: _ownerNotifications.length,
                          itemBuilder: (context, index) {
                            final notification = _ownerNotifications[index];

                            final key = notification["key"]?.toString() ?? "";
                            final title =
                                notification["title"]?.toString() ??
                                "Notifikasi";
                            final body = notification["body"]?.toString() ?? "";
                            final createdAt =
                                notification["created_at"]?.toString() ?? "";
                            final type = notification["type"]?.toString() ?? "";

                            final isRead = _readNotificationKeys.contains(key);

                            final color = type == "cancelled_order"
                                ? Colors.red
                                : Colors.blue;

                            return InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () async {
                                await _openOrderFromNotification(
                                  notification,
                                  bottomSheetContext: bottomSheetContext,
                                );

                                setSheetState(() {});
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isRead
                                      ? Colors.grey.shade50
                                      : color.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isRead
                                        ? Colors.grey.shade200
                                        : color.withOpacity(0.22),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Stack(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: color.withOpacity(
                                            0.12,
                                          ),
                                          child: Icon(
                                            type == "cancelled_order"
                                                ? Icons.cancel_outlined
                                                : Icons.receipt_long_rounded,
                                            color: color,
                                          ),
                                        ),
                                        if (!isRead)
                                          Positioned(
                                            right: 1,
                                            top: 1,
                                            child: Container(
                                              width: 9,
                                              height: 9,
                                              decoration: const BoxDecoration(
                                                color: Colors.red,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),

                                    const SizedBox(width: 12),

                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  title,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontWeight: isRead
                                                        ? FontWeight.w600
                                                        : FontWeight.bold,
                                                    color: Colors.grey.shade900,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                _formatNotificationTime(
                                                  createdAt,
                                                ),
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  color: Colors.grey.shade500,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            body,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12.2,
                                              color: Colors.grey.shade700,
                                              height: 1.35,
                                            ),
                                          ),
                                          const SizedBox(height: 7),
                                          Row(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 9,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: isRead
                                                      ? Colors.grey.shade200
                                                      : color.withOpacity(0.12),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: Text(
                                                  isRead
                                                      ? "Sudah dilihat"
                                                      : "Belum dilihat",
                                                  style: TextStyle(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.bold,
                                                    color: isRead
                                                        ? Colors.grey.shade600
                                                        : color,
                                                  ),
                                                ),
                                              ),
                                              const Spacer(),
                                              Icon(
                                                Icons.chevron_right_rounded,
                                                color: Colors.grey.shade500,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
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

  void _showOrderDetailDialog(OrderModel order) {
    String selectedStatus = order.status;
    bool isStatusChanged = false;

    final bool finalStatus = isFinalStatus(order.status);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final currentColor = getStatusColor(order.status);
            final selectedColor = getStatusColor(selectedStatus);

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 18),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.82,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(18, 18, 14, 18),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.blue.shade700,
                              Colors.blue.shade500,
                            ],
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.35),
                                ),
                              ),
                              child: const Icon(
                                Icons.receipt_long_rounded,
                                color: Colors.white,
                                size: 27,
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
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Detail dan pengelolaan status",
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.82),
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            IconButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),

                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: currentColor.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: currentColor.withOpacity(0.22),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: currentColor.withOpacity(0.14),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.info_outline_rounded,
                                        color: currentColor,
                                        size: 21,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Status Saat Ini",
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            getStatusText(order.status),
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: currentColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 18),

                              _detailSectionTitle("Informasi Customer"),

                              _detailInfoTile(
                                icon: Icons.person_outline_rounded,
                                title: "Nama Customer",
                                value: order.customerName,
                              ),
                              _detailInfoTile(
                                icon: Icons.phone_outlined,
                                title: "Nomor Telepon",
                                value: order.customerPhone,
                              ),
                              _detailInfoTile(
                                icon: Icons.location_on_outlined,
                                title: "Alamat Pickup",
                                value: order.pickupAddress,
                                maxLines: 3,
                              ),

                              const SizedBox(height: 12),

                              _detailSectionTitle("Informasi Pesanan"),

                              _detailInfoTile(
                                icon: Icons.local_laundry_service_rounded,
                                title: "Layanan",
                                value: order.serviceName,
                              ),
                              _detailInfoTile(
                                icon: Icons.monitor_weight_outlined,
                                title: "Berat Laundry",
                                value: "${order.weight} kg",
                              ),
                              _detailInfoTile(
                                icon: Icons.payments_outlined,
                                title: "Total Harga",
                                value: rupiah.format(order.totalPrice),
                                valueColor: Colors.green.shade700,
                                boldValue: true,
                              ),

                              const SizedBox(height: 16),

                              _detailSectionTitle("Ubah Status"),

                              if (finalStatus)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(13),
                                  decoration: BoxDecoration(
                                    color: currentColor.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: currentColor.withOpacity(0.22),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.lock_outline_rounded,
                                        color: currentColor,
                                        size: 21,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          "Status ${getStatusText(order.status)} tidak dapat diubah lagi.",
                                          style: TextStyle(
                                            fontSize: 12.8,
                                            fontWeight: FontWeight.w600,
                                            color: currentColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                DropdownButtonFormField<String>(
                                  initialValue:
                                      _statuses.contains(selectedStatus)
                                      ? selectedStatus
                                      : null,
                                  decoration: InputDecoration(
                                    labelText: "Pilih Status Baru",
                                    filled: true,
                                    fillColor: Colors.grey.shade50,
                                    prefixIcon: Icon(
                                      Icons.sync_rounded,
                                      color: selectedColor,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(
                                        color: Colors.grey.shade200,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(
                                        color: Colors.grey.shade200,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(
                                        color: selectedColor,
                                        width: 1.5,
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 14,
                                    ),
                                  ),
                                  items: _statuses.map((status) {
                                    return DropdownMenuItem(
                                      value: status,
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 10,
                                            height: 10,
                                            decoration: BoxDecoration(
                                              color: getStatusColor(status),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 9),
                                          Text(getStatusText(status)),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    if (value == null) return;

                                    setDialogState(() {
                                      selectedStatus = value;
                                      isStatusChanged = value != order.status;
                                    });
                                  },
                                ),

                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      ),

                      Container(
                        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border(
                            top: BorderSide(color: Colors.grey.shade100),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.grey.shade700,
                                  side: BorderSide(color: Colors.grey.shade300),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 13,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Text(finalStatus ? "Tutup" : "Batal"),
                              ),
                            ),

                            if (!finalStatus) ...[
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: isStatusChanged
                                      ? () async {
                                          Navigator.pop(dialogContext);
                                          await _updateStatus(
                                            order,
                                            selectedStatus,
                                          );
                                        }
                                      : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue.shade700,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor:
                                        Colors.grey.shade300,
                                    disabledForegroundColor:
                                        Colors.grey.shade600,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 13,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: const Text(
                                    "Simpan Status",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _detailSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade800,
        ),
      ),
    );
  }

  Widget _detailInfoTile({
    required IconData icon,
    required String title,
    required String value,
    Color? valueColor,
    bool boldValue = false,
    int maxLines = 2,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: Colors.blue.shade700, size: 19),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: maxLines,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: boldValue ? FontWeight.bold : FontWeight.w600,
                    color: valueColor ?? Colors.grey.shade800,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
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
    final unreadNotifications = _unreadOwnerNotificationCount;

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

  String getFilterText(String status) {
    if (status == "all") return "Semua";
    return getStatusText(status);
  }

  Color getFilterColor(String status) {
    if (status == "all") return Colors.blue;
    return getStatusColor(status);
  }

  int getOrderCountByStatus(List<OrderModel> orders, String status) {
    if (status == "all") return orders.length;

    return orders.where((order) => order.status == status).length;
  }

  List<OrderModel> getFilteredOrders(List<OrderModel> orders) {
    if (_selectedStatusFilter == "all") {
      return orders;
    }

    return orders.where((order) {
      return order.status == _selectedStatusFilter;
    }).toList();
  }

  Widget _buildOrdersSection() {
    final orderProvider = context.watch<OrderProvider>();
    final orders = orderProvider.ownerOrders;
    final filteredOrders = getFilteredOrders(orders);
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
            ],
          ),

          const SizedBox(height: 16),

          if (orders.isNotEmpty) ...[
            _buildStatusFilterSection(orders),
            const SizedBox(height: 16),
          ],

          if (loadingOrders)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (orders.isEmpty)
            _emptyOrders()
          else if (filteredOrders.isEmpty)
            _emptyFilteredOrders()
          else
            Column(
              children: filteredOrders.map((order) {
                return _orderItem(order);
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusFilterSection(List<OrderModel> orders) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _statusFilters.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final status = _statusFilters[index];
          final selected = _selectedStatusFilter == status;
          final color = getFilterColor(status);
          final count = getOrderCountByStatus(orders, status);

          return InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () {
              setState(() {
                _selectedStatusFilter = status;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              decoration: BoxDecoration(
                color: selected ? color.withOpacity(0.13) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: selected
                      ? color.withOpacity(0.45)
                      : Colors.grey.shade200,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (status != "all") ...[
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                  ],
                  Text(
                    getFilterText(status),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                      color: selected ? color : Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? color.withOpacity(0.15) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? color.withOpacity(0.25)
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: Text(
                      "$count",
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: selected ? color : Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
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

  Widget _emptyFilteredOrders() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(
            Icons.filter_alt_off_outlined,
            size: 48,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 10),
          Text(
            "Tidak ada pesanan ${getFilterText(_selectedStatusFilter).toLowerCase()}",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Coba pilih kategori status lainnya.",
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _orderItem(OrderModel order) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          _showOrderDetailDialog(order);
        },
        child: Container(
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
            ],
          ),
        ),
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
