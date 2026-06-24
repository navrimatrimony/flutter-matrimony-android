class ActivationChecklistItem {
  const ActivationChecklistItem({
    required this.key,
    required this.label,
    this.complete = false,
    this.blocking = false,
    this.status,
    this.message,
    this.raw = const <String, dynamic>{},
  });

  final String key;
  final String label;
  final bool complete;
  final bool blocking;
  final String? status;
  final String? message;
  final Map<String, dynamic> raw;

  factory ActivationChecklistItem.fromJson(Map<String, dynamic> json) {
    final key = _stringValue(json['key']) ?? '';
    return ActivationChecklistItem(
      key: key,
      label: _stringValue(json['label']) ?? key,
      complete: _boolValue(json['complete']) ?? false,
      blocking: _boolValue(json['blocking']) ?? false,
      status: _stringValue(json['status']),
      message: _stringValue(json['message']),
      raw: Map<String, dynamic>.from(json),
    );
  }

  static List<ActivationChecklistItem> listFrom(dynamic value) {
    final List<dynamic> rows;
    if (value is List) {
      rows = value;
    } else if (value is Map) {
      final nested =
          value['items'] ?? value['activation_checklist'] ?? value['data'];
      rows = nested is List ? nested : <dynamic>[];
    } else {
      rows = <dynamic>[];
    }

    return rows
        .whereType<Map>()
        .map(
          (row) =>
              ActivationChecklistItem.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList();
  }
}

String? _stringValue(dynamic value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return null;
  return text;
}

bool? _boolValue(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value?.toString().trim().toLowerCase();
  if (text == null || text.isEmpty) return null;
  if (text == '1' || text == 'true' || text == 'yes') return true;
  if (text == '0' || text == 'false' || text == 'no') return false;
  return null;
}
