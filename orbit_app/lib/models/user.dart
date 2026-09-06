class OrbitUser {
  final String username;
  final String email;
  final String name;
  final String gender;
  final String bio;
  final String avatar;

  const OrbitUser({
    required this.username,
    required this.email,
    required this.name,
    required this.gender,
    required this.bio,
    required this.avatar,
  });

  factory OrbitUser.fromJson(Map<String, dynamic> json) => OrbitUser(
    username: (json['username'] ?? '') as String,
    email: (json['email'] ?? '') as String,
    name: (json['name'] ?? '') as String,
    gender: (json['gender'] ?? '') as String,
    bio: (json['bio'] ?? '') as String,
    avatar: (json['avatar'] ?? 'default_white') as String,
  );

  Map<String, dynamic> toJson() => {
    'username': username,
    'email': email,
    'name': name,
    'gender': gender,
    'bio': bio,
    'avatar': avatar,
  };

  OrbitUser copyWith({
    String? username,
    String? email,
    String? name,
    String? gender,
    String? bio,
    String? avatar,
  }) => OrbitUser(
    username: username ?? this.username,
    email: email ?? this.email,
    name: name ?? this.name,
    gender: gender ?? this.gender,
    bio: bio ?? this.bio,
    avatar: avatar ?? this.avatar,
  );

  bool get needsOnboarding => username.trim().isEmpty;
}
