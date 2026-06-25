class OnboardingOption {
  const OnboardingOption({
    this.id,
    this.key,
    required this.label,
    this.translationMissing = false,
    this.popular = false,
    this.meta = const <String, dynamic>{},
    this.raw = const <String, dynamic>{},
  });

  final Object? id;
  final String? key;
  final String label;
  final bool translationMissing;
  final bool popular;
  final Map<String, dynamic> meta;
  final Map<String, dynamic> raw;

  String get identity {
    final keyValue = key?.trim();
    if (keyValue != null && keyValue.isNotEmpty) return 'key:$keyValue';
    final idValue = id?.toString().trim();
    if (idValue != null && idValue.isNotEmpty) return 'id:$idValue';
    return 'label:${label.trim().toLowerCase()}';
  }

  int? get intId {
    final direct = _intValue(id);
    if (direct != null) return direct;
    return metaInt('mother_tongue_id') ?? metaInt('id');
  }

  int? metaInt(String key) {
    final value = meta[key] ?? raw[key];
    return _intValue(value);
  }

  String? metaText(String key) {
    final text = (meta[key] ?? raw[key])?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  bool? metaBool(String key) {
    return _boolValue(meta[key] ?? raw[key]);
  }

  String? get subtitle {
    for (final key in const [
      'subtitle',
      'display_hierarchy',
      'category_label',
      'working_with_label',
      'type',
    ]) {
      final value = meta[key] ?? raw[key];
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty && text != label) return text;
    }

    return null;
  }

  factory OnboardingOption.fromJson(Map<String, dynamic> json) {
    final rawMeta = json['meta'];
    final meta = rawMeta is Map
        ? Map<String, dynamic>.from(rawMeta)
        : <String, dynamic>{};

    void absorbMeta(String key) {
      if (json.containsKey(key) && !meta.containsKey(key)) {
        meta[key] = json[key];
      }
    }

    for (final key in const [
      'category_id',
      'category_label',
      'level_rank',
      'level_rank_source',
      'requires_specialization',
      'requires_college',
      'gender_mode',
      'display_hierarchy',
      'type',
      'tag',
      'is_final_node',
      'status',
      'working_with_id',
      'working_with_label',
      'mother_tongue_id',
      'cm',
    ]) {
      absorbMeta(key);
    }

    return OnboardingOption(
      id:
          json['id'] ??
          json['mother_tongue_id'] ??
          json['location_id'] ??
          json['value'],
      key: _stringValue(json['key'] ?? json['slug'] ?? json['code']),
      label: _labelFromJson(json),
      translationMissing: _boolValue(json['translation_missing']) ?? false,
      popular: _boolValue(json['popular'] ?? json['is_popular']) ?? false,
      meta: meta,
      raw: Map<String, dynamic>.from(json),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (id != null) 'id': id,
      if (key != null && key!.isNotEmpty) 'key': key,
      'label': label,
      'translation_missing': translationMissing,
      'popular': popular,
      if (meta.isNotEmpty) 'meta': meta,
    };
  }

  static List<OnboardingOption> listFrom(dynamic value) {
    final List<dynamic> rows;
    if (value is List) {
      rows = value;
    } else if (value is Map) {
      final nested = value['results'] ?? value['items'] ?? value['data'];
      rows = nested is List ? nested : <dynamic>[];
    } else {
      rows = <dynamic>[];
    }

    return rows
        .whereType<Map>()
        .map((row) => OnboardingOption.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  static String _labelFromJson(Map<String, dynamic> json) {
    for (final key in const ['label', 'name', 'label_en', 'name_en', 'key']) {
      final value = _stringValue(json[key]);
      if (value != null) return value;
    }

    return _stringValue(json['id']) ?? '';
  }

  static String? _stringValue(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  static int? _intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return int.tryParse(text);
  }

  static bool? _boolValue(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().trim().toLowerCase();
    if (text == null || text.isEmpty) return null;
    if (text == '1' || text == 'true' || text == 'yes') return true;
    if (text == '0' || text == 'false' || text == 'no') return false;
    return null;
  }
}
