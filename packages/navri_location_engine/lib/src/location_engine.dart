import 'location_api.dart';
import 'onboarding_option.dart';
import 'paged_lookup_response.dart';
import 'value_parsing.dart';

/// Turns place text into a row in the location hierarchy.
///
/// Two apps ask this question — the member app during onboarding and the Suchak
/// app while entering a customer — and a scanned biodata will ask it too. They
/// used to ask it with separate copies of the same code, which drifted: one got
/// the top-down walk and the other kept searching the whole country. This is
/// that logic, once.
///
/// Nothing here touches a widget. The engine answers questions and returns
/// results; deciding what to show and what to store stays with the caller,
/// which is what lets a non-UI caller use it.
class LocationEngine {
  LocationEngine({
    required LocationApi api,
    required String Function() unknownLabel,
  }) : _api = api,
       _unknownLabel = unknownLabel;

  final LocationApi _api;

  /// What to call a row whose name did not survive the response. A callback
  /// rather than a string because each app words it in the member's language.
  final String Function() _unknownLabel;

  // ---------------------------------------------------------------------------
  // Reading a row
  // ---------------------------------------------------------------------------

  /// 'country' | 'state' | 'district' | 'taluka' | 'city' | 'suburb' | 'village'
  static String? typeOf(OnboardingOption? option) {
    if (option == null) return null;
    return option.metaText('type') ??
        option.metaText('hierarchy') ??
        onboardingText(option.raw['hierarchy']);
  }

  static int? parentIdOf(OnboardingOption? option) =>
      option?.metaInt('parent_id');

  /// A row is approved unless it says otherwise. Rows that predate the approval
  /// flow carry no status at all and must not be treated as rejected.
  static bool isApprovedRow(OnboardingOption option) {
    final status = option.metaText('status');
    return status == null || status == 'approved';
  }

  static bool isPending(OnboardingOption option) {
    return option.metaBool('is_pending_location') == true ||
        option.metaBool('is_custom_location') == true ||
        option.metaText('status') == 'pending';
  }

  /// Whether a row may be *chosen*, as opposed to merely walked through.
  ///
  /// Only leaves count: a district is a step on the way, not an answer. A
  /// pending row is selectable because the member just asked for it to exist
  /// and should not be blocked while it waits for approval.
  static bool isSelectable(OnboardingOption option) {
    if (isPending(option)) return true;
    return option.metaBool('is_final_node') == true &&
        option.metaText('status') == 'approved';
  }

  // ---------------------------------------------------------------------------
  // Matching by name
  // ---------------------------------------------------------------------------

  /// Every spelling of a location's own name the server sent.
  ///
  /// `label` is whatever the request's locale asked for, so on a Marathi phone
  /// it is Devanagari. The device geocoder answers in Latin, and the two never
  /// match. Matching has to see both scripts, and the payload carries them.
  static List<String> nameVariants(OnboardingOption option) {
    final variants = <String>[];
    for (final value in [
      option.label,
      option.metaText('name_en'),
      option.metaText('name_mr'),
      option.metaText('name'),
      option.metaText('display_name'),
    ]) {
      final text = value?.trim();
      if (text != null && text.isNotEmpty && !variants.contains(text)) {
        variants.add(text);
      }
    }

    return variants;
  }

  /// Finds [name] among [options], strictest match first.
  ///
  /// Exact, then fuzzy, then substring — in that order, because a loose rule
  /// applied early would shadow a row that matched exactly.
  static OnboardingOption? findNamed(
    List<OnboardingOption> options,
    String name,
  ) {
    final wanted = name.trim().toLowerCase();
    for (final option in options) {
      for (final variant in nameVariants(option)) {
        if (variant.toLowerCase() == wanted) return option;
      }
    }
    for (final option in options) {
      for (final variant in nameVariants(option)) {
        if (textMatches(variant, name)) return option;
      }
    }
    for (final option in options) {
      for (final variant in nameVariants(option)) {
        if (variant.toLowerCase().contains(wanted)) return option;
      }
    }
    return null;
  }

  /// Whether two place names mean the same place.
  ///
  /// Containment only counts for names of four characters or more, or short
  /// names would swallow each other — "Pen" inside "Pune".
  static bool textMatches(String? left, String? right) {
    final a = normalizeForCompare(left);
    final b = normalizeForCompare(right);
    if (a == null || b == null) return false;
    if (a == b) return true;
    if (a.length >= 4 && b.length >= 4) {
      return a.contains(b) || b.contains(a);
    }
    return false;
  }

  /// Strips what a geocoder adds and our data does not: punctuation, and the
  /// administrative words that ride along with the name ("Pune District").
  static String? normalizeForCompare(String? value) {
    final text = value?.trim().toLowerCase();
    if (text == null || text.isEmpty) return null;
    final normalized = text
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(
          RegExp(
            r'\b(district|dist|division|state|taluka|tehsil|city|village)\b',
          ),
          ' ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return normalized.isEmpty ? null : normalized;
  }

  // ---------------------------------------------------------------------------
  // Ancestors carried on a row
  // ---------------------------------------------------------------------------

  /// Rebuilds an ancestor as a selectable-looking option from the `parent` block
  /// the server attaches to every leaf, so the caller can show the whole chain
  /// without another round trip.
  static OnboardingOption? parentOption(OnboardingOption option, String key) {
    final parent = option.raw['parent'];
    if (parent is! Map) return null;
    final value = parent[key];
    if (value is! Map) return null;
    final id = onboardingInt(value['id']);
    final label = onboardingText(value['label'] ?? value['name']);
    if (id == null || label == null) return null;
    return OnboardingOption(
      id: id,
      label: label,
      meta: <String, dynamic>{
        'type': key,
        'hierarchy': key,
        'status': 'approved',
        'is_final_node': false,
      },
      raw: <String, dynamic>{
        'id': id,
        'location_id': id,
        'label': label,
        'name': label,
        'type': key,
        'hierarchy': key,
      },
    );
  }

  static String? parentLabel(OnboardingOption option, String key) {
    final variants = parentLabelVariants(option, key);
    return variants.isEmpty ? null : variants.first;
  }

  /// Both spellings of an ancestor's name, for the same reason as
  /// [nameVariants]: the label follows the request locale, the device geocoder
  /// does not.
  static List<String> parentLabelVariants(OnboardingOption option, String key) {
    final parent = option.raw['parent'];
    if (parent is! Map) return const <String>[];
    final value = parent[key];
    if (value is! Map) {
      final text = onboardingText(value);
      return text == null ? const <String>[] : <String>[text];
    }

    final variants = <String>[];
    for (final candidate in [
      value['label'],
      value['name_en'],
      value['name_mr'],
      value['name'],
    ]) {
      final text = onboardingText(candidate);
      if (text != null && !variants.contains(text)) variants.add(text);
    }

    return variants;
  }

  // ---------------------------------------------------------------------------
  // Lists and paging
  // ---------------------------------------------------------------------------

  List<OnboardingOption>? _states;
  final Map<int, List<OnboardingOption>> _districtsByState =
      <int, List<OnboardingOption>>{};
  final Map<int, List<OnboardingOption>> _talukasByDistrict =
      <int, List<OnboardingOption>>{};

  /// Every state, fetched once. The list does not change while an app runs, and
  /// the picker asks for it on every keystroke.
  Future<List<OnboardingOption>> states() async {
    final cached = _states;
    if (cached != null) return cached;

    final rows = await _api.states();
    final options = rows
        .map((row) => hierarchyOption(row, 'state'))
        .where((option) => option.intId != null)
        .toList();
    _states = options;
    return options;
  }

  Future<List<OnboardingOption>> districtsForState(
    OnboardingOption state,
  ) async {
    final stateId = state.intId;
    if (stateId == null) return const <OnboardingOption>[];

    final cached = _districtsByState[stateId];
    if (cached != null) return cached;

    final rows = await _api.districtsForState(stateId);
    final options = rows
        .map((row) => hierarchyOption(row, 'district'))
        .where((option) => option.intId != null)
        .toList();
    _districtsByState[stateId] = options;
    return options;
  }

  Future<List<OnboardingOption>> talukasForDistrict(
    OnboardingOption district,
  ) async {
    final districtId = district.intId;
    if (districtId == null) return const <OnboardingOption>[];

    final cached = _talukasByDistrict[districtId];
    if (cached != null) return cached;

    final rows = await _api.talukasForDistrict(districtId);
    final options = rows
        .map((row) => hierarchyOption(row, 'taluka'))
        .where((option) => option.intId != null)
        .toList();
    _talukasByDistrict[districtId] = options;
    return options;
  }

  /// Builds an ancestor row (state / district / taluka) from a lookup response.
  ///
  /// `is_final_node: false` on purpose — these are rungs on the ladder, and
  /// letting one be chosen would store a district where a village belongs.
  OnboardingOption hierarchyOption(Map<String, dynamic> row, String type) {
    final id = onboardingInt(row['id'] ?? row['location_id']);
    final label =
        onboardingText(row['label'] ?? row['name'] ?? row['display_label']) ??
        _unknownLabel();
    final parentId = onboardingInt(row['parent_id']);

    return OnboardingOption(
      id: id,
      key: onboardingText(row['slug'] ?? row['key']),
      label: label,
      meta: <String, dynamic>{
        'type': type,
        'hierarchy': type,
        'status': 'approved',
        'is_final_node': false,
        if (parentId != null) 'parent_id': parentId,
      },
      raw: <String, dynamic>{
        ...row,
        'id': id,
        'location_id': id,
        'label': label,
        'type': type,
        'hierarchy': type,
        if (parentId != null) 'parent_id': parentId,
      },
    );
  }

  /// A single-character query matches half the country, so nothing is sent
  /// until there are two.
  Future<PagedLookupResponse> search(
    String query,
    int page,
    int limit, {
    int? preferredStateId,
  }) async {
    if (query.trim().length < 2) {
      return PagedLookupResponse.fromOptions(const []);
    }
    return PagedLookupResponse.fromJson(
      await _api.search(
        query: query,
        page: page,
        limit: limit,
        preferredStateId: preferredStateId,
      ),
    );
  }

  Future<PagedLookupResponse> childrenOf({
    required OnboardingOption parent,
    required String query,
    required int page,
    required int limit,
    String? filter,
  }) async {
    final parentId = parent.intId;
    if (parentId == null) return PagedLookupResponse.fromOptions(const []);

    return PagedLookupResponse.fromJson(
      await _api.children(
        parentId: parentId,
        query: query.trim().length < 2 ? null : query.trim(),
        page: page,
        limit: limit,
        filter: filter == null || filter == 'all' ? null : filter,
      ),
    );
  }

  /// The first approved row of [type] matching [query].
  Future<OnboardingOption?> findByType(String query, String type) async {
    final page = await search(query, 1, 20);
    for (final option in page.results) {
      if (typeOf(option) == type && isApprovedRow(option)) {
        return option;
      }
    }
    return null;
  }

  /// Pages a list already held in memory, so a picker backed by a cached list
  /// behaves like one backed by the server.
  static PagedLookupResponse pageOf(
    List<OnboardingOption> options,
    String query,
    int page,
    int limit,
  ) {
    final q = query.trim().toLowerCase();
    final rows = options.where((option) {
      return q.isEmpty ||
          option.label.toLowerCase().startsWith(q) ||
          (option.key?.toLowerCase().startsWith(q) ?? false);
    }).toList();
    final start = (page - 1) * limit;
    final pageRows = start >= rows.length
        ? <OnboardingOption>[]
        : rows.skip(start).take(limit).toList();
    return PagedLookupResponse(
      success: true,
      results: pageRows,
      pagination: LookupPagination(
        page: page,
        perPage: limit,
        total: rows.length,
        hasMore: start + pageRows.length < rows.length,
      ),
    );
  }

  static List<OnboardingOption> unique(List<OnboardingOption> options) {
    final seen = <String>{};
    final out = <OnboardingOption>[];
    for (final option in options) {
      if (seen.add(option.identity)) out.add(option);
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // Resolving a place description
  // ---------------------------------------------------------------------------

  /// Reads a value out of a geocoder payload, ignoring blanks.
  static String? placeText(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  static List<String> placeTexts(Map<String, dynamic> data, List<String> keys) {
    final seen = <String>{};
    final values = <String>[];
    for (final key in keys) {
      final text = placeText(data[key]);
      if (text == null) continue;
      if (seen.add(text.toLowerCase())) values.add(text);
    }
    return values;
  }

  /// The names worth searching for, most specific first.
  ///
  /// Order is the point: a sub-locality identifies a place, a district barely
  /// narrows it. The address line is split on commas last, as a fallback for
  /// when the geocoder filled nothing structured.
  static List<String> searchTermsFor(Map<String, dynamic> data) {
    final seen = <String>{};
    final terms = <String>[];
    void addTerm(dynamic value) {
      final text = placeText(value);
      if (text == null || text.length < 2) return;
      if (seen.add(text.toLowerCase())) terms.add(text);
    }

    for (final value in [
      data['sub_locality_en'],
      data['sub_locality'],
      data['locality_en'],
      data['locality'],
      data['feature_name_en'],
      data['feature_name'],
      data['district_en'],
      data['district'],
    ]) {
      addTerm(value);
    }

    for (final key in const ['address_line_en', 'address_line']) {
      final addressLine = placeText(data[key]);
      if (addressLine == null) continue;
      for (final part in addressLine.split(',')) {
        addTerm(part);
      }
    }

    return terms;
  }

  /// How well a row answers the place description.
  ///
  /// Weighted by how much each field narrows things down: a sub-locality is
  /// nearly an answer on its own, a state is barely a hint.
  static int scoreFor(
    OnboardingOption option,
    Map<String, dynamic> data,
    String searchTerm,
  ) {
    final haystack = [
      ...nameVariants(option),
      option.metaText('display_hierarchy'),
      option.metaText('type'),
      option.metaText('tag'),
      parentLabel(option, 'state'),
      parentLabel(option, 'district'),
      parentLabel(option, 'taluka'),
      parentLabel(option, 'city'),
    ].whereType<String>().join(' ').toLowerCase();

    var score = 0;
    final normalizedSearchTerm = searchTerm.trim().toLowerCase();
    if (normalizedSearchTerm.isNotEmpty &&
        haystack.contains(normalizedSearchTerm)) {
      score += 6;
    }
    for (final entry in const [
      MapEntry('locality_en', 5),
      MapEntry('locality', 5),
      MapEntry('sub_locality_en', 5),
      MapEntry('sub_locality', 5),
      MapEntry('feature_name_en', 4),
      MapEntry('feature_name', 4),
      MapEntry('district_en', 3),
      MapEntry('district', 3),
      MapEntry('state_en', 2),
      MapEntry('state', 2),
    ]) {
      final text = placeText(data[entry.key])?.toLowerCase();
      if (text != null && haystack.contains(text)) score += entry.value;
    }
    return score;
  }

  /// Whether a row sits under the state and district the description names.
  ///
  /// Only checked against what the description actually says: a payload with no
  /// district cannot rule anything out on district.
  static bool hierarchyMatches(
    OnboardingOption option,
    Map<String, dynamic> data,
  ) {
    final stateTexts = placeTexts(data, const ['state_en', 'state']);
    if (stateTexts.isNotEmpty) {
      final stateLabels = parentLabelVariants(option, 'state');
      if (stateLabels.isEmpty ||
          !stateTexts.any(
            (text) => stateLabels.any((label) => textMatches(label, text)),
          )) {
        return false;
      }
    }

    final districtTexts = placeTexts(data, const ['district_en', 'district']);
    if (districtTexts.isNotEmpty) {
      final districtLabels = parentLabelVariants(option, 'district');
      if (districtLabels.isEmpty ||
          !districtTexts.any(
            (text) => districtLabels.any((label) => textMatches(label, text)),
          )) {
        return false;
      }
    }

    return true;
  }

  /// The best row among [options], or null when none is good enough.
  ///
  /// [minScore] is a floor rather than a tie-break: a weak best answer is worse
  /// than none, because a wrong village silently written into a profile is not
  /// something the member will notice.
  static OnboardingOption? bestMatch(
    List<OnboardingOption> options,
    Map<String, dynamic> data,
    String searchTerm, {
    bool requireHierarchyMatch = true,
    int minScore = 1,
  }) {
    final approved = options.where((option) {
      if (!isSelectable(option)) return false;
      if (!requireHierarchyMatch) return true;
      return hierarchyMatches(option, data);
    }).toList();
    if (approved.isEmpty) return null;
    approved.sort(
      (a, b) =>
          scoreFor(b, data, searchTerm).compareTo(scoreFor(a, data, searchTerm)),
    );
    final best = approved.first;
    return scoreFor(best, data, searchTerm) >= minScore ? best : null;
  }

  /// Searches for the leaf strictly INSIDE [parent] — the district when one was
  /// resolved, otherwise the state.
  ///
  /// Scope is the whole point. A village name looked up nationally competes
  /// with millions of rows and can land in the wrong district; the same name
  /// under one district is a choice among a few thousand, and the ancestors are
  /// already known to be right because the walk established them.
  Future<OnboardingOption?> findLeafUnder(
    OnboardingOption parent,
    Map<String, dynamic> data,
  ) async {
    final terms = searchTermsFor(data);
    if (terms.isEmpty) return null;

    for (final term in terms) {
      final direct = await childrenOf(
        parent: parent,
        query: term,
        page: 1,
        limit: 25,
      );
      final directMatch = bestMatch(
        direct.results,
        data,
        term,
        requireHierarchyMatch: false,
        minScore: 5,
      );
      if (directMatch != null) return directMatch;

      for (final area in direct.results) {
        if (typeOf(area) != 'taluka') continue;
        final nested = await childrenOf(
          parent: area,
          query: term,
          page: 1,
          limit: 25,
        );
        final nestedMatch = bestMatch(
          nested.results,
          data,
          term,
          requireHierarchyMatch: false,
          minScore: 5,
        );
        if (nestedMatch != null) return nestedMatch;
      }
    }

    return null;
  }

  /// Walks a place description down the hierarchy: country, state, district,
  /// then the leaf inside whichever of those was reached.
  ///
  /// Never searches the country by name. That was the old behaviour and it put
  /// members in the wrong district — the same village name exists in dozens of
  /// them, and a national search has nothing to choose by. If the walk cannot
  /// even establish a state, it returns what little it found rather than
  /// guessing at a leaf.
  Future<ResolvedPlace> resolvePlace(
    Map<String, dynamic> data, {
    OnboardingOption? fallbackCountry,
  }) async {
    final countryText =
        placeText(data['country_en']) ?? placeText(data['country']);
    final stateText = placeText(data['state_en']) ?? placeText(data['state']);
    final districtText =
        placeText(data['district_en']) ?? placeText(data['district']);

    final country = countryText == null
        ? fallbackCountry
        : await findByType(countryText, 'country');

    final allStates = await states();
    final countryId = country?.intId;
    final state = stateText == null
        ? null
        : findNamed(
            allStates.where((option) {
              if (countryId == null) return true;
              return parentIdOf(option) == countryId;
            }).toList(),
            stateText,
          );

    final districts = state == null
        ? const <OnboardingOption>[]
        : await districtsForState(state);
    final district = districtText == null
        ? null
        : findNamed(districts, districtText);

    // Search the leaf under the deepest ancestor the walk reached. A district
    // narrows it to a few thousand rows; the state is the widest this is ever
    // allowed to go. Without either, nothing is searched — a national lookup
    // would be a guess among millions, which is what the walk exists to avoid.
    final leafParent = district ?? state;
    final leaf = leafParent == null
        ? null
        : await findLeafUnder(leafParent, data);

    return ResolvedPlace(
      country: country,
      state: state,
      district: district,
      leaf: leaf,
    );
  }
}

/// How far down the hierarchy a place description got.
///
/// Every field is independently nullable because a partial answer is still
/// worth having: a member handed the right district with an empty village has
/// less left to type than one handed nothing.
class ResolvedPlace {
  const ResolvedPlace({this.country, this.state, this.district, this.leaf});

  final OnboardingOption? country;
  final OnboardingOption? state;
  final OnboardingOption? district;

  /// The village, city or suburb — the row a profile actually stores.
  final OnboardingOption? leaf;

  bool get isEmpty =>
      country == null && state == null && district == null && leaf == null;
}
