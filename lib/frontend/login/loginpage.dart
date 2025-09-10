// loginpage.dart

import 'package:etkinlikuygulamasi/frontend/login/registerpage.dart';
import 'package:etkinlikuygulamasi/frontend/home/homepage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart'; // Bu satırı ekleyin

class Loginpage extends StatefulWidget {
  const Loginpage({super.key});

  @override
  _LoginpageState createState() => _LoginpageState();
}

class _LoginpageState extends State<Loginpage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _rememberMe = false;

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);

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
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const Homepage()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Giriş Başarısız: ${response.body}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ağ hatası: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // Google ile giriş için yeni handler
  Future<void> _handleGoogleSignIn() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // Kullanıcı girişi iptal etti
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken != null) {
        final response = await http.post(
          Uri.parse(
            'https://etkinlikuygulamasi.onrender.com/auth/google/verify',
          ),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'token': idToken}),
        );

        if (response.statusCode == 200) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const Homepage()),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Backend hatası: Giriş başarısız oldu.')),
          );
        }
      }
    } catch (error) {
      print('Google giriş hatası: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google girişinde bir hata oluştu.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              SizedBox(height: 70.h),
              Image.asset('images/eventra.png', width: 250.w),
              SizedBox(height: 40.h),
              Text(
                'Giriş Yap',
                style: TextStyle(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.bold,
                  color: const Color.fromARGB(255, 17, 48, 82),
                ),
              ),
              SizedBox(height: 15.h),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'E-mail',
                  prefixIcon: const Icon(Icons.email),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
              ),
              SizedBox(height: 15.h),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Şifre',
                  prefixIcon: const Icon(Icons.lock),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
              ),
              SizedBox(height: 10.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
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
                      Text('Beni Hatırla', style: TextStyle(fontSize: 14.sp)),
                    ],
                  ),
                  TextButton(
                    onPressed: () {},
                    child: Text(
                      'Şifreni mi unuttun?',
                      style: TextStyle(fontSize: 12.sp, color: Colors.black),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 15.h),
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
                  style: TextStyle(color: Colors.white, fontSize: 18.sp),
                ),
              ),
              SizedBox(height: 24.h),
              Text(
                'ya da sosyal medyayı kullanın',
                style: TextStyle(fontSize: 14.sp),
              ),
              SizedBox(height: 24.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: _handleGoogleSignIn, // Burayı değiştirdik
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
