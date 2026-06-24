class ProfileSummary {
  const ProfileSummary({
    this.id,
    this.profileStatus,
    this.lifecycleState,
    this.isSearchable = false,
    this.photoUploaded,
    this.photoApproved,
    this.locationValid,
    this.raw = const <String, dynamic>{},
  });

  final int? id;
  final String? profileStatus;
  final String? lifecycleState;
  final bool isSearchable;
  final bool? photoUploaded;
  final bool? photoApproved;
  final bool? locationValid;
  final Map<String, dynamic> raw;

  factory ProfileSummary.fromJson(Map<String, dynamic>? json) {
    final source = json ?? <String, dynamic>{};
    return ProfileSummary(
      id: _intValue(source['id'] ?? source['profile_id']),
      profileStatus: _stringValue(source['profile_status']),
      lifecycleState: _stringValue(source['lifecycle_state']),
      isSearchable: _boolValue(source['is_searchable']) ?? false,
      photoUploaded: _boolValue(source['photo_uploaded']),
      photoApproved: _boolValue(source['photo_approved']),
      locationValid: _boolValue(source['location_valid']),
      raw: Map<String, dynamic>.from(source),
    );
  }

  static ProfileSummary? maybeFrom(dynamic value) {
    if (value is Map) {
      return ProfileSummary.fromJson(Map<String, dynamic>.from(value));
    }
    return null;
  }
}

String? _stringValue(dynamic value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return null;
  return text;
}

int? _intValue(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
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
