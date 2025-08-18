import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/services/storage_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _selectedLanguage = 'English';

  final List<Map<String, String>> _languages = [
    {'code': 'en', 'name': 'English', 'flag': '🇺🇸'},
    {'code': 'es', 'name': 'Español', 'flag': '🇪🇸'},
    {'code': 'fr', 'name': 'Français', 'flag': '🇫🇷'},
    {'code': 'ar', 'name': 'العربية', 'flag': '🇸🇦'},
    {'code': 'zh', 'name': '中文', 'flag': '🇨🇳'},
    {'code': 'hi', 'name': 'हिन्दी', 'flag': '🇮🇳'},
  ];

  @override
  void initState() {
    super.initState();
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final languageCode = StorageService.getLanguage();
    final language = _languages.firstWhere(
      (lang) => lang['code'] == languageCode,
      orElse: () => _languages.first,
    );
    setState(() {
      _selectedLanguage = language['name']!;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(AppConstants.mediumSpacing),
        children: [
          _buildSection(context, 'Appearance', [_buildThemeSettings(context)]),

          const SizedBox(height: AppConstants.largeSpacing),

          _buildSection(context, 'Language', [_buildLanguageSettings(context)]),

          const SizedBox(height: AppConstants.largeSpacing),

          _buildSection(context, 'Information', [
            _buildListTile(
              context,
              icon: Icons.info_outline,
              title: 'About DV Program',
              subtitle: 'Learn about the Diversity Visa program',
              onTap: () => _showAboutDialog(context),
            ),
            _buildListTile(
              context,
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy Policy',
              subtitle: 'Your data privacy information',
              onTap: () => _launchUrl(AppConstants.privacyPolicyUrl),
            ),
            _buildListTile(
              context,
              icon: Icons.help_outline,
              title: 'Help & FAQ',
              subtitle: 'Frequently asked questions',
              onTap: () => _showHelpDialog(context),
            ),
          ]),

          const SizedBox(height: AppConstants.largeSpacing),

          _buildSection(context, 'Support', [
            _buildListTile(
              context,
              icon: Icons.star_outline,
              title: 'Rate This App',
              subtitle: 'Share your experience',
              onTap: () => _showRatingDialog(context),
            ),
            _buildListTile(
              context,
              icon: Icons.feedback_outlined,
              title: 'Send Feedback',
              subtitle: 'Help us improve',
              onTap: () => _showFeedbackDialog(context),
            ),
          ]),

          const SizedBox(height: AppConstants.largeSpacing),

          _buildAppInfo(context),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    List<Widget> children,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.mediumSpacing,
            vertical: AppConstants.smallSpacing,
          ),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildThemeSettings(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Column(
          children: [
            _buildListTile(
              context,
              icon: Icons.light_mode_outlined,
              title: 'Light Theme',
              trailing: Radio<ThemeMode>(
                value: ThemeMode.light,
                groupValue: themeProvider.themeMode,
                onChanged: (value) => themeProvider.setThemeMode(value!),
              ),
              onTap: () => themeProvider.setThemeMode(ThemeMode.light),
            ),
            const Divider(height: 1),
            _buildListTile(
              context,
              icon: Icons.dark_mode_outlined,
              title: 'Dark Theme',
              trailing: Radio<ThemeMode>(
                value: ThemeMode.dark,
                groupValue: themeProvider.themeMode,
                onChanged: (value) => themeProvider.setThemeMode(value!),
              ),
              onTap: () => themeProvider.setThemeMode(ThemeMode.dark),
            ),
            const Divider(height: 1),
            _buildListTile(
              context,
              icon: Icons.settings_suggest_outlined,
              title: 'System Default',
              trailing: Radio<ThemeMode>(
                value: ThemeMode.system,
                groupValue: themeProvider.themeMode,
                onChanged: (value) => themeProvider.setThemeMode(value!),
              ),
              onTap: () => themeProvider.setThemeMode(ThemeMode.system),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLanguageSettings(BuildContext context) {
    return _buildListTile(
      context,
      icon: Icons.language,
      title: 'Language',
      subtitle: _selectedLanguage,
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () => _showLanguageDialog(context),
    );
  }

  Widget _buildListTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).primaryColor),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: trailing,
      onTap: onTap,
    );
  }

  Widget _buildAppInfo(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.largeSpacing),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppConstants.largeRadius),
              ),
              child: Icon(
                Icons.description,
                size: 40,
                color: Theme.of(context).primaryColor,
              ),
            ),

            const SizedBox(height: AppConstants.mediumSpacing),

            Text(
              AppConstants.appName,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: AppConstants.smallSpacing),

            Text(
              'Version ${AppConstants.appVersion}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),

            const SizedBox(height: AppConstants.smallSpacing),

            Text(
              AppConstants.appDescription,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _languages.map((language) {
            return ListTile(
              leading: Text(
                language['flag']!,
                style: const TextStyle(fontSize: 24),
              ),
              title: Text(language['name']!),
              trailing: _selectedLanguage == language['name']
                  ? Icon(Icons.check, color: Theme.of(context).primaryColor)
                  : null,
              onTap: () async {
                await StorageService.setLanguage(language['code']!);
                setState(() {
                  _selectedLanguage = language['name']!;
                });
                Navigator.of(context).pop();
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About DV Program'),
        content: SingleChildScrollView(
          child: Text(AppConstants.dvProgramDescription),
        ),
        actions: [
          TextButton(
            onPressed: () => _launchUrl(AppConstants.officialDVUrl),
            child: const Text('Official Website'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help & FAQ'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Q: When can I apply for the DV lottery?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('A: Registration typically opens in October each year.'),
              SizedBox(height: 16),
              Text(
                'Q: Is this app official?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'A: No, this is a helper app. Always submit through the official website.',
              ),
              SizedBox(height: 16),
              Text(
                'Q: Does this app store my data?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('A: No, all data stays on your device for privacy.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showRatingDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rate This App'),
        content: const Text(
          'Thank you for using DV Lottery Helper! Your feedback helps us improve.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Maybe Later'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Implement app store rating
              _showSuccessSnackBar('Thank you for your feedback!');
            },
            child: const Text('Rate Now'),
          ),
        ],
      ),
    );
  }

  void _showFeedbackDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Feedback'),
        content: const TextField(
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Share your thoughts or report issues...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showSuccessSnackBar('Feedback sent successfully!');
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showErrorSnackBar('Could not open URL');
      }
    } catch (e) {
      _showErrorSnackBar('Error opening URL: $e');
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }
}
