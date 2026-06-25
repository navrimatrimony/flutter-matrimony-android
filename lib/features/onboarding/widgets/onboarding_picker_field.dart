import 'package:flutter/material.dart';

import '../models/onboarding_option.dart';
import '../models/paged_lookup_response.dart';
import 'smart_picker_panel.dart';

class OnboardingPickerField extends StatelessWidget {
  const OnboardingPickerField({
    super.key,
    required this.label,
    required this.loadPage,
    required this.onChanged,
    this.selectedItems = const <OnboardingOption>[],
    this.multiSelect = false,
    this.placeholder,
    this.searchHint,
    this.itemSubtitleBuilder,
    this.optionEnabled,
    this.allowRequestToAdd = false,
    this.onRequestToAdd,
    this.enabled = true,
  });

  final String label;
  final Future<PagedLookupResponse> Function(String query, int page, int limit)
  loadPage;
  final ValueChanged<List<OnboardingOption>> onChanged;
  final List<OnboardingOption> selectedItems;
  final bool multiSelect;
  final String? placeholder;
  final String? searchHint;
  final SmartPickerSubtitleBuilder? itemSubtitleBuilder;
  final SmartPickerOptionEnabled? optionEnabled;
  final bool allowRequestToAdd;
  final VoidCallback? onRequestToAdd;
  final bool enabled;
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
                      if (!multiSelect) {
                        return Text(
                          item.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _selectedGreen,
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
                            item.label,
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
      onChanged: onChanged,
      selectedItems: selectedItems,
      multiSelect: multiSelect,
      searchHint: searchHint,
      itemSubtitleBuilder: itemSubtitleBuilder,
      optionEnabled: optionEnabled,
      allowRequestToAdd: allowRequestToAdd,
      onRequestToAdd: onRequestToAdd,
    );
  }
}
