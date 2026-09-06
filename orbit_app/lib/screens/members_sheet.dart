import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/member.dart';
import '../services/api_client.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/orbit_avatar.dart';
import '../widgets/profile_preview.dart';

class MembersSheet extends StatefulWidget {
  final String eventId;
  final bool isHost;
  final VoidCallback onChanged;

  const MembersSheet({
    super.key,
    required this.eventId,
    required this.isHost,
    required this.onChanged,
  });

  @override
  State<MembersSheet> createState() => _MembersSheetState();
}

class _MembersSheetState extends State<MembersSheet> {
  List<Member> _members = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await context.read<AppState>().events.members(
        widget.eventId,
      );
      if (!mounted) return;
      setState(() {
        _members = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load members.';
        _loading = false;
      });
    }
  }

  Future<void> _kick(Member m) async {
    if (!m.canBeKicked) return;
    final ok = await _confirm(
      'Remove @${m.username}?',
      'They will be disconnected from the group chat.',
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await context.read<AppState>().events.kick(widget.eventId, m.email!);
      widget.onChanged();
      await _load();
      _snack('@${m.username} was removed.');
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Could not remove them right now.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final ok = await _confirm(
      'Cancel this hangout?',
      'The pin is removed and the group chat closes for everyone.',
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await context.read<AppState>().events.cancel(widget.eventId);
      widget.onChanged();
      if (!mounted) return;
      Navigator.of(context).pop();
      _snack('Hangout cancelled.');
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Could not cancel right now.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leave() async {
    final ok = await _confirm(
      'Leave this hangout?',
      'You will be removed from the group chat.',
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await context.read<AppState>().events.leave(widget.eventId);
      widget.onChanged();
      if (!mounted) return;
      Navigator.of(context).pop();
      _snack('You left the hangout.');
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Could not leave right now.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool?> _confirm(String title, String body) => showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: OrbitColors.danger),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Yes'),
        ),
      ],
    ),
  );

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      decoration: const BoxDecoration(
        color: OrbitColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: OrbitColors.line,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                const Icon(Icons.groups_rounded, color: OrbitColors.primary),
                const SizedBox(width: 10),
                Text(
                  'Chat room members',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                if (!_loading)
                  Text(
                    '${_members.length}',
                    style: const TextStyle(
                      color: OrbitColors.inkSoft,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    _error!,
                    style: const TextStyle(color: OrbitColors.inkSoft),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _members.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, indent: 68),
                itemBuilder: (_, i) => _memberTile(_members[i]),
              ),
            ),
          const Divider(height: 1),
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              14,
              20,
              14 + MediaQuery.of(context).padding.bottom,
            ),
            child: _busy
                ? const Center(child: CircularProgressIndicator())
                : (widget.isHost ? _hostFooter() : _memberFooter()),
          ),
        ],
      ),
    );
  }

  Widget _memberTile(Member m) {
    final showName = m.name.trim().isNotEmpty;
    final subParts = <String>[
      if (showName) '@${m.username}',
      if (m.bio.trim().isNotEmpty) m.bio.trim(),
    ];
    final sub = subParts.join(' · ');
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: OrbitAvatar(
        m.avatar,
        size: 46,
        onTap: () => showProfilePreview(
          context,
          username: m.username,
          name: m.name,
          gender: m.gender,
          avatar: m.avatar,
          bio: m.bio,
          subtitle: m.isHost ? 'Host' : 'Member',
        ),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              showName ? m.name.trim() : '@${m.username}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          if (m.isHost) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: OrbitColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Host',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: OrbitColors.primary,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: sub.isEmpty
          ? null
          : Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: (widget.isHost && !m.isHost)
          ? (m.canBeKicked
                ? IconButton(
                    tooltip: 'Remove',
                    icon: const Icon(
                      Icons.person_remove_rounded,
                      color: OrbitColors.danger,
                    ),
                    onPressed: () => _kick(m),
                  )
                : null)
          : null,
    );
  }

  Widget _hostFooter() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _cancel,
        icon: const Icon(Icons.cancel_rounded),
        label: const Text('Cancel hangout'),
        style: FilledButton.styleFrom(backgroundColor: OrbitColors.danger),
      ),
    );
  }

  Widget _memberFooter() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _leave,
        icon: const Icon(Icons.logout_rounded),
        label: const Text('Leave hangout'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: OrbitColors.danger),
          foregroundColor: OrbitColors.danger,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
