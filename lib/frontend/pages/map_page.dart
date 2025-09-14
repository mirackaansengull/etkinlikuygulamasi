import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class MapPage extends StatelessWidget {
  const MapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.map,
              size: 80.w,
              color: const Color.fromARGB(255, 17, 48, 82),
            ),
            SizedBox(height: 20.h),
            Text(
              'Harita Sayfası',
              style: TextStyle(
                fontSize: 24.sp,
                fontWeight: FontWeight.bold,
                color: const Color.fromARGB(255, 17, 48, 82),
              ),
            ),
            SizedBox(height: 10.h),
            Text(
              'Yakınınızdaki etkinlikleri harita üzerinde görün.',
              style: TextStyle(fontSize: 16.sp, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
