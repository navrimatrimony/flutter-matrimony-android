import 'onboarding_option.dart';

class PagedLookupResponse {
  const PagedLookupResponse({
    required this.success,
    this.locale,
    this.results = const <OnboardingOption>[],
    this.popular = const <OnboardingOption>[],
    this.pagination = const LookupPagination(),
    this.message,
    this.raw = const <String, dynamic>{},
  });

  final bool success;
  final String? locale;
  final List<OnboardingOption> results;
  final List<OnboardingOption> popular;
  final LookupPagination pagination;
  final String? message;
  final Map<String, dynamic> raw;

  bool get hasMore => pagination.hasMore;

  factory PagedLookupResponse.fromJson(Map<String, dynamic> json) {
    final source = _payloadMap(json);
    final resultSource =
        source['results'] ??
        source['items'] ??
        source['data'] ??
        json['results'];
    final popularSource = source['popular'] ?? json['popular'];
    final paginationSource =
        source['pagination'] ?? source['meta'] ?? json['pagination'];

    return PagedLookupResponse(
      success: _boolValue(json['success'] ?? source['success']) ?? true,
      locale: _stringValue(source['locale'] ?? json['locale']),
      results: OnboardingOption.listFrom(resultSource),
      popular: OnboardingOption.listFrom(popularSource),
      pagination: LookupPagination.fromJson(paginationSource),
      message: _stringValue(json['message'] ?? source['message']),
      raw: Map<String, dynamic>.from(json),
    );
  }

  factory PagedLookupResponse.fromOptions(
    List<OnboardingOption> options, {
    List<OnboardingOption> popular = const <OnboardingOption>[],
  }) {
    return PagedLookupResponse(
      success: true,
      results: options,
      popular: popular,
      pagination: const LookupPagination(hasMore: false),
    );
  }

  static Map<String, dynamic> _payloadMap(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return json;
  }

  static String? _stringValue(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  static bool? _boolValue(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().trim().toLowerCase();
    if (text == null || text.isEmpty) return null;
    if (text == '1' || text == 'true' || text == 'yes') return true;
    if (text == '0' || text == 'false' || text == 'no') return false;
    return null;
  }
}

class LookupPagination {
  const LookupPagination({
    this.page = 1,
    this.perPage = 20,
    this.total,
    this.hasMore = false,
  });

  final int page;
  final int perPage;
  final int? total;
  final bool hasMore;

  factory LookupPagination.fromJson(dynamic value) {
    if (value is! Map) return const LookupPagination();
    final source = Map<String, dynamic>.from(value);

    return LookupPagination(
      page: _intValue(source['page'] ?? source['current_page']) ?? 1,
      perPage: _intValue(source['per_page'] ?? source['limit']) ?? 20,
      total: _intValue(source['total']),
      hasMore:
          _boolValue(
            source['has_more'] ?? source['hasMore'] ?? source['more'],
          ) ??
          false,
    );
  }

  static int? _intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static bool? _boolValue(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().trim().toLowerCase();
    if (text == null || text.isEmpty) return null;
    if (text == '1' || text == 'true' || text == 'yes') return true;
    if (text == '0' || text == 'false' || text == 'no') return false;
    return null;
  }
}
