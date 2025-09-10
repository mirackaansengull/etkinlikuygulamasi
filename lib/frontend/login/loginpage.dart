import 'package:etkinlikuygulamasi/frontend/login/registerpage.dart';
import 'package:etkinlikuygulamasi/frontend/home/homepage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class Loginpage extends StatefulWidget {
  const Loginpage({super.key});

  @override
  _LoginpageState createState() => _LoginpageState();
}

class _LoginpageState extends State<Loginpage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _rememberMe = false;

  // E-posta ve şifre ile giriş için handler
  Future<void> _loginHandler(BuildContext context) async {
    final String serverUrl = "https://etkinlikuygulamasi.onrender.com";
    final Uri url = Uri.parse('$serverUrl/auth/login');

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
          // Başarılı giriş, HomePage'e yönlendir
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const Homepage()),
          );
        } else {
          // Hata mesajı göster
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
    final Uri url = Uri.parse('$serverUrl/auth/google/login');

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('URL açılamadı: $url')));
      }
    } catch (e) {
      debugPrint('Hata: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Bir hata oluştu: $e')));
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
              // 1. Email Girişi
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelStyle: const TextStyle(
                    color: Color.fromARGB(255, 17, 48, 82),
                  ),
                  labelText: 'Email',
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
              SizedBox(height: 16.h),

              // 2. Şifre Girişi
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelStyle: const TextStyle(
                    color: Color.fromARGB(255, 17, 48, 82),
                  ),
                  labelText: 'Şifre',
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

              // 3. Şifremi Unuttum & Beni Hatırla
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

              // 4. Giriş Butonu
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

              // 5. '-- VEYA --' Metni
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

              // 6. Google ve Facebook Butonları
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
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
