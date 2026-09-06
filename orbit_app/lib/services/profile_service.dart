import '../models/user.dart';
import 'api_client.dart';

class ProfileService {
  final ApiClient _api;
  ProfileService(this._api);

  Future<OrbitUser> getProfile() async {
    final data = await _api.get('/user/profile');
    final json = _userMap(data);
    return OrbitUser.fromJson(json);
  }

  Future<OrbitUser> updateProfile({
    required String username,
    required String name,
    required String gender,
    required String bio,
    required String avatar,
  }) async {
    final data = await _api.put('/user/profile', {
      'username': username,
      'name': name,
      'gender': gender,
      'bio': bio,
      'avatar': avatar,
    });

    final json = _userMap(data);
    final merged = OrbitUser(
      username: (json['username'] ?? username) as String,
      email: (json['email'] ?? '') as String,
      name: (json['name'] ?? name) as String,
      gender: (json['gender'] ?? gender) as String,
      bio: (json['bio'] ?? bio) as String,
      avatar: (json['avatar'] ?? avatar) as String,
    );
    return merged;
  }

  Future<(bool, String)> checkUsername(String username) async {
    final data =
        await _api.get('/users/check-username', query: {'username': username})
            as Map<String, dynamic>;
    return (data['available'] == true, (data['message'] ?? '') as String);
  }

  Map<String, dynamic> _userMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      if (data['user'] is Map) {
        return (data['user'] as Map).cast<String, dynamic>();
      }
      return data;
    }
    return <String, dynamic>{};
  }
}
