/// Resolving place text to a row in the Navri location hierarchy.
///
/// Shared by the member app and the Suchak app so the two cannot drift apart
/// again, and written without any UI so a future caller — resolving an address
/// read off a scanned biodata, for instance — can use the same rules.
library;

export 'src/location_api.dart';
export 'src/location_engine.dart';
export 'src/onboarding_option.dart';
export 'src/paged_lookup_response.dart';
export 'src/value_parsing.dart';
