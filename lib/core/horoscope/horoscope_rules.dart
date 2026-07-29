import 'dart:convert';

/// A nakshatra/rashi/charan selection plus the values derived from it.
///
/// Plain value object — no Flutter dependency — so every surface (edit
/// profile, onboarding, any future screen) reconciles the same way.
class HoroscopeSelection {
  const HoroscopeSelection({
    this.nakshatraId,
    this.rashiId,
    this.charan,
    this.ganId,
    this.nadiId,
    this.yoniId,
  });

  final int? nakshatraId;
  final int? rashiId;
  final int? charan;
  final int? ganId;
  final int? nadiId;
  final int? yoniId;

  HoroscopeSelection copyWith({
    int? nakshatraId,
    bool clearNakshatraId = false,
    int? rashiId,
    bool clearRashiId = false,
    int? charan,
    bool clearCharan = false,
    int? ganId,
    bool clearGanId = false,
    int? nadiId,
    bool clearNadiId = false,
    int? yoniId,
    bool clearYoniId = false,
  }) {
    return HoroscopeSelection(
      nakshatraId: clearNakshatraId ? null : (nakshatraId ?? this.nakshatraId),
      rashiId: clearRashiId ? null : (rashiId ?? this.rashiId),
      charan: clearCharan ? null : (charan ?? this.charan),
      ganId: clearGanId ? null : (ganId ?? this.ganId),
      nadiId: clearNadiId ? null : (nadiId ?? this.nadiId),
      yoniId: clearYoniId ? null : (yoniId ?? this.yoniId),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is HoroscopeSelection &&
        other.nakshatraId == nakshatraId &&
        other.rashiId == rashiId &&
        other.charan == charan &&
        other.ganId == ganId &&
        other.nadiId == nadiId &&
        other.yoniId == yoniId;
  }

  @override
  int get hashCode =>
      Object.hash(nakshatraId, rashiId, charan, ganId, nadiId, yoniId);

  @override
  String toString() {
    return 'HoroscopeSelection(nakshatra: $nakshatraId, rashi: $rashiId, '
        'charan: $charan, gan: $ganId, nadi: $nadiId, yoni: $yoniId)';
  }
}

/// Gan / nadi / yoni attributes derived from a nakshatra.
class HoroscopeAttributes {
  const HoroscopeAttributes({this.ganId, this.nadiId, this.yoniId});

  final int? ganId;
  final int? nadiId;
  final int? yoniId;
}

/// UI-free reader over the server `horoscope_rules` payload.
///
/// Expected shape (all parts optional — an empty map is legal and makes every
/// lookup fall back to "no restriction"):
///
/// ```
/// {
///   "nakshatra_attributes": [ {nakshatra_id, gan_id, nadi_id, yoni_id}, ... ],
///   "rashi_rules": [ {nakshatra_id, charan, rashi_id}, ... ],
///   "distinct_rashi_ids_by_nakshatra": { "<nakshatraId>": [rashiId, ...] },
///   "nakshatra_ids_by_rashi": { "<rashiId>": [nakshatraId, ...] }
/// }
/// ```
class HoroscopeRules {
  HoroscopeRules(Map<String, dynamic>? raw)
    : _raw = raw == null ? const <String, dynamic>{} : Map.of(raw);

  /// Rules-less instance: every lookup degrades to the unfiltered defaults.
  static final HoroscopeRules empty = HoroscopeRules(
    const <String, dynamic>{},
  );

  /// Charans offered when the rules cannot narrow the list.
  static const List<int> defaultCharans = <int>[1, 2, 3, 4];

  final Map<String, dynamic> _raw;

  bool get isEmpty => _raw.isEmpty;

  bool get isNotEmpty => _raw.isNotEmpty;

  Map<String, dynamic> get raw => Map.unmodifiable(_raw);

  // ---------------------------------------------------------------------
  // Lookups
  // ---------------------------------------------------------------------

  /// Rashi ids allowed for [nakshatraId]. Empty means "no restriction".
  List<int> allowedRashiIds(int? nakshatraId) {
    return _idList('distinct_rashi_ids_by_nakshatra', nakshatraId);
  }

  /// Nakshatra ids allowed for [rashiId]. Empty means "no restriction".
  List<int> allowedNakshatraIds(int? rashiId) {
    return _idList('nakshatra_ids_by_rashi', rashiId);
  }

  /// Charans valid for the given pair. Falls back to [defaultCharans] when the
  /// pair is incomplete or the rules say nothing about it.
  List<int> validCharans({int? nakshatraId, int? rashiId}) {
    if (nakshatraId == null || rashiId == null) return defaultCharans;

    final charans = ruleRows('rashi_rules')
        .where((row) {
          return readInt(row['nakshatra_id']) == nakshatraId &&
              readInt(row['rashi_id']) == rashiId;
        })
        .map((row) => readInt(row['charan']))
        .whereType<int>()
        .toSet()
        .toList();
    charans.sort();

    return charans.isEmpty ? defaultCharans : charans;
  }

  /// The rashi implied by a (nakshatra, charan) pair, if the rules know it.
  int? rashiIdFor({required int? nakshatraId, required int? charan}) {
    final rule = rashiRuleFor(nakshatraId: nakshatraId, charan: charan);
    return rule == null ? null : readInt(rule['rashi_id']);
  }

  /// Raw `rashi_rules` row matching the given filters (null filters ignored).
  Map<String, dynamic>? rashiRuleFor({
    required int? nakshatraId,
    int? charan,
    int? rashiId,
  }) {
    if (nakshatraId == null) return null;

    for (final row in ruleRows('rashi_rules')) {
      if (readInt(row['nakshatra_id']) != nakshatraId) continue;
      if (charan != null && readInt(row['charan']) != charan) continue;
      if (rashiId != null && readInt(row['rashi_id']) != rashiId) continue;

      return row;
    }

    return null;
  }

  /// Raw `nakshatra_attributes` row for [nakshatraId].
  Map<String, dynamic>? nakshatraAttributeRow(int? nakshatraId) {
    if (nakshatraId == null) return null;

    for (final row in ruleRows('nakshatra_attributes')) {
      if (readInt(row['nakshatra_id']) == nakshatraId) {
        return row;
      }
    }

    return null;
  }

  /// Gan / nadi / yoni derived from [nakshatraId]; null when unknown.
  HoroscopeAttributes? attributesFor(int? nakshatraId) {
    final row = nakshatraAttributeRow(nakshatraId);
    if (row == null) return null;

    return HoroscopeAttributes(
      ganId: readInt(row['gan_id']),
      nadiId: readInt(row['nadi_id']),
      yoniId: readInt(row['yoni_id']),
    );
  }

  /// Yoni ids allowed for [nakshatraId]. Empty means "no restriction".
  List<int> allowedYoniIds(int? nakshatraId) {
    final yoniId = attributesFor(nakshatraId)?.yoniId;
    return yoniId == null ? const <int>[] : <int>[yoniId];
  }

  List<Map<String, dynamic>> ruleRows(String key) => _readRows(_raw[key]);

  // ---------------------------------------------------------------------
  // Reconciliation
  // ---------------------------------------------------------------------

  /// Given a selection whose nakshatra / rashi / charan may have just changed,
  /// return the selection with every dependent value repaired: an invalid rashi
  /// or charan is replaced, gan/nadi/yoni are derived from the nakshatra, and a
  /// nakshatra that does not belong to the chosen rashi is cleared.
  HoroscopeSelection reconcile(HoroscopeSelection selection) {
    var nakshatraId = selection.nakshatraId;
    var rashiId = selection.rashiId;
    var charan = selection.charan;
    var ganId = selection.ganId;
    var nadiId = selection.nadiId;
    var yoniId = selection.yoniId;

    if (nakshatraId != null) {
      final attrs = attributesFor(nakshatraId);
      if (attrs != null) {
        ganId ??= attrs.ganId;
        nadiId ??= attrs.nadiId;
        if (attrs.yoniId != null && yoniId != null && yoniId != attrs.yoniId) {
          yoniId = null;
        }
        yoniId ??= attrs.yoniId;
      }

      if (charan != null && charan >= 1 && charan <= 4 && rashiId == null) {
        rashiId = rashiIdFor(nakshatraId: nakshatraId, charan: charan);
      }

      final allowedRashis = allowedRashiIds(nakshatraId);
      if (allowedRashis.isNotEmpty &&
          rashiId != null &&
          !allowedRashis.contains(rashiId)) {
        rashiId = allowedRashis.first;
      }

      final charans = validCharans(nakshatraId: nakshatraId, rashiId: rashiId);
      if (charan != null && charans.isNotEmpty && !charans.contains(charan)) {
        charan = charans.first;
      }
    } else {
      ganId = null;
      nadiId = null;
      yoniId = null;
    }

    if (rashiId != null) {
      final allowedNakshatras = allowedNakshatraIds(rashiId);
      if (allowedNakshatras.isNotEmpty &&
          nakshatraId != null &&
          !allowedNakshatras.contains(nakshatraId)) {
        nakshatraId = null;
        charan = null;
        ganId = null;
        nadiId = null;
        yoniId = null;
      }
    }

    return HoroscopeSelection(
      nakshatraId: nakshatraId,
      rashiId: rashiId,
      charan: charan,
      ganId: ganId,
      nadiId: nadiId,
      yoniId: yoniId,
    );
  }

  // ---------------------------------------------------------------------
  // Parsing helpers (shared so both screens read the payload identically)
  // ---------------------------------------------------------------------

  static int? readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static Map<String, dynamic> readMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);

    return <String, dynamic>{};
  }

  static List<Map<String, dynamic>> _readRows(dynamic value) {
    if (value is! List) return <Map<String, dynamic>>[];

    return value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  static List<int> readIntList(dynamic value) {
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return <int>[];
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is List) {
          return decoded
              .map(readInt)
              .whereType<int>()
              .toSet()
              .toList(growable: false);
        }
      } catch (_) {
        return trimmed
            .split(',')
            .map(readInt)
            .whereType<int>()
            .toSet()
            .toList(growable: false);
      }
    }

    if (value is! List) return <int>[];

    return value
        .map((item) {
          if (item is Map) return readInt(item['id']);
          return readInt(item);
        })
        .whereType<int>()
        .toSet()
        .toList(growable: false);
  }

  List<int> _idList(String groupKey, int? id) {
    if (id == null) return <int>[];

    final group = readMap(_raw[groupKey]);
    return readIntList(group[id.toString()]);
  }
}
