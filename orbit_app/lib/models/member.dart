class Member {
  final String username;
  final String name;
  final String gender;
  final String avatar;
  final String bio;
  final bool isHost;
  final String? email;

  const Member({
    required this.username,
    required this.name,
    required this.gender,
    required this.avatar,
    required this.bio,
    required this.isHost,
    this.email,
  });

  factory Member.fromJson(Map<String, dynamic> json) => Member(
    username: (json['username'] ?? '') as String,
    name: (json['name'] ?? '') as String,
    gender: (json['gender'] ?? '') as String,
    avatar: (json['avatar'] ?? 'default_white') as String,
    bio: (json['bio'] ?? '') as String,
    isHost: json['is_host'] == true,
    email: json['email'] as String?,
  );

  bool get canBeKicked => email != null && email!.isNotEmpty;
}
