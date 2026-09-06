import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/applicant.dart';
import '../models/hangout.dart';
import '../services/api_client.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/orbit_avatar.dart';
import '../widgets/profile_preview.dart';

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => RequestsScreenState();
}

class RequestsScreenState extends State<RequestsScreen> {
  Hangout? _myHangout;
  List<Applicant> _applicants = [];
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
      final mine = events.where((e) => e.isHost).toList();
      if (mine.isEmpty) {
        if (!mounted) return;
        setState(() {
          _myHangout = null;
          _applicants = [];
          _loading = false;
        });
        return;
      }
      final host = mine.first;
      final applicants = await app.requests.eventRequests(host.id);
      if (!mounted) return;
      setState(() {
        _myHangout = host;
        _applicants = applicants;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load requests.';
        _loading = false;
      });
    }
  }

  Future<void> _respond(Applicant a, bool approve) async {
    try {
      await context.read<AppState>().requests.respond(
        a.requestId,
        approve: approve,
      );
      if (!mounted) return;
      setState(
        () => _applicants.removeWhere((x) => x.requestId == a.requestId),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approve
                ? '@${a.username} approved 🎉'
                : 'Request from @${a.username} declined',
          ),
        ),
      );
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Could not update the request.');
    }
  }

  void _review(Applicant a) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => ProfilePreviewCard(
        username: a.username,
        name: a.name,
        gender: a.gender,
        avatar: a.avatar,
        bio: a.bio,
        subtitle: 'Wants to join your hangout',
        actions: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                Navigator.pop(sheetCtx);
                _respond(a, false);
              },
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                side: const BorderSide(color: OrbitColors.danger),
                foregroundColor: OrbitColors.danger,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Decline'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: () {
                Navigator.pop(sheetCtx);
                _respond(a, true);
              },
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              child: const Text('Approve'),
            ),
          ),
        ],
      ),
    );
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Requests'),
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
    if (_myHangout == null) {
      return const EmptyState(
        icon: Icons.push_pin_outlined,
        title: 'No active hangout',
        subtitle:
            'Post a hangout from the map to start receiving join requests.',
      );
    }
    if (_applicants.isEmpty) {
      return RefreshIndicator(
        onRefresh: reload,
        child: ListView(
          children: [
            _HangoutHeader(hangout: _myHangout!),
            const SizedBox(height: 60),
            const EmptyState(
              icon: Icons.inbox_rounded,
              title: 'No requests yet',
              subtitle: 'When people ask to join, they will show up here.',
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: reload,
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: _applicants.length + 1,
        separatorBuilder: (_, i) =>
            i == 0 ? const SizedBox.shrink() : const Divider(indent: 76),
        itemBuilder: (_, i) {
          if (i == 0) return _HangoutHeader(hangout: _myHangout!);
          final a = _applicants[i - 1];
          return _ApplicantTile(
            applicant: a,
            onReview: () => _review(a),
            onApprove: () => _respond(a, true),
            onDecline: () => _respond(a, false),
          );
        },
      ),
    );
  }
}

class _HangoutHeader extends StatelessWidget {
  final Hangout hangout;
  const _HangoutHeader({required this.hangout});

  @override
  Widget build(BuildContext context) {
    final cat = categoryFor(hangout.category);
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cat.color, cat.color.withValues(alpha: 0.75)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
            child: Icon(cat.icon, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hangout.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${hangout.goingCount} going · ${hangout.spotsLeft} spots left',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ApplicantTile extends StatelessWidget {
  final Applicant applicant;
  final VoidCallback onReview;
  final VoidCallback onApprove;
  final VoidCallback onDecline;

  const _ApplicantTile({
    required this.applicant,
    required this.onReview,
    required this.onApprove,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final showName = applicant.name.trim().isNotEmpty;
    final subParts = <String>[
      if (showName) '@${applicant.username}',
      if (applicant.bio.trim().isNotEmpty) applicant.bio.trim(),
    ];
    final sub = subParts.isEmpty ? 'Tap photo to review' : subParts.join(' · ');
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: OrbitAvatar(applicant.avatar, size: 50, onTap: onReview),
      title: Text(
        showName ? applicant.name.trim() : '@${applicant.username}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: OrbitColors.danger),
            onPressed: onDecline,
          ),
          IconButton(
            icon: const Icon(Icons.check_rounded, color: OrbitColors.gaming),
            onPressed: onApprove,
          ),
        ],
      ),
      onTap: onReview,
    );
  }
}
