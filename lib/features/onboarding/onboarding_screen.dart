// lib/features/onboarding/onboarding_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../app/routes.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  int _currentPage = 0;
  late AnimationController _contentAnimationController;
  late AnimationController _buttonAnimationController;
  late Animation<double> _contentFadeAnimation;
  late Animation<Offset> _contentSlideAnimation;
  late Animation<double> _buttonScaleAnimation;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: 'Welcome to DV App',
      subtitle: 'Your DV Lottery Companion',
      description:
          'Simplify your Diversity Visa application process with our comprehensive tools.',
      icon: Icons.public,
      primaryColor: const Color(0xFF2E7D32),
      secondaryColor: const Color(0xFF4CAF50),
      backgroundColor: const Color(0xFFE8F5E9),
      features: ['Smart Forms', 'Photo Tool', 'Validation', 'Guidance'],
    ),
    OnboardingPage(
      title: 'Perfect DV Photos',
      subtitle: 'Get It Right First Time',
      description:
          'AI-powered photo tool ensures your photos meet all DV requirements.',
      icon: Icons.camera_alt,
      primaryColor: const Color(0xFF1565C0),
      secondaryColor: const Color(0xFF2196F3),
      backgroundColor: const Color(0xFFE3F2FD),
      features: ['Auto-crop', 'Background', 'Baby Mode', 'Validation'],
    ),
    OnboardingPage(
      title: 'Start Your Journey',
      subtitle: 'Apply with Confidence',
      description: 'Complete your DV application with step-by-step guidance.',
      icon: Icons.rocket_launch,
      primaryColor: const Color(0xFF6A1B9A),
      secondaryColor: const Color(0xFF9C27B0),
      backgroundColor: const Color(0xFFF3E5F5),
      features: ['Step Guide', 'Prevention', 'Reminders', 'Support'],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _setupAnimations();

    // Add listener to PageController after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _pageController.addListener(_onPageControllerUpdate);
      }
    });
  }

  void _setupAnimations() {
    _contentAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _buttonAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _contentFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _contentAnimationController,
        curve: Curves.easeIn,
      ),
    );

    _contentSlideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _contentAnimationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _buttonScaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _buttonAnimationController,
        curve: Curves.elasticOut,
      ),
    );

    _contentAnimationController.forward();
    _buttonAnimationController.forward();
  }

  void _onPageControllerUpdate() {
    if (_pageController.hasClients && _pageController.page != null) {
      final newPage = _pageController.page!.round();
      if (newPage != _currentPage) {
        setState(() {
          _currentPage = newPage;
        });
        _contentAnimationController.reset();
        _contentAnimationController.forward();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;
    final isSmallScreen = size.height < 700;
    final page = _pages[_currentPage];

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [page.backgroundColor, Colors.white],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: isSmallScreen ? 8 : 16,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 12 : 16,
                        vertical: isSmallScreen ? 6 : 8,
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
                          fontSize: isSmallScreen ? 12 : 14,
                        ),
                      ),
                    ),
                    if (_currentPage < _pages.length - 1)
                      TextButton(
                        onPressed: _skipOnboarding,
                        child: Text(
                          'Skip',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 14 : 16,
                            fontWeight: FontWeight.w600,
                            color: page.primaryColor,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // PageView
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                    _contentAnimationController.reset();
                    _contentAnimationController.forward();
                  },
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    return _buildPage(_pages[index], isSmallScreen);
                  },
                ),
              ),

              // Bottom Controls
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Page indicators
                    SizedBox(
                      height: 8,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _pages.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            height: 8,
                            width: _currentPage == index ? 24 : 8,
                            decoration: BoxDecoration(
                              color: _currentPage == index
                                  ? page.primaryColor
                                  : page.primaryColor.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: isSmallScreen ? 16 : 24),

                    // Action button
                    ScaleTransition(
                      scale: _buttonScaleAnimation,
                      child: ElevatedButton(
                        onPressed: _handleButtonPress,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: page.primaryColor,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 32 : 48,
                            vertical: isSmallScreen ? 12 : 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _currentPage == _pages.length - 1
                                  ? 'Get Started'
                                  : 'Continue',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 16 : 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.arrow_forward,
                              size: isSmallScreen ? 18 : 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingPage page, bool isSmallScreen) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: isSmallScreen ? 20 : 40),

          // Icon
          FadeTransition(
            opacity: _contentFadeAnimation,
            child: SlideTransition(
              position: _contentSlideAnimation,
              child: Container(
                width: isSmallScreen ? 80 : 120,
                height: isSmallScreen ? 80 : 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
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
                child: Icon(
                  page.icon,
                  size: isSmallScreen ? 40 : 60,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          SizedBox(height: isSmallScreen ? 20 : 40),

          // Title
          FadeTransition(
            opacity: _contentFadeAnimation,
            child: Text(
              page.title,
              style: TextStyle(
                fontSize: isSmallScreen ? 24 : 32,
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
                fontSize: isSmallScreen ? 16 : 18,
                color: page.primaryColor,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          SizedBox(height: isSmallScreen ? 16 : 24),

          // Description
          FadeTransition(
            opacity: _contentFadeAnimation,
            child: Text(
              page.description,
              style: TextStyle(
                fontSize: isSmallScreen ? 14 : 15,
                color: Colors.grey[600],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          SizedBox(height: isSmallScreen ? 20 : 40),

          // Features
          FadeTransition(
            opacity: _contentFadeAnimation,
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: page.features.map((feature) {
                return Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 12 : 16,
                    vertical: isSmallScreen ? 6 : 8,
                  ),
                  decoration: BoxDecoration(
                    color: page.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: page.primaryColor.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    feature,
                    style: TextStyle(
                      color: page.primaryColor,
                      fontSize: isSmallScreen ? 12 : 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          SizedBox(height: isSmallScreen ? 20 : 40),
        ],
      ),
    );
  }

  void _handleButtonPress() {
    HapticFeedback.lightImpact();
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _skipOnboarding() {
    HapticFeedback.lightImpact();
    _completeOnboarding();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    if (mounted) {
      AppRoutes.navigateToHome(context);
    }
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageControllerUpdate);
    _pageController.dispose();
    _contentAnimationController.dispose();
    _buttonAnimationController.dispose();
    super.dispose();
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
  final List<String> features;

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
