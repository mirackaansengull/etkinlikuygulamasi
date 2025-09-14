import 'dart:async';
import 'dart:convert';
import 'package:etkinlikuygulamasi/frontend/home/homepage.dart';
import 'package:etkinlikuygulamasi/frontend/login/loginpage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_links/app_links.dart';

class LoadingPage extends StatefulWidget {
  const LoadingPage({super.key});

  @override
  State<LoadingPage> createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage> {
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _appLinksSubscription;
  bool _isProcessingDeepLink = false;

  @override
  void initState() {
    super.initState();
    // Deep link'leri dinle
    _initAppLinks();
    // Uygulama başladığında ilk olarak bağlantıyı ve giriş durumunu kontrol et
    checkConnectionAndLoginStatus();
  }

  // Deep link'leri dinle
  Future<void> _initAppLinks() async {
    // Uygulama kapalıyken gelen ilk URL'yi al
    final appLink = await _appLinks.getInitialAppLink();
    if (appLink != null && appLink.path.contains('/success')) {
      _handleDeepLink(appLink);
      return; // Deep link varsa normal kontrolleri yapma
    }

    // Uygulama açıkken gelen URL'leri dinle
    _appLinksSubscription = _appLinks.uriLinkStream.listen((uri) {
      if (uri.path.contains('/success') && mounted && !_isProcessingDeepLink) {
        _handleDeepLink(uri);
      }
    });
  }

  // Deep link'den gelen token'ı işle
  void _handleDeepLink(Uri uri) async {
    if (_isProcessingDeepLink) return;
    _isProcessingDeepLink = true;

    final token = uri.queryParameters['token'];
    final loginType = uri.queryParameters['type'];

    if (token != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);

      // Social login tipini kaydet
      if (loginType != null) {
        await prefs.setString('social_login_type', loginType);
        await prefs.setBool('auto_social_login', true);
      }

      if (mounted) {
        _navigateToHomepage();
      }
    }
  }

  // Bağlantıyı ve token'ı kontrol eden fonksiyon
  void checkConnectionAndLoginStatus() async {
    const backendUrl = 'https://etkinlikuygulamasi.onrender.com';

    try {
      final response = await http.get(Uri.parse('$backendUrl/health'));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['status'] == 'ok') {
          // Bağlantı başarılı, şimdi giriş durumunu kontrol et
          await _checkLoginStatus();
        } else {
          // Bağlantı başarısız, tekrar dene
          await Future.delayed(const Duration(seconds: 3));
          checkConnectionAndLoginStatus();
        }
      } else {
        // HTTP hatası, tekrar dene
        await Future.delayed(const Duration(seconds: 3));
        checkConnectionAndLoginStatus();
      }
    } catch (e) {
      // Ağ hatası veya diğer hatalar, tekrar dene
      debugPrint('Bağlantı hatası: $e');
      await Future.delayed(const Duration(seconds: 3));
      checkConnectionAndLoginStatus();
    }
  }

  // Giriş durumunu kontrol et ve yönlendirme yap
  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token != null && token.isNotEmpty) {
      // Eğer token varsa, token'ın geçerliliğini doğrula
      final String serverUrl = "https://etkinlikuygulamasi.onrender.com";
      final Uri url = Uri.parse('$serverUrl/verify-token');
      try {
        final response = await http.post(
          url,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        );

        if (response.statusCode == 200) {
          // Token geçerliyse, doğrudan ana sayfaya yönlendir
          _navigateToHomepage();
        } else {
          // Token geçersizse, social login kontrolü yap
          await _checkAutoSocialLogin(prefs);
        }
      } catch (e) {
        // Ağ hatası durumunda social login kontrolü yap
        debugPrint('Token doğrulama sırasında hata oluştu: $e');
        await _checkAutoSocialLogin(prefs);
      }
    } else {
      // Token yoksa social login kontrolü yap
      await _checkAutoSocialLogin(prefs);
    }
  }

  // Otomatik social login kontrolü
  Future<void> _checkAutoSocialLogin(SharedPreferences prefs) async {
    final autoSocialLogin = prefs.getBool('auto_social_login') ?? false;
    final socialLoginType = prefs.getString('social_login_type');

    if (autoSocialLogin && socialLoginType != null) {
      // Otomatik social login yap
      await _performAutoSocialLogin(socialLoginType);
    } else {
      // Normal giriş sayfasına yönlendir
      _navigateToLoginPage();
    }
  }

  // Otomatik social login gerçekleştir
  Future<void> _performAutoSocialLogin(String loginType) async {
    try {
      // Şimdilik login sayfasına yönlendir
      // Gelecekte burada otomatik social login yapılabilir
      _navigateToLoginPage();
    } catch (e) {
      debugPrint('Otomatik social login hatası: $e');
      _navigateToLoginPage();
    }
  }

  void _navigateToHomepage() {
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const Homepage()),
      );
    }
  }

  void _navigateToLoginPage() {
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const Loginpage()),
      );
    }
  }

  @override
  void dispose() {
    _appLinksSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('images/eventra.png', width: 200.w, height: 200.h),
            SizedBox(
              width: 35.h,
              height: 35.h,
              child: const CircularProgressIndicator(
                color: Color.fromARGB(255, 17, 48, 82),
                strokeCap: StrokeCap.round,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
