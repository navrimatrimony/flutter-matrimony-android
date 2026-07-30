import 'package:navri_location_engine/navri_location_engine.dart';
import 'package:test/test.dart';

/// A hierarchy small enough to reason about, shaped like the real one.
///
/// Renavi is the case that matters: a village whose name also exists in another
/// district. A national search cannot tell the two apart, which is why the walk
/// exists.
class _FakeLocationApi implements LocationApi {
  _FakeLocationApi();

  final List<String> calls = <String>[];

  @override
  Future<List<Map<String, dynamic>>> states() async {
    calls.add('states');
    return [
      {'id': 1, 'name': 'Maharashtra', 'parent_id': 100},
      {'id': 2, 'name': 'Madhya Pradesh', 'parent_id': 100},
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> districtsForState(int stateId) async {
    calls.add('districts:$stateId');
    if (stateId != 1) return [];
    return [
      {'id': 11, 'name': 'Sangli', 'parent_id': 1},
      {'id': 12, 'name': 'Pune', 'parent_id': 1},
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> talukasForDistrict(int districtId) async {
    calls.add('talukas:$districtId');
    return [
      {'id': 111, 'name': 'Khanapur', 'parent_id': 11},
    ];
  }

  @override
  Future<Map<String, dynamic>> children({
    required int parentId,
    String? query,
    required int page,
    required int limit,
    String? filter,
  }) async {
    calls.add('children:$parentId:${query ?? ''}');
    if (parentId == 11) {
      return _rows([_khanapur]);
    }
    if (parentId == 111 && (query ?? '').toLowerCase().contains('renavi')) {
      return _rows([_renaviInSangli]);
    }
    return _rows(const []);
  }

  @override
  Future<Map<String, dynamic>> search({
    required String query,
    required int page,
    required int limit,
    int? preferredStateId,
  }) async {
    calls.add('search:$query');
    if (query.toLowerCase() == 'india') {
      return _rows([
        {
          'id': 100,
          'label': 'India',
          'type': 'country',
          'status': 'approved',
          'is_final_node': false,
        },
      ]);
    }
    // A national search finds both Renavis and has no way to choose.
    if (query.toLowerCase().contains('renavi')) {
      return _rows([_renaviInSatara, _renaviInSangli]);
    }
    return _rows(const []);
  }

  static const Map<String, dynamic> _khanapur = {
    'id': 111,
    'label': 'Khanapur',
    'type': 'taluka',
    'status': 'approved',
    'is_final_node': false,
  };

  static const Map<String, dynamic> _renaviInSangli = {
    'id': 501,
    'label': 'Renavi',
    'name_en': 'Renavi',
    'type': 'village',
    'status': 'approved',
    'is_final_node': true,
    'parent': {
      'state': {'id': 1, 'label': 'Maharashtra', 'name_en': 'Maharashtra'},
      'district': {'id': 11, 'label': 'Sangli', 'name_en': 'Sangli'},
      'taluka': {'id': 111, 'label': 'Khanapur', 'name_en': 'Khanapur'},
    },
  };

  static const Map<String, dynamic> _renaviInSatara = {
    'id': 777,
    'label': 'Renavi',
    'name_en': 'Renavi',
    'type': 'village',
    'status': 'approved',
    'is_final_node': true,
    'parent': {
      'state': {'id': 1, 'label': 'Maharashtra', 'name_en': 'Maharashtra'},
      'district': {'id': 13, 'label': 'Satara', 'name_en': 'Satara'},
    },
  };

  static Map<String, dynamic> _rows(List<Map<String, dynamic>> rows) {
    return {
      'success': true,
      'results': rows,
      'pagination': {'has_more': false},
    };
  }
}

LocationEngine _engine(_FakeLocationApi api) =>
    LocationEngine(api: api, unknownLabel: () => 'Unknown');

void main() {
  group('name matching', () {
    test('matches a Devanagari label against a Latin geocoder answer', () {
      final option = OnboardingOption(
        id: 1,
        label: 'सांगली',
        meta: const {'name_en': 'Sangli'},
      );

      expect(LocationEngine.findNamed([option], 'Sangli'), option);
    });

    test('ignores the administrative words a geocoder adds', () {
      expect(LocationEngine.textMatches('Pune', 'Pune District'), isTrue);
      expect(LocationEngine.textMatches('Khanapur', 'Khanapur Taluka'), isTrue);
    });

    test('does not let a short name swallow a different one', () {
      // Both normalise to three letters, so containment must not apply.
      expect(LocationEngine.textMatches('Pen', 'Pun'), isFalse);
    });

    test('prefers an exact name over one that merely contains it', () {
      final exact = OnboardingOption(id: 1, label: 'Karad');
      final longer = OnboardingOption(id: 2, label: 'Karadkhel');

      expect(LocationEngine.findNamed([longer, exact], 'Karad'), exact);
    });
  });

  group('selectability', () {
    test('a district is walked through, never chosen', () {
      final district = OnboardingOption(
        id: 11,
        label: 'Sangli',
        meta: const {
          'type': 'district',
          'status': 'approved',
          'is_final_node': false,
        },
      );

      expect(LocationEngine.isSelectable(district), isFalse);
    });

    test('a row still awaiting approval can be chosen', () {
      // The member just asked for it to exist; blocking them until an admin
      // wakes up would strand them on the step.
      final pending = OnboardingOption(
        id: 900,
        label: 'New Wadi',
        meta: const {'status': 'pending'},
      );

      expect(LocationEngine.isSelectable(pending), isTrue);
    });
  });

  group('resolving a GPS fix', () {
    test('walks down to the village inside the right district', () async {
      final api = _FakeLocationApi();

      final resolved = await _engine(api).resolvePlace({
        'country_en': 'India',
        'state_en': 'Maharashtra',
        'district_en': 'Sangli',
        'locality_en': 'Renavi',
      });

      expect(resolved.state?.label, 'Maharashtra');
      expect(resolved.district?.label, 'Sangli');
      expect(resolved.leaf?.intId, 501, reason: 'the Renavi under Sangli');
    });

    test('never falls back to searching the whole country', () async {
      final api = _FakeLocationApi();

      // No state and no district — the walk cannot get started.
      final resolved = await _engine(api).resolvePlace({
        'locality_en': 'Renavi',
      });

      expect(resolved.leaf, isNull);
      expect(
        api.calls.where((call) => call.startsWith('search:Renavi')),
        isEmpty,
        reason: 'a national search would pick between two identical names',
      );
    });

    test('keeps the ancestors it did resolve when the leaf is not found', () async {
      final api = _FakeLocationApi();

      final resolved = await _engine(api).resolvePlace({
        'state_en': 'Maharashtra',
        'district_en': 'Sangli',
        'locality_en': 'Nowhere At All',
      });

      expect(resolved.leaf, isNull);
      expect(resolved.district?.label, 'Sangli');
    });

    test('a state it cannot place stops the walk instead of guessing', () async {
      final api = _FakeLocationApi();

      final resolved = await _engine(api).resolvePlace({
        'state_en': 'Atlantis',
        'locality_en': 'Renavi',
      });

      expect(resolved.state, isNull);
      expect(resolved.leaf, isNull);
    });
  });

  group('caching', () {
    test('asks for a list once however often it is needed', () async {
      final api = _FakeLocationApi();
      final engine = _engine(api);

      await engine.states();
      await engine.states();
      await engine.states();

      expect(api.calls.where((call) => call == 'states').length, 1);
    });
  });
}
