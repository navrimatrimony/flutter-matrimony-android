import 'dart:async';

import 'package:flutter/material.dart';

import '../models/onboarding_option.dart';
import '../models/paged_lookup_response.dart';

typedef SmartPickerPageLoader =
    Future<PagedLookupResponse> Function(String query, int page, int limit);

typedef SmartPickerSubtitleBuilder = String? Function(OnboardingOption option);

class SmartPickerPanel extends StatefulWidget {
  const SmartPickerPanel({
    super.key,
    required this.title,
    required this.loadPage,
    required this.onChanged,
    this.selectedItems = const <OnboardingOption>[],
    this.multiSelect = false,
    this.searchHint,
    this.itemSubtitleBuilder,
    this.allowRequestToAdd = false,
    this.onRequestToAdd,
    this.closeOnSingleSelect = true,
    this.pageSize = 20,
  });

  final String title;
  final SmartPickerPageLoader loadPage;
  final ValueChanged<List<OnboardingOption>> onChanged;
  final List<OnboardingOption> selectedItems;
  final bool multiSelect;
  final String? searchHint;
  final SmartPickerSubtitleBuilder? itemSubtitleBuilder;
  final bool allowRequestToAdd;
  final VoidCallback? onRequestToAdd;
  final bool closeOnSingleSelect;
  final int pageSize;

  static Future<List<OnboardingOption>?> show(
    BuildContext context, {
    required String title,
    required SmartPickerPageLoader loadPage,
    required ValueChanged<List<OnboardingOption>> onChanged,
    List<OnboardingOption> selectedItems = const <OnboardingOption>[],
    bool multiSelect = false,
    String? searchHint,
    SmartPickerSubtitleBuilder? itemSubtitleBuilder,
    bool allowRequestToAdd = false,
    VoidCallback? onRequestToAdd,
    bool closeOnSingleSelect = true,
    int pageSize = 20,
  }) {
    return showGeneralDialog<List<OnboardingOption>>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return SmartPickerPanel(
          title: title,
          loadPage: loadPage,
          onChanged: onChanged,
          selectedItems: selectedItems,
          multiSelect: multiSelect,
          searchHint: searchHint,
          itemSubtitleBuilder: itemSubtitleBuilder,
          allowRequestToAdd: allowRequestToAdd,
          onRequestToAdd: onRequestToAdd,
          closeOnSingleSelect: closeOnSingleSelect,
          pageSize: pageSize,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final offset =
            Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            );

        return SlideTransition(position: offset, child: child);
      },
    );
  }

  @override
  State<SmartPickerPanel> createState() => _SmartPickerPanelState();
}

class _SmartPickerPanelState extends State<SmartPickerPanel> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Map<String, OnboardingOption> _selected = <String, OnboardingOption>{};

  Timer? _debounce;
  List<OnboardingOption> _results = <OnboardingOption>[];
  List<OnboardingOption> _popular = <OnboardingOption>[];
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _page = 1;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final item in widget.selectedItems) {
      _selected[item.identity] = item;
    }
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(reset: true));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _scrollController.removeListener(_onScroll);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 280),
      () => _load(reset: true),
    );
  }

  void _onScroll() {
    if (!_hasMore || _loading || _loadingMore) return;
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 160) {
      _load(reset: false);
    }
  }

  Future<void> _load({required bool reset}) async {
    if (_loading || _loadingMore) return;

    setState(() {
      if (reset) {
        _loading = true;
        _page = 1;
        _error = null;
      } else {
        _loadingMore = true;
      }
    });

    try {
      final nextPage = reset ? 1 : _page + 1;
      final response = await widget.loadPage(
        _searchController.text.trim(),
        nextPage,
        widget.pageSize,
      );

      if (!mounted) return;
      if (!response.success) {
        setState(() {
          _error = response.message ?? 'Could not load options.';
          _loading = false;
          _loadingMore = false;
        });
        return;
      }

      setState(() {
        _error = null;
        _page = nextPage;
        _popular = response.popular;
        _hasMore = response.hasMore;
        if (reset) {
          _results = response.results;
        } else {
          final existing = _results.map((item) => item.identity).toSet();
          _results = <OnboardingOption>[
            ..._results,
            ...response.results.where(
              (item) => !existing.contains(item.identity),
            ),
          ];
        }
        _loading = false;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  void _select(OnboardingOption option) {
    if (widget.multiSelect) {
      setState(() {
        if (_selected.containsKey(option.identity)) {
          _selected.remove(option.identity);
        } else {
          _selected[option.identity] = option;
        }
      });
      widget.onChanged(_selected.values.toList());
      _clearSearchAfterSelection();
      return;
    }

    final selected = <OnboardingOption>[option];
    widget.onChanged(selected);
    _clearSearchAfterSelection();
    if (widget.closeOnSingleSelect) {
      Navigator.of(context).pop(selected);
    }
  }

  void _clearSearchAfterSelection() {
    if (_searchController.text.isEmpty) return;
    _searchController.clear();
  }

  void _finishMultiSelect() {
    final selected = _selected.values.toList();
    widget.onChanged(selected);
    Navigator.of(context).pop(selected);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewInsets = MediaQuery.viewInsetsOf(context);

    return Material(
      type: MaterialType.transparency,
      child: Align(
        alignment: Alignment.centerRight,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth;
            final minWidth = maxWidth < 300 ? maxWidth : 300.0;
            final preferredWidth = maxWidth < 520
                ? maxWidth * 0.94
                : maxWidth * 0.7;
            final width = preferredWidth.clamp(minWidth, maxWidth).toDouble();

            return AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: viewInsets.bottom),
              child: SafeArea(
                child: SizedBox(
                  width: width,
                  height: double.infinity,
                  child: Material(
                    color: theme.colorScheme.surface,
                    elevation: 24,
                    child: Column(
                      children: [
                        _PanelHeader(title: widget.title),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                          child: TextField(
                            controller: _searchController,
                            autofocus: true,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.search),
                              hintText: widget.searchHint ?? 'Search',
                              suffixIcon: _searchController.text.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: 'Clear',
                                      icon: const Icon(Icons.close),
                                      onPressed: _searchController.clear,
                                    ),
                            ),
                          ),
                        ),
                        Expanded(child: _buildBody(context)),
                        _buildFooter(context),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _PanelMessage(
        icon: Icons.error_outline,
        title: 'Unable to load',
        message: _error!,
        actionLabel: 'Retry',
        onAction: () => _load(reset: true),
      );
    }

    final showPopular =
        _searchController.text.trim().isEmpty && _popular.isNotEmpty;
    final hasResults = _results.isNotEmpty || showPopular;

    if (!hasResults) {
      return _PanelMessage(
        icon: Icons.search_off,
        title: 'No options found',
        message: 'Try another search term.',
        actionLabel: widget.allowRequestToAdd ? 'Request to add' : null,
        onAction: widget.allowRequestToAdd ? widget.onRequestToAdd : null,
      );
    }

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
      children: [
        if (showPopular) ...[
          const _SectionLabel(label: 'Popular'),
          ..._popular.map(_buildOptionTile),
          const SizedBox(height: 10),
          const _SectionLabel(label: 'All'),
        ],
        ..._results.map(_buildOptionTile),
        if (_loadingMore)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Widget _buildOptionTile(OnboardingOption option) {
    final selected = _selected.containsKey(option.identity);
    final subtitle =
        widget.itemSubtitleBuilder?.call(option) ?? option.subtitle;

    return ListTile(
      dense: true,
      selected: selected,
      leading: widget.multiSelect
          ? Checkbox(value: selected, onChanged: (_) => _select(option))
          : selected
          ? const Icon(Icons.check_circle)
          : const Icon(Icons.radio_button_unchecked),
      title: Text(option.label, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: subtitle == null
          ? null
          : Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: option.translationMissing
          ? const Tooltip(
              message: 'Translation missing. Showing fallback label.',
              child: Icon(Icons.translate, size: 18),
            )
          : null,
      onTap: () => _select(option),
    );
  }

  Widget _buildFooter(BuildContext context) {
    if (!widget.multiSelect) {
      if (!widget.allowRequestToAdd) return const SizedBox.shrink();
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: OutlinedButton.icon(
            onPressed: widget.onRequestToAdd,
            icon: const Icon(Icons.add),
            label: const Text('Request to add'),
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${_selected.length} selected',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            TextButton(
              onPressed: () {
                setState(_selected.clear);
                widget.onChanged(const <OnboardingOption>[]);
              },
              child: const Text('Clear'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _finishMultiSelect,
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PanelMessage extends StatelessWidget {
  const _PanelMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 38, color: colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
