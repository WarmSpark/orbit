import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

import '../config.dart';
import '../models/chat_message.dart';

sealed class ChatEvent {
  const ChatEvent();
}

class ChatHistory extends ChatEvent {
  final List<ChatMessage> messages;
  const ChatHistory(this.messages);
}

class ChatIncoming extends ChatEvent {
  final ChatMessage message;
  const ChatIncoming(this.message);
}

class ChatAction extends ChatEvent {
  final String action;
  final String reason;
  const ChatAction(this.action, this.reason);
}

class ChatClosed extends ChatEvent {
  final String? reason;
  const ChatClosed(this.reason);
}

enum SendResult { ok, rateLimited, notConnected }

class ChatConnection {
  final WebSocketChannel _channel;
  final _controller = StreamController<ChatEvent>.broadcast();
  StreamSubscription? _sub;
  bool _closed = false;

  static const int _maxPerWindow = 15;
  static const Duration _window = Duration(seconds: 5);
  final List<DateTime> _recentSends = [];

  ChatConnection._(this._channel) {
    _sub = _channel.stream.listen(
      _onData,
      onError: (e) {
        if (!_closed) _controller.add(ChatClosed('$e'));
      },
      onDone: () {
        if (!_closed) _controller.add(const ChatClosed(null));
      },
    );
  }

  Stream<ChatEvent> get events => _controller.stream;

  void _onData(dynamic raw) {
    for (final line in raw.toString().split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      Map<String, dynamic> json;
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is! Map) continue;
        json = decoded.cast<String, dynamic>();
      } catch (_) {
        continue;
      }

      switch (json['type']) {
        case 'history':
          final list = (json['history'] as List?) ?? const [];
          _controller.add(
            ChatHistory(
              list
                  .whereType<Map>()
                  .map((e) => ChatMessage.fromJson(e.cast<String, dynamic>()))
                  .toList(),
            ),
          );
        case 'action':
          _controller.add(
            ChatAction(
              (json['action'] ?? '') as String,
              (json['reason'] ?? '') as String,
            ),
          );
        default:
          _controller.add(ChatIncoming(ChatMessage.fromJson(json)));
      }
    }
  }

  SendResult send(String text, {String? replyToId, String? replyToText}) {
    if (_closed) return SendResult.notConnected;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return SendResult.ok;

    final now = DateTime.now();
    _recentSends.removeWhere((t) => now.difference(t) > _window);
    if (_recentSends.length >= _maxPerWindow) {
      return SendResult.rateLimited;
    }
    _recentSends.add(now);

    final payload = <String, dynamic>{'message': trimmed};
    if (replyToId != null) payload['reply_to_id'] = replyToId;
    if (replyToText != null) payload['reply_to_text'] = replyToText;
    _channel.sink.add(jsonEncode(payload));
    return SendResult.ok;
  }

  Future<void> dispose() async {
    if (_closed) return;
    _closed = true;
    await _sub?.cancel();
    try {
      await _channel.sink.close(ws_status.normalClosure);
    } catch (_) {}
    await _controller.close();
  }
}

class ChatService {
  final String? Function() _tokenProvider;
  ChatService(this._tokenProvider);

  ChatConnection connectEvent(String roomId) {
    final token = _tokenProvider() ?? '';
    final uri = Uri.parse(
      '${Config.wsBase}/chat/ws',
    ).replace(queryParameters: {'room_id': roomId, 'token': token});
    return ChatConnection._(WebSocketChannel.connect(uri));
  }

  ChatConnection connectTownhall(double lat, double lng) {
    final token = _tokenProvider() ?? '';
    final uri = Uri.parse(
      '${Config.wsBase}/townhall/ws',
    ).replace(queryParameters: {'token': token, 'lat': '$lat', 'lng': '$lng'});
    return ChatConnection._(WebSocketChannel.connect(uri));
  }
}
