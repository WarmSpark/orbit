import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import 'chat_view.dart';
import 'members_sheet.dart';

class ChatScreen extends StatelessWidget {
  final String roomId;
  final String title;
  final bool isHost;

  const ChatScreen({
    super.key,
    required this.roomId,
    required this.title,
    required this.isHost,
  });

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            const Text(
              'Hangout chat',
              style: TextStyle(fontSize: 12, color: OrbitColors.inkSoft),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Members',
            icon: const Icon(Icons.groups_rounded),
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => MembersSheet(
                eventId: roomId,
                isHost: isHost,
                onChanged: () {},
              ),
            ),
          ),
        ],
      ),
      body: ChatView(connect: () => app.chat.connectEvent(roomId)),
    );
  }
}
