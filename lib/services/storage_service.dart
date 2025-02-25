import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String keyUsername = 'username';
  static const String keyPassword = 'password';
  static const String keySessionId = 'sessionId';
  static const String keyToken = 'token';
  static const String keyIsLoggedIn = 'isLoggedIn';

  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  
  StorageService._internal();

  Future<void> saveCredentials({
    required String username,
    required String password,
    required String sessionId,
    required String token,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyUsername, username);
    await prefs.setString(keyPassword, password);
    await prefs.setString(keySessionId, sessionId);
    await prefs.setString(keyToken, token);
    await prefs.setBool(keyIsLoggedIn, true);
  }

  Future<Map<String, String?>> getCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'username': prefs.getString(keyUsername),
      'password': prefs.getString(keyPassword),
      'sessionId': prefs.getString(keySessionId),
      'token': prefs.getString(keyToken),
    };
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyIsLoggedIn) ?? false;
  }

  Future<void> clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
