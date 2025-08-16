import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';

class PhotoRequirementsCard extends StatelessWidget {
  final bool isBabyMode;

  const PhotoRequirementsCard({Key? key, this.isBabyMode = false})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final requirements = isBabyMode
        ? AppConstants.babyPhotoTips
        : AppConstants.photoRequirements;

    return Container(
      margin: const EdgeInsets.all(AppConstants.mediumSpacing),
      padding: const EdgeInsets.all(AppConstants.mediumSpacing),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.mediumRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                isBabyMode ? Icons.child_care : Icons.camera_alt,
                color: Theme.of(context).primaryColor,
                size: AppConstants.mediumIconSize,
              ),
              const SizedBox(width: AppConstants.smallSpacing),
              Text(
                isBabyMode ? 'Baby Photo Tips' : 'Photo Requirements',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),

          const SizedBox(height: AppConstants.mediumSpacing),

          if (isBabyMode)
            Container(
              padding: const EdgeInsets.all(AppConstants.mediumSpacing),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppConstants.smallRadius),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.orange,
                    size: AppConstants.mediumIconSize,
                  ),
                  const SizedBox(width: AppConstants.smallSpacing),
                  const Expanded(
                    child: Text(
                      'Special guidelines for infants and toddlers',
                      style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (isBabyMode) const SizedBox(height: AppConstants.mediumSpacing),

          ...requirements.map(
            (requirement) => _buildRequirementItem(context, requirement),
          ),

          if (!isBabyMode) ...[
            const SizedBox(height: AppConstants.mediumSpacing),
            _buildSizeInfo(context),
          ],
        ],
      ),
    );
  }

  Widget _buildRequirementItem(BuildContext context, String requirement) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppConstants.smallSpacing),
          Expanded(
            child: Text(
              requirement,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSizeInfo(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.mediumSpacing),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppConstants.smallRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Technical Specifications:',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: AppConstants.smallSpacing),
          _buildSpecRow(context, 'Dimensions', '600 x 600 pixels'),
          _buildSpecRow(context, 'Format', 'JPEG only'),
          _buildSpecRow(context, 'File Size', '10KB - 240KB'),
          _buildSpecRow(context, 'Color Mode', 'Color (24-bit)'),
        ],
      ),
    );
  }

  Widget _buildSpecRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}
