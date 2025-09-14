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
  bool _hasProcessedDeepLink = false;

  @override
  void initState() {
    super.initState();
    // Deep link'leri dinle ve kontrolleri başlat
    _initializeApp();
  }

  // Uygulamayı başlat
  Future<void> _initializeApp() async {
    // Önce deep link kontrolü yap
    final hasDeepLink = await _checkForDeepLink();

    // Deep link yoksa normal kontrolleri başlat
    if (!hasDeepLink) {
      checkConnectionAndLoginStatus();
    }

    // Deep link listener'ı başlat
    _startDeepLinkListener();
  }

  // Deep link kontrolü
  Future<bool> _checkForDeepLink() async {
    try {
      final appLink = await _appLinks.getInitialAppLink();
      if (appLink != null && appLink.path.contains('/success')) {
        debugPrint('Deep link bulundu: $appLink');
        _handleDeepLink(appLink);
        return true;
      }
    } catch (e) {
      debugPrint('Deep link kontrol hatası: $e');
    }
    return false;
  }

  // Deep link listener'ı başlat
  void _startDeepLinkListener() {
    _appLinksSubscription = _appLinks.uriLinkStream.listen((uri) {
      debugPrint('Yeni deep link alındı: $uri');
      if (uri.path.contains('/success') && mounted && !_isProcessingDeepLink) {
        _handleDeepLink(uri);
      }
    });
  }

  // Deep link'den gelen token'ı işle
  void _handleDeepLink(Uri uri) async {
    if (_isProcessingDeepLink || _hasProcessedDeepLink) return;
    _isProcessingDeepLink = true;
    _hasProcessedDeepLink = true;

    debugPrint('🔗 Deep link işleniyor: $uri');

    final token = uri.queryParameters['token'];
    final loginType = uri.queryParameters['type'];

    debugPrint(
      '🔑 Token: ${token != null ? "${token.substring(0, 20)}..." : "null"}, Type: $loginType',
    );

    if (token != null && token.isNotEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', token);
        debugPrint('✅ Token kaydedildi');

        // Social login tipini kaydet
        if (loginType != null) {
          await prefs.setString('social_login_type', loginType);
          await prefs.setBool('auto_social_login', true);
          debugPrint('✅ Social login tipi kaydedildi: $loginType');
        }

        // Kısa bir gecikme ekle ve homepage'e git
        await Future.delayed(const Duration(milliseconds: 100));

        if (mounted) {
          debugPrint('🏠 Homepage\'e yönlendiriliyor...');
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const Homepage()),
            (route) => false,
          );
        }
      } catch (e) {
        debugPrint('❌ Deep link işleme hatası: $e');
        _isProcessingDeepLink = false;
        _hasProcessedDeepLink = false;
      }
    } else {
      debugPrint('❌ Token bulunamadı, login sayfasına yönlendiriliyor');
      _isProcessingDeepLink = false;
      _hasProcessedDeepLink = false;
      _navigateToLoginPage();
    }
  }

  // Bağlantıyı ve token'ı kontrol eden fonksiyon
  void checkConnectionAndLoginStatus() async {
    // Deep link işleniyorsa normal kontrolleri yapma
    if (_hasProcessedDeepLink) {
      debugPrint('🔗 Deep link işlendi, normal kontroller atlanıyor');
      return;
    }

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
          if (!_hasProcessedDeepLink) {
            checkConnectionAndLoginStatus();
          }
        }
      } else {
        // HTTP hatası, tekrar dene
        await Future.delayed(const Duration(seconds: 3));
        if (!_hasProcessedDeepLink) {
          checkConnectionAndLoginStatus();
        }
      }
    } catch (e) {
      // Ağ hatası veya diğer hatalar, tekrar dene
      debugPrint('Bağlantı hatası: $e');
      await Future.delayed(const Duration(seconds: 3));
      if (!_hasProcessedDeepLink) {
        checkConnectionAndLoginStatus();
      }
    }
  }

  // Giriş durumunu kontrol et ve yönlendirme yap
  Future<void> _checkLoginStatus() async {
    // Deep link işleniyorsa kontrolleri yapma
    if (_hasProcessedDeepLink) return;

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
          if (!_hasProcessedDeepLink) {
            _navigateToHomepage();
          }
        } else {
          // Token geçersizse, social login kontrolü yap
          if (!_hasProcessedDeepLink) {
            await _checkAutoSocialLogin(prefs);
          }
        }
      } catch (e) {
        // Ağ hatası durumunda social login kontrolü yap
        debugPrint('Token doğrulama sırasında hata oluştu: $e');
        if (!_hasProcessedDeepLink) {
          await _checkAutoSocialLogin(prefs);
        }
      }
    } else {
      // Token yoksa social login kontrolü yap
      if (!_hasProcessedDeepLink) {
        await _checkAutoSocialLogin(prefs);
      }
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
