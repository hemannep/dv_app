// lib/features/home/home_screen.dart - Fixed overflow issue
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/theme_provider.dart';
import '../../app/routes.dart';
import '../../shared/widgets/action_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              return IconButton(
                onPressed: () => themeProvider.toggleTheme(),
                icon: Icon(
                  themeProvider.isDarkMode
                      ? Icons.wb_sunny
                      : Icons.nightlight_round,
                ),
                tooltip: themeProvider.isDarkMode ? 'Light Mode' : 'Dark Mode',
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.mediumSpacing),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome section
            _buildWelcomeSection(context),

            const SizedBox(height: AppConstants.largeSpacing),

            // Quick stats card
            _buildStatsCard(context),

            const SizedBox(height: AppConstants.largeSpacing),

            // Main action cards
            Text(
              'Get Started',
              style: Theme.of(context).textTheme.headlineMedium,
            ),

            const SizedBox(height: AppConstants.mediumSpacing),

            _buildActionCards(context),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context),
    );
  }

  Widget _buildWelcomeSection(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.largeSpacing),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(AppConstants.largeRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome Back!',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppConstants.smallSpacing),
          Text(
            'Ready to start your DV Lottery application journey?',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.largeSpacing),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Theme.of(context).primaryColor),
                const SizedBox(width: AppConstants.smallSpacing),
                Text(
                  'DV Program Info',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: AppConstants.mediumSpacing),
            _buildStatRow(context, 'Application Period', 'Oct - Nov'),
            _buildStatRow(context, 'Results Available', 'Next May'),
            _buildStatRow(context, 'Total Visas', '55K annually'),
            const SizedBox(height: AppConstants.mediumSpacing),
            Container(
              padding: const EdgeInsets.all(AppConstants.mediumSpacing),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppConstants.mediumRadius),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.schedule,
                    color: Theme.of(context).primaryColor,
                    size: AppConstants.mediumIconSize,
                  ),
                  const SizedBox(width: AppConstants.mediumSpacing),
                  Expanded(
                    child: Text(
                      'Registration typically opens in October. Check official website for exact dates.',
                      style: Theme.of(context).textTheme.bodyMedium,
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

  // Fixed overflow issue by using Flexible and shorter text
  Widget _buildStatRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).primaryColor,
              ),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCards(BuildContext context) {
    return Column(
      children: [
        ActionCard(
          icon: Icons.description,
          title: 'Fill DV Form',
          subtitle: 'Access official application form',
          description: 'Complete your DV application on the official website',
          onTap: () => _launchDVForm(context),
          gradient: LinearGradient(colors: [Colors.blue, Colors.blue.shade700]),
        ),

        const SizedBox(height: AppConstants.mediumSpacing),

        ActionCard(
          icon: Icons.camera_alt,
          title: 'Photo Tool',
          subtitle: 'Create compliant photos',
          description: '600x600px format with compliance checks',
          onTap: () => AppRoutes.navigateToPhotoTool(context),
          gradient: LinearGradient(
            colors: [Colors.green, Colors.green.shade700],
          ),
        ),

        const SizedBox(height: AppConstants.mediumSpacing),

        ActionCard(
          icon: Icons.child_care,
          title: 'Baby Photo Mode',
          subtitle: 'Special mode for infants',
          description: 'Guidelines and tools for young children',
          onTap: () => AppRoutes.navigateToPhotoTool(context),
          gradient: LinearGradient(
            colors: [Colors.orange, Colors.orange.shade700],
          ),
        ),

        const SizedBox(height: AppConstants.mediumSpacing),

        ActionCard(
          icon: Icons.help_outline,
          title: 'Requirements & Tips',
          subtitle: 'Eligibility & guidelines',
          description: 'Important deadlines and requirements',
          onTap: () => _showRequirementsDialog(context),
          gradient: LinearGradient(
            colors: [Colors.purple, Colors.purple.shade700],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: 0,
      onTap: (index) {
        switch (index) {
          case 0:
            // Already on home
            break;
          case 1:
            AppRoutes.navigateToPhotoTool(context);
            break;
          case 2:
            AppRoutes.navigateToSettings(context);
            break;
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(
          icon: Icon(Icons.camera_alt),
          label: 'Photo Tool',
        ),
        BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
      ],
    );
  }

  Future<void> _launchDVForm(BuildContext context) async {
    try {
      final Uri url = Uri.parse(AppConstants.officialDVUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error opening URL: $e')));
      }
    }
  }

  void _showRequirementsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('DV Lottery Requirements'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildRequirementSection('Eligibility', [
                  'Born in eligible country',
                  'High school education or equivalent',
                  'Two years work experience in qualifying occupation',
                ]),
                const SizedBox(height: 16),
                _buildRequirementSection('Photo Requirements', [
                  '600x600 pixels JPEG format',
                  'Head size 50-69% of image',
                  'Neutral expression, eyes open',
                  'Plain white/off-white background',
                ]),
                const SizedBox(height: 16),
                _buildRequirementSection('Important Dates', [
                  'Registration: October - November',
                  'Results: May following year',
                  'Only one entry per person allowed',
                ]),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () => _launchDVForm(context),
              child: const Text('Visit Official Site'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRequirementSection(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(fontSize: 16)),
                Expanded(child: Text(item)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
