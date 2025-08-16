import 'package:flutter/material.dart';
import '../features/splash/splash_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/home/home_screen.dart';
import '../features/photo/photo_tool_screen.dart';
import '../features/settings/settings_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String home = '/home';
  static const String photoTool = '/photo-tool';
  static const String settings = '/settings';

  static Map<String, WidgetBuilder> routes = {
    splash: (context) => const SplashScreen(),
    onboarding: (context) => const OnboardingScreen(),
    home: (context) => const HomeScreen(),
    photoTool: (context) => const PhotoToolScreen(),
    settings: (context) => const SettingsScreen(),
  };

  static void navigateToHome(BuildContext context) {
    Navigator.of(context).pushNamedAndRemoveUntil(home, (route) => false);
  }

  static void navigateToOnboarding(BuildContext context) {
    Navigator.of(context).pushReplacementNamed(onboarding);
  }

  static void navigateToPhotoTool(BuildContext context) {
    Navigator.of(context).pushNamed(photoTool);
  }

  static void navigateToSettings(BuildContext context) {
    Navigator.of(context).pushNamed(settings);
  }
}
