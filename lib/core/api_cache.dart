typedef ApiCacheLoader<T> = Future<T> Function();
typedef ApiCacheCopier<T> = T Function(T value);
typedef ApiCacheShouldStore<T> = bool Function(T value);

class ApiCacheEntry {
  const ApiCacheEntry({
    required this.value,
    required this.storedAt,
    required this.ttl,
    required this.tags,
  });

  final Object? value;
  final DateTime storedAt;
  final Duration ttl;
  final Set<String> tags;

  bool isFresh(DateTime now) => now.difference(storedAt) < ttl;
}

class ApiCache {
  ApiCache._();

  static final ApiCache instance = ApiCache._();

  final Map<String, ApiCacheEntry> _entries = <String, ApiCacheEntry>{};
  final Map<String, Future<Object?>> _inFlight = <String, Future<Object?>>{};

  Future<T> remember<T>({
    required String key,
    required Duration ttl,
    required ApiCacheLoader<T> fetch,
    ApiCacheCopier<T>? copy,
    ApiCacheShouldStore<T>? shouldStore,
    Set<String> tags = const <String>{},
    bool forceRefresh = false,
    bool serveStaleOnError = true,
  }) async {
    final now = DateTime.now();
    final cached = _entries[key];
    if (!forceRefresh && cached != null && cached.isFresh(now)) {
      return _copyValue<T>(cached.value, copy);
    }

    final inFlight = _inFlight[key];
    if (inFlight != null) {
      final value = await inFlight;
      return _copyValue<T>(value, copy);
    }

    final future = fetch().then<Object?>((value) {
      if (shouldStore?.call(value) ?? true) {
        _entries[key] = ApiCacheEntry(
          value: copy == null ? value : copy(value),
          storedAt: DateTime.now(),
          ttl: ttl,
          tags: Set<String>.from(tags),
        );
      }
      return value;
    });

    _inFlight[key] = future;
    try {
      final value = await future;
      return _copyValue<T>(value, copy);
    } catch (_) {
      if (serveStaleOnError && cached != null) {
        return _copyValue<T>(cached.value, copy);
      }
      rethrow;
    } finally {
      _inFlight.remove(key);
    }
  }

  void invalidateTags(Iterable<String> tags) {
    final tagSet = tags.toSet();
    if (tagSet.isEmpty) return;

    _entries.removeWhere((_, entry) {
      return entry.tags.any(tagSet.contains);
    });
  }

  void invalidateKey(String key) {
    _entries.remove(key);
  }

  void clear() {
    _entries.clear();
    _inFlight.clear();
  }

  T _copyValue<T>(Object? value, ApiCacheCopier<T>? copy) {
    final typed = value as T;
    return copy == null ? typed : copy(typed);
  }
}
