import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class Loginpage extends StatelessWidget {
  const Loginpage({super.key});

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
                decoration: InputDecoration(
                  labelStyle: TextStyle(color: Color.fromARGB(255, 17, 48, 82)),
                  labelText: 'Email',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(5.r),
                  ),
                  // Odaklandığında kenarlık rengini koyu siyaha ayarlar
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(7.r),
                    borderSide: const BorderSide(
                      color: Color.fromARGB(255, 17, 48, 82),
                      width: 2,
                    ), // Kalın ve koyu siyah
                  ),
                ),
              ),
              SizedBox(height: 16.h),

              // 2. Şifre Girişi
              TextField(
                obscureText: true,
                decoration: InputDecoration(
                  labelStyle: TextStyle(color: Color.fromARGB(255, 17, 48, 82)),
                  labelText: 'Şifre',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(5.r),
                  ),
                  // Odaklandığında kenarlık rengini koyu siyaha ayarlar
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(7.r),
                    borderSide: const BorderSide(
                      color: Color.fromARGB(255, 17, 48, 82),
                      width: 2,
                    ), // Kalın ve koyu siyah
                  ),
                ),
              ),
              SizedBox(height: 8.h),

              // 3. Şifremi Unuttum & Beni Hatırla
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () {
                      // Şifremi unuttum butonu
                    },
                    child: Text(
                      'Şifremi Unuttum?',
                      style: TextStyle(fontSize: 12.sp, color: Colors.black),
                    ),
                  ),
                  Row(
                    children: [
                      Checkbox(value: false, onChanged: (bool? value) {}),
                      Text('Beni Hatırla', style: TextStyle(fontSize: 12.sp)),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 24.h),

              // 4. Giriş Butonu
              ElevatedButton(
                onPressed: () {
                  // Giriş butonu işlemleri
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color.fromARGB(255, 17, 48, 82),
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
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                        color: Colors.grey,
                        width: 1.0,
                      ), // Kenarlık rengi
                      minimumSize: Size(80.w, 50.h), // Buton boyutu
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
                      ), // Kenarlık rengi
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
            ],
          ),
        ),
      ),
    );
  }
}
