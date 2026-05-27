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
  });

  // Used for local Hive cart persistence (round-trip with toJson)
  factory ProductModel.fromJson(Map<String, dynamic> json) => ProductModel(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        price: (json['price'] as num).toDouble(),
        currency: json['currency'] as String? ?? 'PKR',
        image: json['image'] as String?,
        category: json['category'] as String? ?? '',
        inStock: json['inStock'] as bool? ?? true,
        stock: json['stock'] as int? ?? 0,
      );

  // Used when parsing the /api/core/storefront/products response
  factory ProductModel.fromStorefrontJson(
    Map<String, dynamic> json, {
    String imageBaseUrl = '',
  }) {
    final images = (json['images'] as List<dynamic>?) ?? [];
    final rawImage = images.isNotEmpty ? images[0] as String? : null;
    String? image;
    if (rawImage != null && rawImage.isNotEmpty) {
      image = rawImage.startsWith('http') ? rawImage : '$imageBaseUrl$rawImage';
    }

    final stockStatus = json['stockStatus'] as String? ?? 'IN_STOCK';
    final hasInventory = json['hasInventory'] as bool? ?? false;
    final availableStock = (json['availableStock'] as num?)?.toInt() ?? 0;
    final inStock = hasInventory ? availableStock > 0 : stockStatus != 'OUT_OF_STOCK';

    return ProductModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      price: (json['defaultPrice'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'PKR',
      image: image,
      category: json['categoryId'] as String? ?? '',
      inStock: inStock,
      stock: availableStock,
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
      };
}
