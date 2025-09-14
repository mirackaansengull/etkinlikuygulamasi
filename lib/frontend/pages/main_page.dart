import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class MainPage extends StatelessWidget {
  const MainPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.home,
              size: 80.w,
              color: const Color.fromARGB(255, 17, 48, 82),
            ),
            SizedBox(height: 20.h),
            Text(
              'Ana Sayfa',
              style: TextStyle(
                fontSize: 24.sp,
                fontWeight: FontWeight.bold,
                color: const Color.fromARGB(255, 17, 48, 82),
              ),
            ),
            SizedBox(height: 10.h),
            Text(
              'Hoş geldiniz! Etkinlikleri keşfetmeye başlayın.',
              style: TextStyle(fontSize: 16.sp, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
