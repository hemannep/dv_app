import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';

class ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String description;
  final VoidCallback onTap;
  final Gradient? gradient;
  final Color? backgroundColor;

  const ActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.onTap,
    this.gradient,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.largeRadius),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.largeRadius),
        child: Container(
          padding: const EdgeInsets.all(AppConstants.largeSpacing),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppConstants.largeRadius),
          ),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: gradient,
                  color: backgroundColor ?? Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(
                    AppConstants.mediumRadius,
                  ),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: AppConstants.largeIconSize,
                ),
              ),

              const SizedBox(width: AppConstants.mediumSpacing),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),

              // Arrow icon
              Icon(
                Icons.arrow_forward_ios,
                color: Theme.of(context).textTheme.bodySmall?.color,
                size: AppConstants.mediumIconSize,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
