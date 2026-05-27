class CategoryModel {
  final String id;
  final String name;
  final String? image;
  final String? parentId;

  const CategoryModel({
    required this.id,
    required this.name,
    this.image,
    this.parentId,
  });

  factory CategoryModel.fromJson(
    Map<String, dynamic> json, {
    String imageBaseUrl = '',
  }) =>
      CategoryModel(
        id: json['id'] as String,
        name: json['name'] as String,
        image: _resolveImage(json['image'], imageBaseUrl),
        parentId: json['parentId'] as String?,
      );

  static String? _resolveImage(dynamic raw, String imageBaseUrl) {
    if (raw == null) return null;
    final s = raw as String;
    if (s.isEmpty) return null;
    if (s.startsWith('http')) return s;
    return imageBaseUrl.isNotEmpty ? '$imageBaseUrl$s' : s;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'image': image,
        'parentId': parentId,
      };
}
