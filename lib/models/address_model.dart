class AddressModel {
  final String id;
  final String label;
  final String line1;
  final String city;
  final double lat;
  final double lng;

  const AddressModel({
    required this.id,
    required this.label,
    required this.line1,
    required this.city,
    required this.lat,
    required this.lng,
  });

  factory AddressModel.fromJson(Map<String, dynamic> json) => AddressModel(
        id: json['id'] as String,
        label: json['label'] as String? ?? '',
        line1: json['line1'] as String? ?? '',
        city: json['city'] as String? ?? '',
        lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
        lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'line1': line1,
        'city': city,
        'lat': lat,
        'lng': lng,
      };

  String get fullAddress => '$line1, $city';
}
