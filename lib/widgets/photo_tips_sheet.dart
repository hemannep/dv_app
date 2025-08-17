// lib/widgets/photo_tips_sheet.dart

import 'package:flutter/material.dart';

class PhotoTipsSheet extends StatelessWidget {
  final bool isBabyMode;

  const PhotoTipsSheet({super.key, this.isBabyMode = false});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                    Icon(Icons.lightbulb, color: Colors.blue[600], size: 28),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Tips to Make a Great Photo',
                        style: TextStyle(
                          fontSize: 20,
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
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    if (isBabyMode) ...[
                      _buildSection('Baby Photo Special Instructions', [
                        _buildTip(
                          Icons.baby_changing_station,
                          'Position',
                          'Lay baby on their back on a plain white sheet. Support their head to keep it upright.',
                        ),
                        _buildTip(
                          Icons.visibility,
                          'Eyes',
                          'Baby\'s eyes should be open if possible, but closed eyes are acceptable for newborns.',
                        ),
                        _buildTip(
                          Icons.do_not_disturb,
                          'No Props',
                          'Remove pacifiers, toys, and ensure supporting hands are not visible.',
                        ),
                      ]),
                      const SizedBox(height: 24),
                    ],

                    _buildSection('Lighting', [
                      _buildTip(
                        Icons.wb_sunny,
                        'Natural Light',
                        'Face a window with indirect sunlight for the best results. Avoid harsh direct sunlight.',
                      ),
                      _buildTip(
                        Icons.lightbulb,
                        'Even Lighting',
                        'Ensure light is even across your face. Avoid shadows on one side.',
                      ),
                      _buildTip(
                        Icons.flash_off,
                        'No Flash',
                        'Avoid using flash as it can create harsh shadows and red-eye.',
                      ),
                    ]),

                    const SizedBox(height: 24),

                    _buildSection('Position', [
                      _buildTip(
                        Icons.center_focus_strong,
                        'Center Face',
                        'Keep your face centered in the frame with equal space on all sides.',
                      ),
                      _buildTip(
                        Icons.straighten,
                        'Keep Straight',
                        'Keep your head straight - no tilting. Shoulders should be level.',
                      ),
                      _buildTip(
                        Icons.remove_red_eye,
                        'Look Forward',
                        'Look directly at the camera with both eyes open and clearly visible.',
                      ),
                    ]),

                    const SizedBox(height: 24),

                    _buildSection('Background', [
                      _buildTip(
                        Icons.wallpaper,
                        'Plain Background',
                        'Use a plain white or light-colored wall. Avoid patterns or busy backgrounds.',
                      ),
                      _buildTip(
                        Icons.contrast,
                        'Good Contrast',
                        'Ensure good contrast between you and the background.',
                      ),
                    ]),

                    const SizedBox(height: 24),

                    _buildSection('Expression & Appearance', [
                      _buildTip(
                        Icons.sentiment_neutral,
                        'Neutral Expression',
                        'Keep a neutral expression with mouth closed. No smiling.',
                      ),
                      _buildTip(
                        Icons.remove,
                        'Remove Accessories',
                        'Remove hats and sunglasses. Prescription glasses are okay if worn daily.',
                      ),
                      _buildTip(
                        Icons.checkroom,
                        'Appropriate Clothing',
                        'Wear normal daily clothing. Avoid uniforms unless religious.',
                      ),
                    ]),

                    const SizedBox(height: 24),

                    _buildExamplePhotos(),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSection(String title, List<Widget> tips) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        ...tips,
      ],
    );
  }

  Widget _buildTip(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.blue[600], size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExamplePhotos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Example Photos',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),

        // Good examples
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.withOpacity(0.3), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green[600], size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Good Examples',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildExampleImage(true, 'Even lighting'),
                  const SizedBox(width: 12),
                  _buildExampleImage(true, 'Neutral expression'),
                  const SizedBox(width: 12),
                  _buildExampleImage(true, 'Centered face'),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Bad examples
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.withOpacity(0.3), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.cancel, color: Colors.red[600], size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Bad Examples',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildExampleImage(false, 'Uneven shoulders'),
                  const SizedBox(width: 12),
                  _buildExampleImage(false, 'Bad lighting'),
                  const SizedBox(width: 12),
                  _buildExampleImage(false, 'Looking away'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExampleImage(bool isGood, String label) {
    return Expanded(
      child: Column(
        children: [
          Container(
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isGood ? Colors.green : Colors.red,
                width: 2,
              ),
            ),
            child: Center(
              child: Icon(Icons.person, size: 40, color: Colors.grey[400]),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
