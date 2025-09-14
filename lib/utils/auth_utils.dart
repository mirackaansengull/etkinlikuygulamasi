import 'package:shared_preferences/shared_preferences.dart';

class AuthUtils {
  // Tüm oturum bilgilerini temizle
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();

    // Token'ı temizle
    await prefs.remove('auth_token');

    // Kaydedilmiş kullanıcı bilgilerini temizle
    await prefs.remove('saved_email');
    await prefs.remove('saved_password');
    await prefs.setBool('remember_me', false);

    // Social login bilgilerini temizle
    await prefs.remove('social_login_type');
    await prefs.setBool('auto_social_login', false);
  }

  // Sadece token'ı temizle (kullanıcı bilgilerini koru)
  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  // Kullanıcının giriş yapmış olup olmadığını kontrol et
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    return token != null && token.isNotEmpty;
  }

  // Kaydedilmiş kullanıcı bilgilerini al
  static Future<Map<String, String?>> getSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'email': prefs.getString('saved_email'),
      'password': prefs.getString('saved_password'),
      'rememberMe': prefs.getBool('remember_me').toString(),
    };
  }
}
