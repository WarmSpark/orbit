import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/orbit_avatar.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

enum _NameState { empty, checking, available, taken, invalid }

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _usernameCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  String _avatar = kAvatarStyles.first.key;
  String _gender = '';
  Timer? _debounce;
  _NameState _nameState = _NameState.empty;
  String _nameMsg = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final u = context.read<AppState>().user;
    if (u != null) {
      if (u.username.isNotEmpty) _usernameCtrl.text = u.username;
      if (u.name.isNotEmpty) _nameCtrl.text = u.name;
      if (u.bio.isNotEmpty) _bioCtrl.text = u.bio;
      if (u.avatar.isNotEmpty) _avatar = u.avatar;
      _gender = u.gender.trim().toLowerCase();
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

  bool get _canSave =>
      !_saving &&
      (_nameState == _NameState.available ||
          (_nameState == _NameState.taken &&
              _usernameCtrl.text.trim() ==
                  (context.read<AppState>().user?.username ?? '')));

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await context.read<AppState>().saveProfile(
        username: _usernameCtrl.text.trim(),
        name: _nameCtrl.text.trim(),
        gender: _gender,
        bio: _bioCtrl.text.trim(),
        avatar: _avatar,
      );
    } on ApiException catch (e) {
      _err(e.message);
    } catch (_) {
      _err('Could not save your profile. Try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _err(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set up your profile')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Center(child: OrbitAvatar(_avatar, size: 92)),
            const SizedBox(height: 20),
            const Text(
              'Pick an avatar',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 12),
            _AvatarGrid(
              selected: _avatar,
              onSelect: (k) => setState(() => _avatar = k),
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
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
                LengthLimitingTextInputFormatter(20),
              ],
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
                  : const Text('Enter Orbit'),
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
              : context.cSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? OrbitColors.primary : context.cLine,
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
                color: selected ? OrbitColors.primary : context.cInkSoft,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? OrbitColors.primary : context.cInk,
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
        return context.cInkSoft;
    }
  }
}

class _AvatarGrid extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  const _AvatarGrid({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final a in kAvatarStyles)
          GestureDetector(
            onTap: () => onSelect(a.key),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected == a.key
                      ? OrbitColors.primary
                      : Colors.transparent,
                  width: 2.5,
                ),
              ),
              child: OrbitAvatar(a.key, size: 54),
            ),
          ),
      ],
    );
  }
}
