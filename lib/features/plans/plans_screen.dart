import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/api_error_text.dart';
import '../../core/app_loading.dart';
import '../../core/app_strings.dart';
import '../../core/app_language.dart';
import 'plan_coupon_screen.dart';

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> with WidgetsBindingObserver {
  static const Color _brandColor = Color(0xFFDC2626);
  static const Color _brandDark = Color(0xFF9F1239);
  static const Color _surface = Color(0xFFFFF8F5);

  /// Fixed catalog strip — independent of which plan card is open.
  static const List<String> _billingKeys = <String>[
    'monthly',
    'quarterly',
    'half_yearly',
    'yearly',
    'lifetime',
  ];

  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  Map<String, dynamic>? _current;
  List<Map<String, dynamic>> _plans = <Map<String, dynamic>>[];
  int? _checkoutPlanId;

  String _selectedBillingKey = 'monthly';
  int _selectedPlanIndex = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.98);
    WidgetsBinding.instance.addObserver(this);
    _loadPlans();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (_checkoutPlanId != null) return;
    _loadPlans(silent: true);
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

      if (!mounted) return;
      setState(() {
        _current = currentResponse;
        _plans = plans;
        _error = _responseSuccess(plansResponse)
            ? null
            : _responseMessage(plansResponse, AppStrings.plansLoadFailed);
        _selectedPlanIndex = _clampIndex(
          _selectedPlanIndex,
          _visiblePlans.length,
        );
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_pageController.hasClients) return;
        final visible = _visiblePlans;
        if (visible.isEmpty) return;
        _pageController.jumpToPage(_selectedPlanIndex);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = failureText(AppStrings.plansLoadFailed, error);
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

  List<Map<String, dynamic>> get _visiblePlans {
    return _plans.where(_planSupportsSelectedBilling).toList(growable: false);
  }

  bool _planSupportsSelectedBilling(Map<String, dynamic> plan) {
    final terms = _safeMapList(plan['terms']);
    // Free / term-less catalog rows stay visible for every duration tab.
    if (terms.isEmpty) return true;
    return terms.any(
      (term) => _stringValue(term['billing_key']) == _selectedBillingKey,
    );
  }

  Map<String, dynamic>? get _selectedPlan {
    final visible = _visiblePlans;
    if (visible.isEmpty) return null;
    if (_selectedPlanIndex < 0 || _selectedPlanIndex >= visible.length) {
      return visible.first;
    }
    return visible[_selectedPlanIndex];
  }

  Map<String, dynamic>? _termForBilling(Map<String, dynamic> plan) {
    for (final term in _safeMapList(plan['terms'])) {
      if (_stringValue(term['billing_key']) == _selectedBillingKey) {
        return term;
      }
    }
    return null;
  }

  /// Ordered feature labels across the full catalog (for included + missing rows).
  List<String> get _featureCatalogLabels {
    final labels = <String>[];
    final seen = <String>{};

    List<Map<String, dynamic>> ordered = List<Map<String, dynamic>>.from(
      _plans,
    );
    ordered.sort((a, b) {
      final aCount = _stringList(a['features']).length;
      final bCount = _stringList(b['features']).length;
      return bCount.compareTo(aCount);
    });

    for (final plan in ordered) {
      for (final line in _stringList(plan['features'])) {
        final label = _featureLabelOf(line);
        if (label.isEmpty || !seen.add(label)) continue;
        labels.add(label);
      }
    }
    return labels;
  }

  Future<void> _startCheckout(Map<String, dynamic> plan) async {
    final planId = _asInt(plan['id']);
    if (planId == null) return;

    final term = _termForBilling(plan);
    final terms = _safeMapList(plan['terms']);
    if (terms.isNotEmpty && term == null) {
      _showSnackBar(
        currentAppLanguage == AppLanguage.marathi
            ? 'हा कालावधी या प्लॅनसाठी उपलब्ध नाही.'
            : 'This duration is not available for this plan.',
      );
      return;
    }

    setState(() {
      _checkoutPlanId = planId;
    });

    try {
      final completed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => PlanCouponScreen(
            plan: plan,
            planTermId: _asInt(term?['id']),
          ),
        ),
      );

      if (!mounted) return;
      await _loadPlans(silent: true);
      if (!mounted) return;

      if (completed == true) {
        final hasActive = _safeMap(_current?['active_subscription']) != null;
        _showSnackBar(
          hasActive
              ? AppStrings.plansActiveSubscription
              : (currentAppLanguage == AppLanguage.marathi
                    ? 'पेमेंट पूर्ण झाले. स्थिती रिफ्रेश झाली.'
                    : 'Payment finished. Plan status refreshed.'),
        );
      }
    } catch (error) {
      if (!mounted) return;
      _showSnackBar(failureText(AppStrings.plansLoadFailed, error));
    } finally {
      if (mounted) {
        setState(() {
          _checkoutPlanId = null;
        });
      }
    }
  }

  String get _headerCurrentPlanText {
    final currentPlan = _safeMap(_current?['current_plan']);
    final name = _stringValue(
      currentPlan?['display_name'] ?? currentPlan?['name'],
    );
    if (name.isEmpty) return '—';
    final mr = currentAppLanguage == AppLanguage.marathi;
    return mr ? 'सध्या: $name' : 'Now: $name';
  }

  void _selectBillingKey(String key) {
    if (key == _selectedBillingKey) return;
    final previousId = _asInt(_selectedPlan?['id']);
    setState(() {
      _selectedBillingKey = key;
      final visible = _visiblePlans;
      var nextIndex = 0;
      if (previousId != null) {
        final keep = visible.indexWhere((p) => _asInt(p['id']) == previousId);
        if (keep >= 0) nextIndex = keep;
      }
      _selectedPlanIndex = _clampIndex(nextIndex, visible.length);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) return;
      if (_visiblePlans.isEmpty) return;
      _pageController.jumpToPage(_selectedPlanIndex);
    });
  }

  void _selectPlanIndex(int index, {bool animate = true}) {
    final visible = _visiblePlans;
    if (index < 0 || index >= visible.length) return;
    setState(() {
      _selectedPlanIndex = index;
    });
    if (!_pageController.hasClients) return;
    if (animate) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      _pageController.jumpToPage(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mr = currentAppLanguage == AppLanguage.marathi;

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _brandColor,
        elevation: 0,
        title: Text(
          AppStrings.plansTitle,
          style: const TextStyle(
            color: _brandColor,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          if (!_loading)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 140),
                  child: Text(
                    _headerCurrentPlanText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ),
            ),
          IconButton(
            tooltip: AppStrings.plansRefresh,
            onPressed: _refreshing ? null : () => _loadPlans(silent: true),
            icon: _refreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh, size: 20),
          ),
        ],
      ),
      body: _loading
          ? AppLoadingState.list(
              title: appText.loadingPlans,
              icon: Icons.workspace_premium_outlined,
            )
          : Column(
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: _buildErrorBanner(_error!),
                  ),
                if (_plans.isEmpty)
                  Expanded(child: Center(child: _buildEmptyCard()))
                else ...[
                  _buildBillingStrip(mr),
                  _buildPlanNameStrip(mr),
                  Expanded(
                    child: _visiblePlans.isEmpty
                        ? Center(child: _buildNoPlansForBilling(mr))
                        : _buildPlanPager(),
                  ),
                  _buildBottomCta(mr),
                ],
              ],
            ),
    );
  }

  Widget _buildBillingStrip(bool mr) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        itemCount: _billingKeys.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final key = _billingKeys[index];
          final selected = key == _selectedBillingKey;
          return ChoiceChip(
            label: Text(_billingLabel(key, mr)),
            selected: selected,
            selectedColor: _brandColor,
            labelStyle: TextStyle(
              color: selected ? Colors.white : _brandDark,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
            backgroundColor: Colors.white,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            side: BorderSide(
              color: selected ? _brandColor : const Color(0xFFE8DDD7),
            ),
            onSelected: (_) => _selectBillingKey(key),
          );
        },
      ),
    );
  }

  Widget _buildPlanNameStrip(bool mr) {
    final visible = _visiblePlans;
    if (visible.isEmpty) return const SizedBox(height: 4);

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
        itemCount: visible.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final plan = visible[index];
          final selected = index == _selectedPlanIndex;
          final name = _shortPlanName(plan);
          return InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => _selectPlanIndex(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFFFFF1F2) : Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected ? _brandColor : const Color(0xFFE8DDD7),
                  width: selected ? 1.4 : 1,
                ),
              ),
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: selected ? _brandColor : _brandDark,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlanPager() {
    final visible = _visiblePlans;
    return PageView.builder(
      controller: _pageController,
      itemCount: visible.length,
      onPageChanged: (index) {
        setState(() {
          _selectedPlanIndex = index;
        });
      },
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
          child: _buildMainPlanCard(visible[index], index, visible.length),
        );
      },
    );
  }

  Widget _buildMainPlanCard(
    Map<String, dynamic> plan,
    int index,
    int total,
  ) {
    final selectedTerm = _termForBilling(plan);
    final name = _stringValue(
      plan['display_name'] ?? plan['name'],
      fallback: AppStrings.plansTitle,
    );
    final badge = _stringValue(plan['marketing_badge']);
    final highlight = plan['highlight'] == true;
    final mr = currentAppLanguage == AppLanguage.marathi;
    final featureRows = _featureRowsFor(plan);

    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shadowColor: Colors.black26,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: highlight ? _brandColor : const Color(0xFFE8DDD7),
          width: highlight ? 1.6 : 1,
        ),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.workspace_premium_rounded,
                      color: highlight ? _brandColor : Colors.blueGrey,
                      size: 26,
                    ),
                    const Spacer(),
                    if (badge.isNotEmpty) _buildBadge(badge),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: _brandDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _priceOnly(plan, selectedTerm),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: _brandColor,
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _durationChip(plan, selectedTerm, mr),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _brandDark,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: featureRows.isEmpty
                      ? Center(
                          child: Text(
                            _stringValue(plan['description']),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: featureRows.length,
                          itemBuilder: (context, i) {
                            final row = featureRows[i];
                            return _buildFeatureRow(row.text, row.included);
                          },
                        ),
                ),
                if (total > 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < total; i++)
                          Container(
                            width: i == index ? 8 : 6,
                            height: i == index ? 8 : 6,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i == index
                                  ? _brandColor
                                  : Colors.grey.shade300,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (total > 1) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: index <= 0
                    ? null
                    : () => _selectPlanIndex(index - 1),
                icon: Icon(
                  Icons.chevron_left_rounded,
                  color: index <= 0 ? Colors.grey.shade300 : _brandColor,
                  size: 30,
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                onPressed: index >= total - 1
                    ? null
                    : () => _selectPlanIndex(index + 1),
                icon: Icon(
                  Icons.chevron_right_rounded,
                  color: index >= total - 1
                      ? Colors.grey.shade300
                      : _brandColor,
                  size: 30,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<({String text, bool included})> _featureRowsFor(
    Map<String, dynamic> plan,
  ) {
    final lines = _stringList(plan['features']);
    final byLabel = <String, String>{};
    for (final line in lines) {
      final label = _featureLabelOf(line);
      if (label.isEmpty) continue;
      byLabel[label] = line;
    }

    final catalog = _featureCatalogLabels;
    if (catalog.isEmpty) {
      return lines
          .map((line) => (text: line, included: true))
          .toList(growable: false);
    }

    return catalog
        .map((label) {
          final line = byLabel[label];
          return (text: line ?? label, included: line != null);
        })
        .toList(growable: false);
  }

  Widget _buildBottomCta(bool mr) {
    final plan = _selectedPlan;
    final planId = plan == null ? null : _asInt(plan['id']);
    final isCheckoutLoading = planId != null && _checkoutPlanId == planId;
    final terms = plan == null ? const <Map<String, dynamic>>[] : _safeMapList(plan['terms']);
    final termOk = plan != null && (terms.isEmpty || _termForBilling(plan) != null);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed:
                    plan == null ||
                        planId == null ||
                        isCheckoutLoading ||
                        !termOk
                    ? null
                    : () => _startCheckout(plan),
                style: FilledButton.styleFrom(
                  backgroundColor: _brandColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: isCheckoutLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        mr ? 'पुढे — पेमेंट' : 'Next — Payment',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: 13, color: Colors.grey.shade600),
                const SizedBox(width: 5),
                Text(
                  mr ? 'सुरक्षित पेमेंट · PayU' : 'Secure payment · PayU',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoPlansForBilling(bool mr) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        mr
            ? 'या कालावधीसाठी प्लॅन उपलब्ध नाही.'
            : 'No plans for this duration.',
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        AppStrings.plansEmpty,
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w700),
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

  Widget _buildFeatureRow(String text, bool included) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Opacity(
        opacity: included ? 1 : 0.45,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              included ? Icons.check_circle : Icons.remove_circle_outline,
              color: included ? const Color(0xFF16A085) : Colors.grey,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                  color: included ? Colors.black87 : Colors.grey.shade600,
                  decoration: included
                      ? TextDecoration.none
                      : TextDecoration.lineThrough,
                  decorationColor: Colors.grey.shade500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _shortPlanName(Map<String, dynamic> plan) {
    final name = _stringValue(
      plan['display_name'] ?? plan['name'],
      fallback: 'Plan',
    );
    return name.split('(').first.trim();
  }

  String _billingLabel(String key, bool mr) {
    switch (key) {
      case 'monthly':
        return mr ? 'मासिक' : 'Monthly';
      case 'quarterly':
        return mr ? 'तिमाही' : 'Quarterly';
      case 'half_yearly':
        return mr ? 'सहामाही' : 'Half-yearly';
      case 'yearly':
        return mr ? 'वार्षिक' : 'Yearly';
      case 'lifetime':
        return mr ? 'लग्न ठरेपर्यंत' : 'Till marriage';
      default:
        return key;
    }
  }

  String _priceOnly(
    Map<String, dynamic> plan,
    Map<String, dynamic>? selectedTerm,
  ) {
    final amount = selectedTerm?['final_price'] ?? plan['final_price'];
    return _currency(amount);
  }

  String _durationChip(
    Map<String, dynamic> plan,
    Map<String, dynamic>? selectedTerm,
    bool mr,
  ) {
    if (selectedTerm == null && _safeMapList(plan['terms']).isEmpty) {
      return mr ? 'फ्री' : 'Free';
    }
    return _billingLabel(_selectedBillingKey, mr);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  static int _clampIndex(int index, int length) {
    if (length <= 0) return 0;
    if (index < 0) return 0;
    if (index >= length) return 0;
    return index;
  }

  static String _featureLabelOf(String line) {
    final parts = line.split(RegExp(r'\s*[—–-]\s*'));
    final label = parts.first.trim();
    return label.isEmpty ? line.trim() : label;
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
