import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/app_strings.dart';

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  static const Color _brandColor = Color(0xFFDC2626);
  static const Color _brandDark = Color(0xFF9F1239);
  static const Color _gold = Color(0xFFC79A3B);
  static const Color _surface = Color(0xFFFFFBF7);

  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  Map<String, dynamic>? _current;
  List<Map<String, dynamic>> _plans = <Map<String, dynamic>>[];
  final Map<int, int?> _selectedTermIds = <int, int?>{};
  int? _checkoutPlanId;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans({bool silent = false}) async {
    setState(() {
      if (silent) {
        _refreshing = true;
      } else {
        _loading = true;
      }
      _error = null;
    });

    try {
      final responses = await Future.wait<Map<String, dynamic>>([
        ApiClient.getCurrentPlan(),
        ApiClient.getPlans(),
      ]);
      final currentResponse = responses[0];
      final plansResponse = responses[1];
      final plans = _safeMapList(plansResponse['plans']);

      final nextSelectedTerms = <int, int?>{};
      for (final plan in plans) {
        final planId = _asInt(plan['id']);
        if (planId == null) continue;
        nextSelectedTerms[planId] = _defaultPlanTermId(plan);
      }

      if (!mounted) return;
      setState(() {
        _current = currentResponse;
        _plans = plans;
        _selectedTermIds
          ..clear()
          ..addAll(nextSelectedTerms);
        _error = _responseSuccess(plansResponse)
            ? null
            : _responseMessage(plansResponse, AppStrings.plansLoadFailed);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '${AppStrings.plansLoadFailed} $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
      }
    }
  }

  Future<void> _startCheckout(Map<String, dynamic> plan) async {
    final planId = _asInt(plan['id']);
    if (planId == null) return;

    setState(() {
      _checkoutPlanId = planId;
    });

    try {
      final response = await ApiClient.startPlanCheckout(
        planId,
        planTermId: _selectedTermIds[planId],
      );
      if (!mounted) return;

      if (!_responseSuccess(response)) {
        _showSnackBar(_responseMessage(response, AppStrings.plansLoadFailed));
        return;
      }

      final checkoutUrl = _stringValue(response['checkout_url']);
      final uri = Uri.tryParse(checkoutUrl);
      if (checkoutUrl.isEmpty || uri == null) {
        _showSnackBar(AppStrings.plansCheckoutUrlMissing);
        return;
      }

      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!mounted) return;

      if (opened) {
        _showSnackBar(AppStrings.plansBrowserNote);
      } else {
        await Clipboard.setData(ClipboardData(text: checkoutUrl));
        if (!mounted) return;
        _showSnackBar(AppStrings.plansOpenFailedCopied);
      }
    } catch (error) {
      if (!mounted) return;
      _showSnackBar('${AppStrings.plansLoadFailed} $error');
    } finally {
      if (mounted) {
        setState(() {
          _checkoutPlanId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4EF),
      appBar: AppBar(title: Text(AppStrings.plansTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _loadPlans(silent: true),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                children: [
                  _buildCurrentPlanCard(),
                  const SizedBox(height: 16),
                  _buildSectionHeader(AppStrings.plansAvailablePlans),
                  const SizedBox(height: 10),
                  if (_error != null) _buildErrorBanner(_error!),
                  if (_plans.isEmpty) _buildEmptyCard(),
                  for (final plan in _plans) _buildPlanCard(plan),
                ],
              ),
            ),
    );
  }

  Widget _buildCurrentPlanCard() {
    final currentPlan = _safeMap(_current?['current_plan']);
    final subscription = _safeMap(_current?['active_subscription']);
    final contactView = _safeMap(_current?['contact_view']);
    final usage = _safeMap(contactView?['usage']);
    final state = _safeMap(contactView?['state']);
    final planName = _stringValue(
      currentPlan?['display_name'] ?? currentPlan?['name'],
      fallback: AppStrings.plansNoCurrentPlan,
    );
    final hasActiveSubscription = subscription != null;
    final statusText = hasActiveSubscription
        ? AppStrings.plansActiveSubscription
        : AppStrings.plansFreeOrLocked;

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFE8DDD7)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.workspace_premium, color: _gold),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppStrings.plansCurrentPlan,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: _brandDark,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _refreshing
                      ? null
                      : () => _loadPlans(silent: true),
                  icon: _refreshing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, size: 18),
                  label: Text(AppStrings.plansRefresh),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              planName,
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              statusText,
              style: const TextStyle(
                color: Color(0xFF6B4B4B),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            _buildQuotaLine(usage, state),
            const SizedBox(height: 10),
            Text(
              AppStrings.plansManualRefreshHint,
              style: const TextStyle(color: Color(0xFF7C6A64), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuotaLine(
    Map<String, dynamic>? usage,
    Map<String, dynamic>? state,
  ) {
    final used = usage?['used'] ?? state?['used'] ?? 0;
    final limit = usage?['limit'] ?? state?['limit'] ?? '-';
    final remaining = usage?['remaining'] ?? state?['remaining'] ?? '-';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE8DDD7)),
      ),
      child: Row(
        children: [
          const Icon(Icons.phone_in_talk, color: _brandColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${AppStrings.plansContactQuota}: $used / $limit, ${AppStrings.plansRemaining} $remaining',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: _brandDark,
        fontSize: 18,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CD),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFFE08A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFF8A5A00)),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }

  Widget _buildEmptyCard() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFE8DDD7)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Text(
          AppStrings.plansEmpty,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildPlanCard(Map<String, dynamic> plan) {
    final planId = _asInt(plan['id']);
    final terms = _safeMapList(plan['terms']);
    final selectedTerm = _selectedTerm(plan);
    final name = _stringValue(
      plan['display_name'] ?? plan['name'],
      fallback: AppStrings.plansTitle,
    );
    final description = _stringValue(plan['description']);
    final badge = _stringValue(plan['marketing_badge']);
    final features = _stringList(plan['features']);
    final isCheckoutLoading = planId != null && _checkoutPlanId == planId;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: plan['highlight'] == true ? _gold : const Color(0xFFE8DDD7),
          width: plan['highlight'] == true ? 1.4 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: _brandDark,
                    ),
                  ),
                ),
                if (badge.isNotEmpty) _buildBadge(badge),
              ],
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                description,
                style: const TextStyle(color: Color(0xFF6B4B4B)),
              ),
            ],
            const SizedBox(height: 14),
            Text(
              _priceLine(plan, selectedTerm),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            if (terms.length > 1) _buildTermPicker(plan, terms),
            if (terms.length == 1)
              Text(
                _termLabel(terms.first),
                style: const TextStyle(
                  color: Color(0xFF6B4B4B),
                  fontWeight: FontWeight.w700,
                ),
              ),
            if (features.isNotEmpty) ...[
              const SizedBox(height: 14),
              ...features.map(_buildFeatureRow),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: planId == null || isCheckoutLoading
                    ? null
                    : () => _startCheckout(plan),
                icon: isCheckoutLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.open_in_new),
                label: Text(
                  isCheckoutLoading
                      ? AppStrings.plansOpeningCheckout
                      : AppStrings.plansChoose,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4CC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE6B84F)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF7A4A00),
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildTermPicker(
    Map<String, dynamic> plan,
    List<Map<String, dynamic>> terms,
  ) {
    final planId = _asInt(plan['id']);
    if (planId == null) return const SizedBox.shrink();

    return DropdownButtonFormField<int>(
      initialValue: _selectedTermIds[planId],
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.calendar_month),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      items: terms
          .map(
            (term) => DropdownMenuItem<int>(
              value: _asInt(term['id']),
              child: Text(_termLabel(term), overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (value) {
        setState(() {
          _selectedTermIds[planId] = value;
        });
      },
    );
  }

  Widget _buildFeatureRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF16A085), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.w700, height: 1.25),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic>? _selectedTerm(Map<String, dynamic> plan) {
    final planId = _asInt(plan['id']);
    if (planId == null) return null;
    final selectedId = _selectedTermIds[planId];
    if (selectedId == null) return null;

    for (final term in _safeMapList(plan['terms'])) {
      if (_asInt(term['id']) == selectedId) return term;
    }

    return null;
  }

  String _priceLine(
    Map<String, dynamic> plan,
    Map<String, dynamic>? selectedTerm,
  ) {
    final amount = selectedTerm?['final_price'] ?? plan['final_price'];
    final duration = selectedTerm?['duration_label'] ?? plan['duration_label'];
    final price = _currency(amount);
    final label = _stringValue(duration);

    return label.isEmpty ? price : '$price / $label';
  }

  String _termLabel(Map<String, dynamic> term) {
    final label = _stringValue(
      term['label'],
      fallback: _stringValue(term['billing_key']),
    );
    final duration = _stringValue(term['duration_label']);
    final price = _currency(term['final_price']);
    final parts = <String>[label];
    if (duration.isNotEmpty) parts.add(duration);
    parts.add(price);

    return parts.where((part) => part.trim().isNotEmpty).join(' · ');
  }

  int? _defaultPlanTermId(Map<String, dynamic> plan) {
    final backendDefault = _asInt(plan['default_plan_term_id']);
    if (backendDefault != null) return backendDefault;
    final terms = _safeMapList(plan['terms']);
    if (terms.isEmpty) return null;

    return _asInt(terms.first['id']);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  static bool _responseSuccess(Map<String, dynamic> response) {
    final statusCode = _asInt(response['statusCode']) ?? 0;
    return response['success'] == true && statusCode >= 200 && statusCode < 300;
  }

  static String _responseMessage(
    Map<String, dynamic> response,
    String fallback,
  ) {
    final message = _stringValue(response['message']);
    return message.isEmpty ? fallback : message;
  }

  static Map<String, dynamic>? _safeMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static List<Map<String, dynamic>> _safeMapList(dynamic value) {
    if (value is! List) return <Map<String, dynamic>>[];

    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) return <String>[];

    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  static String _stringValue(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static String _currency(dynamic value) {
    final amount = value is num ? value.toDouble() : double.tryParse('$value');
    if (amount == null) return '₹0';
    if (amount == amount.roundToDouble()) {
      return '₹${amount.toStringAsFixed(0)}';
    }

    return '₹${amount.toStringAsFixed(2)}';
  }
}
