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

  factory CategoryModel.fromJson(Map<String, dynamic> json) => CategoryModel(
        id: json['id'] as String,
        name: json['name'] as String,
        image: json['image'] as String?,
        parentId: json['parentId'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'image': image,
        'parentId': parentId,
      };
}
