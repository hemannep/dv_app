import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';

class PhotoRequirementsCard extends StatelessWidget {
  final bool isBabyMode;
  final bool isCompact;

  const PhotoRequirementsCard({
    Key? key,
    this.isBabyMode = false,
    this.isCompact = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final requirements = isBabyMode
        ? AppConstants.babyPhotoTips
        : AppConstants.photoRequirements;

    return Container(
      margin: EdgeInsets.all(
        isCompact ? AppConstants.smallSpacing : AppConstants.mediumSpacing,
      ),
      padding: EdgeInsets.all(
        isCompact ? AppConstants.smallSpacing : AppConstants.mediumSpacing,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
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
          // Header with icon and title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isBabyMode
                      ? Colors.orange.withOpacity(0.1)
                      : Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isBabyMode ? Icons.child_care : Icons.camera_alt,
                  color: isBabyMode
                      ? Colors.orange
                      : Theme.of(context).primaryColor,
                  size: AppConstants.mediumIconSize,
                ),
              ),
              const SizedBox(width: AppConstants.mediumSpacing),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isBabyMode
                          ? 'Baby Photo Requirements'
                          : 'DV Photo Requirements',
                      style: TextStyle(
                        fontSize: isCompact ? 14 : 16,
                        fontWeight: FontWeight.bold,
                        color: isBabyMode
                            ? Colors.orange
                            : Theme.of(context).primaryColor,
                      ),
                    ),
                    if (!isCompact)
                      Text(
                        'Follow these guidelines for compliance',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                  ],
                ),
              ),
            ],
          ),

          if (!isCompact) ...[
            const SizedBox(height: AppConstants.mediumSpacing),

            // Baby mode special notice
            if (isBabyMode)
              Container(
                padding: const EdgeInsets.all(AppConstants.mediumSpacing),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppConstants.smallRadius),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
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
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            if (isBabyMode) const SizedBox(height: AppConstants.mediumSpacing),

            // Requirements list
            ...requirements
                .take(isCompact ? 3 : requirements.length)
                .map(
                  (requirement) => _buildRequirementItem(context, requirement),
                ),

            if (isCompact && requirements.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '+${requirements.length - 3} more requirements',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),

            // Technical specifications for non-baby mode
            if (!isBabyMode && !isCompact) ...[
              const SizedBox(height: AppConstants.mediumSpacing),
              _buildTechnicalSpecs(context),
            ],
          ],

          // Compact mode - show only essential info
          if (isCompact) ...[
            const SizedBox(height: AppConstants.smallSpacing),
            _buildCompactInfo(context),
          ],
        ],
      ),
    );
  }

  Widget _buildRequirementItem(BuildContext context, String requirement) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isBabyMode
                  ? Colors.orange
                  : Theme.of(context).primaryColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppConstants.smallSpacing),
          Expanded(
            child: Text(
              requirement,
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTechnicalSpecs(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.mediumSpacing),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(AppConstants.smallRadius),
        border: Border.all(
          color: Theme.of(context).primaryColor.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.settings,
                color: Theme.of(context).primaryColor,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'Technical Specifications',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.smallSpacing),
          _buildSpecRow(context, 'Dimensions', '600 x 600 pixels'),
          _buildSpecRow(context, 'Format', 'JPEG (.jpg)'),
          _buildSpecRow(context, 'File Size', '10KB - 240KB'),
          _buildSpecRow(context, 'Color Mode', '24-bit color'),
          _buildSpecRow(context, 'Head Height', '50% - 69% of image'),
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
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black87),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactInfo(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.photo_size_select_large,
                size: 16,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(width: 8),
              const Text(
                '600x600px • JPEG • 10-240KB',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.face, size: 16, color: Theme.of(context).primaryColor),
              const SizedBox(width: 8),
              Text(
                isBabyMode
                    ? 'Baby: White background, calm pose'
                    : 'Head 50-69% • Plain background • No glasses',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Enhanced Photo Compliance Indicator
class PhotoComplianceIndicator extends StatelessWidget {
  final double complianceScore;
  final List<String> errors;
  final bool isValid;

  const PhotoComplianceIndicator({
    Key? key,
    required this.complianceScore,
    required this.errors,
    required this.isValid,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = _getScoreColor(complianceScore);
    final status = _getStatus(complianceScore, isValid);

    return Container(
      padding: const EdgeInsets.all(AppConstants.mediumSpacing),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppConstants.mediumRadius),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Score header
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Stack(
                  children: [
                    Center(
                      child: Text(
                        '${complianceScore.toInt()}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    CircularProgressIndicator(
                      value: complianceScore / 100,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.white,
                      ),
                      strokeWidth: 3,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppConstants.mediumSpacing),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: color,
                      ),
                    ),
                    Text(
                      _getDescription(complianceScore, isValid),
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Icon(
                isValid ? Icons.check_circle : Icons.warning,
                color: color,
                size: AppConstants.largeIconSize,
              ),
            ],
          ),

          // Error details if any
          if (errors.isNotEmpty) ...[
            const SizedBox(height: AppConstants.mediumSpacing),
            Text(
              'Issues to fix:',
              style: TextStyle(fontWeight: FontWeight.w600, color: color),
            ),
            const SizedBox(height: AppConstants.smallSpacing),
            ...errors
                .take(3)
                .map(
                  (error) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, size: 16, color: color),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            error,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            if (errors.length > 3)
              Text(
                '+${errors.length - 3} more issues',
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ],
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  String _getStatus(double score, bool isValid) {
    if (isValid && score >= 80) return 'Excellent';
    if (score >= 80) return 'Very Good';
    if (score >= 60) return 'Good';
    if (score >= 40) return 'Needs Work';
    return 'Poor Quality';
  }

  String _getDescription(double score, bool isValid) {
    if (isValid) return 'Ready for DV application';
    if (score >= 60) return 'Minor adjustments needed';
    return 'Significant improvements required';
  }
}
