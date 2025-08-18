// lib/app/app.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/theme_provider.dart';
import '../core/theme/app_theme.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/photo/photo_tool_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DVLotteryApp extends StatelessWidget {
  const DVLotteryApp({super.key});

  Future<bool> _checkFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    final isFirstTime = prefs.getBool('first_time') ?? true;
    if (isFirstTime) {
      await prefs.setBool('first_time', false);
    }
    return isFirstTime;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'DV Photo Tool',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          home: FutureBuilder<bool>(
            future: _checkFirstTime(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.data == true) {
                return const OnboardingScreen();
              } else {
                return const PhotoToolScreen();
              }
            },
          ),
        );
      },
    );
  }
}
