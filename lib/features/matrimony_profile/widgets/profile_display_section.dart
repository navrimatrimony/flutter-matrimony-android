import 'package:flutter/material.dart';

class ProfileDisplaySectionData {
  final String key;
  final String title;
  final List<ProfileDisplayItemData> items;

  const ProfileDisplaySectionData({
    required this.key,
    required this.title,
    required this.items,
  });

  static ProfileDisplaySectionData? fromMap(dynamic value) {
    if (value is! Map) return null;

    final Map<String, dynamic> row;
    try {
      row = Map<String, dynamic>.from(value);
    } catch (_) {
      return null;
    }
    final title = _cleanDisplayString(row['title']);
    if (title == null) return null;

    final rawItems = row['items'];
    if (rawItems is! List) return null;

    final items = rawItems
        .map(ProfileDisplayItemData.fromMap)
        .whereType<ProfileDisplayItemData>()
        .toList();

    if (items.isEmpty) return null;

    return ProfileDisplaySectionData(
      key: _cleanDisplayString(row['key']) ?? '',
      title: title,
      items: items,
    );
  }
}

class ProfileDisplayItemData {
  final String label;
  final String value;
  final String? icon;
  final bool locked;

  const ProfileDisplayItemData({
    required this.label,
    required this.value,
    this.icon,
    this.locked = false,
  });

  static ProfileDisplayItemData? fromMap(dynamic value) {
    if (value is! Map) return null;

    final Map<String, dynamic> row;
    try {
      row = Map<String, dynamic>.from(value);
    } catch (_) {
      return null;
    }
    final label = _cleanDisplayString(row['label']);
    final displayValue = _cleanDisplayString(row['value']);
    if (label == null || displayValue == null) return null;

    return ProfileDisplayItemData(
      label: label,
      value: displayValue,
      icon: _cleanDisplayString(row['icon']),
      locked: row['locked'] == true,
    );
  }
}

class ProfileDisplaySection extends StatelessWidget {
  final ProfileDisplaySectionData section;
  final String? titleOverride;
  final Widget? headerTrailing;

  const ProfileDisplaySection({
    super.key,
    required this.section,
    this.titleOverride,
    this.headerTrailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  titleOverride ?? section.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF2E2220),
                  ),
                ),
              ),
              if (headerTrailing != null) ...[
                const SizedBox(width: 12),
                headerTrailing!,
              ],
            ],
          ),
          const SizedBox(height: 12),
          ...section.items.map(ProfileDisplayItem.new),
        ],
      ),
    );
  }
}

class ProfileDisplayItem extends StatelessWidget {
  final ProfileDisplayItemData item;

  const ProfileDisplayItem(this.item, {super.key});

  @override
  Widget build(BuildContext context) {
    final muted = item.locked;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: muted
                  ? const Color(0xFFF1ECE9)
                  : const Color(0xFF9B1B46).withValues(alpha: 0.09),
              shape: BoxShape.circle,
            ),
            child: Icon(
              muted ? Icons.lock_outline : _iconFor(item.icon),
              size: 18,
              color: muted ? Colors.grey.shade600 : const Color(0xFF9B1B46),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.value,
                  softWrap: true,
                  style: TextStyle(
                    color: muted ? Colors.grey.shade700 : Colors.black87,
                    fontSize: 15,
                    height: 1.32,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

IconData _iconFor(String? icon) {
  switch (icon?.trim().toLowerCase()) {
    case 'id':
    case 'profile':
      return Icons.badge;
    case 'age':
    case 'calendar':
      return Icons.calendar_today;
    case 'height':
      return Icons.straighten;
    case 'heart':
      return Icons.favorite_border;
    case 'location':
      return Icons.place;
    case 'community':
      return Icons.people_outline;
    case 'language':
      return Icons.translate;
    case 'diet':
      return Icons.restaurant;
    case 'family':
    case 'parents':
    case 'siblings':
    case 'relatives':
      return Icons.people_outline;
    case 'income':
      return Icons.attach_money;
    case 'property':
      return Icons.home;
    case 'education':
      return Icons.school;
    case 'work':
    case 'company':
      return Icons.work;
    case 'astro':
      return Icons.auto_awesome;
    case 'time':
      return Icons.access_time;
    default:
      return Icons.check_circle_outline;
  }
}

String? _cleanDisplayString(dynamic value) {
  if (value == null) return null;
  if (value is Map || value is List) return null;
  if (value is bool) return value ? 'Yes' : 'No';

  final text = value.toString().trim();
  if (text.isEmpty) return null;
  if (text.startsWith('{') || text.startsWith('[')) return null;
  if (text.contains('=>')) return null;
  if (text.toLowerCase().startsWith('location id:')) return null;

  return text;
}
