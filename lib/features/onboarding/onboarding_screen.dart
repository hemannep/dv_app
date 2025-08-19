// lib/features/onboarding/onboarding_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/services/storage_service.dart';
import '../../app/routes.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Animation controllers
  late AnimationController _backgroundController;
  late AnimationController _contentController;
  late AnimationController _buttonController;
  late AnimationController _indicatorController;

  // Animations
  late Animation<double> _backgroundAnimation;
  late Animation<double> _contentFadeAnimation;
  late Animation<Offset> _contentSlideAnimation;
  late Animation<double> _buttonScaleAnimation;
  late Animation<double> _indicatorAnimation;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: 'Welcome to Your\nDV Journey',
      subtitle: 'Complete Guide to Success',
      description:
          'The Diversity Visa Program provides 55,000 immigrant visas annually to people from countries with low US immigration rates.',
      icon: Icons.public,
      primaryColor: const Color(0xFF4CAF50),
      secondaryColor: const Color(0xFF81C784),
      backgroundColor: const Color(0xFFF1F8E9),
      features: [
        FeatureItem(
          icon: Icons.check_circle,
          title: 'Step-by-step guidance',
          color: Colors.green,
        ),
        FeatureItem(
          icon: Icons.camera_alt,
          title: 'Photo compliance checker',
          color: Colors.blue,
        ),
        FeatureItem(
          icon: Icons.notifications,
          title: 'Deadline reminders',
          color: Colors.orange,
        ),
        FeatureItem(
          icon: Icons.lock,
          title: 'Private & secure',
          color: Colors.purple,
        ),
      ],
    ),
    OnboardingPage(
      title: 'Perfect DV Photos\nMade Easy',
      subtitle: 'Professional Results Every Time',
      description:
          'Our advanced photo tool ensures your photos meet all strict DV requirements with real-time guidance.',
      icon: Icons.camera_alt_rounded,
      primaryColor: const Color(0xFF2196F3),
      secondaryColor: const Color(0xFF64B5F6),
      backgroundColor: const Color(0xFFE3F2FD),
      features: [
        FeatureItem(
          icon: Icons.aspect_ratio,
          title: '600x600 pixel format',
          color: Colors.blue,
        ),
        FeatureItem(
          icon: Icons.face,
          title: 'Face positioning guide',
          color: Colors.green,
        ),
        FeatureItem(
          icon: Icons.child_care,
          title: 'Baby/toddler mode',
          color: Colors.pink,
        ),
        FeatureItem(
          icon: Icons.verified,
          title: 'Instant verification',
          color: Colors.teal,
        ),
      ],
    ),
    OnboardingPage(
      title: 'Key Requirements\nfor Success',
      subtitle: 'Everything You Need to Know',
      description:
          'Understanding DV requirements is crucial. We guide you through every step of the application process.',
      icon: Icons.fact_check_rounded,
      primaryColor: const Color(0xFFFF9800),
      secondaryColor: const Color(0xFFFFB74D),
      backgroundColor: const Color(0xFFFFF3E0),
      features: [
        FeatureItem(
          icon: Icons.calendar_today,
          title: 'October-November period',
          color: Colors.orange,
        ),
        FeatureItem(
          icon: Icons.public,
          title: 'Eligible countries only',
          color: Colors.blue,
        ),
        FeatureItem(
          icon: Icons.school,
          title: 'Education requirements',
          color: Colors.green,
        ),
        FeatureItem(
          icon: Icons.warning,
          title: 'One entry per person',
          color: Colors.red,
        ),
      ],
    ),
    OnboardingPage(
      title: 'Your Privacy\nMatters Most',
      subtitle: 'Secure & Private by Design',
      description:
          'No registration, no data collection. Everything stays on your device. Your privacy is our priority.',
      icon: Icons.security_rounded,
      primaryColor: const Color(0xFF9C27B0),
      secondaryColor: const Color(0xFFBA68C8),
      backgroundColor: const Color(0xFFF3E5F5),
      features: [
        FeatureItem(
          icon: Icons.phone_android,
          title: 'Local processing only',
          color: Colors.purple,
        ),
        FeatureItem(
          icon: Icons.no_accounts,
          title: 'No registration needed',
          color: Colors.indigo,
        ),
        FeatureItem(
          icon: Icons.lock,
          title: 'Your data stays yours',
          color: Colors.green,
        ),
        FeatureItem(
          icon: Icons.verified_user,
          title: 'Official links only',
          color: Colors.blue,
        ),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _backgroundController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _contentController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _buttonController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _indicatorController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _backgroundAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _backgroundController, curve: Curves.easeInOut),
    );

    _contentFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeIn),
    );

    _contentSlideAnimation =
        Tween<Offset>(begin: const Offset(0.3, 0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _contentController,
            curve: Curves.easeOutCubic,
          ),
        );

    _buttonScaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _buttonController, curve: Curves.elasticOut),
    );

    _indicatorAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _indicatorController, curve: Curves.easeInOut),
    );

    // Start initial animations
    _backgroundController.forward();
    _contentController.forward();
    _buttonController.forward();
    _indicatorController.forward();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });

    // Reset and play animations
    _contentController.reset();
    _contentController.forward();
    _buttonController.reset();
    _buttonController.forward();

    // Haptic feedback
    HapticFeedback.selectionClick();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _skipOnboarding() {
    HapticFeedback.mediumImpact();
    _completeOnboarding();
  }

  Future<void> _completeOnboarding() async {
    await StorageService.setOnboardingCompleted(true);
    if (mounted) {
      AppRoutes.navigateToHome(context);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _backgroundController.dispose();
    _contentController.dispose();
    _buttonController.dispose();
    _indicatorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final page = _pages[_currentPage];

    return Theme(
      data: ThemeData(brightness: Brightness.light, useMaterial3: true),
      child: Scaffold(
        body: Stack(
          children: [
            // Animated background
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [page.backgroundColor, Colors.white],
                ),
              ),
            ),

            // Decorative circles
            Positioned(
              top: -100,
              right: -100,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: page.primaryColor.withOpacity(0.1),
                ),
              ),
            ),
            Positioned(
              bottom: -150,
              left: -150,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: page.secondaryColor.withOpacity(0.08),
                ),
              ),
            ),

            // Main content
            SafeArea(
              child: Column(
                children: [
                  // Header with skip button
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Page counter
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: page.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_currentPage + 1} / ${_pages.length}',
                            style: TextStyle(
                              color: page.primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        // Skip button
                        if (_currentPage < _pages.length - 1)
                          TextButton(
                            onPressed: _skipOnboarding,
                            style: TextButton.styleFrom(
                              foregroundColor: page.primaryColor,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                            ),
                            child: const Text(
                              'Skip',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Page view
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: _onPageChanged,
                      itemCount: _pages.length,
                      itemBuilder: (context, index) {
                        return _buildPage(_pages[index]);
                      },
                    ),
                  ),

                  // Bottom section
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(30),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 20,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Page indicators
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            _pages.length,
                            (index) => _buildPageIndicator(index),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Action button
                        ScaleTransition(
                          scale: _buttonScaleAnimation,
                          child: SizedBox(
                            width: double.infinity,
                            height: 60,
                            child: ElevatedButton(
                              onPressed: _nextPage,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: page.primaryColor,
                                foregroundColor: Colors.white,
                                elevation: 8,
                                shadowColor: page.primaryColor.withOpacity(0.4),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _currentPage == _pages.length - 1
                                        ? 'Get Started'
                                        : 'Continue',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Icon(
                                    _currentPage == _pages.length - 1
                                        ? Icons.arrow_forward
                                        : Icons.arrow_forward_ios,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingPage page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const Spacer(flex: 1),

          // Icon with gradient background
          FadeTransition(
            opacity: _contentFadeAnimation,
            child: SlideTransition(
              position: _contentSlideAnimation,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [page.primaryColor, page.secondaryColor],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: page.primaryColor.withOpacity(0.4),
                      blurRadius: 30,
                      offset: const Offset(0, 15),
                    ),
                  ],
                ),
                child: Icon(page.icon, size: 60, color: Colors.white),
              ),
            ),
          ),

          const SizedBox(height: 40),

          // Title
          FadeTransition(
            opacity: _contentFadeAnimation,
            child: Text(
              page.title,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.grey[900],
                height: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 12),

          // Subtitle
          FadeTransition(
            opacity: _contentFadeAnimation,
            child: Text(
              page.subtitle,
              style: TextStyle(
                fontSize: 18,
                color: page.primaryColor,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 24),

          // Description
          FadeTransition(
            opacity: _contentFadeAnimation,
            child: Text(
              page.description,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[600],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 40),

          // Features grid
          FadeTransition(
            opacity: _contentFadeAnimation,
            child: SizedBox(
              height: 180,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.8,
                ),
                itemCount: page.features.length,
                itemBuilder: (context, index) {
                  final feature = page.features[index];
                  return _buildFeatureCard(feature);
                },
              ),
            ),
          ),

          const Spacer(flex: 2),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(FeatureItem feature) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: feature.color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: feature.color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(feature.icon, color: feature.color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            feature.title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator(int index) {
    final isActive = _currentPage == index;
    final page = _pages[_currentPage];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 6),
      width: isActive ? 32 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive ? page.primaryColor : Colors.grey[300],
        borderRadius: BorderRadius.circular(4),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: page.primaryColor.withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : [],
      ),
    );
  }
}

class OnboardingPage {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color primaryColor;
  final Color secondaryColor;
  final Color backgroundColor;
  final List<FeatureItem> features;

  OnboardingPage({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.primaryColor,
    required this.secondaryColor,
    required this.backgroundColor,
    required this.features,
  });
}

class FeatureItem {
  final IconData icon;
  final String title;
  final Color color;

  FeatureItem({required this.icon, required this.title, required this.color});
}
