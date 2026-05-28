import 'package:flutter/foundation.dart';

class ProductModel {
  final String id;
  final String name;
  final String description;
  final double price;
  final String currency;
  final String? image;
  final String category;
  final bool inStock;
  final int stock;
  final double? weight;
  final String? unit;
  final double? compareAtPrice;
  final String? piecesInfo;

  const ProductModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.currency,
    required this.category,
    required this.inStock,
    required this.stock,
    this.image,
    this.weight,
    this.unit,
    this.compareAtPrice,
    this.piecesInfo,
  });

  String? get weightLabel {
    if (weight == null || unit == null || unit!.isEmpty) return null;
    final w = weight!;
    final formatted = w % 1 == 0 ? w.toInt().toString() : w.toString();
    return '$formatted ${unit!}';
  }

  // Used for local Hive cart persistence (round-trip with toJson)
  factory ProductModel.fromJson(Map<String, dynamic> json) => ProductModel(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String? ?? '',
    price: (json['price'] as num?)?.toDouble() ?? 0.0,
    currency: json['currency'] as String? ?? '',
    image: json['image'] as String?,
    category: json['category'] as String? ?? '',
    inStock: ((json['stock'] as num?) ?? (json['quantity'] as num?) ?? 0) > 0,
    stock: (json['stock'] as num?)?.toInt() ?? 0,
    weight: (json['weight'] as num?)?.toDouble(),
    unit: json['unit'] as String?,
    compareAtPrice: (json['compareAtPrice'] as num?)?.toDouble(),
    piecesInfo: json['piecesInfo'] as String?,
  );

  // Parses the /api/core/storefront/products response shape.
  // imageBaseUrl should be the storefront domain (e.g. https://arbazfreshmeat.quantixtechnology.in)
  factory ProductModel.fromStorefrontJson(
    Map<String, dynamic> json, {
    required String currency,
    String imageBaseUrl = '',
  }) {
    final imagesList = json['images'];
    String? firstImage;
    if (imagesList is List && imagesList.isNotEmpty) {
      final raw = imagesList.first as String? ?? '';
      firstImage = raw.startsWith('http') ? raw : '$imageBaseUrl$raw';
    }

    // Resolve stock from whichever field the backend sends
    final availableStock = (json['availableStock'] as num?)?.toInt()
        ?? (json['quantity'] as num?)?.toInt()
        ?? (json['stock'] as num?)?.toInt()
        ?? (json['inventory'] as num?)?.toInt()
        ?? (json['availableQuantity'] as num?)?.toInt()
        ?? 0;
    final stockStatus = json['stockStatus'] as String? ?? '';
    final inStock = availableStock > 0 || stockStatus == 'IN_STOCK';

    final weight = (json['weight'] as num?)?.toDouble();
    final unit = (json['unit'] as String?) ?? (json['weightUnit'] as String?);
    final compareAtPrice = (json['compareAtPrice'] as num?)?.toDouble()
        ?? (json['mrp'] as num?)?.toDouble()
        ?? (json['originalPrice'] as num?)?.toDouble();
    final piecesInfo = (json['piecesInfo'] as String?)
        ?? (json['variant'] as String?)
        ?? (json['size'] as String?);

    debugPrint(
      '[PRODUCT] id=${json['id']} '
      'stock={avail:${json['availableStock']},qty:${json['quantity']},stk:${json['stock']},inv:${json['inventory']},aqty:${json['availableQuantity']},status:${json['stockStatus']}} '
      '→ resolved=$availableStock inStock=$inStock '
      'weight={w:${json['weight']},u:${json['unit']},wu:${json['weightUnit']}}',
    );

    return ProductModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      price: (json['defaultPrice'] as num?)?.toDouble() ?? 0.0,
      currency: currency,
      image: firstImage,
      category: json['categoryId'] as String? ?? '',
      inStock: inStock,
      stock: availableStock,
      weight: weight,
      unit: unit,
      compareAtPrice: compareAtPrice,
      piecesInfo: piecesInfo,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'price': price,
    'currency': currency,
    'image': image,
    'category': category,
    'inStock': inStock,
    'stock': stock,
    'weight': weight,
    'unit': unit,
    'compareAtPrice': compareAtPrice,
    'piecesInfo': piecesInfo,
  };
}
