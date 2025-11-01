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
  AppLinks? _appLinks;
  StreamSubscription<Uri>? _appLinksSubscription;
  bool _isHandlingDeepLink = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _checkTokenAfterResume();
    }
  }

  Future<void> _checkTokenAfterResume() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (_isHandlingDeepLink) return;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token != null && token.isNotEmpty) {
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const Homepage()),
          (route) => false,
        );
      }
    }
  }

  Future<void> _initializeApp() async {
    // Start deep link listener (background)
    _appLinks = AppLinks();
    _appLinksSubscription = _appLinks!.uriLinkStream.listen(_handleDeepLink, onError: (_) {});

    // Handle initial link if app was opened via deep link
    try {
      final initialUri = await _appLinks!.getInitialAppLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
        return;
      }
    } catch (_) {}

    await checkConnectionAndLoginStatus();
  }

  void _handleDeepLink(Uri uri) async {
    debugPrint('[LOADING] Deep link received: $uri');
    if (!(uri.scheme == 'etkinlikuygulamasi' && uri.host == 'login' && uri.path == '/success')) {
      return;
    }
    if (_isHandlingDeepLink) return;
    _isHandlingDeepLink = true;
    final token = uri.queryParameters['token'];
    debugPrint('[LOADING] Token present: ${token != null && token.isNotEmpty}');
    if (token == null || token.isEmpty) {
      _isHandlingDeepLink = false;
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);

    if (!mounted) {
      _isHandlingDeepLink = false;
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const Homepage()),
      (route) => false,
    );
    _isHandlingDeepLink = false;
  }

  // Bağlantıyı ve token'ı kontrol eden fonksiyon
  Future<void> checkConnectionAndLoginStatus() async {
    if (_isHandlingDeepLink) return;
    const backendUrl = 'https://eventra-2dwa.onrender.com';

    try {
      final response = await http.get(Uri.parse('$backendUrl/health'));
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['status'] == 'ok') {
          await _checkLoginStatus();
        } else {
          await Future.delayed(const Duration(seconds: 3));
          await checkConnectionAndLoginStatus();
        }
      } else {
        await Future.delayed(const Duration(seconds: 3));
        await checkConnectionAndLoginStatus();
      }
    } catch (e) {
      await Future.delayed(const Duration(seconds: 3));
      await checkConnectionAndLoginStatus();
    }
  }

  // Giriş durumunu kontrol et ve yönlendirme yap
  Future<void> _checkLoginStatus() async {
    if (_isHandlingDeepLink) return;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token != null && token.isNotEmpty) {
      // Token'ı doğrula
      final String serverUrl = "https://eventra-2dwa.onrender.com";
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
          _navigateToHomepage();
        } else {
          _navigateToLoginPage();
        }
      } catch (e) {
        _navigateToLoginPage();
      }
    } else {
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
          ],
        ),
      ),
    );
  }
}
