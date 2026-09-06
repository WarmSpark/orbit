import 'package:flutter/material.dart';

import '../theme.dart';

class AvatarStyle {
  final String key;
  final String emoji;
  final Color color;
  const AvatarStyle(this.key, this.emoji, this.color);
}

const List<AvatarStyle> kAvatarStyles = [
  AvatarStyle('coral', '🦊', Color(0xFFFF8A3D)),
  AvatarStyle('ocean', '🐳', Color(0xFF2DA4FF)),
  AvatarStyle('forest', '🐸', Color(0xFF22C55E)),
  AvatarStyle('grape', '🦄', Color(0xFF7C5CFC)),
  AvatarStyle('sun', '🐥', Color(0xFFF5B942)),
  AvatarStyle('rose', '🌸', Color(0xFFFF5A7A)),
  AvatarStyle('sky', '⛅', Color(0xFF5B6EF5)),
  AvatarStyle('mint', '🍀', Color(0xFF14B8A6)),
];

const AvatarStyle _fallback = AvatarStyle(
  'default_white',
  '🙂',
  OrbitColors.primary,
);

AvatarStyle avatarStyleFor(String key) =>
    kAvatarStyles.firstWhere((a) => a.key == key, orElse: () => _fallback);

class OrbitAvatar extends StatelessWidget {
  final String avatarKey;
  final double size;
  final VoidCallback? onTap;

  const OrbitAvatar(this.avatarKey, {super.key, this.size = 44, this.onTap});

  @override
  Widget build(BuildContext context) {
    final style = avatarStyleFor(avatarKey);
    final circle = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: style.color.withValues(alpha: 0.18),
        border: Border.all(
          color: style.color.withValues(alpha: 0.55),
          width: 2,
        ),
      ),
      child: Text(style.emoji, style: TextStyle(fontSize: size * 0.5)),
    );

    if (onTap == null) return circle;
    return GestureDetector(onTap: onTap, child: circle);
  }
}
