import 'package:flutter/material.dart';

class ProfilePhotoView extends StatelessWidget {
  const ProfilePhotoView({
    super.key,
    required this.photoUrl,
    required this.width,
    required this.height,
    this.circle = false,
    this.borderRadius,
    this.backgroundColor = const Color(0xFFF1DDD8),
    this.placeholderColor = const Color(0xFF9B1B46),
    this.placeholderIcon = Icons.person,
    this.placeholderSize,
    this.border,
  });

  final String? photoUrl;
  final double width;
  final double height;
  final bool circle;
  final BorderRadius? borderRadius;
  final Color backgroundColor;
  final Color placeholderColor;
  final IconData placeholderIcon;
  final double? placeholderSize;
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(8);
    final content = photoUrl == null
        ? _fallback()
        : Image.network(
            photoUrl!,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            errorBuilder: (_, _, _) => _fallback(),
          );

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : radius,
        border: border,
      ),
      clipBehavior: Clip.antiAlias,
      child: circle
          ? ClipOval(child: content)
          : ClipRRect(borderRadius: radius, child: content),
    );
  }

  Widget _fallback() {
    return Container(
      color: backgroundColor,
      alignment: Alignment.center,
      child: Icon(
        placeholderIcon,
        color: placeholderColor,
        size: placeholderSize ?? (width < height ? width : height) * 0.48,
      ),
    );
  }
}
