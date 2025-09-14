import 'dart:async';
import 'dart:convert';
import 'package:etkinlikuygulamasi/frontend/home/homepage.dart';
import 'package:etkinlikuygulamasi/frontend/login/forgotpasswordpage.dart';
import 'package:etkinlikuygulamasi/frontend/login/registerpage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class Loginpage extends StatefulWidget {
  const Loginpage({super.key});

  @override
  State<Loginpage> createState() => _LoginpageState();
}

class _LoginpageState extends State<Loginpage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    // Kaydedilmiş bilgileri yükle
    _loadSavedCredentials();
  }

  // Kaydedilmiş kullanıcı bilgilerini yükle
  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('saved_email');
    final savedPassword = prefs.getString('saved_password');
    final rememberMe = prefs.getBool('remember_me') ?? false;

    if (savedEmail != null && savedPassword != null && rememberMe) {
      setState(() {
        _emailController.text = savedEmail;
        _passwordController.text = savedPassword;
        _rememberMe = rememberMe;
      });

      // Otomatik giriş yap
      await _autoLogin();
    }
  }

  // Otomatik giriş fonksiyonu
  Future<void> _autoLogin() async {
    if (_emailController.text.isNotEmpty &&
        _passwordController.text.isNotEmpty) {
      await _loginHandler(context);
    }
  }

  // Kullanıcı bilgilerini kaydet
  Future<void> _saveCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setString('saved_email', _emailController.text.trim());
      await prefs.setString('saved_password', _passwordController.text);
      await prefs.setBool('remember_me', true);
    } else {
      // Beni hatırla seçili değilse kaydedilmiş bilgileri sil
      await prefs.remove('saved_email');
      await prefs.remove('saved_password');
      await prefs.setBool('remember_me', false);
    }
  }

  void _navigateToHomepage() {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const Homepage()),
      );
    }
  }

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
        final token = responseData['token'];

        if (token != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_token', token);

          // Kullanıcı bilgilerini kaydet (beni hatırla seçiliyse)
          await _saveCredentials();
        }

        if (mounted) {
          _navigateToHomepage();
        }
      } else {
        final responseData = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(responseData['message'] ?? 'Giriş başarısız oldu.'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bir hata oluştu. Lütfen tekrar deneyin.'),
          ),
        );
      }
    }
  }

  void _launchGoogleLogin(BuildContext context) async {
    final String serverUrl = "https://etkinlikuygulamasi.onrender.com";
    final Uri url = Uri.parse('$serverUrl/google/login');
    if (await canLaunchUrl(url)) {
      // External browser'da aç (in-app browser yerine)
      await launchUrl(url, mode: LaunchMode.externalApplication);

      // Google login'den sonra token kontrolü yap
      _startTokenCheckTimer();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('URL açılamadı: $url')));
      }
    }
  }

  // Google login sonrası token kontrolü
  void _startTokenCheckTimer() {
    debugPrint('🔄 Token kontrol timer başlatıldı');
    Timer.periodic(const Duration(seconds: 2), (timer) async {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      debugPrint('⏰ Timer kontrol: Token var mı? ${token != null}');

      if (token != null && token.isNotEmpty) {
        debugPrint('✅ Token bulundu, homepage\'e yönlendiriliyor');
        timer.cancel();
        if (mounted) {
          _navigateToHomepage();
        }
      } else if (timer.tick > 30) {
        // 60 saniye sonra durdur
        debugPrint('⏰ Timer timeout, durduruluyor');
        timer.cancel();
      }
    });
  }

  // Manuel token girişi dialog'u
  void _showManualTokenDialog() {
    final tokenController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manuel Token Girişi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Google/Facebook girişi sonrası aldığınız token\'ı buraya yapıştırın:',
            ),
            SizedBox(height: 16.h),
            TextField(
              controller: tokenController,
              decoration: const InputDecoration(
                labelText: 'Token',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final token = tokenController.text.trim();
              if (token.isNotEmpty) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('auth_token', token);
                await prefs.setString('social_login_type', 'manual');
                await prefs.setBool('auto_social_login', true);

                if (mounted) {
                  Navigator.pop(context);
                  _navigateToHomepage();
                }
              }
            },
            child: const Text('Giriş Yap'),
          ),
        ],
      ),
    );
  }

  void _launchFacebookLogin(BuildContext context) async {
    final String serverUrl = "https://etkinlikuygulamasi.onrender.com";
    final Uri url = Uri.parse('$serverUrl/facebook/login');
    if (await canLaunchUrl(url)) {
      // External browser'da aç (in-app browser yerine)
      await launchUrl(url, mode: LaunchMode.externalApplication);

      // Facebook login'den sonra token kontrolü yap
      _startTokenCheckTimer();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('URL açılamadı: $url')));
      }
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
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const ForgotPasswordPage(),
                        ),
                      );
                    },
                    child: Text(
                      'Şifremi Unuttum?',
                      style: TextStyle(fontSize: 12.sp, color: Colors.black),
                    ),
                  ),
                  Row(
                    children: [
                      Checkbox(
                        value: _rememberMe,
                        onChanged: (bool? value) async {
                          setState(() {
                            _rememberMe = value ?? false;
                          });

                          // Eğer "Beni Hatırla" kapatıldıysa, kaydedilmiş bilgileri temizle
                          if (!_rememberMe) {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.remove('saved_email');
                            await prefs.remove('saved_password');
                            await prefs.setBool('remember_me', false);
                          }
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
                    onPressed: () => _launchFacebookLogin(context),
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
              SizedBox(height: 16.h),
              // Manuel token girişi butonu
              TextButton(
                onPressed: _showManualTokenDialog,
                child: Text(
                  'Manuel Token Girişi',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.grey[600],
                    decoration: TextDecoration.underline,
                  ),
                ),
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
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
