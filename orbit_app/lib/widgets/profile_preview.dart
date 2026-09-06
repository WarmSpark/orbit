import 'package:flutter/material.dart';

import '../theme.dart';
import 'orbit_avatar.dart';

class ProfilePreviewCard extends StatelessWidget {
  final String username;
  final String name;
  final String gender;
  final String avatar;
  final String bio;
  final String? subtitle;
  final List<Widget> actions;

  const ProfilePreviewCard({
    super.key,
    required this.username,
    required this.avatar,
    required this.bio,
    this.name = '',
    this.gender = '',
    this.subtitle,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final hasName = name.trim().isNotEmpty;
    final handle = username.isEmpty ? '' : '@$username';
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
        decoration: const BoxDecoration(
          color: OrbitColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _Grabber(),
            const SizedBox(height: 16),
            OrbitAvatar(avatar, size: 96),
            const SizedBox(height: 14),

            Text(
              hasName ? name.trim() : (handle.isEmpty ? 'Someone' : handle),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: OrbitColors.ink,
              ),
            ),

            if (hasName && handle.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                handle,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: OrbitColors.inkSoft,
                ),
              ),
            ],
            if (_genderLabel(gender) != null) ...[
              const SizedBox(height: 10),
              _GenderChip(gender: gender),
            ],
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: const TextStyle(
                  fontSize: 13,
                  color: OrbitColors.inkSoft,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: OrbitColors.bg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                bio.trim().isEmpty ? 'No bio yet.' : bio,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  color: OrbitColors.ink,
                ),
              ),
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 20),
              Row(children: actions),
            ],
          ],
        ),
      ),
    );
  }
}

class _Grabber extends StatelessWidget {
  const _Grabber();
  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 4,
    decoration: BoxDecoration(
      color: OrbitColors.line,
      borderRadius: BorderRadius.circular(2),
    ),
  );
}

Future<void> showProfilePreview(
  BuildContext context, {
  required String username,
  required String avatar,
  required String bio,
  String name = '',
  String gender = '',
  String? subtitle,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => ProfilePreviewCard(
      username: username,
      name: name,
      gender: gender,
      avatar: avatar,
      bio: bio,
      subtitle: subtitle,
    ),
  );
}

String? _genderLabel(String gender) {
  switch (gender.trim().toLowerCase()) {
    case 'male':
      return 'Male';
    case 'female':
      return 'Female';
    default:
      return null;
  }
}

class _GenderChip extends StatelessWidget {
  final String gender;
  const _GenderChip({required this.gender});

  @override
  Widget build(BuildContext context) {
    final label = _genderLabel(gender);
    if (label == null) return const SizedBox.shrink();
    final icon = gender.trim().toLowerCase() == 'female'
        ? Icons.female_rounded
        : Icons.male_rounded;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: OrbitColors.bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: OrbitColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: OrbitColors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
