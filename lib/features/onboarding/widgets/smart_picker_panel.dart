import 'dart:async';

import 'package:flutter/material.dart';

import '../models/onboarding_option.dart';
import '../models/paged_lookup_response.dart';

typedef SmartPickerPageLoader =
    Future<PagedLookupResponse> Function(String query, int page, int limit);
typedef SmartPickerFilteredPageLoader =
    Future<PagedLookupResponse> Function(
      String query,
      int page,
      int limit,
      String? filterKey,
    );

typedef SmartPickerSubtitleBuilder = String? Function(OnboardingOption option);
typedef SmartPickerOptionEnabled = bool Function(OnboardingOption option);
typedef SmartPickerEmptyTextBuilder = String Function(String query);

class SmartPickerFilterOption {
  const SmartPickerFilterOption({required this.key, required this.label});

  final String key;
  final String label;
}

class SmartPickerPanel extends StatefulWidget {
  const SmartPickerPanel({
    super.key,
    required this.title,
    required this.loadPage,
    required this.onChanged,
    this.filteredLoadPage,
    this.selectedItems = const <OnboardingOption>[],
    this.multiSelect = false,
    this.searchHint,
    this.itemSubtitleBuilder,
    this.optionEnabled,
    this.allowRequestToAdd = false,
    this.requestToAddOnlyAfterQuery = false,
    this.onRequestToAdd,
    this.closeOnSingleSelect = true,
    this.pageSize = 20,
    this.showDividers = false,
    this.showOptionSubtitles = true,
    this.showSearch = true,
    this.groupOptions = false,
    this.initialScrollIndex,
    this.initialFilterKey,
    this.filterOptions = const <SmartPickerFilterOption>[],
    this.emptyTitle,
    this.emptyMessage,
    this.emptyTitleBuilder,
    this.emptyMessageBuilder,
    this.requestToAddLabel,
    this.requestToAddLabelBuilder,
  });

  final String title;
  final SmartPickerPageLoader loadPage;
  final SmartPickerFilteredPageLoader? filteredLoadPage;
  final ValueChanged<List<OnboardingOption>> onChanged;
  final List<OnboardingOption> selectedItems;
  final bool multiSelect;
  final String? searchHint;
  final SmartPickerSubtitleBuilder? itemSubtitleBuilder;
  final SmartPickerOptionEnabled? optionEnabled;
  final bool allowRequestToAdd;
  final bool requestToAddOnlyAfterQuery;
  final VoidCallback? onRequestToAdd;
  final bool closeOnSingleSelect;
  final int pageSize;
  final bool showDividers;
  final bool showOptionSubtitles;
  final bool showSearch;
  final bool groupOptions;
  final int? initialScrollIndex;
  final String? initialFilterKey;
  final List<SmartPickerFilterOption> filterOptions;
  final String? emptyTitle;
  final String? emptyMessage;
  final SmartPickerEmptyTextBuilder? emptyTitleBuilder;
  final SmartPickerEmptyTextBuilder? emptyMessageBuilder;
  final String? requestToAddLabel;
  final SmartPickerEmptyTextBuilder? requestToAddLabelBuilder;

  static Future<List<OnboardingOption>?> show(
    BuildContext context, {
    required String title,
    required SmartPickerPageLoader loadPage,
    required ValueChanged<List<OnboardingOption>> onChanged,
    SmartPickerFilteredPageLoader? filteredLoadPage,
    List<OnboardingOption> selectedItems = const <OnboardingOption>[],
    bool multiSelect = false,
    String? searchHint,
    SmartPickerSubtitleBuilder? itemSubtitleBuilder,
    SmartPickerOptionEnabled? optionEnabled,
    bool allowRequestToAdd = false,
    bool requestToAddOnlyAfterQuery = false,
    VoidCallback? onRequestToAdd,
    bool closeOnSingleSelect = true,
    int pageSize = 20,
    bool showDividers = false,
    bool showOptionSubtitles = true,
    bool showSearch = true,
    bool groupOptions = false,
    int? initialScrollIndex,
    String? initialFilterKey,
    List<SmartPickerFilterOption> filterOptions =
        const <SmartPickerFilterOption>[],
    String? emptyTitle,
    String? emptyMessage,
    SmartPickerEmptyTextBuilder? emptyTitleBuilder,
    SmartPickerEmptyTextBuilder? emptyMessageBuilder,
    String? requestToAddLabel,
    SmartPickerEmptyTextBuilder? requestToAddLabelBuilder,
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
          filteredLoadPage: filteredLoadPage,
          onChanged: onChanged,
          selectedItems: selectedItems,
          multiSelect: multiSelect,
          searchHint: searchHint,
          itemSubtitleBuilder: itemSubtitleBuilder,
          optionEnabled: optionEnabled,
          allowRequestToAdd: allowRequestToAdd,
          requestToAddOnlyAfterQuery: requestToAddOnlyAfterQuery,
          onRequestToAdd: onRequestToAdd,
          closeOnSingleSelect: closeOnSingleSelect,
          pageSize: pageSize,
          showDividers: showDividers,
          showOptionSubtitles: showOptionSubtitles,
          showSearch: showSearch,
          groupOptions: groupOptions,
          initialScrollIndex: initialScrollIndex,
          initialFilterKey: initialFilterKey,
          filterOptions: filterOptions,
          emptyTitle: emptyTitle,
          emptyMessage: emptyMessage,
          emptyTitleBuilder: emptyTitleBuilder,
          emptyMessageBuilder: emptyMessageBuilder,
          requestToAddLabel: requestToAddLabel,
          requestToAddLabelBuilder: requestToAddLabelBuilder,
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
  static const Color _selectedGreen = Color(0xFF0F8F5F);
  static const Color _selectedGreenSurface = Color(0xFFE7F6ED);

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Map<String, OnboardingOption> _selected = <String, OnboardingOption>{};

  Timer? _debounce;
  List<OnboardingOption> _results = <OnboardingOption>[];
  List<OnboardingOption> _popular = <OnboardingOption>[];
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = false;
  bool _initialScrollApplied = false;
  int _page = 1;
  String? _error;
  String? _selectedFilterKey;

  @override
  void initState() {
    super.initState();
    _selectedFilterKey = widget.filterOptions.isEmpty
        ? null
        : widget.filterOptions.any(
            (option) => option.key == widget.initialFilterKey,
          )
        ? widget.initialFilterKey
        : widget.filterOptions.first.key;
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
      final query = _searchController.text.trim();
      final response = widget.filteredLoadPage == null
          ? await widget.loadPage(query, nextPage, widget.pageSize)
          : await widget.filteredLoadPage!(
              query,
              nextPage,
              widget.pageSize,
              _selectedFilterKey,
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
      _scheduleInitialScrollIfNeeded(reset: reset);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  void _scheduleInitialScrollIfNeeded({required bool reset}) {
    if (!reset || _initialScrollApplied) return;
    if (_searchController.text.trim().isNotEmpty) return;
    final index = widget.initialScrollIndex;
    if (index == null || index <= 0 || index >= _results.length) return;

    _initialScrollApplied = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      const estimatedTileExtent = 49.0;
      final target = (index * estimatedTileExtent).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.jumpTo(target);
    });
  }

  void _select(OnboardingOption option) {
    if (!(widget.optionEnabled?.call(option) ?? true)) return;

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

  void _setFilter(String key) {
    if (_selectedFilterKey == key) return;
    setState(() {
      _selectedFilterKey = key;
      _results = const <OnboardingOption>[];
      _popular = const <OnboardingOption>[];
      _hasMore = false;
      _page = 1;
    });
    _load(reset: true);
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
            final minWidth = maxWidth < 360 ? maxWidth : 300.0;
            final preferredWidth = maxWidth * 0.7;
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
                        if (widget.showSearch)
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
                          )
                        else
                          const SizedBox(height: 6),
                        if (widget.filterOptions.length > 1)
                          _FilterChips(
                            options: widget.filterOptions,
                            selectedKey: _selectedFilterKey,
                            enabled: !_loading && !_loadingMore,
                            onSelected: _setFilter,
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
      final query = _searchController.text.trim();
      final canRequestToAdd =
          widget.allowRequestToAdd &&
          (!widget.requestToAddOnlyAfterQuery || query.isNotEmpty);
      return _PanelMessage(
        icon: Icons.search_off,
        title:
            widget.emptyTitleBuilder?.call(query) ??
            widget.emptyTitle ??
            'No options found',
        message:
            widget.emptyMessageBuilder?.call(query) ??
            widget.emptyMessage ??
            'Try another search term.',
        actionLabel: canRequestToAdd
            ? widget.requestToAddLabelBuilder?.call(query) ??
                  widget.requestToAddLabel ??
                  'Request to add'
            : null,
        onAction: canRequestToAdd ? widget.onRequestToAdd : null,
      );
    }

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
      children: [
        if (showPopular) ...[
          const _SectionLabel(label: 'Popular'),
          ..._buildOptionTiles(_popular),
          const SizedBox(height: 10),
          const _SectionLabel(label: 'All'),
        ],
        ..._buildOptionTiles(_results),
        if (_loadingMore)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  List<Widget> _buildOptionTiles(List<OnboardingOption> options) {
    if (!widget.showDividers && !widget.groupOptions) {
      return options.map(_buildOptionTile).toList();
    }

    final tiles = <Widget>[];
    String? previousGroup;
    var hasAddedOption = false;
    for (final option in options) {
      final groupLabel = widget.groupOptions ? _optionGroupLabel(option) : null;
      if (widget.showDividers && hasAddedOption) {
        tiles.add(
          Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
        );
      }
      if (groupLabel != null && groupLabel != previousGroup) {
        if (hasAddedOption) {
          tiles.add(const SizedBox(height: 8));
        }
        tiles.add(_SectionLabel(label: groupLabel));
        previousGroup = groupLabel;
      }
      tiles.add(_buildOptionTile(option));
      hasAddedOption = true;
    }
    return tiles;
  }

  Widget _buildOptionTile(OnboardingOption option) {
    final selected = _selected.containsKey(option.identity);
    final subtitle = widget.showOptionSubtitles
        ? (widget.itemSubtitleBuilder?.call(option) ?? option.subtitle)
        : null;
    final enabled = widget.optionEnabled?.call(option) ?? true;

    return ListTile(
      dense: true,
      enabled: enabled,
      selected: selected,
      selectedTileColor: _selectedGreenSurface,
      selectedColor: _selectedGreen,
      leading: widget.multiSelect
          ? Checkbox(
              value: selected,
              onChanged: enabled ? (_) => _select(option) : null,
              activeColor: _selectedGreen,
            )
          : selected
          ? const Icon(Icons.check_circle, color: _selectedGreen)
          : const Icon(Icons.radio_button_unchecked),
      title: Text(option.label, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: subtitle == null
          ? null
          : Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: !enabled
          ? const Tooltip(
              message: 'Not selectable for this field.',
              child: Icon(Icons.lock_outline, size: 18),
            )
          : option.translationMissing
          ? const Tooltip(
              message: 'Translation missing. Showing fallback label.',
              child: Icon(Icons.translate, size: 18),
            )
          : null,
      onTap: enabled ? () => _select(option) : null,
    );
  }

  String? _optionGroupLabel(OnboardingOption option) {
    return option.metaText('group_label');
  }

  Widget _buildFooter(BuildContext context) {
    if (!widget.multiSelect) {
      if (!widget.allowRequestToAdd || widget.requestToAddOnlyAfterQuery) {
        return const SizedBox.shrink();
      }
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: OutlinedButton.icon(
            onPressed: widget.onRequestToAdd,
            icon: const Icon(Icons.add),
            label: Text(widget.requestToAddLabel ?? 'Request to add'),
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

class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.options,
    required this.selectedKey,
    required this.enabled,
    required this.onSelected,
  });

  final List<SmartPickerFilterOption> options;
  final String? selectedKey;
  final bool enabled;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final option = options[index];
          return ChoiceChip(
            label: Text(option.label),
            selected: option.key == selectedKey,
            onSelected: enabled ? (_) => onSelected(option.key) : null,
          );
        },
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemCount: options.length,
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
            if (message.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
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
