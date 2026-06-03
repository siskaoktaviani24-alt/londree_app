import 'laundry_model.dart';

class OrderModel {
  final int id;
  final int customerId;
  final int laundryId;
  final int serviceId;
  final double weight;
  final double totalPrice;
  final String pickupAddress;
  final String note;
  final String status;
  final String orderDate;
  final String laundryName;
  final String serviceName;
  final String customerName;
  final String customerPhone;

  OrderModel({
    required this.id,
    required this.customerId,
    required this.laundryId,
    required this.serviceId,
    required this.weight,
    required this.totalPrice,
    required this.pickupAddress,
    required this.note,
    required this.status,
    required this.orderDate,
    required this.laundryName,
    required this.serviceName,
    required this.customerName,
    required this.customerPhone,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: toInt(json["id"]),
      customerId: toInt(json["customer_id"]),
      laundryId: toInt(json["laundry_id"]),
      serviceId: toInt(json["service_id"]),
      weight: toDouble(json["weight"]),
      totalPrice: toDouble(json["total_price"]),
      pickupAddress: json["pickup_address"] ?? "",
      note: json["note"] ?? "",
      status: json["status"] ?? "",
      orderDate: json["order_date"] ?? "",
      laundryName: json["laundry_name"] ?? "",
      serviceName: json["service_name"] ?? "",
      customerName: json["customer_name"] ?? "",
      customerPhone: json["customer_phone"] ?? "",
    );
  }
}