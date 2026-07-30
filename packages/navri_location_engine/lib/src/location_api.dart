/// The five calls the engine needs from whoever owns the network.
///
/// Deliberately an interface rather than a concrete client: the member app and
/// the Suchak app each have their own `ApiClient` with its own base URL, auth
/// header and locale handling, and neither should have to know the other
/// exists. The engine only cares that these five questions can be answered.
///
/// It also keeps the engine testable without a server, and leaves room for a
/// caller that is not an app at all — a scanned-address resolver, say, reading
/// the same hierarchy through a different transport.
abstract class LocationApi {
  /// Every state, unfiltered. The engine caches the result.
  Future<List<Map<String, dynamic>>> states();

  Future<List<Map<String, dynamic>>> districtsForState(int stateId);

  Future<List<Map<String, dynamic>>> talukasForDistrict(int districtId);

  /// Rows directly under [parentId]. [query] is already trimmed, and is null
  /// when the caller wants the unfiltered list. [filter] narrows by hierarchy
  /// type; null means no narrowing.
  Future<Map<String, dynamic>> children({
    required int parentId,
    String? query,
    required int page,
    required int limit,
    String? filter,
  });

  /// Name search across the hierarchy. [preferredStateId] only reorders
  /// results; it must not exclude anything.
  Future<Map<String, dynamic>> search({
    required String query,
    required int page,
    required int limit,
    int? preferredStateId,
  });
}
