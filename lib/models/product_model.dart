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
    price: (json['price'] as num?)?.toDouble() ?? 0.0,
    currency: json['currency'] as String? ?? '',
    image: json['image'] as String?,
    category: json['category'] as String? ?? '',
    inStock: (json['stock'] ?? json['quantity'] ?? 0) > 0,
    stock: (json['stock'] as num?)?.toInt() ?? 0,
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

    final availableStock = (json['availableStock'] as num?)?.toInt() ?? 0;
    final stockStatus = json['stockStatus'] as String? ?? '';
    final inStock = availableStock > 0 || stockStatus == 'IN_STOCK';

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
