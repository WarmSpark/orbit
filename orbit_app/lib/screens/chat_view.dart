import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/chat_message.dart';
import '../services/chat_service.dart';
import '../state/app_state.dart';
import '../theme.dart';

class ChatView extends StatefulWidget {
  final ChatConnection Function() connect;

  final String Function(String action, String reason)? actionMessage;

  const ChatView({super.key, required this.connect, this.actionMessage});

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  ChatConnection? _conn;
  StreamSubscription<ChatEvent>? _sub;
  final _messages = <ChatMessage>[];
  final _input = TextEditingController();
  final _scroll = ScrollController();

  bool _connected = false;
  bool _closed = false;
  ChatMessage? _replyTo;

  String get _myHandle {
    final u = context.read<AppState>().user?.username ?? '';
    return u.isEmpty ? '' : '@$u';
  }

  @override
  void initState() {
    super.initState();
    _open();
  }

  void _open() {
    _closed = false;
    final conn = widget.connect();
    _conn = conn;
    _sub = conn.events.listen(_onEvent);
    setState(() => _connected = true);
  }

  void _onEvent(ChatEvent event) {
    if (!mounted) return;
    switch (event) {
      case ChatHistory(:final messages):
        setState(() {
          _messages
            ..clear()
            ..addAll(messages);
        });
        _scrollToBottomSoon();
      case ChatIncoming(:final message):
        setState(() => _messages.add(message));
        _scrollToBottomSoon();
      case ChatAction(:final action, :final reason):
        _handleAction(action, reason);
      case ChatClosed():
        setState(() {
          _connected = false;
          _closed = true;
        });
    }
  }

  void _handleAction(String action, String reason) {
    final msg =
        widget.actionMessage?.call(action, reason) ??
        switch (action) {
          'kicked' => 'You were removed from this hangout by the host.',
          'cancelled' => 'This hangout was cancelled by the host.',
          'left' => 'You left this hangout.',
          _ => reason.isNotEmpty ? reason : 'You are no longer in this chat.',
        };
    _closed = true;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Chat closed'),
        content: Text(msg),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).maybePop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _scrollToBottomSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty || _conn == null) return;
    final result = _conn!.send(
      text,
      replyToId: _replyTo?.id,
      replyToText: _replyTo == null
          ? null
          : '${_replyTo!.displayName}: ${_replyTo!.message}',
    );
    switch (result) {
      case SendResult.ok:
        _input.clear();
        setState(() => _replyTo = null);
      case SendResult.rateLimited:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Slow down a little — too many messages.'),
          ),
        );
      case SendResult.notConnected:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not connected. Try reconnecting.')),
        );
    }
  }

  Future<void> _reconnect() async {
    await _sub?.cancel();
    await _conn?.dispose();
    _messages.clear();
    _open();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _conn?.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _DisappearBanner(),
        Expanded(
          child: _messages.isEmpty
              ? _EmptyChat(closed: _closed)
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  itemCount: _messages.length,
                  itemBuilder: (_, i) {
                    final m = _messages[i];
                    if (m.isSystem) return _SystemLine(text: m.message);
                    return _MessageBubble(
                      message: m,
                      mine: m.senderHandle == _myHandle,
                      onReply: () => setState(() => _replyTo = m),
                    );
                  },
                ),
        ),
        if (_closed)
          _ReconnectBar(onReconnect: _reconnect)
        else ...[
          if (_replyTo != null)
            _ReplyPreview(
              message: _replyTo!,
              onCancel: () => setState(() => _replyTo = null),
            ),
          _Composer(controller: _input, enabled: _connected, onSend: _send),
        ],
      ],
    );
  }
}

class _DisappearBanner extends StatelessWidget {
  const _DisappearBanner();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: OrbitColors.primary.withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.timer_outlined,
            size: 15,
            color: OrbitColors.primary,
          ),
          const SizedBox(width: 6),
          Text(
            'Everything disappears after 24 hours',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: OrbitColors.primary.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool mine;
  final VoidCallback onReply;

  const _MessageBubble({
    required this.message,
    required this.mine,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(message.id),
      direction: DismissDirection.startToEnd,
      dismissThresholds: const {DismissDirection.startToEnd: 0.25},
      confirmDismiss: (_) async {
        onReply();
        return false;
      },
      background: const Padding(
        padding: EdgeInsets.only(left: 20),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Icon(Icons.reply_rounded, color: OrbitColors.primary),
        ),
      ),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.76,
          ),
          decoration: BoxDecoration(
            color: mine ? OrbitColors.primary : OrbitColors.surface,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(mine ? 18 : 4),
              bottomRight: Radius.circular(mine ? 4 : 18),
            ),
            border: mine ? null : Border.all(color: OrbitColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!mine)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    message.displayName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _nameColor(message.displayName),
                    ),
                  ),
                ),
              if (message.replyToText != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 5),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: (mine ? Colors.white : OrbitColors.primary)
                        .withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                    border: Border(
                      left: BorderSide(
                        color: mine ? Colors.white : OrbitColors.primary,
                        width: 3,
                      ),
                    ),
                  ),
                  child: Text(
                    message.replyToText!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: mine
                          ? Colors.white.withValues(alpha: 0.9)
                          : OrbitColors.inkSoft,
                    ),
                  ),
                ),
              Text(
                message.message,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.3,
                  color: mine ? Colors.white : OrbitColors.ink,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _time(message.timestamp),
                style: TextStyle(
                  fontSize: 10.5,
                  color: mine
                      ? Colors.white.withValues(alpha: 0.75)
                      : OrbitColors.inkSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _time(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m ${t.hour < 12 ? "AM" : "PM"}';
  }

  static const _palette = [
    OrbitColors.movie,
    OrbitColors.canteen,
    OrbitColors.study,
    OrbitColors.gaming,
    OrbitColors.sports,
  ];

  Color _nameColor(String name) =>
      _palette[name.hashCode.abs() % _palette.length];
}

class _SystemLine extends StatelessWidget {
  final String text;
  const _SystemLine({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: OrbitColors.inkSoft.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 12, color: OrbitColors.inkSoft),
        ),
      ),
    );
  }
}

class _ReplyPreview extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback onCancel;
  const _ReplyPreview({required this.message, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: OrbitColors.bg,
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Container(width: 3, height: 34, color: OrbitColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Replying to ${message.displayName}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: OrbitColors.primary,
                  ),
                ),
                Text(
                  message.message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: OrbitColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSend;
  const _Composer({
    required this.controller,
    required this.enabled,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: const BoxDecoration(
          color: OrbitColors.surface,
          border: Border(top: BorderSide(color: OrbitColors.line)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: enabled ? 'Message…' : 'Connecting…',
                  filled: true,
                  fillColor: OrbitColors.bg,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: OrbitColors.primary,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: enabled ? onSend : null,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReconnectBar extends StatelessWidget {
  final VoidCallback onReconnect;
  const _ReconnectBar({required this.onReconnect});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(12),
        color: OrbitColors.surface,
        child: Row(
          children: [
            const Icon(Icons.wifi_off_rounded, color: OrbitColors.inkSoft),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Disconnected from chat.',
                style: TextStyle(color: OrbitColors.inkSoft),
              ),
            ),
            FilledButton(
              onPressed: onReconnect,
              style: FilledButton.styleFrom(minimumSize: const Size(110, 44)),
              child: const Text('Reconnect'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  final bool closed;
  const _EmptyChat({required this.closed});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              closed ? Icons.wifi_off_rounded : Icons.forum_outlined,
              size: 48,
              color: OrbitColors.inkSoft,
            ),
            const SizedBox(height: 12),
            Text(
              closed ? 'Chat disconnected' : 'Say hi 👋',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: OrbitColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              closed
                  ? 'Reconnect to keep chatting.'
                  : 'Be the first to start the conversation.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: OrbitColors.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}
