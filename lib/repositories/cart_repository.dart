import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cart_item_model.dart';
import '../models/product_model.dart';

class CartRepository {
  final List<CartItemModel> _items = [];

  List<CartItemModel> get items => List.unmodifiable(_items);

  double get subtotal => _items.fold(0, (sum, i) => sum + i.subtotal);

  void addItem(ProductModel product) {
    final idx = _items.indexWhere((i) => i.product.id == product.id);
    if (idx >= 0) {
      _items[idx] = _items[idx].copyWith(quantity: _items[idx].quantity + 1);
    } else {
      _items.add(CartItemModel(product: product, quantity: 1));
    }
  }

  void removeItem(String productId) {
    _items.removeWhere((i) => i.product.id == productId);
  }

  void decrementItem(String productId) {
    final idx = _items.indexWhere((i) => i.product.id == productId);
    if (idx < 0) return;
    if (_items[idx].quantity <= 1) {
      _items.removeAt(idx);
    } else {
      _items[idx] = _items[idx].copyWith(quantity: _items[idx].quantity - 1);
    }
  }

  void clear() => _items.clear();
}

final cartRepositoryProvider = Provider<CartRepository>((ref) => CartRepository());
