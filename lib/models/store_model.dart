class StoreModel {
  final String id;
  final String name;
  final String? slug;
  final String? address;
  final String? city;
  final String? state;
  final String? pincode;
  final String? phone;
  final double? latitude;
  final double? longitude;
  final double deliveryRadius;
  final double deliveryFee;
  final double? freeDeliveryAbove;
  final double minOrderAmount;
  final int preparationTime;
  final bool isMainStore;
  final double? distance;
  final bool serviceable;

  const StoreModel({
    required this.id,
    required this.name,
    this.slug,
    this.address,
    this.city,
    this.state,
    this.pincode,
    this.phone,
    this.latitude,
    this.longitude,
    this.deliveryRadius = 5.0,
    this.deliveryFee = 0.0,
    this.freeDeliveryAbove,
    this.minOrderAmount = 0.0,
    this.preparationTime = 30,
    this.isMainStore = false,
    this.distance,
    this.serviceable = true,
  });

  String get areaLabel {
    final parts = <String>[];
    if (address?.isNotEmpty == true) parts.add(address!);
    if (city?.isNotEmpty == true) parts.add(city!);
    return parts.isEmpty ? 'Store' : parts.join(', ');
  }

  String get cityLabel => city ?? state ?? 'Local';

  String get etaLabel {
    final lo = preparationTime;
    final hi = lo + 15;
    return '$lo–$hi mins';
  }

  String get distanceLabel {
    if (distance == null) return '';
    return distance! < 1.0
        ? '${(distance! * 1000).round()} m'
        : '${distance!.toStringAsFixed(1)} km';
  }

  factory StoreModel.fromJson(Map<String, dynamic> json) => StoreModel(
        id: json['id'] as String,
        name: json['name'] as String? ?? 'Store',
        slug: json['slug'] as String?,
        address: json['address'] as String?,
        city: json['city'] as String?,
        state: json['state'] as String?,
        pincode: json['pincode'] as String?,
        phone: json['phone'] as String?,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        deliveryRadius: (json['deliveryRadius'] as num?)?.toDouble() ?? 5.0,
        deliveryFee: (json['deliveryFee'] as num?)?.toDouble() ?? 0.0,
        freeDeliveryAbove: (json['freeDeliveryAbove'] as num?)?.toDouble(),
        minOrderAmount: (json['minOrderAmount'] as num?)?.toDouble() ?? 0.0,
        preparationTime: json['preparationTime'] as int? ?? 30,
        isMainStore: json['isMainStore'] as bool? ?? false,
        distance: (json['distance'] as num?)?.toDouble(),
        serviceable: json['serviceable'] as bool? ?? true,
      );
}
