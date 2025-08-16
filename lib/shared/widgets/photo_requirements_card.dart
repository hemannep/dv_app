import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';

class PhotoRequirementsCard extends StatefulWidget {
  final bool isBabyMode;
  final VoidCallback? onClose;

  const PhotoRequirementsCard({
    Key? key,
    required this.isBabyMode,
    this.onClose,
  }) : super(key: key);

  @override
  State<PhotoRequirementsCard> createState() => _PhotoRequirementsCardState();
}

class _PhotoRequirementsCardState extends State<PhotoRequirementsCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: AppConstants.mediumAnimation,
      vsync: this,
    );

    _slideAnimation = Tween<double>(begin: -1.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    // Start animation
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  void _closeCard() {
    _animationController.reverse().then((_) {
      if (widget.onClose != null) {
        widget.onClose!();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value * 100),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              margin: const EdgeInsets.all(AppConstants.mediumSpacing),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.85),
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                border: Border.all(
                  color: widget.isBabyMode
                      ? Colors.pink.withOpacity(0.5)
                      : Colors.blue.withOpacity(0.5),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  _buildHeader(),

                  // Content
                  if (_isExpanded) _buildExpandedContent(),
                  if (!_isExpanded) _buildCollapsedContent(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(AppConstants.mediumSpacing),
      child: Row(
        children: [
          // Mode icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: widget.isBabyMode
                  ? Colors.pink.withOpacity(0.2)
                  : Colors.blue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              widget.isBabyMode ? Icons.child_care : Icons.person,
              color: widget.isBabyMode ? Colors.pink[300] : Colors.blue[300],
              size: AppConstants.mediumIconSize,
            ),
          ),

          const SizedBox(width: AppConstants.mediumSpacing),

          // Title and subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isBabyMode
                      ? 'Baby Photo Mode'
                      : 'DV Photo Requirements',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isExpanded ? 'Tap to collapse' : 'Tap for details',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Expand/collapse button
          GestureDetector(
            onTap: _toggleExpanded,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                _isExpanded ? Icons.expand_less : Icons.expand_more,
                color: Colors.white,
                size: AppConstants.mediumIconSize,
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Close button
          GestureDetector(
            onTap: _closeCard,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.close, color: Colors.red, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsedContent() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.mediumSpacing,
        0,
        AppConstants.mediumSpacing,
        AppConstants.mediumSpacing,
      ),
      child: Column(
        children: [
          // Quick requirements
          _buildQuickRequirement(
            icon: Icons.crop_square,
            text: '600x600 pixels',
            color: Colors.green,
          ),
          const SizedBox(height: 8),
          _buildQuickRequirement(
            icon: Icons.face,
            text: widget.isBabyMode
                ? 'Baby face centered'
                : 'Face 50-70% of image',
            color: Colors.blue,
          ),
          const SizedBox(height: 8),
          _buildQuickRequirement(
            icon: Icons.wb_sunny,
            text: 'Good lighting',
            color: Colors.orange,
          ),
          const SizedBox(height: 8),
          _buildQuickRequirement(
            icon: Icons.wallpaper,
            text: 'Plain white background',
            color: Colors.purple,
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedContent() {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.mediumSpacing,
        0,
        AppConstants.mediumSpacing,
        AppConstants.mediumSpacing,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Technical Requirements
          _buildSection(
            title: 'Technical Requirements',
            icon: Icons.settings,
            color: Colors.green,
            items: [
              'Image size: 600 x 600 pixels exactly',
              'File format: JPEG (.jpg)',
              'File size: Under 240KB',
              'Color: Full color (24-bit)',
              'Recent photo (within 6 months)',
            ],
          ),

          const SizedBox(height: AppConstants.mediumSpacing),

          // Face Requirements
          _buildSection(
            title: widget.isBabyMode
                ? 'Baby Face Requirements'
                : 'Face Requirements',
            icon: Icons.face,
            color: Colors.blue,
            items: widget.isBabyMode
                ? [
                    'Baby\'s head positioned upright',
                    'Eyes open if possible (flexible)',
                    'Face clearly visible and centered',
                    'No toys or pacifiers visible',
                    'Support hands not visible',
                  ]
                : [
                    'Face 50-70% of image area',
                    'Look directly at camera',
                    'Neutral expression (no smiling)',
                    'Eyes open and clearly visible',
                    'Head positioned straight',
                  ],
          ),

          const SizedBox(height: AppConstants.mediumSpacing),

          // Lighting & Background
          _buildSection(
            title: 'Lighting & Background',
            icon: Icons.wb_sunny,
            color: Colors.orange,
            items: [
              'Plain white or off-white background',
              'Even lighting across face',
              'No shadows on face',
              'No patterns or objects in background',
              'Good contrast with clothing',
            ],
          ),

          if (widget.isBabyMode) ...[
            const SizedBox(height: AppConstants.mediumSpacing),
            _buildSection(
              title: 'Baby Photo Tips',
              icon: Icons.child_care,
              color: Colors.pink,
              items: [
                'Choose calm, alert time for baby',
                'Use white sheet as background',
                'Baby may lie down if head upright',
                'Car seat OK if not visible',
                'Take multiple shots',
              ],
            ),
          ],

          const SizedBox(height: AppConstants.mediumSpacing),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  label: 'View Tips',
                  icon: Icons.lightbulb_outline,
                  onPressed: () => _showPhotoTips(context),
                  color: Colors.amber,
                ),
              ),
              const SizedBox(width: AppConstants.mediumSpacing),
              Expanded(
                child: _buildActionButton(
                  label: 'Examples',
                  icon: Icons.photo_library,
                  onPressed: () => _showExamples(context),
                  color: Colors.blue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickRequirement({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<String> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Section items
        ...items
            .map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.8),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.5), width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPhotoTips(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PhotoTipsBottomSheet(isBabyMode: widget.isBabyMode),
    );
  }

  void _showExamples(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          PhotoExamplesBottomSheet(isBabyMode: widget.isBabyMode),
    );
  }
}

class PhotoTipsBottomSheet extends StatelessWidget {
  final bool isBabyMode;

  const PhotoTipsBottomSheet({Key? key, required this.isBabyMode})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.lightbulb, color: Colors.amber, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isBabyMode ? 'Baby Photo Tips' : 'Photo Tips',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  if (isBabyMode) ..._buildBabyTips() else ..._buildAdultTips(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildBabyTips() {
    return [
      _buildTipCard(
        icon: Icons.access_time,
        title: 'Timing',
        tips: AppConstants.photoTips['baby_specific']!,
        color: Colors.pink,
      ),
      _buildTipCard(
        icon: Icons.wb_sunny,
        title: 'Lighting',
        tips: AppConstants.photoTips['lighting']!,
        color: Colors.orange,
      ),
      _buildTipCard(
        icon: Icons.camera_alt,
        title: 'Camera Setup',
        tips: AppConstants.photoTips['technical']!,
        color: Colors.blue,
      ),
    ];
  }

  List<Widget> _buildAdultTips() {
    return [
      _buildTipCard(
        icon: Icons.wb_sunny,
        title: 'Lighting',
        tips: AppConstants.photoTips['lighting']!,
        color: Colors.orange,
      ),
      _buildTipCard(
        icon: Icons.wallpaper,
        title: 'Background',
        tips: AppConstants.photoTips['background']!,
        color: Colors.purple,
      ),
      _buildTipCard(
        icon: Icons.person,
        title: 'Positioning',
        tips: AppConstants.photoTips['positioning']!,
        color: Colors.green,
      ),
      _buildTipCard(
        icon: Icons.camera_alt,
        title: 'Technical',
        tips: AppConstants.photoTips['technical']!,
        color: Colors.blue,
      ),
    ];
  }

  Widget _buildTipCard({
    required IconData icon,
    required String title,
    required List<String> tips,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...tips
              .map(
                (tip) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(tip, style: const TextStyle(fontSize: 14)),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ],
      ),
    );
  }
}

class PhotoExamplesBottomSheet extends StatelessWidget {
  final bool isBabyMode;

  const PhotoExamplesBottomSheet({Key? key, required this.isBabyMode})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.photo_library, color: Colors.blue, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isBabyMode ? 'Baby Photo Examples' : 'Photo Examples',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildExampleSection(
                    title: 'Good Examples',
                    icon: Icons.check_circle,
                    color: Colors.green,
                    examples: isBabyMode
                        ? [
                            'Baby lying down with head upright and centered',
                            'Clear face visibility with natural lighting',
                            'Plain white background (white sheet or blanket)',
                            'Baby calm and alert, eyes open if possible',
                          ]
                        : [
                            'Face centered and occupying 50-70% of frame',
                            'Direct eye contact with camera lens',
                            'Even lighting with no harsh shadows',
                            'Plain white background with good contrast',
                          ],
                  ),

                  const SizedBox(height: 24),

                  _buildExampleSection(
                    title: 'Avoid These',
                    icon: Icons.cancel,
                    color: Colors.red,
                    examples: isBabyMode
                        ? [
                            'Baby with toys, pacifiers, or hands covering face',
                            'Supporting hands visible in the photo',
                            'Poor lighting or harsh shadows',
                            'Busy background with patterns or objects',
                          ]
                        : [
                            'Face too small or too large in frame',
                            'Looking away from camera or eyes closed',
                            'Smiling or unusual expressions',
                            'Dark, uneven lighting or shadows on face',
                          ],
                  ),

                  const SizedBox(height: 24),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info, color: Colors.blue, size: 24),
                            const SizedBox(width: 12),
                            const Text(
                              'Remember',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'The app will automatically validate your photo and provide feedback. Take multiple shots to get the best result!',
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExampleSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<String> examples,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...examples
            .map(
              (example) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(icon, color: color, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        example,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ],
    );
  }
}
