import 'package:flutter/material.dart';

import 'app_strings.dart';
import '../core/app_language.dart';

class AppLoadingState extends StatelessWidget {
  final String title;
  final String? message;
  final IconData icon;
  final int skeletonRows;
  final EdgeInsetsGeometry padding;

  const AppLoadingState({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.favorite_rounded,
    this.skeletonRows = 3,
    this.padding = const EdgeInsets.fromLTRB(16, 18, 16, 24),
  });

  factory AppLoadingState.matches() {
    return AppLoadingState(
      title: appText.loadingMatches,
      message: appText.preparingProfilesForYou,
      icon: Icons.favorite_border_rounded,
      skeletonRows: 2,
    );
  }

  factory AppLoadingState.profile() {
    return AppLoadingState(
      title: appText.loadingProfile,
      message: appText.preparingYourInformation,
      icon: Icons.person_outline_rounded,
      skeletonRows: 4,
    );
  }

  factory AppLoadingState.list({
    required String title,
    IconData icon = Icons.list_alt_rounded,
    int skeletonRows = 4,
  }) {
    return AppLoadingState(
      title: title,
      icon: icon,
      skeletonRows: skeletonRows,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: padding,
      children: [
        _LoadingHero(title: title, message: message, icon: icon),
        const SizedBox(height: 14),
        for (var i = 0; i < skeletonRows; i++) ...[
          _SkeletonCard(compact: i > 0),
          if (i != skeletonRows - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _LoadingHero extends StatelessWidget {
  final String title;
  final String? message;
  final IconData icon;

  const _LoadingHero({
    required this.title,
    required this.message,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF8C7CF)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                color: Color(0xFFDC2626),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF3A2328),
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (message != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      message!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF72545A),
                        fontSize: 13,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  final bool compact;

  const _SkeletonCard({required this.compact});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8DDD7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _SkeletonBlock(width: 58, height: 58, radius: 16),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    _SkeletonBlock(width: double.infinity, height: 16),
                    SizedBox(height: 9),
                    _SkeletonBlock(width: 150, height: 13),
                  ],
                ),
              ),
            ],
          ),
          if (!compact) ...[
            const SizedBox(height: 15),
            const _SkeletonBlock(width: double.infinity, height: 12),
            const SizedBox(height: 8),
            const _SkeletonBlock(width: 220, height: 12),
          ],
        ],
      ),
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const _SkeletonBlock({
    required this.width,
    required this.height,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFF2E7E2),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
