import 'dart:async';
import 'dart:convert';
import 'package:etkinlikuygulamasi/frontend/home/homepage.dart';
import 'package:etkinlikuygulamasi/frontend/login/registerpage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:app_links/app_links.dart';

class Loginpage extends StatefulWidget {
  const Loginpage({super.key});

  @override
  _LoginpageState createState() => _LoginpageState();
}

class _LoginpageState extends State<Loginpage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _rememberMe = false;

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _appLinksSubscription;

  @override
  void initState() {
    super.initState();
    _initAppLinks();
  }

  Future<void> _initAppLinks() async {
    // Uygulama kapalıyken gelen ilk URL'yi al
    try {
      final appLink = await _appLinks.getInitialAppLink();
      if (appLink != null && appLink.path == '/success') {
        _navigateToHomepage();
      }
    } on PlatformException {
      // Hata oluşursa
      debugPrint('Initial app link alırken hata oluştu.');
    }

    // Uygulama açıkken gelen URL'leri dinle
    _appLinksSubscription = _appLinks.uriLinkStream.listen((uri) {
      if (uri.path == '/success' && mounted) {
        _navigateToHomepage();
      }
    });
  }

  void _navigateToHomepage() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const Homepage()),
    );
  }

  // E-posta ve şifre ile giriş için handler
  Future<void> _loginHandler(BuildContext context) async {
    final String serverUrl = "https://etkinlikuygulamasi.onrender.com";
    final Uri url = Uri.parse('$serverUrl/login');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _emailController.text.trim(),
          'sifre': _passwordController.text,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          _navigateToHomepage();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(responseData['message'] ?? 'Giriş başarısız'),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sunucu hatası: ${response.statusCode}')),
        );
      }
    } catch (e) {
      debugPrint('Giriş hatası: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Bir hata oluştu')));
    }
  }

  // Google Giriş için URL'yi başlatma fonksiyonu
  void _launchGoogleLogin(BuildContext context) async {
    final String serverUrl = "https://etkinlikuygulamasi.onrender.com";
    final Uri url = Uri.parse('$serverUrl/google/login');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.inAppBrowserView);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('URL açılamadı: $url')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('images/eventra.png', width: 150.w, height: 150.h),
              SizedBox(height: 16.h),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: const TextStyle(
                    color: Color.fromARGB(255, 17, 48, 82),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(5.r),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(7.r),
                    borderSide: const BorderSide(
                      color: Color.fromARGB(255, 17, 48, 82),
                      width: 1,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Şifre',
                  labelStyle: const TextStyle(
                    color: Color.fromARGB(255, 17, 48, 82),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(5.r),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(7.r),
                    borderSide: const BorderSide(
                      color: Color.fromARGB(255, 17, 48, 82),
                      width: 2,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 8.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () {},
                    child: Text(
                      'Şifremi Unuttum?',
                      style: TextStyle(fontSize: 12.sp, color: Colors.black),
                    ),
                  ),
                  Row(
                    children: [
                      Checkbox(
                        value: _rememberMe,
                        onChanged: (bool? value) {
                          setState(() {
                            _rememberMe = value ?? false;
                          });
                        },
                      ),
                      Text('Beni Hatırla', style: TextStyle(fontSize: 12.sp)),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 24.h),
              ElevatedButton(
                onPressed: () => _loginHandler(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 17, 48, 82),
                  minimumSize: Size(double.infinity, 50.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
                child: Text(
                  'Giriş Yap',
                  style: TextStyle(fontSize: 16.sp, color: Colors.white),
                ),
              ),
              SizedBox(height: 24.h),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text('VEYA'),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              SizedBox(height: 24.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: () => _launchGoogleLogin(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.grey, width: 1.0),
                      minimumSize: Size(80.w, 50.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                    ),
                    child: Image.asset(
                      'images/google.png',
                      height: 50.h,
                      width: 80.w,
                    ),
                  ),
                  SizedBox(width: 24.w),
                  OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                        color: Color.fromARGB(255, 158, 158, 158),
                        width: 1.0,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                    ),
                    child: Image.asset(
                      'images/facebook.png',
                      height: 50.h,
                      width: 80.w,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24.h),
              Text('Hala üye değil misin?', style: TextStyle(fontSize: 14.sp)),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const Registerpage(),
                    ),
                  );
                },
                child: Text(
                  'Kayıt ol',
                  style: TextStyle(fontSize: 12.sp, color: Colors.black),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _appLinksSubscription?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
