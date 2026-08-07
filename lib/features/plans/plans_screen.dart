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
  int? _checkoutPlanId;

  int _selectedPlanIndex = 0;
  int _selectedTermIndex = 0;
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

      var planIndex = _selectedPlanIndex;
      if (plans.isEmpty) {
        planIndex = 0;
      } else if (planIndex >= plans.length) {
        planIndex = 0;
      }

      // Prefer opening on the user's current catalog plan when present.
      final currentId = _asInt(
        _safeMap(currentResponse['current_plan'])?['id'],
      );
      if (currentId != null) {
        final currentIdx = plans.indexWhere((p) => _asInt(p['id']) == currentId);
        if (currentIdx >= 0) planIndex = currentIdx;
      }

      final termIndex = plans.isEmpty
          ? 0
          : _defaultTermIndexFor(plans[planIndex]);

      if (!mounted) return;
      setState(() {
        _current = currentResponse;
        _plans = plans;
        _selectedPlanIndex = planIndex;
        _selectedTermIndex = termIndex;
        _error = _responseSuccess(plansResponse)
            ? null
            : _responseMessage(plansResponse, AppStrings.plansLoadFailed);
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_pageController.hasClients) return;
        final cards = _termCardsForSelectedPlan;
        if (cards.isEmpty) return;
        _pageController.jumpToPage(
          _selectedTermIndex.clamp(0, cards.length - 1),
        );
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

  Map<String, dynamic>? get _selectedPlan {
    if (_plans.isEmpty) return null;
    if (_selectedPlanIndex < 0 || _selectedPlanIndex >= _plans.length) {
      return _plans.first;
    }
    return _plans[_selectedPlanIndex];
  }

  /// One card per admin-visible term; plan-level fallback when terms empty.
  List<Map<String, dynamic>> get _termCardsForSelectedPlan {
    final plan = _selectedPlan;
    if (plan == null) return const <Map<String, dynamic>>[];
    final terms = _safeMapList(plan['terms']);
    if (terms.isNotEmpty) return terms;
    return <Map<String, dynamic>>[
      {
        'id': null,
        'billing_key': '',
        'label': '',
        'duration_days': plan['duration_days'],
        'duration_label': plan['duration_label'],
        'price': plan['price'],
        'final_price': plan['final_price'],
        'discount_percent': plan['discount_percent'],
        '_plan_level': true,
      },
    ];
  }

  Map<String, dynamic>? get _selectedTerm {
    final cards = _termCardsForSelectedPlan;
    if (cards.isEmpty) return null;
    final i = _selectedTermIndex.clamp(0, cards.length - 1);
    return cards[i];
  }

  int _defaultTermIndexFor(Map<String, dynamic> plan) {
    final terms = _safeMapList(plan['terms']);
    if (terms.isEmpty) return 0;
    final defaultId = _asInt(plan['default_plan_term_id']);
    if (defaultId != null) {
      final idx = terms.indexWhere((t) => _asInt(t['id']) == defaultId);
      if (idx >= 0) return idx;
    }
    return 0;
  }

  List<String> get _featureCatalogLabels {
    final labels = <String>[];
    final seen = <String>{};
    final ordered = List<Map<String, dynamic>>.from(_plans)
      ..sort((a, b) {
        return _stringList(b['features']).length.compareTo(
          _stringList(a['features']).length,
        );
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
    if (_isFreeCatalogPlan(plan)) {
      _showSnackBar(
        currentAppLanguage == AppLanguage.marathi
            ? 'Free प्लॅन खरेदी करण्याची गरज नाही.'
            : 'The Free plan does not require payment.',
      );
      return;
    }

    final term = _selectedTerm;
    final termId = _asInt(term?['id']);

    setState(() {
      _checkoutPlanId = planId;
    });

    try {
      final completed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => PlanCouponScreen(
            plan: plan,
            planTermId: termId,
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
    final short = name.split('(').first.trim();
    final mr = currentAppLanguage == AppLanguage.marathi;
    return mr ? 'सध्या: $short' : 'Now: $short';
  }

  void _selectPlanIndex(int index) {
    if (index < 0 || index >= _plans.length) return;
    final termIndex = _defaultTermIndexFor(_plans[index]);
    setState(() {
      _selectedPlanIndex = index;
      _selectedTermIndex = termIndex;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) return;
      final cards = _termCardsForSelectedPlan;
      if (cards.isEmpty) return;
      _pageController.jumpToPage(termIndex.clamp(0, cards.length - 1));
    });
  }

  void _selectTermIndex(int index, {bool animate = true}) {
    final cards = _termCardsForSelectedPlan;
    if (index < 0 || index >= cards.length) return;
    setState(() {
      _selectedTermIndex = index;
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
                  _buildPlanNameStrip(mr),
                  Expanded(child: _buildTermPager()),
                  _buildBottomCta(mr),
                ],
              ],
            ),
    );
  }

  Widget _buildPlanNameStrip(bool mr) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFE8DDD7)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < _plans.length; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                _buildPlanChip(i, mr),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlanChip(int index, bool mr) {
    final plan = _plans[index];
    final selected = index == _selectedPlanIndex;
    final isCurrent = plan['is_current'] == true;
    final name = _shortPlanName(plan);

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => _selectPlanIndex(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _brandColor : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: isCurrent && !selected
              ? Border.all(color: _brandColor.withValues(alpha: 0.45))
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white : _brandDark,
              ),
            ),
            if (isCurrent) ...[
              const SizedBox(width: 6),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? Colors.white : _brandColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTermPager() {
    final plan = _selectedPlan;
    final cards = _termCardsForSelectedPlan;
    if (plan == null || cards.isEmpty) {
      return const SizedBox.shrink();
    }

    return PageView.builder(
      controller: _pageController,
      itemCount: cards.length,
      onPageChanged: (index) {
        setState(() {
          _selectedTermIndex = index;
        });
      },
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
          child: _buildMainPlanCard(plan, cards[index], index, cards.length),
        );
      },
    );
  }

  Widget _buildMainPlanCard(
    Map<String, dynamic> plan,
    Map<String, dynamic> term,
    int index,
    int total,
  ) {
    final mr = currentAppLanguage == AppLanguage.marathi;
    final highlight = plan['highlight'] == true;
    final isCurrent = plan['is_current'] == true;
    final name = _stringValue(
      plan['display_name'] ?? plan['name'],
      fallback: AppStrings.plansTitle,
    );
    final marketingLabel = _marketingBadgeLabel(plan, mr);
    final featureRows = _featureRowsFor(plan, term);
    final pricing = _pricingFor(plan, term);

    return Card(
      elevation: highlight ? 4 : 2,
      margin: EdgeInsets.zero,
      shadowColor: Colors.black26,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: isCurrent
              ? const Color(0xFF4F46E5)
              : (highlight ? _brandColor : const Color(0xFFE8DDD7)),
          width: (isCurrent || highlight) ? 1.7 : 1,
        ),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isCurrent || marketingLabel != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (isCurrent)
                          _buildStatusChip(
                            mr ? 'तुमचा सध्याचा प्लॅन' : 'Your current plan',
                            const Color(0xFF4F46E5),
                          ),
                        if (marketingLabel != null)
                          _buildStatusChip(marketingLabel, _brandColor),
                      ],
                    ),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.workspace_premium_rounded,
                            color: highlight ? _brandColor : Colors.blueGrey,
                            size: 28,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    color: _brandDark,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today_outlined,
                                      size: 13,
                                      color: Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        _durationLine(term, mr),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildPriceBlock(pricing, mr),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: featureRows.isEmpty
                      ? Center(
                          child: Text(
                            _stringValue(plan['description']),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        )
                      : ListView.separated(
                          padding: EdgeInsets.zero,
                          itemCount: featureRows.length,
                          separatorBuilder: (context, i) => Divider(
                            height: 1,
                            color: Colors.grey.shade200,
                          ),
                          itemBuilder: (context, i) {
                            final row = featureRows[i];
                            return _buildFeatureRow(row.text, row.included);
                          },
                        ),
                ),
                if (total > 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        _circleChevron(
                          icon: Icons.chevron_left_rounded,
                          enabled: index > 0,
                          onTap: () => _selectTermIndex(index - 1),
                        ),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (var i = 0; i < total; i++)
                                Container(
                                  width: i == index ? 8 : 6,
                                  height: i == index ? 8 : 6,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                  ),
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
                        _circleChevron(
                          icon: Icons.chevron_right_rounded,
                          enabled: index < total - 1,
                          onTap: () => _selectTermIndex(index + 1),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceBlock(_PlanPricing pricing, bool mr) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (pricing.showListStrike) ...[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _currency(pricing.listPrice),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  decoration: TextDecoration.lineThrough,
                  decorationColor: Colors.grey.shade500,
                ),
              ),
              if (pricing.discountPercent > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE4E6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    mr
                        ? '${pricing.discountPercent}% सूट'
                        : '${pricing.discountPercent}% OFF',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: _brandDark,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
        ],
        Text(
          _currency(pricing.finalPrice),
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: _brandColor,
            height: 1.05,
          ),
        ),
      ],
    );
  }

  Widget _circleChevron({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 1,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            icon,
            size: 22,
            color: enabled ? _brandColor : Colors.grey.shade300,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildBottomCta(bool mr) {
    final plan = _selectedPlan;
    final planId = plan == null ? null : _asInt(plan['id']);
    final isCheckoutLoading = planId != null && _checkoutPlanId == planId;
    final isFree = plan != null && _isFreeCatalogPlan(plan);
    final isCurrent = plan?['is_current'] == true;

    String ctaLabel;
    if (isFree && isCurrent) {
      ctaLabel = mr ? 'तुमचा सध्याचा प्लॅन' : 'Your current plan';
    } else if (isFree) {
      ctaLabel = mr ? 'Free प्लॅन' : 'Free plan';
    } else {
      ctaLabel = mr ? 'पुढे — पेमेंट' : 'Next — Payment';
    }

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
                onPressed: plan == null ||
                        planId == null ||
                        isCheckoutLoading ||
                        isFree
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
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            ctaLabel,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (!isFree) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.arrow_forward, size: 18),
                          ],
                        ],
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

  /// Display-only: prefers Laravel term-level final `features` (SSOT). No client multiplication.
  List<({String text, bool included})> _featureRowsFor(
    Map<String, dynamic> plan,
    Map<String, dynamic> term,
  ) {
    final lines = _stringList(term['features']).isNotEmpty
        ? _stringList(term['features'])
        : _stringList(plan['features']);
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

  Widget _buildFeatureRow(String text, bool included) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
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

  /// Mirrors Laravel public pricing discount display.
  _PlanPricing _pricingFor(
    Map<String, dynamic> plan,
    Map<String, dynamic> term,
  ) {
    final list = _asDouble(term['price']) ?? _asDouble(plan['price']) ?? 0;
    final finalPrice =
        _asDouble(term['final_price']) ?? _asDouble(plan['final_price']) ?? 0;
    var disc =
        _asInt(term['discount_percent']) ??
        _asInt(plan['discount_percent']) ??
        0;
    if (disc <= 0 && list > finalPrice + 0.004) {
      disc = (100 * (1 - finalPrice / list)).round().clamp(0, 100);
    }
    final showStrike = disc > 0 && list > finalPrice + 0.004;
    return _PlanPricing(
      listPrice: list,
      finalPrice: finalPrice,
      discountPercent: disc,
      showListStrike: showStrike,
    );
  }

  String _durationLine(Map<String, dynamic> term, bool mr) {
    final billing = _stringValue(term['billing_key']);
    final billingLabel = _billingLabel(billing, mr);
    final days = _asInt(term['duration_days']);
    final durationLabel = _stringValue(term['duration_label']);
    final label = _stringValue(term['label']);

    final primary = billingLabel.isNotEmpty
        ? billingLabel
        : (label.isNotEmpty
              ? label
              : (durationLabel.isNotEmpty
                    ? durationLabel
                    : (mr ? 'मुदत' : 'Duration')));

    if (billing == 'lifetime' || (days != null && days <= 0)) {
      return mr ? '$primary · लग्न ठरेपर्यंत' : '$primary · Till marriage';
    }
    if (days != null && days > 0) {
      return mr ? '$primary · $days दिवस' : '$primary · $days days';
    }
    return primary;
  }

  String? _marketingBadgeLabel(Map<String, dynamic> plan, bool mr) {
    final highlight = plan['highlight'] == true;
    if (!highlight) return null;

    final key = _stringValue(plan['marketing_badge']).toLowerCase();
    switch (key) {
      case 'best_seller':
        return mr ? 'Best Seller' : 'Best Seller';
      case 'popular':
        return mr ? 'Popular' : 'Popular';
      case 'new':
        return mr ? 'New' : 'New';
      case 'limited_offer':
        return mr ? 'Limited offer' : 'Limited offer';
      case 'recommended':
        return mr ? 'Recommended' : 'Recommended';
      default:
        // Admin "highlight" without badge — same as website gold fallback tone.
        return mr ? 'सर्वाधिक लोकप्रिय' : 'Most Popular';
    }
  }

  String _shortPlanName(Map<String, dynamic> plan) {
    final name = _stringValue(
      plan['display_name'] ?? plan['name'],
      fallback: 'Plan',
    );
    return name.split('(').first.trim();
  }

  static bool _isFreeCatalogPlan(Map<String, dynamic> plan) {
    final slug = _stringValue(plan['slug']).toLowerCase();
    return slug == 'free' || slug.startsWith('free_');
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
      case 'five_yearly':
        return mr ? '5 वर्षे' : '5 years';
      case 'lifetime':
        return mr ? 'लग्न ठरेपर्यंत' : 'Till marriage';
      default:
        return '';
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
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

  static double? _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
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

class _PlanPricing {
  const _PlanPricing({
    required this.listPrice,
    required this.finalPrice,
    required this.discountPercent,
    required this.showListStrike,
  });

  final double listPrice;
  final double finalPrice;
  final int discountPercent;
  final bool showListStrike;
}
