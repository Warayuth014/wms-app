import 'package:shared_preferences/shared_preferences.dart';

class AuthSession {
  final String? userId;
  final String? fullName;
  final String? role;

  const AuthSession({
    required this.userId,
    required this.fullName,
    required this.role,
  });

  bool get isLoggedIn => userId != null;
}

class AuthSessionService {
  const AuthSessionService();

  Future<AuthSession> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    return AuthSession(
      userId: prefs.getString('userId'),
      fullName: prefs.getString('fullName'),
      role: prefs.getString('role'),
    );
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
