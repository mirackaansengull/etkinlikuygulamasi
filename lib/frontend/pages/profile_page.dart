import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:etkinlikuygulamasi/utils/auth_utils.dart';
import 'package:etkinlikuygulamasi/frontend/login/loginpage.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String userName = 'Kullanıcı';
  String userEmail = 'email@example.com';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token != null) {
        // Backend'den kullanıcı bilgilerini al
        final response = await http.get(
          Uri.parse('https://etkinlikuygulamasi.onrender.com/user/profile'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        );

        if (response.statusCode == 200) {
          final userData = jsonDecode(response.body);
          setState(() {
            userName = '${userData['ad'] ?? ''} ${userData['soyad'] ?? ''}'
                .trim();
            userEmail = userData['email'] ?? 'email@example.com';
            isLoading = false;
          });
        } else {
          // Token geçersizse varsayılan değerleri kullan
          setState(() {
            isLoading = false;
          });
        }
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Kullanıcı bilgileri yüklenirken hata: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    await AuthUtils.logout();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const Loginpage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color.fromARGB(255, 17, 48, 82),
              ),
            )
          : Padding(
              padding: EdgeInsets.all(24.w),
              child: Column(
                children: [
                  SizedBox(height: 60.h),
                  // Profil Bilgileri
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(24.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 2,
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 50.r,
                          backgroundColor: const Color.fromARGB(
                            255,
                            17,
                            48,
                            82,
                          ),
                          child: Icon(
                            Icons.person,
                            size: 50.w,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 20.h),
                        Text(
                          userName,
                          style: TextStyle(
                            fontSize: 24.sp,
                            fontWeight: FontWeight.bold,
                            color: const Color.fromARGB(255, 17, 48, 82),
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          userEmail,
                          style: TextStyle(
                            fontSize: 16.sp,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 40.h),
                  // Menü Seçenekleri
                  _buildMenuOption(
                    icon: Icons.settings,
                    title: 'Ayarlar',
                    onTap: () {
                      // Ayarlar sayfasına git
                    },
                  ),
                  SizedBox(height: 16.h),
                  _buildMenuOption(
                    icon: Icons.help,
                    title: 'Yardım',
                    onTap: () {
                      // Yardım sayfasına git
                    },
                  ),
                  SizedBox(height: 16.h),
                  _buildMenuOption(
                    icon: Icons.info,
                    title: 'Hakkında',
                    onTap: () {
                      // Hakkında sayfasına git
                    },
                  ),
                  const Spacer(),
                  // Çıkış Butonu
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _logout,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        minimumSize: Size(double.infinity, 50.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout, color: Colors.white, size: 20.w),
                          SizedBox(width: 8.w),
                          Text(
                            'Çıkış Yap',
                            style: TextStyle(
                              fontSize: 16.sp,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 40.h),
                ],
              ),
            ),
    );
  }

  Widget _buildMenuOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10.r),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: const Color.fromARGB(255, 17, 48, 82),
          size: 24.w,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w500,
            color: const Color.fromARGB(255, 17, 48, 82),
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: Colors.grey[400],
          size: 16.w,
        ),
        onTap: onTap,
      ),
    );
  }
}
