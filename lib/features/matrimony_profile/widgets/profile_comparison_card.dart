import 'package:flutter/material.dart';

import '../../../core/app_strings.dart';
import '../../../core/profile_photo_view.dart';

class ProfileComparisonData {
  final String title;
  final String? summary;
  final String viewerName;
  final String? viewerPhotoUrl;
  final String targetName;
  final String? targetPhotoUrl;
  final int? matchedCount;
  final int? totalCount;
  final List<ProfileComparisonItemData> items;

  const ProfileComparisonData({
    required this.title,
    required this.summary,
    required this.viewerName,
    required this.viewerPhotoUrl,
    required this.targetName,
    required this.targetPhotoUrl,
    required this.matchedCount,
    required this.totalCount,
    required this.items,
  });

  bool get hasValidCount {
    final matched = matchedCount;
    final total = totalCount;
    return matched != null && total != null && matched >= 0 && total > 0;
  }

  double? get progressValue {
    if (!hasValidCount) return null;
    return (matchedCount! / totalCount!).clamp(0, 1).toDouble();
  }
}

class ProfileComparisonItemData {
  final String? key;
  final String label;
  final String status;
  final String? statusLabel;
  final String? targetValue;
  final String? viewerValue;
  final bool isCounted;

  const ProfileComparisonItemData({
    required this.key,
    required this.label,
    required this.status,
    required this.statusLabel,
    required this.targetValue,
    required this.viewerValue,
    required this.isCounted,
  });
}

class ProfileComparisonCard extends StatefulWidget {
  final ProfileComparisonData comparison;

  const ProfileComparisonCard({super.key, required this.comparison});

  @override
  State<ProfileComparisonCard> createState() => _ProfileComparisonCardState();
}

class _ProfileComparisonCardState extends State<ProfileComparisonCard> {
  static const int _visibleLimit = 12;

  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final comparison = widget.comparison;
    final visibleItems = _showAll || comparison.items.length <= _visibleLimit
        ? comparison.items
        : comparison.items.take(_visibleLimit).toList();
    final groups = _groupItems(visibleItems);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEDE2DE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PreferenceTitle(
            title: AppStrings.comparisonPreferenceTitle(comparison.title),
          ),
          const SizedBox(height: 12),
          _PreferenceHeroSummary(comparison: comparison),
          if (comparison.progressValue != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: comparison.progressValue,
                minHeight: 7,
                backgroundColor: const Color(0xFFF1ECE9),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF2F9E67),
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          for (final group in groups) ...[
            _PreferenceGroupHeader(
              title: AppStrings.comparisonPreferenceGroup(group.key),
            ),
            const SizedBox(height: 8),
            for (final item in group.items) _PreferenceRow(item: item),
            const SizedBox(height: 8),
          ],
          if (comparison.items.length > _visibleLimit) ...[
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _showAll = !_showAll;
                  });
                },
                icon: Icon(
                  _showAll ? Icons.expand_less : Icons.expand_more,
                  size: 19,
                ),
                label: Text(
                  _showAll
                      ? AppStrings.comparisonShowLess
                      : AppStrings.comparisonViewAll,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<_ComparisonGroup> _groupItems(List<ProfileComparisonItemData> items) {
    final grouped = <String, List<ProfileComparisonItemData>>{
      'basic': [],
      'religious': [],
      'professional': [],
      'location': [],
      'lifestyle': [],
      'other': [],
    };

    for (final item in items) {
      final groupKey = _groupKeyForItem(item);
      grouped.putIfAbsent(groupKey, () => []).add(item);
    }

    return grouped.entries
        .where((entry) => entry.value.isNotEmpty)
        .map((entry) => _ComparisonGroup(entry.key, entry.value))
        .toList();
  }
}

class _PreferenceTitle extends StatelessWidget {
  final String title;

  const _PreferenceTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.auto_awesome, color: Color(0xFF9B1B46), size: 18),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: const Color(0xFF2E2220),
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 8),
        const Icon(Icons.auto_awesome, color: Color(0xFF9B1B46), size: 18),
      ],
    );
  }
}

class _PreferenceHeroSummary extends StatelessWidget {
  final ProfileComparisonData comparison;

  const _PreferenceHeroSummary({required this.comparison});

  @override
  Widget build(BuildContext context) {
    final summary = comparison.hasValidCount
        ? AppStrings.comparisonPreferenceMatchSummary(
            comparison.matchedCount!,
            comparison.totalCount!,
            comparison.title,
          )
        : comparison.summary ??
              AppStrings.comparisonPreferenceFallbackSummary(comparison.title);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8FC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7B7DA)),
      ),
      child: Row(
        children: [
          _ComparisonProfilePhoto(photoUrl: comparison.targetPhotoUrl),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              summary,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF2E2220),
                fontSize: 14,
                height: 1.25,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          _ComparisonProfilePhoto(photoUrl: comparison.viewerPhotoUrl),
        ],
      ),
    );
  }
}

class _PreferenceGroupHeader extends StatelessWidget {
  final String title;

  const _PreferenceGroupHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9F7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF5ECE8)),
      ),
      child: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFF2E2220),
          fontSize: 14,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _PreferenceRow extends StatelessWidget {
  final ProfileComparisonItemData item;

  const _PreferenceRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final targetValue = item.targetValue ?? AppStrings.comparisonValueUnknown;
    final viewerValue = item.viewerValue?.trim();
    final showViewerValue =
        viewerValue != null &&
        viewerValue.isNotEmpty &&
        item.status != 'strong' &&
        item.status != 'match';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF1E6E1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.comparisonPreferredLabel(item.label),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  targetValue,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF2E2220),
                    fontSize: 13.5,
                    height: 1.25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (showViewerValue) ...[
                  const SizedBox(height: 4),
                  Text(
                    AppStrings.comparisonYourValue(viewerValue),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF7A6F6A),
                      fontSize: 11.5,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          _PreferenceStatusIcon(status: item.status, label: item.statusLabel),
        ],
      ),
    );
  }
}

class _PreferenceStatusIcon extends StatelessWidget {
  final String status;
  final String? label;

  const _PreferenceStatusIcon({required this.status, required this.label});

  @override
  Widget build(BuildContext context) {
    final style = _statusStyle(status);

    return Tooltip(
      message: label ?? style.label,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: style.chipColor,
          shape: BoxShape.circle,
          border: Border.all(color: style.borderColor),
        ),
        child: Icon(style.icon, color: style.color, size: 22),
      ),
    );
  }
}

class _ComparisonProfilePhoto extends StatelessWidget {
  final String? photoUrl;

  const _ComparisonProfilePhoto({required this.photoUrl});

  @override
  Widget build(BuildContext context) {
    final url = photoUrl;

    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        color: const Color(0xFFF6E7E2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ProfilePhotoView(
        photoUrl: url,
        width: 62,
        height: 62,
        borderRadius: BorderRadius.circular(11),
        backgroundColor: const Color(0xFFF6E7E2),
        placeholderColor: const Color(0xFF9B1B46),
        placeholderIcon: Icons.person,
        placeholderSize: 32,
      ),
    );
  }
}

class _ComparisonGroup {
  final String key;
  final List<ProfileComparisonItemData> items;

  const _ComparisonGroup(this.key, this.items);
}

String _groupKeyForItem(ProfileComparisonItemData item) {
  final value = '${item.key ?? ''} ${item.label}'.toLowerCase();

  if (value.contains('age') ||
      value.contains('height') ||
      value.contains('marital')) {
    return 'basic';
  }
  if (value.contains('religion') ||
      value.contains('caste') ||
      value.contains('community') ||
      value.contains('sub-caste') ||
      value.contains('sub_caste') ||
      value.contains('gunamilan')) {
    return 'religious';
  }
  if (value.contains('education') ||
      value.contains('profession') ||
      value.contains('occupation') ||
      value.contains('income') ||
      value.contains('work')) {
    return 'professional';
  }
  if (value.contains('location') ||
      value.contains('country') ||
      value.contains('state') ||
      value.contains('district') ||
      value.contains('taluka') ||
      value.contains('city')) {
    return 'location';
  }
  if (value.contains('diet') ||
      value.contains('eating') ||
      value.contains('smoking') ||
      value.contains('drinking') ||
      value.contains('lifestyle')) {
    return 'lifestyle';
  }

  return 'other';
}

_ComparisonStatusStyle _statusStyle(String status) {
  switch (status) {
    case 'strong':
      return const _ComparisonStatusStyle(
        label: 'Strong match',
        icon: Icons.verified_outlined,
        color: Color(0xFF13795B),
        chipColor: Color(0xFFE2F4EB),
        borderColor: Color(0xFFAEDCC8),
      );
    case 'match':
      return const _ComparisonStatusStyle(
        label: 'Match',
        icon: Icons.check_circle_outline,
        color: Color(0xFF2F8F55),
        chipColor: Color(0xFFE7F6ED),
        borderColor: Color(0xFFBFE7D5),
      );
    case 'near':
    case 'flexible':
      return const _ComparisonStatusStyle(
        label: 'Near match',
        icon: Icons.check_circle_outline,
        color: Color(0xFF9A6A00),
        chipColor: Color(0xFFFFF4D8),
        borderColor: Color(0xFFEED088),
      );
    case 'not_matched':
    case 'mismatch':
      return const _ComparisonStatusStyle(
        label: 'Needs review',
        icon: Icons.cancel_outlined,
        color: Color(0xFFB33A3A),
        chipColor: Color(0xFFFFEEEE),
        borderColor: Color(0xFFF0B8B8),
      );
    default:
      return const _ComparisonStatusStyle(
        label: 'Review',
        icon: Icons.help_outline,
        color: Color(0xFF7A6F6A),
        chipColor: Color(0xFFF4ECE8),
        borderColor: Color(0xFFE5D8D2),
      );
  }
}

class _ComparisonStatusStyle {
  final String label;
  final IconData icon;
  final Color color;
  final Color chipColor;
  final Color borderColor;

  const _ComparisonStatusStyle({
    required this.label,
    required this.icon,
    required this.color,
    required this.chipColor,
    required this.borderColor,
  });
}
