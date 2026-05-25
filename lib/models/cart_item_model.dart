import 'product_model.dart';

class CartItemModel {
  final ProductModel product;
  final int quantity;

  const CartItemModel({required this.product, required this.quantity});

  double get subtotal => product.price * quantity;

  CartItemModel copyWith({int? quantity}) =>
      CartItemModel(product: product, quantity: quantity ?? this.quantity);
}
