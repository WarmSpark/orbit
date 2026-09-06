import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/orbit_avatar.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You can sign back in with Google anytime.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: OrbitColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<AppState>().logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppState>().user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const EditProfileScreen()),
            ),
          ),
        ],
      ),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                const SizedBox(height: 8),
                Center(child: OrbitAvatar(user.avatar, size: 108)),
                const SizedBox(height: 16),
                if (user.name.trim().isNotEmpty)
                  Center(
                    child: Text(
                      user.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    user.username.isEmpty ? 'you' : '@${user.username}',
                    style: TextStyle(
                      fontSize: user.name.trim().isEmpty ? 22 : 15,
                      fontWeight: user.name.trim().isEmpty
                          ? FontWeight.w800
                          : FontWeight.w600,
                      color: user.name.trim().isEmpty
                          ? OrbitColors.ink
                          : OrbitColors.inkSoft,
                    ),
                  ),
                ),
                if (_genderLabel(user.gender) != null) ...[
                  const SizedBox(height: 10),
                  Center(child: _GenderChip(gender: user.gender)),
                ],
                if (user.email.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      user.email,
                      style: const TextStyle(color: OrbitColors.inkSoft),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                _SectionCard(
                  title: 'About you',
                  child: Text(
                    user.bio.trim().isEmpty
                        ? 'No bio yet — tap edit to add one.'
                        : user.bio,
                    style: TextStyle(
                      height: 1.4,
                      color: user.bio.trim().isEmpty
                          ? OrbitColors.inkSoft
                          : OrbitColors.ink,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const EditProfileScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Edit profile'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    side: const BorderSide(color: OrbitColors.line),
                    foregroundColor: OrbitColors.ink,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _logout(context),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Log out'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    side: const BorderSide(color: OrbitColors.danger),
                    foregroundColor: OrbitColors.danger,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Center(
                  child: Text(
                    'Orbit · NCR beta',
                    style: TextStyle(color: OrbitColors.inkSoft, fontSize: 12),
                  ),
                ),
              ],
            ),
    );
  }
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
        color: OrbitColors.surface,
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

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: OrbitColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: OrbitColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: OrbitColors.inkSoft,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

enum _NameState { empty, checking, available, taken, invalid }

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _usernameCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  String _avatar = kAvatarStyles.first.key;
  String _gender = '';
  Timer? _debounce;
  _NameState _nameState = _NameState.available;
  String _nameMsg = '';
  bool _saving = false;
  String _originalName = '';

  @override
  void initState() {
    super.initState();
    final u = context.read<AppState>().user;
    if (u != null) {
      _usernameCtrl.text = u.username;
      _nameCtrl.text = u.name;
      _bioCtrl.text = u.bio;
      if (u.avatar.isNotEmpty) _avatar = u.avatar;
      _gender = u.gender.trim().toLowerCase();
      _originalName = u.username;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _usernameCtrl.dispose();
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  void _onUsernameChanged(String value) {
    _debounce?.cancel();
    final name = value.trim();
    if (name == _originalName) {
      setState(() {
        _nameState = _NameState.available;
        _nameMsg = '';
      });
      return;
    }
    if (name.isEmpty) {
      setState(() {
        _nameState = _NameState.empty;
        _nameMsg = '';
      });
      return;
    }
    final valid = RegExp(r'^[a-zA-Z0-9_]{3,20}$').hasMatch(name);
    if (!valid) {
      setState(() {
        _nameState = _NameState.invalid;
        _nameMsg = '3–20 letters, numbers or underscores.';
      });
      return;
    }
    setState(() {
      _nameState = _NameState.checking;
      _nameMsg = 'Checking availability…';
    });
    _debounce = Timer(const Duration(milliseconds: 450), () => _check(name));
  }

  Future<void> _check(String name) async {
    try {
      final (available, message) = await context
          .read<AppState>()
          .profiles
          .checkUsername(name);
      if (!mounted || _usernameCtrl.text.trim() != name) return;
      setState(() {
        _nameState = available ? _NameState.available : _NameState.taken;
        _nameMsg = message.isNotEmpty
            ? message
            : (available ? 'Nice, that one is free!' : 'Already taken.');
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _nameState = _NameState.invalid;
        _nameMsg = 'Could not check right now.';
      });
    }
  }

  bool get _canSave {
    if (_saving) return false;
    final name = _usernameCtrl.text.trim();
    if (name.isEmpty) return false;
    if (name == _originalName) return true;
    return _nameState == _NameState.available;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await context.read<AppState>().saveProfile(
        username: _usernameCtrl.text.trim(),
        name: _nameCtrl.text.trim(),
        gender: _gender,
        bio: _bioCtrl.text.trim(),
        avatar: _avatar,
      );
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Profile updated')));
      navigator.pop();
    } on ApiException catch (e) {
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not save your profile. Try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Center(child: OrbitAvatar(_avatar, size: 92)),
            const SizedBox(height: 20),
            const Text(
              'Avatar',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final a in kAvatarStyles)
                  GestureDetector(
                    onTap: () => setState(() => _avatar = a.key),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _avatar == a.key
                              ? OrbitColors.primary
                              : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                      child: OrbitAvatar(a.key, size: 54),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Name',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameCtrl,
              maxLength: 60,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                hintText: 'Your name, e.g. Aditi Sharma',
                counterText: '',
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Username',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _usernameCtrl,
              onChanged: _onUsernameChanged,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                hintText: 'e.g. aditi_23',
                prefixText: '@ ',
                suffixIcon: _nameSuffix(),
              ),
            ),
            if (_nameMsg.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Text(
                  _nameMsg,
                  style: TextStyle(fontSize: 12.5, color: _nameColor()),
                ),
              ),
            const SizedBox(height: 20),
            const Text(
              'Gender',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _genderOption('male', 'Male', Icons.male_rounded),
                _genderOption('female', 'Female', Icons.female_rounded),
                _genderOption('', 'Prefer not to say', null),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Bio',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _bioCtrl,
              maxLength: 120,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'A line about you — what you love to do.',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _canSave ? _save : null,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save changes'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _genderOption(String value, String label, IconData? icon) {
    final selected = _gender == value;
    return GestureDetector(
      onTap: () => setState(() => _gender = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: selected
              ? OrbitColors.primary.withValues(alpha: 0.12)
              : OrbitColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? OrbitColors.primary : OrbitColors.line,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 18,
                color: selected ? OrbitColors.primary : OrbitColors.inkSoft,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? OrbitColors.primary : OrbitColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _nameSuffix() {
    switch (_nameState) {
      case _NameState.checking:
        return const Padding(
          padding: EdgeInsets.all(14),
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          ),
        );
      case _NameState.available:
        return const Icon(Icons.check_circle, color: OrbitColors.gaming);
      case _NameState.taken:
      case _NameState.invalid:
        return const Icon(Icons.error_outline, color: OrbitColors.danger);
      case _NameState.empty:
        return null;
    }
  }

  Color _nameColor() {
    switch (_nameState) {
      case _NameState.available:
        return OrbitColors.gaming;
      case _NameState.taken:
      case _NameState.invalid:
        return OrbitColors.danger;
      default:
        return OrbitColors.inkSoft;
    }
  }
}
