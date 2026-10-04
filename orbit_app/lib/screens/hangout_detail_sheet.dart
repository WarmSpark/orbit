import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../config.dart';
import '../models/hangout.dart';
import '../services/api_client.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/orbit_avatar.dart';
import '../widgets/profile_preview.dart';
import 'chat_screen.dart';
import 'members_sheet.dart';

enum _Membership { unknown, host, approved, pending, declined, none }

class HangoutDetailSheet extends StatefulWidget {
  final Hangout hangout;

  final VoidCallback onChanged;

  const HangoutDetailSheet({
    super.key,
    required this.hangout,
    required this.onChanged,
  });

  @override
  State<HangoutDetailSheet> createState() => _HangoutDetailSheetState();
}

class _HangoutDetailSheetState extends State<HangoutDetailSheet> {
  _Membership _membership = _Membership.unknown;
  bool _busy = false;

  Hangout get h => widget.hangout;

  @override
  void initState() {
    super.initState();
    if (h.isHost) {
      _membership = _Membership.host;
    } else {
      _loadMembership();
    }
  }

  Future<void> _loadMembership() async {
    try {
      final mine = await context.read<AppState>().requests.myRequests();
      final match = mine.where((r) => r.eventId == h.id).toList();
      if (!mounted) return;
      setState(() {
        if (match.isEmpty) {
          _membership = _Membership.none;
        } else if (match.any((r) => r.isApproved)) {
          _membership = _Membership.approved;
        } else if (match.any((r) => r.isPending)) {
          _membership = _Membership.pending;
        } else {
          _membership = _Membership.declined;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _membership = _Membership.none);
    }
  }

  Future<void> _join() async {
    setState(() => _busy = true);
    try {
      await context.read<AppState>().events.join(h.id);
      if (!mounted) return;
      setState(() => _membership = _Membership.pending);
      _snack('Request sent! The host will review it soon.');
      widget.onChanged();
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Could not send your request.');
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
    final navigator = Navigator.of(context);
    try {
      await context.read<AppState>().events.leave(h.id);
      if (!mounted) return;
      _snack('You left the hangout.');
      widget.onChanged();
      navigator.pop();
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Could not leave right now.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openChat() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ChatScreen(roomId: h.id, title: h.title, isHost: h.isHost),
      ),
    );
  }

  void _openMembers() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MembersSheet(
        eventId: h.id,
        isHost: h.isHost,
        onChanged: widget.onChanged,
      ),
    );
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
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Confirm'),
        ),
      ],
    ),
  );

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _share() async {
    final link = '${Config.shareBase}/?h=${h.id}';
    final text =
        'Join my Orbit hangout 👋\n${h.title}\n📍 ${h.location}\n🕒 ${h.timeLabel}\n\n$link';
    await SharePlus.instance.share(ShareParams(text: text, subject: h.title));
  }

  @override
  Widget build(BuildContext context) {
    final cat = categoryFor(h.category);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: context.cSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.cLine,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: cat.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(cat.icon, size: 16, color: cat.color),
                    const SizedBox(width: 6),
                    Text(
                      h.category,
                      style: TextStyle(
                        color: cat.color,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Share',
                onPressed: _share,
                icon: Icon(Icons.ios_share_rounded, color: context.cInkSoft),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Text(
            h.title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: context.cInk,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 18),
          _InfoRow(icon: Icons.place_rounded, text: h.location),
          const SizedBox(height: 12),
          _InfoRow(icon: Icons.schedule_rounded, text: h.timeLabel),
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.groups_rounded,
            text: h.isFull
                ? '${h.goingCount} going · full'
                : '${h.goingCount} going · ${h.spotsLeft} ${h.spotsLeft == 1 ? "spot" : "spots"} left',
          ),
          const SizedBox(height: 18),
          const Divider(),
          const SizedBox(height: 8),

          Row(
            children: [
              OrbitAvatar(
                h.hostAvatar,
                size: 46,
                onTap: () => showProfilePreview(
                  context,
                  username: h.hostUsername,
                  name: h.hostName,
                  gender: h.hostGender,
                  avatar: h.hostAvatar,
                  bio: h.hostBio,
                  subtitle: 'Host of this hangout',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      h.hostName.trim().isNotEmpty
                          ? h.hostName.trim()
                          : (h.hostUsername.isEmpty
                                ? 'Host'
                                : '@${h.hostUsername}'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      h.hostName.trim().isNotEmpty && h.hostUsername.isNotEmpty
                          ? '@${h.hostUsername} · Hosting'
                          : 'Hosting',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.cInkSoft,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _actionArea(),
        ],
      ),
    );
  }

  Widget _actionArea() {
    if (_busy) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(8),
          child: CircularProgressIndicator(),
        ),
      );
    }

    switch (_membership) {
      case _Membership.unknown:
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(8),
            child: SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          ),
        );
      case _Membership.host:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _openMembers,
                icon: const Icon(Icons.manage_accounts_rounded),
                label: const Text('Manage'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  side: BorderSide(color: context.cLine),
                  foregroundColor: context.cInk,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: _openChat,
                icon: const Icon(Icons.forum_rounded),
                label: const Text('Chat'),
              ),
            ),
          ],
        );
      case _Membership.approved:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _leave,
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Leave'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  side: const BorderSide(color: OrbitColors.danger),
                  foregroundColor: OrbitColors.danger,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: _openChat,
                icon: const Icon(Icons.forum_rounded),
                label: const Text('Open chat'),
              ),
            ),
          ],
        );
      case _Membership.pending:
        return FilledButton.icon(
          onPressed: null,
          icon: const Icon(Icons.hourglass_top_rounded),
          label: const Text('Requested — waiting for host'),
          style: FilledButton.styleFrom(
            backgroundColor: context.cInkSoft.withValues(alpha: 0.25),
          ),
        );
      case _Membership.declined:
      case _Membership.none:
        final full = h.isFull;
        return FilledButton.icon(
          onPressed: full ? null : _join,
          icon: Icon(full ? Icons.block_rounded : Icons.waving_hand_rounded),
          label: Text(full ? 'Hangout is full' : 'Request to join'),
        );
    }
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: OrbitColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text.isEmpty ? '—' : text,
            style: TextStyle(fontSize: 15, color: context.cInk),
          ),
        ),
      ],
    );
  }
}
