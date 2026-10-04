import 'package:google_sign_in/google_sign_in.dart';

import '../config.dart';
import '../models/user.dart';
import 'api_client.dart';

class AuthResult {
  final String token;
  final OrbitUser user;
  final bool isNewUser;
  const AuthResult({
    required this.token,
    required this.user,
    required this.isNewUser,
  });
}

class AuthService {
  final ApiClient _api;

  AuthService(this._api);

  late final GoogleSignIn _google = GoogleSignIn(
    scopes: const ['email', 'profile'],

    serverClientId: Config.hasGoogleClientId
        ? Config.googleServerClientId
        : null,
  );

  Future<AuthResult> signInWithGoogle() async {
    if (!Config.hasGoogleClientId) {
      throw ApiException(
        0,
        'Google Sign-In is not configured. Pass --dart-define='
        'ORBIT_GOOGLE_CLIENT_ID=<your web client id> when running the app.',
      );
    }

    await _google.signOut();

    final account = await _google.signIn();
    if (account == null) {
      throw ApiException(0, 'Sign-in cancelled.');
    }

    final auth = await account.authentication;
    final idToken = auth.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw ApiException(
        0,
        'Could not get a Google id token. Check your OAuth setup.',
      );
    }

    final data =
        await _api.post('/auth/google', {'id_token': idToken})
            as Map<String, dynamic>;

    final token = (data['token'] ?? '') as String;
    if (token.isEmpty) {
      throw ApiException(500, 'Server did not return a session token.');
    }
    _api.setToken(token);

    final userJson =
        (data['user'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    return AuthResult(
      token: token,
      user: OrbitUser.fromJson(userJson),
      isNewUser: data['is_new_user'] == true,
    );
  }

  Future<void> signOut() async {
    try {
      await _google.signOut();
    } catch (_) {}
    _api.setToken(null);
  }
}
