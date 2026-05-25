enum UserRole { customer, rider, admin }

class UserModel {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final UserRole role;
  final String businessId;

  const UserModel({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    required this.role,
    required this.businessId,
  });

  factory UserModel.fromBackend(Map<String, dynamic> json, {required String businessId}) => UserModel(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        email: json['email'] as String?,
        role: UserRole.customer,
        businessId: businessId,
      );

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String,
        name: json['name'] as String,
        phone: json['phone'] as String? ?? '',
        email: json['email'] as String?,
        role: UserRole.values.firstWhere(
          (r) => r.name == (json['role'] as String? ?? 'customer').toLowerCase(),
          orElse: () => UserRole.customer,
        ),
        businessId: json['businessId'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'role': role.name,
        'businessId': businessId,
      };
}
