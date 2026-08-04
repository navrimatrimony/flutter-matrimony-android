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

  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  Map<String, dynamic>? _current;
  List<Map<String, dynamic>> _plans = <Map<String, dynamic>>[];
  final Map<int, int?> _selectedTermIds = <int, int?>{};
  int? _checkoutPlanId;

  int _selectedPlanIndex = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.92);
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

      final nextSelectedTerms = <int, int?>{};
      for (final plan in plans) {
        final planId = _asInt(plan['id']);
        if (planId == null) continue;
        nextSelectedTerms[planId] = _defaultPlanTermId(plan);
      }

      var nextIndex = _selectedPlanIndex;
      if (plans.isEmpty) {
        nextIndex = 0;
      } else if (nextIndex >= plans.length) {
        nextIndex = 0;
      }

      if (!mounted) return;
      setState(() {
        _current = currentResponse;
        _plans = plans;
        _selectedTermIds
          ..clear()
          ..addAll(nextSelectedTerms);
        _selectedPlanIndex = nextIndex;
        _error = _responseSuccess(plansResponse)
            ? null
            : _responseMessage(plansResponse, AppStrings.plansLoadFailed);
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_pageController.hasClients || plans.isEmpty) return;
        _pageController.jumpToPage(nextIndex);
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

  Future<void> _startCheckout(Map<String, dynamic> plan) async {
    final planId = _asInt(plan['id']);
    if (planId == null) return;

    setState(() {
      _checkoutPlanId = planId;
    });

    try {
      final completed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => PlanCouponScreen(
            plan: plan,
            planTermId: _selectedTermIds[planId],
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
    if (name.isEmpty) {
      return currentAppLanguage == AppLanguage.marathi ? '—' : '—';
    }
    final mr = currentAppLanguage == AppLanguage.marathi;
    return mr ? 'सध्या: $name' : 'Now: $name';
  }

  Map<String, dynamic>? get _selectedPlan {
    if (_plans.isEmpty) return null;
    if (_selectedPlanIndex < 0 || _selectedPlanIndex >= _plans.length) {
      return _plans.first;
    }
    return _plans[_selectedPlanIndex];
  }

  void _selectPlanIndex(int index, {bool animate = true}) {
    if (index < 0 || index >= _plans.length) return;
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
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 148),
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
                  const SizedBox(height: 8),
                  _buildTermToggle(mr),
                  const SizedBox(height: 8),
                  Expanded(child: _buildPlanPager()),
                  _buildScrubber(mr),
                  _buildBottomCta(mr),
                ],
              ],
            ),
    );
  }

  Widget _buildTermToggle(bool mr) {
    final plan = _selectedPlan;
    if (plan == null) return const SizedBox.shrink();
    final terms = _safeMapList(plan['terms']);
    final planId = _asInt(plan['id']);
    if (planId == null || terms.length <= 1) {
      if (terms.length == 1) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Text(
            _termChipLabel(terms.first, mr),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }
      return const SizedBox(height: 4);
    }

    final selectedId = _selectedTermIds[planId];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (final term in terms)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(_termChipLabel(term, mr)),
                selected: _asInt(term['id']) == selectedId,
                selectedColor: _brandColor,
                labelStyle: TextStyle(
                  color: _asInt(term['id']) == selectedId
                      ? Colors.white
                      : _brandDark,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: _asInt(term['id']) == selectedId
                      ? _brandColor
                      : const Color(0xFFE8DDD7),
                ),
                onSelected: (_) {
                  setState(() {
                    _selectedTermIds[planId] = _asInt(term['id']);
                  });
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlanPager() {
    return PageView.builder(
      controller: _pageController,
      itemCount: _plans.length,
      onPageChanged: (index) {
        setState(() {
          _selectedPlanIndex = index;
        });
      },
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: _buildMainPlanCard(_plans[index], index),
        );
      },
    );
  }

  Widget _buildMainPlanCard(Map<String, dynamic> plan, int index) {
    final terms = _safeMapList(plan['terms']);
    final selectedTerm = _selectedTerm(plan);
    final name = _stringValue(
      plan['display_name'] ?? plan['name'],
      fallback: AppStrings.plansTitle,
    );
    final badge = _stringValue(plan['marketing_badge']);
    final features = _stringList(plan['features']);
    final highlight = plan['highlight'] == true;
    final mr = currentAppLanguage == AppLanguage.marathi;

    return Card(
      elevation: 3,
      shadowColor: Colors.black26,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: highlight ? _brandColor : const Color(0xFFE8DDD7),
          width: highlight ? 1.6 : 1,
        ),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.workspace_premium_rounded,
                      color: highlight ? _brandColor : Colors.blueGrey,
                      size: 28,
                    ),
                    const Spacer(),
                    if (badge.isNotEmpty) _buildBadge(badge),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: _brandDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _priceOnly(plan, selectedTerm),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: _brandColor,
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
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
                const SizedBox(height: 12),
                Expanded(
                  child: features.isEmpty
                      ? Center(
                          child: Text(
                            _stringValue(plan['description']),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        )
                      : ListView(
                          children: [
                            for (final feature in features.take(6))
                              _buildFeatureRow(feature),
                          ],
                        ),
                ),
                if (_plans.length > 1)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < _plans.length; i++)
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
                if (terms.length == 1) ...[
                  const SizedBox(height: 4),
                  Text(
                    _termLabel(terms.first),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_plans.length > 1) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: index <= 0
                    ? null
                    : () => _selectPlanIndex(index - 1),
                icon: Icon(
                  Icons.chevron_left_rounded,
                  color: index <= 0 ? Colors.grey.shade300 : _brandColor,
                  size: 32,
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                onPressed: index >= _plans.length - 1
                    ? null
                    : () => _selectPlanIndex(index + 1),
                icon: Icon(
                  Icons.chevron_right_rounded,
                  color: index >= _plans.length - 1
                      ? Colors.grey.shade300
                      : _brandColor,
                  size: 32,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScrubber(bool mr) {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        itemCount: _plans.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final plan = _plans[index];
          final selected = index == _selectedPlanIndex;
          final name = _stringValue(
            plan['display_name'] ?? plan['name'],
            fallback: 'Plan',
          );
          final shortName = name.split('(').first.trim();
          final selectedTerm = _selectedTerm(plan);
          final price = _priceOnly(plan, selectedTerm);

          return InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _selectPlanIndex(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 92,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFFFFF1F2) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? _brandColor : const Color(0xFFE8DDD7),
                  width: selected ? 1.6 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.workspace_premium_outlined,
                    size: 18,
                    color: selected ? _brandColor : Colors.blueGrey,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    shortName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: selected ? _brandColor : _brandDark,
                    ),
                  ),
                  Text(
                    price,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomCta(bool mr) {
    final plan = _selectedPlan;
    final planId = plan == null ? null : _asInt(plan['id']);
    final isCheckoutLoading = planId != null && _checkoutPlanId == planId;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: plan == null || planId == null || isCheckoutLoading
                    ? null
                    : () => _startCheckout(plan),
                style: FilledButton.styleFrom(
                  backgroundColor: _brandColor,
                  padding: const EdgeInsets.symmetric(vertical: 15),
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
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: 13, color: Colors.grey.shade600),
                const SizedBox(width: 5),
                Text(
                  mr
                      ? 'सुरक्षित पेमेंट · PayU'
                      : 'Secure payment · PayU',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
        ),
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
    final duration = _stringValue(
      selectedTerm?['duration_label'] ?? plan['duration_label'],
    );
    if (duration.isNotEmpty) {
      return mr ? '$duration वैध' : 'Valid $duration';
    }
    final days = selectedTerm?['duration_days'] ?? plan['duration_days'];
    if (days != null) {
      return mr ? '$days दिवस वैध' : 'Valid $days days';
    }
    return mr ? 'कालावधी' : 'Duration';
  }

  String _termChipLabel(Map<String, dynamic> term, bool mr) {
    final label = _stringValue(term['label']);
    if (label.isNotEmpty) return label;
    final duration = _stringValue(term['duration_label']);
    if (duration.isNotEmpty) return duration;
    final days = term['duration_days'];
    if (days != null) return mr ? '$days दिवस' : '$days days';
    return _stringValue(term['billing_key'], fallback: mr ? 'टर्म' : 'Term');
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
