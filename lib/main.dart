import 'package:etkinlikuygulamasi/frontend/loading/loading.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(
        360,
        690,
      ), // iPhone 8 boyutları gibi referans bir boyut
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            scaffoldBackgroundColor: Colors.white,
            primaryColor: Colors.black,
            fontFamily: 'Montserrat',
            chipTheme: const ChipThemeData(
              selectedColor: Colors.black,
              checkmarkColor: Colors.white,
            ),
            cardTheme: const CardThemeData(color: Colors.white, elevation: 2),
            colorScheme: ColorScheme.fromSwatch(
              primarySwatch: Colors.grey,
            ).copyWith(surface: Colors.white),
          ),

          debugShowCheckedModeBanner: false,
          home: LoadingPage(),
        );
      },
    );
  }
}
