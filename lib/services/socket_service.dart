import 'dart:developer' as developer;
import 'dart:ui';

import 'package:socket_io_client/socket_io_client.dart' as io;

typedef SocketDataHandler = void Function(Map<String, dynamic> data);

class SocketService {
  SocketService._internal();

  static final SocketService _instance = SocketService._internal();

  factory SocketService() => _instance;

  io.Socket? _socket;
  String? _serverUrl;

  VoidCallback? _onConnected;
  VoidCallback? _onDisconnected;

  SocketDataHandler? _onOrderReceived;
  SocketDataHandler? _onOrderStatusUpdated;

  bool get isConnected => _socket?.connected ?? false;

  void connect({
    required String serverUrl,
    SocketDataHandler? onOrderReceived,
    SocketDataHandler? onOrderStatusUpdated,
    VoidCallback? onConnected,
    VoidCallback? onDisconnected,
  }) {
    _serverUrl = serverUrl;
    _onOrderReceived = onOrderReceived;
    _onOrderStatusUpdated = onOrderStatusUpdated;
    _onConnected = onConnected;
    _onDisconnected = onDisconnected;

    if (_socket != null && _socket!.connected) {
      _bindBusinessListeners();
      _onConnected?.call();
      return;
    }

    if (_socket != null) {
      try {
        _socket!.disconnect();
        _socket!.dispose();
      } catch (_) {}

      _socket = null;
    }

    _socket = io.io(
      serverUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(100)
          .setReconnectionDelay(1000)
          .build(),
    );

    _bindCoreListeners();
    _bindBusinessListeners();

    _socket!.connect();
  }

  void _bindCoreListeners() {
    final socket = _socket;

    if (socket == null) return;

    socket.off('connect');
    socket.off('disconnect');
    socket.off('connect_error');
    socket.off('error');

    socket.onConnect((_) {
      developer.log("Socket connected: ${socket.id}");
      _onConnected?.call();
    });

    socket.onDisconnect((_) {
      developer.log("Socket disconnected");
      _onDisconnected?.call();
    });

    socket.onConnectError((data) {
      developer.log("Socket connect error: $data");
      _onDisconnected?.call();
    });

    socket.onError((data) {
      developer.log("Socket error: $data");
    });
  }

  void _bindBusinessListeners() {
    final socket = _socket;

    if (socket == null) return;

    socket.off('order:received');
    socket.off('order:status_updated');

    socket.on('order:received', (data) {
      developer.log("order:received => $data");

      if (data is Map) {
        _onOrderReceived?.call(
          Map<String, dynamic>.from(data),
        );
      }
    });

    socket.on('order:status_updated', (data) {
      developer.log("order:status_updated => $data");

      if (data is Map) {
        _onOrderStatusUpdated?.call(
          Map<String, dynamic>.from(data),
        );
      }
    });
  }

  void joinOwnerRoom({
    required int ownerId,
  }) {
    final socket = _socket;

    if (socket == null || !socket.connected) {
      developer.log("joinOwnerRoom gagal: socket belum connect");
      return;
    }

    socket.emit('owner:join', {
      'ownerId': ownerId,
    });

    developer.log("Owner join room: owner_$ownerId");
  }

  void joinCustomerRoom({
    required int customerId,
  }) {
    final socket = _socket;

    if (socket == null || !socket.connected) {
      developer.log("joinCustomerRoom gagal: socket belum connect");
      return;
    }

    socket.emit('customer:join', {
      'customerId': customerId,
    });

    developer.log("Customer join room: customer_$customerId");
  }

  void sendNewOrder({
    required int ownerId,
    required int laundryId,
    required int orderId,
    required int customerId,
    required String customerName,
  }) {
    final socket = _socket;

    if (socket == null || !socket.connected) {
      developer.log("sendNewOrder gagal: socket belum connect");
      return;
    }

    socket.emit('order:new', {
      'ownerId': ownerId,
      'laundryId': laundryId,
      'orderId': orderId,
      'customerId': customerId,
      'customerName': customerName,
      'message': 'Ada pesanan baru masuk',
      'timestamp': DateTime.now().toIso8601String(),
    });

    developer.log("Emit order:new untuk owner_$ownerId");
  }

  void sendStatusChanged({
    required int customerId,
    required int orderId,
    required String status,
  }) {
    final socket = _socket;

    if (socket == null || !socket.connected) {
      developer.log("sendStatusChanged gagal: socket belum connect");
      return;
    }

    socket.emit('order:status_changed', {
      'customerId': customerId,
      'orderId': orderId,
      'status': status,
      'message': 'Status pesanan diperbarui',
      'timestamp': DateTime.now().toIso8601String(),
    });

    developer.log("Emit order:status_changed untuk customer_$customerId");
  }

  void disconnect() {
    final socket = _socket;

    if (socket == null) return;

    try {
      socket.disconnect();
      socket.dispose();
    } catch (e) {
      developer.log("Socket disconnect error: $e");
    } finally {
      _socket = null;
    }
  }

  void reconnect() {
    if (_serverUrl == null) return;

    connect(
      serverUrl: _serverUrl!,
      onOrderReceived: _onOrderReceived,
      onOrderStatusUpdated: _onOrderStatusUpdated,
      onConnected: _onConnected,
      onDisconnected: _onDisconnected,
    );
  }
}