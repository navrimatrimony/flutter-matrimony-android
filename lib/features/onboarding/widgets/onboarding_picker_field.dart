import 'package:flutter/material.dart';

import '../models/onboarding_option.dart';
import '../models/paged_lookup_response.dart';
import 'smart_picker_panel.dart';

typedef OnboardingPickerSelectedLabelBuilder =
    String Function(OnboardingOption option);

class OnboardingPickerField extends StatelessWidget {
  const OnboardingPickerField({
    super.key,
    required this.label,
    required this.loadPage,
    required this.onChanged,
    this.filteredLoadPage,
    this.selectedItems = const <OnboardingOption>[],
    this.multiSelect = false,
    this.placeholder,
    this.searchHint,
    this.itemSubtitleBuilder,
    this.selectedLabelBuilder,
    this.optionEnabled,
    this.allowRequestToAdd = false,
    this.requestToAddOnlyAfterQuery = false,
    this.onRequestToAdd,
    this.enabled = true,
    this.errorText,
    this.showDividers = false,
    this.showOptionSubtitles = true,
    this.groupOptions = false,
    this.filterOptions = const <SmartPickerFilterOption>[],
    this.emptyTitle,
    this.emptyMessage,
    this.emptyTitleBuilder,
    this.emptyMessageBuilder,
    this.requestToAddLabel,
    this.requestToAddLabelBuilder,
  });

  final String label;
  final Future<PagedLookupResponse> Function(String query, int page, int limit)
  loadPage;
  final SmartPickerFilteredPageLoader? filteredLoadPage;
  final ValueChanged<List<OnboardingOption>> onChanged;
  final List<OnboardingOption> selectedItems;
  final bool multiSelect;
  final String? placeholder;
  final String? searchHint;
  final SmartPickerSubtitleBuilder? itemSubtitleBuilder;
  final OnboardingPickerSelectedLabelBuilder? selectedLabelBuilder;
  final SmartPickerOptionEnabled? optionEnabled;
  final bool allowRequestToAdd;
  final bool requestToAddOnlyAfterQuery;
  final VoidCallback? onRequestToAdd;
  final bool enabled;
  final String? errorText;
  final bool showDividers;
  final bool showOptionSubtitles;
  final bool groupOptions;
  final List<SmartPickerFilterOption> filterOptions;
  final String? emptyTitle;
  final String? emptyMessage;
  final SmartPickerEmptyTextBuilder? emptyTitleBuilder;
  final SmartPickerEmptyTextBuilder? emptyMessageBuilder;
  final String? requestToAddLabel;
  final SmartPickerEmptyTextBuilder? requestToAddLabelBuilder;
  static const Color _selectedGreen = Color(0xFF0F8F5F);
  static const Color _selectedGreenSurface = Color(0xFFE7F6ED);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasSelection = selectedItems.isNotEmpty;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: enabled ? () => _openPanel(context) : null,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          errorText: errorText,
          suffixIcon: Icon(
            Icons.chevron_right,
            color: enabled ? colorScheme.primary : Colors.grey,
          ),
          enabled: enabled,
        ),
        child: hasSelection
            ? LayoutBuilder(
                builder: (context, constraints) {
                  final chipLabelMaxWidth = (constraints.maxWidth - 54)
                      .clamp(120.0, constraints.maxWidth)
                      .toDouble();
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: selectedItems.map((item) {
                      final selectedLabel =
                          selectedLabelBuilder?.call(item) ?? item.label;
                      if (!multiSelect) {
                        return Text(
                          selectedLabel,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey.shade900,
                            fontWeight: FontWeight.w700,
                          ),
                        );
                      }

                      return InputChip(
                        backgroundColor: _selectedGreenSurface,
                        selectedColor: _selectedGreenSurface,
                        side: const BorderSide(color: _selectedGreen),
                        label: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: chipLabelMaxWidth,
                          ),
                          child: Text(
                            selectedLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _selectedGreen,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        onDeleted: enabled
                            ? () {
                                onChanged(
                                  selectedItems
                                      .where(
                                        (selected) =>
                                            selected.identity != item.identity,
                                      )
                                      .toList(),
                                );
                              }
                            : null,
                      );
                    }).toList(),
                  );
                },
              )
            : Text(
                placeholder ?? 'Select',
                style: TextStyle(color: Colors.grey.shade700),
              ),
      ),
    );
  }

  Future<void> _openPanel(BuildContext context) {
    return SmartPickerPanel.show(
      context,
      title: label,
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
      showDividers: showDividers,
      showOptionSubtitles: showOptionSubtitles,
      groupOptions: groupOptions,
      filterOptions: filterOptions,
      emptyTitle: emptyTitle,
      emptyMessage: emptyMessage,
      emptyTitleBuilder: emptyTitleBuilder,
      emptyMessageBuilder: emptyMessageBuilder,
      requestToAddLabel: requestToAddLabel,
      requestToAddLabelBuilder: requestToAddLabelBuilder,
    );
  }
}
