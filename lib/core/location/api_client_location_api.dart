import 'package:navri_location_engine/navri_location_engine.dart';

import '../api_client.dart';

/// Lets the shared location engine speak through this app's own `ApiClient`.
///
/// The engine deliberately knows nothing about base URLs, auth headers or the
/// member's language; this is the one place that maps its five questions onto
/// the calls this app already makes. The Suchak app has its own equivalent, so
/// neither app has to adopt the other's networking to share the engine.
class ApiClientLocationApi implements LocationApi {
  const ApiClientLocationApi({required this.locale});

  /// Sent on every call so rows come back in the member's language. The engine
  /// matches on the untranslated names carried alongside, so a Marathi label
  /// never stops a Latin-script geocoder result from matching.
  final String locale;

  @override
  Future<List<Map<String, dynamic>>> states() {
    return ApiClient.getInternalLocationStates();
  }

  @override
  Future<List<Map<String, dynamic>>> districtsForState(int stateId) {
    return ApiClient.getInternalLocationDistricts(stateId: stateId);
  }

  @override
  Future<List<Map<String, dynamic>>> talukasForDistrict(int districtId) {
    return ApiClient.getInternalLocationTalukas(districtId: districtId);
  }

  @override
  Future<Map<String, dynamic>> children({
    required int parentId,
    String? query,
    required int page,
    required int limit,
    String? filter,
  }) {
    return ApiClient.getInternalLocationChildren(
      parentId: parentId,
      query: query,
      page: page,
      limit: limit,
      locale: locale,
      filter: filter,
    );
  }

  @override
  Future<Map<String, dynamic>> search({
    required String query,
    required int page,
    required int limit,
    int? preferredStateId,
  }) {
    return ApiClient.searchLocationsForOnboarding(
      query: query,
      page: page,
      limit: limit,
      locale: locale,
      preferredStateId: preferredStateId,
    );
  }
}
