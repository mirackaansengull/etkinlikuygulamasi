import 'package:etkinlikuygulamasi/frontend/login/loginpage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LoadingPage extends StatefulWidget {
  const LoadingPage({super.key});

  @override
  _LoadingPageState createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage> {
  @override
  void initState() {
    super.initState();
    checkConnection();
  }

  // MongoDB bağlantısını kontrol eden fonksiyon
  void checkConnection() async {
    final backend_url = Uri.parse('https://etkinlikuygulamasi.onrender.com');

    try {
      final response = await http.get(Uri.parse('$backend_url/healt'));

      if (response.statusCode == 200) {
        // Bağlantı başarılı, JSON yanıtını kontrol et
        final responseData = json.decode(response.body);
        if (responseData['status'] == 'ok') {
          // Bağlantı başarılı, ana sayfaya yönlendir
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => Loginpage(), // Ana sayfanızın sınıfı
            ),
          );
        } else {
          // Bağlantı başarısız, tekrar dene
          await Future.delayed(Duration(seconds: 3));
          checkConnection();
        }
      } else {
        // HTTP hatası, tekrar dene
        await Future.delayed(Duration(seconds: 3));
        checkConnection();
      }
    } catch (e) {
      // Ağ hatası veya diğer hatalar, tekrar dene
      print('Bağlantı hatası: $e');
      await Future.delayed(Duration(seconds: 3));
      checkConnection();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromARGB(255, 255, 255, 255),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('images/eventra.png', width: 200.w, height: 200.h),
            SizedBox(
              width: 35.h, // Genişliği belirle
              height: 35.h, // Yüksekliği belirle
              child: CircularProgressIndicator(
                color: Color.fromARGB(255, 17, 48, 82),
                strokeCap: StrokeCap.round,
              ),
            ), // Yükleniyor animasyonu
          ],
        ),
      ),
    );
  }
}
