import 'dart:async';
import 'dart:convert';
import 'package:etkinlikuygulamasi/frontend/home/homepage.dart';
import 'package:etkinlikuygulamasi/frontend/login/loginpage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LoadingPage extends StatefulWidget {
  const LoadingPage({super.key});

  @override
  _LoadingPageState createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage> {
  @override
  void initState() {
    super.initState();
    // Uygulama başladığında ilk olarak bağlantıyı ve giriş durumunu kontrol et
    checkConnectionAndLoginStatus();
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
            'Authorization': 'Bearer $token', // DÜZELTİLMİŞ SATIR
            'Content-Type': 'application/json',
          },
        );

        if (response.statusCode == 200) {
          // Token geçerliyse, doğrudan ana sayfaya yönlendir
          _navigateToHomepage();
        } else {
          // Token geçersizse, token'ı sil ve giriş ekranına yönlendir
          await prefs.remove('auth_token');
          _navigateToLoginPage();
        }
      } catch (e) {
        // Ağ hatası durumunda
        debugPrint('Token doğrulama sırasında hata oluştu: $e');
        _navigateToLoginPage();
      }
    } else {
      // Token yoksa doğrudan giriş sayfasına yönlendir
      _navigateToLoginPage();
    }
  }

  void _navigateToHomepage() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const Homepage()),
    );
  }

  void _navigateToLoginPage() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const Loginpage()),
    );
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
