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

class _LoadingPageState extends State<LoadingPage> with WidgetsBindingObserver {
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _appLinksSubscription;
  bool _isProcessingDeepLink = false;
  bool _hasProcessedDeepLink = false;

  @override
  void initState() {
    super.initState();
    // App lifecycle observer ekle
    WidgetsBinding.instance.addObserver(this);
    // Deep link'leri dinle ve kontrolleri başlat
    _initializeApp();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    debugPrint('📱 App lifecycle değişti: $state');

    if (state == AppLifecycleState.resumed) {
      debugPrint('🔄 App resume oldu, token kontrol ediliyor...');
      _checkTokenAfterResume();
    }
  }

  // App resume olduktan sonra token kontrolü
  Future<void> _checkTokenAfterResume() async {
    await Future.delayed(const Duration(milliseconds: 500));

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    debugPrint(
      '🔍 Resume sonrası token kontrolü: ${token != null ? "Token var" : "Token yok"}',
    );

    if (token != null && token.isNotEmpty && !_hasProcessedDeepLink) {
      debugPrint('✅ Token bulundu, homepage\'e yönlendiriliyor');
      _hasProcessedDeepLink = true;
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const Homepage()),
          (route) => false,
        );
      }
    }
  }

  // Uygulamayı başlat
  Future<void> _initializeApp() async {
    debugPrint('🚀 Uygulama başlatılıyor...');

    // Deep link listener'ı hemen başlat
    _startDeepLinkListener();

    // Kısa bir gecikme sonra deep link kontrolü yap
    await Future.delayed(const Duration(milliseconds: 500));
    final hasDeepLink = await _checkForDeepLink();

    // Deep link yoksa normal kontrolleri başlat
    if (!hasDeepLink) {
      debugPrint('📱 Normal kontroller başlatılıyor...');
      // Periyodik deep link kontrolü başlat
      _startPeriodicDeepLinkCheck();
      checkConnectionAndLoginStatus();
    }
  }

  // Periyodik deep link kontrolü
  void _startPeriodicDeepLinkCheck() {
    Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_hasProcessedDeepLink) {
        timer.cancel();
        return;
      }

      final hasDeepLink = await _checkForDeepLink();
      if (hasDeepLink) {
        timer.cancel();
      } else if (timer.tick > 60) {
        // 60 saniye sonra durdur
        timer.cancel();
      }
    });
  }

  // Deep link kontrolü
  Future<bool> _checkForDeepLink() async {
    debugPrint('🔍 Deep link kontrol ediliyor...');
    try {
      final appLink = await _appLinks.getInitialAppLink();
      debugPrint('📋 Initial app link: $appLink');

      if (appLink != null && appLink.path.contains('/success')) {
        debugPrint('✅ Deep link bulundu: $appLink');
        _handleDeepLink(appLink);
        return true;
      } else {
        debugPrint('❌ Deep link bulunamadı');
      }
    } catch (e) {
      debugPrint('❌ Deep link kontrol hatası: $e');
    }
    return false;
  }

  // Deep link listener'ı başlat
  void _startDeepLinkListener() {
    debugPrint('👂 Deep link listener başlatılıyor...');
    _appLinksSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        debugPrint('📨 Yeni deep link alındı: $uri');
        if (uri.path.contains('/success') &&
            mounted &&
            !_isProcessingDeepLink) {
          debugPrint('✅ Deep link işlenecek');
          _handleDeepLink(uri);
        } else {
          debugPrint(
            '❌ Deep link işlenmedi - path: ${uri.path}, mounted: $mounted, processing: $_isProcessingDeepLink',
          );
        }
      },
      onError: (error) {
        debugPrint('❌ Deep link listener hatası: $error');
      },
    );
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
    WidgetsBinding.instance.removeObserver(this);
    _appLinksSubscription?.cancel();
    super.dispose();
  }

  // Test için manuel deep link işleme
  void _testDeepLink() {
    final testUri = Uri.parse(
      'etkinlikuygulamasi://login/success?token=test_token&type=google',
    );
    debugPrint('🧪 Test deep link işleniyor: $testUri');
    _handleDeepLink(testUri);
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
            SizedBox(height: 20.h),
            SizedBox(
              width: 35.h,
              height: 35.h,
              child: const CircularProgressIndicator(
                color: Color.fromARGB(255, 17, 48, 82),
                strokeCap: StrokeCap.round,
              ),
            ),
            SizedBox(height: 40.h),
            // Test butonu (sadece debug için)
            if (true) // Debug mode kontrolü yapabilirsiniz
              ElevatedButton(
                onPressed: _testDeepLink,
                child: const Text('Test Deep Link'),
              ),
          ],
        ),
      ),
    );
  }
}
