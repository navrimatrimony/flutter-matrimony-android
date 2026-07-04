import 'package:flutter_matrimony_android/core/api_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(ApiCache.instance.clear);
  tearDown(ApiCache.instance.clear);

  test('returns a fresh cached copy without refetching', () async {
    var fetchCount = 0;

    Future<Map<String, dynamic>> loadProfile() async {
      fetchCount++;
      return <String, dynamic>{'name': 'Cached profile'};
    }

    final first = await ApiCache.instance.remember<Map<String, dynamic>>(
      key: 'profile',
      ttl: const Duration(minutes: 1),
      tags: const <String>{'profile'},
      fetch: loadProfile,
      copy: (value) => Map<String, dynamic>.from(value),
    );
    first['name'] = 'Mutated locally';

    final second = await ApiCache.instance.remember<Map<String, dynamic>>(
      key: 'profile',
      ttl: const Duration(minutes: 1),
      tags: const <String>{'profile'},
      fetch: loadProfile,
      copy: (value) => Map<String, dynamic>.from(value),
    );

    expect(fetchCount, 1);
    expect(second['name'], 'Cached profile');
  });

  test('invalidates entries by tag', () async {
    var fetchCount = 0;

    Future<int> loadValue() async {
      fetchCount++;
      return fetchCount;
    }

    final first = await ApiCache.instance.remember<int>(
      key: 'profile',
      ttl: const Duration(minutes: 1),
      tags: const <String>{'profile'},
      fetch: loadValue,
    );

    ApiCache.instance.invalidateTags(const <String>{'profile'});

    final second = await ApiCache.instance.remember<int>(
      key: 'profile',
      ttl: const Duration(minutes: 1),
      tags: const <String>{'profile'},
      fetch: loadValue,
    );

    expect(first, 1);
    expect(second, 2);
  });

  test('serves stale data when refresh fails', () async {
    var failRefresh = false;

    Future<String> loadValue() async {
      if (failRefresh) {
        throw Exception('network failed');
      }
      return 'stale fallback';
    }

    await ApiCache.instance.remember<String>(
      key: 'lookup',
      ttl: Duration.zero,
      tags: const <String>{'lookups'},
      fetch: loadValue,
    );

    failRefresh = true;

    final value = await ApiCache.instance.remember<String>(
      key: 'lookup',
      ttl: Duration.zero,
      tags: const <String>{'lookups'},
      fetch: loadValue,
    );

    expect(value, 'stale fallback');
  });
}
