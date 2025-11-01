import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:etkinlikuygulamasi/frontend/login/loginpage.dart';

class Registerpage extends StatefulWidget {
  const Registerpage({super.key});

  @override
  _RegisterpageState createState() => _RegisterpageState();
}

class _RegisterpageState extends State<Registerpage> {
  // Metin giriş alanlarının controller'ları
  final TextEditingController _adController = TextEditingController();
  final TextEditingController _soyadController = TextEditingController();
  final TextEditingController _telefonController = TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _sifreController = TextEditingController();
  final TextEditingController _verificationCodeController =
      TextEditingController();

  // Doğrulama aşamasını kontrol eden değişken
  bool _isVerificationSent = false;
  // Geri sayım sayacını kontrol eden değişkenler
  int _countdown = 180; // 3 dakika = 180 saniye
  Timer? _timer;
  final backend_url = Uri.parse('https://eventra-2dwa.onrender.com');

  @override
  void dispose() {
    _adController.dispose();
    _soyadController.dispose();
    _telefonController.dispose();
    _birthDateController.dispose();
    _emailController.dispose();
    _sifreController.dispose();
    _verificationCodeController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  // Doğum tarihi seçme işlevi
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color.fromARGB(255, 17, 48, 82), // Takvim başlık rengi
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _birthDateController.text = DateFormat('dd.MM.yyyy').format(picked);
      });
    }
  }

  // Geri sayım sayacını başlatma
  void _startTimer() {
    _countdown = 180;
    _timer?.cancel(); // Önceki sayacı durdur
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_countdown > 0) {
          _countdown--;
        } else {
          _timer?.cancel();
        }
      });
    });
  }

  // Backend'e doğrulama kodu gönderme isteği
  Future<void> _sendVerificationCode() async {
    // Tüm alanların dolu olup olmadığını kontrol et
    if (_adController.text.isEmpty ||
        _soyadController.text.isEmpty ||
        _telefonController.text.isEmpty ||
        _birthDateController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _sifreController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen tüm alanları doldurun.')),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('$backend_url/send-code'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': _emailController.text}),
      );

      if (response.statusCode == 200) {
        setState(() {
          _isVerificationSent = true;
          _startTimer();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Doğrulama kodu email adresinize gönderildi.'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hata: Kod gönderilemedi. Lütfen tekrar deneyin.'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Bir hata oluştu. Lütfen internet bağlantınızı kontrol edin.',
          ),
        ),
      );
    }
  }

  // Backend'e doğrulama ve kayıt isteği
  Future<void> _verifyAndRegister() async {
    final verificationCode = _verificationCodeController.text;

    if (verificationCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen doğrulama kodunu girin.')),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('$backend_url/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'ad': _adController.text,
          'soyad': _soyadController.text,
          'telefon': _telefonController.text,
          'dogumTarihi': _birthDateController.text,
          'email': _emailController.text,
          'sifre': _sifreController.text,
          'verificationCode': verificationCode,
        }),
      );

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Kayıt başarılı! Giriş sayfasına yönlendiriliyorsunuz.',
            ),
          ),
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const Loginpage()),
        );
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorData['message'] ?? 'Kayıt başarısız oldu.'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bir hata oluştu. Lütfen tekrar deneyin.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Image.asset('images/eventra_appbar.png', height: kToolbarHeight),
        centerTitle: true,
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
        foregroundColor: const Color.fromARGB(255, 17, 48, 82),
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Kayıt Formu', style: TextStyle(fontSize: 20.sp)),
                SizedBox(height: 25.h),

                // Doğrulama kodu gönderilmemişse formu göster
                if (!_isVerificationSent) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _adController,
                          decoration: InputDecoration(
                            labelText: 'Ad',
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
                      ),
                      SizedBox(width: 16.w),
                      Expanded(
                        child: TextField(
                          controller: _soyadController,
                          decoration: InputDecoration(
                            labelText: 'Soyad',
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
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  TextField(
                    controller: _telefonController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Telefon Numarası',
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
                  TextField(
                    controller: _birthDateController,
                    readOnly: true,
                    onTap: () => _selectDate(context),
                    decoration: InputDecoration(
                      labelText: 'Doğum Tarihi',
                      suffixIcon: const Icon(
                        Icons.calendar_today,
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
                  SizedBox(height: 16.h),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
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
                  TextField(
                    controller: _sifreController,
                    obscureText: true,
                    decoration: InputDecoration(
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
                  SizedBox(height: 24.h),
                  ElevatedButton(
                    onPressed: _sendVerificationCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 17, 48, 82),
                      minimumSize: Size(double.infinity, 50.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                    ),
                    child: Text(
                      'Kayıt Ol',
                      style: TextStyle(fontSize: 16.sp, color: Colors.white),
                    ),
                  ),
                ],

                // Doğrulama kodu gönderildiyse doğrulama alanlarını göster
                if (_isVerificationSent) ...[
                  TextField(
                    controller: _verificationCodeController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Doğrulama Kodu',
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
                  Text(
                    'Kalan süre: $_countdown saniye',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: _countdown > 0 ? Colors.black : Colors.red,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _countdown == 0
                              ? _sendVerificationCode
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromARGB(
                              255,
                              17,
                              48,
                              82,
                            ),
                            minimumSize: Size(double.infinity, 50.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                          ),
                          child: Text(
                            'Tekrar Gönder',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                      SizedBox(width: 16.w),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _verifyAndRegister,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromARGB(
                              255,
                              17,
                              48,
                              82,
                            ),
                            minimumSize: Size(double.infinity, 50.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                          ),
                          child: Text(
                            'Doğrula',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                SizedBox(height: 24.h),
                Text(
                  'Hesabın zaten var mı?',
                  style: TextStyle(fontSize: 14.sp),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const Loginpage(),
                      ),
                    );
                  },
                  child: Text(
                    'Giriş Yap',
                    style: TextStyle(fontSize: 12.sp, color: Colors.black),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
