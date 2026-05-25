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
