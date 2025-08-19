// lib/widgets/photo_tips_sheet.dart - Fixed missing assets
import 'package:flutter/material.dart';

class PhotoTipsSheet extends StatelessWidget {
  final bool isBabyMode;

  const PhotoTipsSheet({super.key, this.isBabyMode = false});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Title
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Icon(
                      Icons.tips_and_updates,
                      color: Theme.of(context).primaryColor,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isBabyMode ? 'Baby Photo Tips' : 'Photo Requirements',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isBabyMode)
                        _buildBabyTipsContent()
                      else
                        _buildGeneralTipsContent(),

                      const SizedBox(height: 20),

                      // Examples section with text descriptions instead of images
                      _buildExamplesSection(),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGeneralTipsContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTipSection('📐 Size & Format', [
          'Image must be 600x600 pixels',
          'JPEG format only',
          'File size: 240KB maximum',
          'Square aspect ratio (1:1)',
        ]),
        _buildTipSection('👤 Head Position', [
          'Head size: 50-69% of image height',
          'Face directly toward camera',
          'Eyes at 56-69% of image height',
          'Head centered horizontally',
        ]),
        _buildTipSection('😐 Expression & Eyes', [
          'Neutral expression (no smiling)',
          'Both eyes open and visible',
          'Look directly at camera',
          'No head coverings (except religious)',
        ]),
        _buildTipSection('🎨 Background & Lighting', [
          'Plain white or off-white background',
          'No shadows on face or background',
          'Even lighting on face',
          'No reflections from glasses',
        ]),
      ],
    );
  }

  Widget _buildBabyTipsContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.child_care, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text(
                    'Special Rules for Babies',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[800],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Babies and young children have relaxed requirements, but still need to meet basic photo standards.',
                style: TextStyle(color: Colors.orange[700]),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildTipSection('👶 Baby-Specific Tips', [
          'Both eyes must be open and visible',
          'Neutral expression preferred (slight smile OK)',
          'No other people in photo',
          'Baby can be lying down if necessary',
          'Use natural lighting when possible',
        ]),
        _buildTipSection('📱 Practical Tips', [
          'Take photos during baby\'s alert time',
          'Have someone make sounds behind camera',
          'Take multiple shots for best result',
          'Ensure baby is comfortable and clean',
          'Use burst mode if available',
        ]),
      ],
    );
  }

  Widget _buildTipSection(String title, List<String> tips) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...tips.map(
          (tip) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(fontSize: 16)),
                Expanded(child: Text(tip)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildExamplesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '✅ Good Examples',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              _buildExampleItem('Direct gaze at camera', true),
              _buildExampleItem('Plain white background', true),
              _buildExampleItem('Good lighting, no shadows', true),
              _buildExampleItem('Correct head size (50-69%)', true),
            ],
          ),
        ),

        const SizedBox(height: 16),

        const Text(
          '❌ Avoid These',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              _buildExampleItem('Looking away from camera', false),
              _buildExampleItem('Smiling or unusual expressions', false),
              _buildExampleItem('Shadows on face or background', false),
              _buildExampleItem('Head too small or too large', false),
              _buildExampleItem('Wearing hats or head coverings', false),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExampleItem(String description, bool isGood) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isGood ? Icons.check_circle : Icons.cancel,
            color: isGood ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(description)),
        ],
      ),
    );
  }
}
