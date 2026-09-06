class Applicant {
  final String requestId;
  final String username;
  final String name;
  final String gender;
  final String avatar;
  final String bio;
  final DateTime createdAt;

  const Applicant({
    required this.requestId,
    required this.username,
    required this.name,
    required this.gender,
    required this.avatar,
    required this.bio,
    required this.createdAt,
  });

  factory Applicant.fromJson(Map<String, dynamic> json) => Applicant(
    requestId: (json['request_id'] ?? '').toString(),
    username: (json['username'] ?? '') as String,
    name: (json['name'] ?? '') as String,
    gender: (json['gender'] ?? '') as String,
    avatar: (json['avatar'] ?? 'default_white') as String,
    bio: (json['bio'] ?? '') as String,
    createdAt:
        DateTime.tryParse('${json['created_at'] ?? ''}')?.toLocal() ??
        DateTime.now(),
  );
}
