import '../models/applicant.dart';
import '../models/join_request.dart';
import 'api_client.dart';

class RequestService {
  final ApiClient _api;
  RequestService(this._api);

  Future<List<Applicant>> eventRequests(String eventId) async {
    final data = await _api.get(
      '/events/requests',
      query: {'event_id': eventId},
    );
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => Applicant.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<void> respond(String requestId, {required bool approve}) => _api.post(
    '/events/requests/respond',
    {'request_id': requestId, 'status': approve ? 'approved' : 'declined'},
  );

  Future<List<MyRequest>> myRequests() async {
    final data = await _api.get('/user/requests');
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => MyRequest.fromJson(e.cast<String, dynamic>()))
        .toList();
  }
}
