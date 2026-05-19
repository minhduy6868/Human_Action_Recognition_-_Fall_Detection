class Source {
  const Source({
    required this.id,
    required this.name,
    required this.sourceType,
    required this.sourceUrl,
    required this.isActive,
  });

  final String id;
  final String name;
  final String sourceType;
  final String sourceUrl;
  final bool isActive;

  factory Source.fromMap(Map<String, dynamic> map) {
    return Source(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      sourceType: map['source_type'] as String? ?? '',
      sourceUrl: map['source_url'] as String? ?? '',
      isActive: map['is_active'] as bool? ?? false,
    );
  }
}
