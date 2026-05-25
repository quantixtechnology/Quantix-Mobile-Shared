import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/cart_item_model.dart';
import '../models/product_model.dart';

const _kCartBox = 'cart_box';
const _kCartKey = 'cart_items';

class CartRepository {
  final Box _box;

  CartRepository(this._box);

  List<CartItemModel> get items {
    final raw = _box.get(_kCartKey) as String?;
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) {
      final m = e as Map<String, dynamic>;
      return CartItemModel(
        product: ProductModel.fromJson(m['product'] as Map<String, dynamic>),
        quantity: m['quantity'] as int,
      );
    }).toList();
  }

  Future<void> _save(List<CartItemModel> items) async {
    final encoded = jsonEncode(items
        .map((i) => {'product': i.product.toJson(), 'quantity': i.quantity})
        .toList());
    await _box.put(_kCartKey, encoded);
  }

  Future<void> addItem(ProductModel product) async {
    final current = items;
    final idx = current.indexWhere((i) => i.product.id == product.id);
    if (idx >= 0) {
      current[idx] = current[idx].copyWith(quantity: current[idx].quantity + 1);
    } else {
      current.add(CartItemModel(product: product, quantity: 1));
    }
    await _save(current);
  }

  Future<void> removeItem(String productId) async {
    final current = items..removeWhere((i) => i.product.id == productId);
    await _save(current);
  }

  Future<void> decrementItem(String productId) async {
    final current = items;
    final idx = current.indexWhere((i) => i.product.id == productId);
    if (idx < 0) return;
    if (current[idx].quantity <= 1) {
      current.removeAt(idx);
    } else {
      current[idx] = current[idx].copyWith(quantity: current[idx].quantity - 1);
    }
    await _save(current);
  }

  Future<void> clear() => _box.delete(_kCartKey);
}

final cartRepositoryProvider = Provider<CartRepository>((ref) {
  final box = Hive.box(_kCartBox);
  return CartRepository(box);
});

Future<void> openCartBox() => Hive.openBox(_kCartBox);
