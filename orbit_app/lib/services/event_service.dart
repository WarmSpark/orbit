import '../models/hangout.dart';
import '../models/member.dart';
import 'api_client.dart';

class EventService {
  final ApiClient _api;
  EventService(this._api);

  Future<List<Hangout>> listEvents() async {
    final data = await _api.get('/events');
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => Hangout.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<void> createEvent({
    required String title,
    required String category,
    required String location,
    required double latitude,
    required double longitude,
    required DateTime time,
    required int maxParticipants,
  }) async {
    await _api.post('/events', {
      'title': title,
      'category': category,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'time': time.toUtc().toIso8601String(),
      'max_participants': maxParticipants,
    });
  }

  Future<void> join(String eventId) =>
      _api.post('/events/join', {'event_id': eventId});

  Future<void> cancel(String eventId) =>
      _api.post('/events/cancel', {'event_id': eventId});

  Future<void> leave(String eventId) =>
      _api.post('/events/leave', {'event_id': eventId});

  Future<void> kick(String eventId, String participantEmail) => _api.post(
    '/events/kick',
    {'event_id': eventId, 'participant_email': participantEmail},
  );

  Future<List<Member>> members(String eventId) async {
    final data = await _api.get(
      '/events/members',
      query: {'event_id': eventId},
    );
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => Member.fromJson(e.cast<String, dynamic>()))
        .toList();
  }
}
