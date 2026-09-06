import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../models/user.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/event_service.dart';
import '../services/geocoding_service.dart';
import '../services/location_service.dart';
import '../services/profile_service.dart';
import '../services/request_service.dart';

enum AuthStatus { unknown, unauthenticated, onboarding, authenticated }

class AppState extends ChangeNotifier {
  static const _kToken = 'orbit_token';
  static const _kUser = 'orbit_user';

  final ApiClient api = ApiClient();
  late final AuthService auth = AuthService(api);
  late final ProfileService profiles = ProfileService(api);
  late final EventService events = EventService(api);
  late final RequestService requests = RequestService(api);
  late final ChatService chat = ChatService(() => api.token);
  final LocationService location = LocationService();
  final GeocodingService geocoding = GeocodingService();

  AuthStatus status = AuthStatus.unknown;
  OrbitUser? user;
  LatLng? myLocation;

  bool get isSignedIn => api.hasToken;

  Future<void> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_kToken);

    if (token == null || token.isEmpty) {
      _set(AuthStatus.unauthenticated);
      return;
    }

    api.setToken(token);

    final cached = prefs.getString(_kUser);
    if (cached != null && cached.isNotEmpty) {
      try {
        user = OrbitUser.fromJson(_decodeUser(cached));
      } catch (_) {}
    }

    try {
      user = await profiles.getProfile();
      await _persistUser();
      _set(
        user!.needsOnboarding
            ? AuthStatus.onboarding
            : AuthStatus.authenticated,
      );
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await logout();
      } else if (user != null) {
        _set(
          user!.needsOnboarding
              ? AuthStatus.onboarding
              : AuthStatus.authenticated,
        );
      } else {
        _set(AuthStatus.unauthenticated);
      }
    } catch (_) {
      if (user != null) {
        _set(
          user!.needsOnboarding
              ? AuthStatus.onboarding
              : AuthStatus.authenticated,
        );
      } else {
        _set(AuthStatus.unauthenticated);
      }
    }
  }

  Future<void> signInWithGoogle() async {
    final result = await auth.signInWithGoogle();
    user = result.user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kToken, result.token);
    await _persistUser();
    _set(
      (result.isNewUser || result.user.needsOnboarding)
          ? AuthStatus.onboarding
          : AuthStatus.authenticated,
    );
  }

  Future<void> devSignIn(String email) async {
    final result = await auth.devSignIn(email);
    user = result.user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kToken, result.token);
    await _persistUser();
    _set(
      (result.isNewUser || result.user.needsOnboarding)
          ? AuthStatus.onboarding
          : AuthStatus.authenticated,
    );
  }

  Future<void> saveProfile({
    required String username,
    required String name,
    required String gender,
    required String bio,
    required String avatar,
  }) async {
    final updated = await profiles.updateProfile(
      username: username,
      name: name,
      gender: gender,
      bio: bio,
      avatar: avatar,
    );

    user = updated.copyWith(
      email: updated.email.isEmpty ? user?.email : updated.email,
    );
    await _persistUser();
    _set(AuthStatus.authenticated);
  }

  void setLocation(LatLng loc) {
    myLocation = loc;
    notifyListeners();
  }

  bool get isInNCR {
    final l = myLocation;
    return l != null && Config.withinNCR(l.latitude, l.longitude);
  }

  Future<void> logout() async {
    await auth.signOut();
    user = null;
    myLocation = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
    await prefs.remove(_kUser);
    _set(AuthStatus.unauthenticated);
  }

  Future<void> _persistUser() async {
    if (user == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUser, _encodeUser(user!));
  }

  void _set(AuthStatus s) {
    status = s;
    notifyListeners();
  }

  String _encodeUser(OrbitUser u) => jsonEncode(u.toJson());

  Map<String, dynamic> _decodeUser(String s) =>
      (jsonDecode(s) as Map).cast<String, dynamic>();
}
