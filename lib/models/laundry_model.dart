double toDouble(dynamic value) {
  if (value == null) return 0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}

int toInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  return int.tryParse(value.toString()) ?? 0;
}

class LaundryModel {
  final int id;
  final int ownerId;
  final String name;
  final String description;
  final String address;
  final double latitude;
  final double longitude;
  final double distance;
  final double rating;

  LaundryModel({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.description,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.distance,
    required this.rating,
  });

  factory LaundryModel.fromJson(Map<String, dynamic> json) {
    return LaundryModel(
      id: toInt(json["id"]),
      ownerId: toInt(json["owner_id"]),
      name: json["name"] ?? "",
      description: json["description"] ?? "",
      address: json["address"] ?? "",
      latitude: toDouble(json["latitude"]),
      longitude: toDouble(json["longitude"]),
      distance: toDouble(json["distance"]),
      rating: toDouble(json["rating"]),
    );
  }
}

class LaundryServiceModel {
  final int id;
  final int laundryId;
  final String serviceName;
  final double pricePerKg;
  final String estimatedTime;

  LaundryServiceModel({
    required this.id,
    required this.laundryId,
    required this.serviceName,
    required this.pricePerKg,
    required this.estimatedTime,
  });

  factory LaundryServiceModel.fromJson(Map<String, dynamic> json) {
    return LaundryServiceModel(
      id: toInt(json["id"]),
      laundryId: toInt(json["laundry_id"]),
      serviceName: json["service_name"] ?? "",
      pricePerKg: toDouble(json["price_per_kg"]),
      estimatedTime: json["estimated_time"] ?? "",
    );
  }
}