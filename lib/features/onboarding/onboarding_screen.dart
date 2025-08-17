import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/storage_service.dart';
import '../../app/routes.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: 'Welcome to Your DV Journey',
      subtitle: 'Complete Guide to US Diversity Visa Application',
      icon: Icons.public,
      primaryColor: const Color(0xFF4CAF50),
      secondaryColor: const Color(0xFF81C784),
      backgroundColor: const Color(0xFFF1F8E9),
      description:
          'The Diversity Visa Program provides 55,000 immigrant visas annually to people from countries with low US immigration rates.',
      features: [
        '✓ Step-by-step application guidance',
        '✓ Photo compliance checker',
        '✓ Deadline reminders & tips',
        '✓ All data stays private on your device',
      ],
    ),
    OnboardingPage(
      title: 'Perfect DV Photos Made Easy',
      subtitle: 'Professional Photos with Built-in Compliance',
      icon: Icons.camera_alt_rounded,
      primaryColor: const Color(0xFF2196F3),
      secondaryColor: const Color(0xFF64B5F6),
      backgroundColor: const Color(0xFFE3F2FD),
      description:
          'DV photos must meet strict requirements. Our tool ensures your photos are compliant every time.',
      features: [
        '📐 Exact 600x600 pixel format',
        '🎯 Real-time face positioning guide',
        '👶 Special baby/toddler mode',
        '✅ Instant compliance verification',
      ],
    ),
    OnboardingPage(
      title: 'Key DV Requirements',
      subtitle: 'Essential Information for Success',
      icon: Icons.fact_check_rounded,
      primaryColor: const Color(0xFFFF9800),
      secondaryColor: const Color(0xFFFFB74D),
      backgroundColor: const Color(0xFFFFF3E0),
      description:
          'Understanding DV requirements is crucial for a successful application.',
      features: [
        '📅 Application period: October-November',
        '🌍 Must be from eligible country',
        '🎓 High school education OR work experience',
        '⚠️ Only ONE entry per person allowed',
      ],
    ),
    OnboardingPage(
      title: 'Privacy & Security First',
      subtitle: 'Your Data Stays Safe With You',
      icon: Icons.security_rounded,
      primaryColor: const Color(0xFF9C27B0),
      secondaryColor: const Color(0xFFBA68C8),
      backgroundColor: const Color(0xFFF3E5F5),
      description:
          'We prioritize your privacy. No registration, no data collection, everything stays on your device.',
      features: [
        '🔐 No personal data collection',
        '📱 All processing done locally',
        '🚫 No registration required',
        '🔗 Direct links to official DV website',
      ],
    ),
  ];

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: AppConstants.animationDuration,
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _skipOnboarding() {
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      // Force light theme for onboarding
      data: ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        fontFamily: 'Poppins',
      ),
      child: Scaffold(
        backgroundColor: _pages[_currentPage].backgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              // Header with skip button
              Padding(
                padding: const EdgeInsets.all(AppConstants.mediumSpacing),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Progress indicator
                    Text(
                      '${_currentPage + 1} of ${_pages.length}',
                      style: TextStyle(
                        color: _pages[_currentPage].primaryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    // Skip button
                    TextButton(
                      onPressed: _skipOnboarding,
                      style: TextButton.styleFrom(
                        foregroundColor: _pages[_currentPage].primaryColor,
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
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    return _buildPage(_pages[index]);
                  },
                ),
              ),

              // Bottom section with indicators and button
              Container(
                padding: const EdgeInsets.all(AppConstants.largeSpacing),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AppConstants.extraLargeRadius),
                    topRight: Radius.circular(AppConstants.extraLargeRadius),
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Page indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _pages.length,
                        (index) => _buildPageIndicator(index),
                      ),
                    ),

                    const SizedBox(height: AppConstants.largeSpacing),

                    // Next/Get Started button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _nextPage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _pages[_currentPage].primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppConstants.mediumRadius,
                            ),
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
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              _currentPage == _pages.length - 1
                                  ? Icons.check_rounded
                                  : Icons.arrow_forward_rounded,
                              size: 20,
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

  Widget _buildPage(OnboardingPage page) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.largeSpacing),
      child: Column(
        children: [
          const SizedBox(height: AppConstants.mediumSpacing),

          // Icon container with gradient background
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [page.primaryColor, page.secondaryColor],
              ),
              borderRadius: BorderRadius.circular(
                AppConstants.extraLargeRadius,
              ),
              boxShadow: [
                BoxShadow(
                  color: page.primaryColor.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(page.icon, size: 60, color: Colors.white),
          ),

          const SizedBox(height: AppConstants.extraLargeSpacing),

          // Title
          Text(
            page.title,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: page.primaryColor,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: AppConstants.mediumSpacing),

          // Subtitle
          Text(
            page.subtitle,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: AppConstants.largeSpacing),

          // Description
          Container(
            padding: const EdgeInsets.all(AppConstants.largeSpacing),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppConstants.largeRadius),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  page.description,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[800],
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: AppConstants.largeSpacing),

                // Features list
                ...page.features.map(
                  (feature) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: page.primaryColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: AppConstants.mediumSpacing),
                        Expanded(
                          child: Text(
                            feature,
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppConstants.largeSpacing),
        ],
      ),
    );
  }

  Widget _buildPageIndicator(int index) {
    final isActive = _currentPage == index;
    final page = _pages[_currentPage];

    return AnimatedContainer(
      duration: AppConstants.animationDuration,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive
            ? page.primaryColor
            : page.primaryColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class OnboardingPage {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color primaryColor;
  final Color secondaryColor;
  final Color backgroundColor;
  final String description;
  final List<String> features;

  OnboardingPage({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.primaryColor,
    required this.secondaryColor,
    required this.backgroundColor,
    required this.description,
    required this.features,
  });
}
