import 'package:latlong2/latlong.dart';

class Hangout {
  final String id;
  final String title;
  final String category;
  final String location;
  final double latitude;
  final double longitude;

  final String timeText;

  final int maxParticipants;
  final int approvedCount;
  final bool isFull;
  final bool isHost;
  final DateTime createdAt;
  final String hostUsername;
  final String hostName;
  final String hostGender;
  final String hostAvatar;
  final String hostBio;

  const Hangout({
    required this.id,
    required this.title,
    required this.category,
    required this.location,
    required this.latitude,
    required this.longitude,
    required this.timeText,
    required this.maxParticipants,
    required this.approvedCount,
    required this.isFull,
    required this.isHost,
    required this.createdAt,
    required this.hostUsername,
    required this.hostName,
    required this.hostGender,
    required this.hostAvatar,
    required this.hostBio,
  });

  LatLng get latLng => LatLng(latitude, longitude);

  int get goingCount => approvedCount + 1;

  int get spotsLeft {
    final left = maxParticipants - 1 - approvedCount;
    return left < 0 ? 0 : left;
  }

  DateTime? get timeParsed => DateTime.tryParse(timeText)?.toLocal();

  String get timeLabel {
    final t = timeParsed;
    if (t == null) return timeText;
    return formatWhen(t);
  }

  static DateTime _parseDate(dynamic v) {
    if (v == null) return DateTime.now();
    return DateTime.tryParse(v.toString())?.toLocal() ?? DateTime.now();
  }

  static double _d(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0.0;

  static int _i(dynamic v) =>
      v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;

  factory Hangout.fromJson(Map<String, dynamic> json) => Hangout(
    id: (json['id'] ?? '').toString(),
    title: (json['title'] ?? '') as String,
    category: (json['category'] ?? 'All') as String,
    location: (json['location'] ?? '') as String,
    latitude: _d(json['latitude']),
    longitude: _d(json['longitude']),
    timeText: (json['time'] ?? '').toString(),
    maxParticipants: _i(json['max_participants']),
    approvedCount: _i(json['approved_count']),
    isFull: json['is_full'] == true,
    isHost: json['is_host'] == true,
    createdAt: _parseDate(json['created_at']),
    hostUsername: (json['host_username'] ?? '') as String,
    hostName: (json['host_name'] ?? '') as String,
    hostGender: (json['host_gender'] ?? '') as String,
    hostAvatar: (json['host_avatar'] ?? 'default_white') as String,
    hostBio: (json['host_bio'] ?? '') as String,
  );
}

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String formatWhen(DateTime t) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(t.year, t.month, t.day);
  final diff = day.difference(today).inDays;

  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute.toString().padLeft(2, '0');
  final ampm = t.hour < 12 ? 'AM' : 'PM';
  final time = '$h:$m $ampm';

  if (diff == 0) return 'Today · $time';
  if (diff == 1) return 'Tomorrow · $time';
  if (diff == -1) return 'Yesterday · $time';
  final wd = _weekdays[(t.weekday - 1) % 7];
  final mo = _months[(t.month - 1) % 12];
  return '$wd ${t.day} $mo · $time';
}
