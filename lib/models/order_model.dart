import 'package:flutter/foundation.dart';
import 'address_model.dart';

enum OrderStatus {
  pending,
  confirmed,
  preparing,
  dispatched,
  delivered,
  cancelled;

  static OrderStatus fromString(String value) {
    return OrderStatus.values.firstWhere(
      (s) => s.name == value.toLowerCase(),
      orElse: () => OrderStatus.pending,
    );
  }

  String get label {
    switch (this) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.confirmed:
        return 'Confirmed';
      case OrderStatus.preparing:
        return 'Preparing';
      case OrderStatus.dispatched:
        return 'Dispatched';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  bool get isActive =>
      this == OrderStatus.pending ||
      this == OrderStatus.confirmed ||
      this == OrderStatus.preparing ||
      this == OrderStatus.dispatched;
}

class OrderItem {
  final String productId;
  final String name;
  final int quantity;
  final double price;

  const OrderItem({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.price,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
        productId: json['productId'] as String? ?? json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        quantity: json['qty'] as int? ?? json['quantity'] as int? ?? 1,
        price: (json['price'] as num?)?.toDouble() ?? 0.0,
      );

  double get subtotal => price * quantity;
}

class OrderModel {
  final String id;
  final OrderStatus status;
  final List<OrderItem> items;
  final double total;
  final AddressModel? address;
  final DateTime createdAt;
  final DateTime? eta;
  final String? riderId;
  final String? riderName;

  const OrderModel({
    required this.id,
    required this.status,
    required this.items,
    required this.total,
    required this.createdAt,
    this.address,
    this.eta,
    this.riderId,
    this.riderName,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final itemsRaw = json['items'] ?? json['orderItems'] ?? [];
    final itemsJson = itemsRaw is List ? itemsRaw : <dynamic>[];
    final riderJson = json['rider'] as Map<String, dynamic>?;
    final addressJson = (json['address'] ?? json['deliveryAddress']) as Map<String, dynamic>?;

    // Backend may send total as 'total', 'totalAmount', or 'grandTotal'
    final total = (json['total'] ?? json['totalAmount'] ?? json['grandTotal'] as num?)
            ?.toDouble() ??
        0.0;

    // createdAt may be named differently
    final createdAtStr = (json['createdAt'] ?? json['created_at'] ?? json['placedAt']) as String?;

    debugPrint('[ORDER] parsing id=${json['id']} status=${json['status']} total=$total items=${itemsJson.length}');

    return OrderModel(
      id: json['id'] as String? ?? json['orderId'] as String? ?? '',
      status: OrderStatus.fromString(json['status'] as String? ?? 'pending'),
      items: itemsJson
          .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: total,
      address: addressJson != null ? AddressModel.fromJson(addressJson) : null,
      createdAt: createdAtStr != null
          ? DateTime.tryParse(createdAtStr) ?? DateTime.now()
          : DateTime.now(),
      eta: json['eta'] != null ? DateTime.tryParse(json['eta'] as String) : null,
      riderId: riderJson?['id'] as String?,
      riderName: riderJson?['name'] as String?,
    );
  }
}
