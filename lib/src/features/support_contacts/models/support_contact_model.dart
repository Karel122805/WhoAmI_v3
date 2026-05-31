class SupportContactModel {
  final String id;
  final String name;
  final String phone;
  final bool isDefault;

  const SupportContactModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.isDefault,
  });

  factory SupportContactModel.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    return SupportContactModel(
      id: id,
      name: (data['name'] as String?)?.trim() ?? '',
      phone: (data['phone'] as String?)?.trim() ?? '',
      isDefault: data['isDefault'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name.trim(),
      'phone': phone.trim(),
      'isDefault': isDefault,
    };
  }
}