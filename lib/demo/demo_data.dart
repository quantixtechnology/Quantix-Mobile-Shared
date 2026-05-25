import '../models/address_model.dart';
import '../models/category_model.dart';
import '../models/order_model.dart';
import '../models/product_model.dart';
import '../auth/user_model.dart';

// Set --dart-define=USE_DEMO_DATA=true to enable offline seed data.
const bool kUseDemoData = bool.fromEnvironment('USE_DEMO_DATA', defaultValue: false);

abstract final class DemoData {
  static List<CategoryModel> get categories => [
        const CategoryModel(id: 'cat_001', name: 'Groceries'),
        const CategoryModel(id: 'cat_002', name: 'Beverages'),
        const CategoryModel(id: 'cat_003', name: 'Snacks'),
        const CategoryModel(id: 'cat_004', name: 'Dairy'),
        const CategoryModel(id: 'cat_005', name: 'Bakery'),
      ];

  static List<ProductModel> get products => [
        const ProductModel(
          id: 'prd_001', name: 'Whole Milk 1L', description: 'Fresh full-fat milk.',
          price: 120, currency: 'PKR', category: 'cat_004', inStock: true, stock: 50,
        ),
        const ProductModel(
          id: 'prd_002', name: 'Brown Bread', description: 'Whole wheat loaf.',
          price: 85, currency: 'PKR', category: 'cat_005', inStock: true, stock: 30,
        ),
        const ProductModel(
          id: 'prd_003', name: 'Orange Juice 500ml', description: 'Cold-pressed juice.',
          price: 150, currency: 'PKR', category: 'cat_002', inStock: true, stock: 20,
        ),
        const ProductModel(
          id: 'prd_004', name: 'Potato Chips', description: 'Salted crisps.',
          price: 65, currency: 'PKR', category: 'cat_003', inStock: true, stock: 100,
        ),
        const ProductModel(
          id: 'prd_005', name: 'Basmati Rice 1kg', description: 'Long-grain fragrant rice.',
          price: 220, currency: 'PKR', category: 'cat_001', inStock: true, stock: 40,
        ),
        const ProductModel(
          id: 'prd_006', name: 'Mineral Water 1.5L', description: 'Still spring water.',
          price: 55, currency: 'PKR', category: 'cat_002', inStock: true, stock: 200,
        ),
      ];

  static List<OrderModel> get orders => [
        OrderModel(
          id: 'ord_demo_001',
          status: OrderStatus.dispatched,
          items: [
            const OrderItem(productId: 'prd_001', name: 'Whole Milk 1L', quantity: 2, price: 120),
            const OrderItem(productId: 'prd_002', name: 'Brown Bread', quantity: 1, price: 85),
          ],
          total: 325,
          createdAt: DateTime.now().subtract(const Duration(hours: 1)),
          eta: DateTime.now().add(const Duration(minutes: 15)),
        ),
        OrderModel(
          id: 'ord_demo_002',
          status: OrderStatus.delivered,
          items: [
            const OrderItem(productId: 'prd_004', name: 'Potato Chips', quantity: 3, price: 65),
          ],
          total: 245,
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
      ];

  static List<AddressModel> get addresses => [
        const AddressModel(
          id: 'addr_001', label: 'Home',
          line1: '12-B Model Town', city: 'Lahore',
          lat: 31.5204, lng: 74.3587,
        ),
        const AddressModel(
          id: 'addr_002', label: 'Office',
          line1: 'Plot 5, Tech Park, Gulberg', city: 'Lahore',
          lat: 31.5101, lng: 74.3360,
        ),
      ];

  static List<UserModel> get customers => [
        const UserModel(id: 'usr_001', name: 'Ahmed Khan', phone: '+92-300-1234567',
            email: 'ahmed@example.com', role: UserRole.customer, businessId: 'QTX001'),
        const UserModel(id: 'usr_002', name: 'Sara Ali', phone: '+92-321-7654321',
            email: 'sara@example.com', role: UserRole.customer, businessId: 'QTX001'),
        const UserModel(id: 'usr_003', name: 'Zain Malik', phone: '+92-333-1112233',
            role: UserRole.customer, businessId: 'QTX001'),
        // Arbaz Fresh Meat — existing customer
        const UserModel(
          id: 'CUS-BUS-202605-0001-000001',
          name: 'Rita Khan',
          phone: '',
          email: 'antoinetteritap@gmail.com',
          role: UserRole.customer,
          businessId: 'BUS-202605-0001',
        ),
      ];

  static Map<String, dynamic> get adminStats => {
        'todayOrders': 24,
        'revenue': 18650.0,
        'activeRiders': 3,
        'pendingOrders': 7,
      };

  static List<Map<String, dynamic>> get inventoryItems => products
      .map((p) => {
            'product': p.toJson(),
            'stock': p.stock,
          })
      .toList();
}
