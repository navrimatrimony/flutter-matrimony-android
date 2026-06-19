import 'package:flutter/material.dart';

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
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final comparison = widget.comparison;
    final visibleItems = _showAll || comparison.items.length <= 5
        ? comparison.items
        : comparison.items.take(5).toList();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
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
          _ComparisonHeader(comparison: comparison),
          if (comparison.summary != null || comparison.hasValidCount) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (comparison.summary != null)
                  Expanded(
                    child: Text(
                      comparison.summary!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  )
                else
                  const Spacer(),
                const SizedBox(width: 10),
                if (comparison.hasValidCount)
                  _MatchCountBadge(
                    matchedCount: comparison.matchedCount!,
                    totalCount: comparison.totalCount!,
                  ),
              ],
            ),
          ],
          if (comparison.progressValue != null) ...[
            const SizedBox(height: 14),
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
          ...visibleItems.map(
            (item) => _ComparisonRow(
              item,
              viewerLabel: comparison.viewerName,
              targetLabel: comparison.targetName,
            ),
          ),
          if (comparison.items.length > 5) ...[
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _showAll = !_showAll;
                });
              },
              icon: Icon(
                _showAll ? Icons.expand_less : Icons.expand_more,
                size: 19,
              ),
              label: Text(_showAll ? 'Show less' : 'View all'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ComparisonHeader extends StatelessWidget {
  final ProfileComparisonData comparison;

  const _ComparisonHeader({required this.comparison});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0E2DD)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _ComparisonPersonBadge(
            name: comparison.viewerName,
            photoUrl: comparison.viewerPhotoUrl,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  comparison.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    height: 1.15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
          _ComparisonPersonBadge(
            name: comparison.targetName,
            photoUrl: comparison.targetPhotoUrl,
          ),
        ],
      ),
    );
  }
}

class _ComparisonPersonBadge extends StatelessWidget {
  final String name;
  final String? photoUrl;

  const _ComparisonPersonBadge({required this.name, required this.photoUrl});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ComparisonProfilePhoto(photoUrl: photoUrl),
          const SizedBox(height: 7),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF2E2220),
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
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
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: Colors.black,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipOval(
        child: url == null
            ? const _ComparisonFallbackAvatar()
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const _ComparisonFallbackAvatar();
                },
              ),
      ),
    );
  }
}

class _ComparisonFallbackAvatar extends StatelessWidget {
  const _ComparisonFallbackAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF6E7E2),
      alignment: Alignment.center,
      child: const Icon(Icons.person, color: Color(0xFF9B1B46), size: 34),
    );
  }
}

class _MatchCountBadge extends StatelessWidget {
  final int matchedCount;
  final int totalCount;

  const _MatchCountBadge({
    required this.matchedCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7F0),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFCDEBDA)),
      ),
      child: Text(
        '$matchedCount/$totalCount',
        style: const TextStyle(
          color: Color(0xFF21784D),
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  final ProfileComparisonItemData item;
  final String viewerLabel;
  final String targetLabel;

  const _ComparisonRow(
    this.item, {
    required this.viewerLabel,
    required this.targetLabel,
  });

  @override
  Widget build(BuildContext context) {
    final status = _statusStyle(item.status);
    final showStatusChip =
        item.status == 'strong' ||
        item.status == 'match' ||
        item.status == 'near';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: status.backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: status.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(status.icon, color: status.color, size: 21),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.label,
                  style: const TextStyle(
                    color: Color(0xFF2E2220),
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (showStatusChip)
                _StatusChip(
                  label: item.statusLabel ?? status.label,
                  style: status,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _ValueBlock(label: viewerLabel, value: item.viewerValue),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ValueBlock(label: targetLabel, value: item.targetValue),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final _ComparisonStatusStyle style;

  const _StatusChip({required this.label, required this.style});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: style.chipColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: style.borderColor),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: style.color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ValueBlock extends StatelessWidget {
  final String label;
  final String? value;

  const _ValueBlock({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final displayValue = value ?? 'माहिती नाही';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF1E6E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            displayValue,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF2E2220),
              fontSize: 13,
              height: 1.25,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

_ComparisonStatusStyle _statusStyle(String status) {
  switch (status) {
    case 'strong':
      return const _ComparisonStatusStyle(
        label: 'Strong',
        icon: Icons.verified,
        color: Color(0xFF13795B),
        backgroundColor: Color(0xFFEAF8F2),
        chipColor: Color(0xFFD7F1E5),
        borderColor: Color(0xFFBFE7D5),
      );
    case 'match':
      return const _ComparisonStatusStyle(
        label: 'Match',
        icon: Icons.check_circle,
        color: Color(0xFF2F8F55),
        backgroundColor: Color(0xFFF1FAF4),
        chipColor: Color(0xFFE1F4E8),
        borderColor: Color(0xFFCDEBDA),
      );
    case 'near':
      return const _ComparisonStatusStyle(
        label: 'Near',
        icon: Icons.auto_awesome,
        color: Color(0xFF9A6A00),
        backgroundColor: Color(0xFFFFF8E7),
        chipColor: Color(0xFFFFEAB5),
        borderColor: Color(0xFFF3D993),
      );
    default:
      return const _ComparisonStatusStyle(
        label: 'Basic',
        icon: Icons.info_outline,
        color: Color(0xFF7A6F6A),
        backgroundColor: Color(0xFFFFFCFA),
        chipColor: Color(0xFFF4ECE8),
        borderColor: Color(0xFFF0E6E1),
      );
  }
}

class _ComparisonStatusStyle {
  final String label;
  final IconData icon;
  final Color color;
  final Color backgroundColor;
  final Color chipColor;
  final Color borderColor;

  const _ComparisonStatusStyle({
    required this.label,
    required this.icon,
    required this.color,
    required this.backgroundColor,
    required this.chipColor,
    required this.borderColor,
  });
}
