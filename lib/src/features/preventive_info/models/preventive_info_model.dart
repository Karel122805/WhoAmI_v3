class PreventiveInfoModel {
  final String id;
  final String title;
  final String description;
  final String content;
  final String category;
  final String imageUrl;
  final String targetRole;
  final int order;
  final bool active;

  const PreventiveInfoModel({
    required this.id,
    required this.title,
    required this.description,
    required this.content,
    required this.category,
    required this.imageUrl,
    required this.targetRole,
    required this.order,
    required this.active,
  });
}