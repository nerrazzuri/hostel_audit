class TemplateSection {
  final int id;
  final String nameEn;
  final String nameMs;
  final int position;
  final bool isActive;

  TemplateSection({
    required this.id,
    required this.nameEn,
    required this.nameMs,
    required this.position,
    required this.isActive,
  });

  factory TemplateSection.fromJson(Map<String, dynamic> json) {
    return TemplateSection(
      id: json['id'],
      nameEn: json['name_en'],
      nameMs: json['name_ms'],
      position: json['position'],
      isActive: json['is_active'] ?? true,
    );
  }
}

class TemplateItem {
  final int id;
  final int sectionId;
  final String nameEn;
  final String nameMs;
  final int position;
  final bool isCritical;
  final bool requiresPhoto;

  TemplateItem({
    required this.id,
    required this.sectionId,
    required this.nameEn,
    required this.nameMs,
    required this.position,
    required this.isCritical,
    required this.requiresPhoto,
  });

  factory TemplateItem.fromJson(Map<String, dynamic> json) {
    return TemplateItem(
      id: json['id'],
      sectionId: json['section_id'],
      nameEn: json['name_en'],
      nameMs: json['name_ms'],
      position: json['position'],
      isCritical: json['is_critical'] ?? false,
      requiresPhoto: json['requires_photo'] ?? false,
    );
  }
}
