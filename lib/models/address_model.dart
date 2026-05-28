class AddressModel {
  final String id;
  final String label;
  final String addressLine1;
  final String? addressLine2;
  final String? area;
  final String? landmark;
  final String city;
  final String state;
  final String pincode;
  final String? instructions;
  final bool isDefault;
  final double latitude;
  final double longitude;

  const AddressModel({
    required this.id,
    required this.label,
    required this.addressLine1,
    this.addressLine2,
    this.area,
    this.landmark,
    required this.city,
    this.state = '',
    this.pincode = '',
    this.instructions,
    this.isDefault = false,
    this.latitude = 0.0,
    this.longitude = 0.0,
  });

  // Backward-compat getters
  String get line1 => addressLine1;
  double get lat => latitude;
  double get lng => longitude;

  String get fullAddress {
    final parts = <String>[
      if (addressLine1.isNotEmpty) addressLine1,
      if (area?.isNotEmpty == true) area!,
      if (city.isNotEmpty) city,
      if (pincode.isNotEmpty) pincode,
    ];
    return parts.join(', ');
  }

  factory AddressModel.fromJson(Map<String, dynamic> json) => AddressModel(
        id: json['id'] as String? ?? '',
        label: json['label'] as String? ?? '',
        addressLine1: json['addressLine1'] as String? ??
            json['line1'] as String? ??
            json['address'] as String? ??
            '',
        addressLine2: json['addressLine2'] as String?,
        area: json['area'] as String?,
        landmark: json['landmark'] as String?,
        city: json['city'] as String? ?? '',
        state: json['state'] as String? ?? '',
        pincode: json['pincode'] as String? ?? '',
        instructions: json['instructions'] as String?,
        isDefault: json['isDefault'] as bool? ?? false,
        latitude: (json['latitude'] as num?)?.toDouble() ??
            (json['lat'] as num?)?.toDouble() ??
            0.0,
        longitude: (json['longitude'] as num?)?.toDouble() ??
            (json['lng'] as num?)?.toDouble() ??
            0.0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'addressLine1': addressLine1,
        if (addressLine2 != null) 'addressLine2': addressLine2,
        if (area != null) 'area': area,
        if (landmark != null) 'landmark': landmark,
        'city': city,
        'state': state,
        'pincode': pincode,
        if (instructions != null) 'instructions': instructions,
        'isDefault': isDefault,
        'latitude': latitude,
        'longitude': longitude,
      };

  AddressModel copyWith({
    String? label,
    String? addressLine1,
    String? addressLine2,
    String? area,
    String? landmark,
    String? city,
    String? state,
    String? pincode,
    String? instructions,
    bool? isDefault,
    double? latitude,
    double? longitude,
  }) =>
      AddressModel(
        id: id,
        label: label ?? this.label,
        addressLine1: addressLine1 ?? this.addressLine1,
        addressLine2: addressLine2 ?? this.addressLine2,
        area: area ?? this.area,
        landmark: landmark ?? this.landmark,
        city: city ?? this.city,
        state: state ?? this.state,
        pincode: pincode ?? this.pincode,
        instructions: instructions ?? this.instructions,
        isDefault: isDefault ?? this.isDefault,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
      );
}
