import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/hangout.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/empty_state.dart';
import 'chat_screen.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => ChatsScreenState();
}

class ChatsScreenState extends State<ChatsScreen> {
  List<Hangout> _chats = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final app = context.read<AppState>();
      final events = await app.events.listEvents();
      final requests = await app.requests.myRequests();
      final approvedIds = requests
          .where((r) => r.isApproved)
          .map((r) => r.eventId)
          .toSet();

      final chats =
          events.where((e) => e.isHost || approvedIds.contains(e.id)).toList()
            ..sort((a, b) {
              if (a.isHost != b.isHost) return a.isHost ? -1 : 1;
              return a.title.toLowerCase().compareTo(b.title.toLowerCase());
            });

      if (!mounted) return;
      setState(() {
        _chats = chats;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load your chats.';
        _loading = false;
      });
    }
  }

  Future<void> _open(Hangout h) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ChatScreen(roomId: h.id, title: h.title, isHost: h.isHost),
      ),
    );

    if (mounted) reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        actions: [
          IconButton(
            onPressed: _loading ? null : reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return EmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Something went wrong',
        subtitle: _error!,
        action: FilledButton(onPressed: reload, child: const Text('Retry')),
      );
    }
    if (_chats.isEmpty) {
      return RefreshIndicator(
        onRefresh: reload,
        child: ListView(
          children: const [
            SizedBox(height: 80),
            EmptyState(
              icon: Icons.forum_outlined,
              title: 'No hangout chats yet',
              subtitle:
                  'Host a hangout or get approved to join one, and its group '
                  'chat will appear here.',
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: reload,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _chats.length,
        separatorBuilder: (_, _) => const Divider(height: 1, indent: 84),
        itemBuilder: (_, i) =>
            _ChatTile(hangout: _chats[i], onTap: () => _open(_chats[i])),
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  final Hangout hangout;
  final VoidCallback onTap;
  const _ChatTile({required this.hangout, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cat = categoryFor(hangout.category);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      onTap: onTap,
      leading: Container(
        width: 52,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: cat.color.withValues(alpha: 0.14),
          shape: BoxShape.circle,
        ),
        child: Icon(cat.icon, color: cat.color),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              hangout.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          if (hangout.isHost) ...[
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
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Text(
          '${hangout.goingCount} going · disappears after 24h',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: OrbitColors.inkSoft, fontSize: 13),
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: OrbitColors.inkSoft,
      ),
    );
  }
}
