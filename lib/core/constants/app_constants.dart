class AppConstants {
  // DV Photo Requirements (Official U.S. State Department specifications)
  static const int photoWidth = 600; // pixels
  static const int photoHeight = 600; // pixels
  static const double photoAspectRatio = 1.0; // 1:1 square
  static const int maxFileSizeKB = 240; // 240KB maximum
  static const int minFileSizeKB = 10; // 10KB minimum

  // Face detection requirements
  static const double minFaceRatio = 0.5; // 50% of image area minimum
  static const double maxFaceRatio = 0.7; // 70% of image area maximum
  static const double minFaceRatioBaby = 0.4; // 40% for babies (more lenient)
  static const double maxFaceRatioBaby = 0.8; // 80% for babies (more lenient)

  // Image quality thresholds
  static const int minImageBrightness = 80;
  static const int maxImageBrightness = 220;
  static const int maxImageVariance = 2000;
  static const int maxBackgroundVariance = 1000;
  static const int minBackgroundBrightness = 180;

  // Camera settings
  static const double cameraAspectRatio = 1.0;
  static const int cameraResolutionWidth = 1200;
  static const int cameraResolutionHeight = 1200;

  // UI Constants
  static const double smallSpacing = 8.0;
  static const double mediumSpacing = 16.0;
  static const double largeSpacing = 24.0;
  static const double extraLargeSpacing = 32.0;

  static const double smallIconSize = 16.0;
  static const double mediumIconSize = 24.0;
  static const double largeIconSize = 32.0;
  static const double extraLargeIconSize = 48.0;

  static const double smallButtonHeight = 36.0;
  static const double mediumButtonHeight = 48.0;
  static const double largeButtonHeight = 56.0;

  static const double borderRadius = 12.0;
  static const double smallBorderRadius = 8.0;
  static const double largeBorderRadius = 16.0;
  static const double smallRadius = 8.0;
  static const double mediumRadius = 12.0;
  static const double largeRadius = 16.0;
  static const double extraLargeRadius = 24.0;

  // Animation durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 300);
  static const Duration longAnimation = Duration(milliseconds: 500);
  static const Duration longAnimationDuration = Duration(milliseconds: 500);
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration splashDuration = Duration(seconds: 3);

  // Error messages for photo validation
  static const Map<String, String> photoErrors = {
    'invalid_dimensions':
        'Photo must be exactly 600x600 pixels. Current photo has incorrect dimensions.',
    'file_too_large':
        'Photo file size must be under 240KB. Please compress the image or take a new photo.',
    'file_too_small':
        'Photo file size is too small. Please ensure the image has sufficient quality.',
    'no_face_detected':
        'No face detected in the photo. Please ensure your face is clearly visible and centered.',
    'multiple_faces':
        'Multiple faces detected. Only one person should be in the photo.',
    'face_too_small':
        'Face is too small in the photo. Please move closer to the camera so your face fills more of the frame.',
    'face_too_large':
        'Face is too large in the photo. Please move back slightly so your entire head fits in the frame.',
    'poor_lighting':
        'Lighting is too dark or uneven. Please take the photo in good, even lighting.',
    'shadows_detected':
        'Harsh shadows detected on the face. Please use softer, more even lighting.',
    'complex_background':
        'Background is too complex or patterned. Please use a plain white or light-colored background.',
    'poor_contrast':
        'Poor contrast between subject and background. Please use a lighter background.',
    'image_too_dark':
        'Image is too dark. Please increase lighting or take photo in brighter conditions.',
    'image_too_bright':
        'Image is too bright or overexposed. Please reduce lighting or take photo in softer light.',
    'image_blurry':
        'Image appears blurry. Please hold the camera steady and ensure good focus.',
    'wrong_format': 'Image must be in JPEG format with .jpg extension.',
    'corrupted_image':
        'Image file appears to be corrupted. Please take a new photo.',
  };

  // Success messages
  static const Map<String, String> successMessages = {
    'photo_captured': 'Photo captured successfully!',
    'photo_saved': 'Photo saved to gallery successfully!',
    'photo_validated': 'Photo meets all DV requirements!',
    'photo_exported': 'Photo exported to device gallery!',
    'settings_saved': 'Settings saved successfully!',
    'backup_created': 'Backup created successfully!',
    'photos_restored': 'Photos restored from backup!',
  };

  // DV Application specific requirements
  static const Map<String, String> dvRequirements = {
    'head_position':
        'Head must be positioned directly facing the camera with a neutral expression.',
    'eye_position':
        'Eyes must be open and clearly visible, looking directly at the camera.',
    'mouth_position':
        'Mouth must be closed with a neutral expression (no smiling).',
    'head_covering':
        'Head coverings are only permitted for religious purposes.',
    'glasses':
        'Glasses are permitted if they do not obscure the eyes and have no tinted lenses.',
    'jewelry':
        'Jewelry is permitted as long as it does not obscure facial features.',
    'makeup':
        'Makeup is permitted but should be natural and not dramatically alter appearance.',
    'facial_hair':
        'Facial hair is permitted and should represent your normal appearance.',
    'recent_photo': 'Photo must be taken within the last 6 months.',
    'digital_format':
        'Photo must be in digital format, not a scan of a printed photo.',
  };

  // Baby-specific requirements
  static const Map<String, String> babyRequirements = {
    'eyes_open':
        'Baby\'s eyes should be open if possible, but this requirement is more flexible.',
    'head_position':
        'Baby\'s head should be positioned upright and facing the camera.',
    'no_toys':
        'No toys, pacifiers, or other objects should be visible in the photo.',
    'no_hands': 'Baby\'s hands should not be covering the face.',
    'plain_background': 'Use a plain white sheet or blanket as background.',
    'support_allowed':
        'You may support the baby, but supporting hands should not be visible.',
    'car_seat_ok':
        'Baby may be photographed in a car seat if the seat is not visible.',
    'lying_down_ok': 'Baby may be lying down if head is positioned upright.',
  };

  // Photo tips for better results
  static const Map<String, List<String>> photoTips = {
    'lighting': [
      'Use natural light from a window when possible',
      'Avoid harsh direct sunlight',
      'Ensure even lighting across the face',
      'Avoid fluorescent lighting which can cause color casts',
      'Use soft, diffused light to minimize shadows',
    ],
    'background': [
      'Use a plain white or off-white background',
      'Hang a white sheet or use a white wall',
      'Ensure the background is evenly lit',
      'Remove any objects or patterns from the background',
      'Stand at least 2 feet away from the background to avoid shadows',
    ],
    'positioning': [
      'Look directly at the camera lens',
      'Keep your head centered in the frame',
      'Ensure your entire face is visible',
      'Maintain a neutral expression',
      'Keep your shoulders square to the camera',
    ],
    'technical': [
      'Use the highest resolution setting on your camera',
      'Hold the camera steady or use a tripod',
      'Take multiple shots and choose the best one',
      'Avoid using zoom - move physically closer instead',
      'Check focus before taking the photo',
    ],
    'baby_specific': [
      'Choose a time when baby is calm and alert',
      'Have someone else operate the camera while you position the baby',
      'Use gentle sounds or toys to get baby\'s attention (but keep them out of frame)',
      'Be patient and take multiple shots',
      'Consider having baby lying on a white blanket',
    ],
  };

  // Simplified photo requirements for display
  static const List<String> photoRequirements = [
    '600x600 pixels exactly',
    'JPEG format only',
    'Under 240KB file size',
    'Face 50-70% of image',
    'Plain white background',
    'Even lighting, no shadows',
    'Neutral expression',
    'Looking directly at camera',
  ];

  // Baby photo specific tips
  static const List<String> babyPhotoTips = [
    'Baby lying down with head upright',
    'Eyes open if possible (flexible)',
    'Plain white background',
    'No toys or pacifiers visible',
    'Support hands not visible',
    'Even, soft lighting',
  ];

  // Validation thresholds for different aspects
  static const Map<String, Map<String, double>> validationThresholds = {
    'face_detection': {
      'min_confidence': 0.7,
      'max_faces': 1.0,
      'min_face_ratio': 0.5,
      'max_face_ratio': 0.7,
    },
    'lighting': {
      'min_brightness': 80.0,
      'max_brightness': 220.0,
      'max_variance': 2000.0,
      'min_contrast': 0.4,
    },
    'background': {
      'max_complexity': 1000.0,
      'min_brightness': 180.0,
      'max_color_variance': 500.0,
    },
    'quality': {
      'min_sharpness': 0.5,
      'max_noise': 0.3,
      'min_resolution': 600.0,
    },
  };

  // File format specifications
  static const Map<String, dynamic> fileFormats = {
    'accepted_formats': ['jpg', 'jpeg'],
    'color_space': 'sRGB',
    'compression': 'JPEG',
    'quality_min': 85,
    'quality_max': 100,
    'bit_depth': 24,
  };

  // App configuration
  static const String appName = 'DV Photo Tool';
  static const String appVersion = '1.0.0';
  static const String appDescription =
      'Professional DV Lottery photo tool for creating compliant diversity visa photos';
  static const String dvProgramDescription =
      'The Diversity Visa Program makes up to 50,000 immigrant visas available annually, drawn from random selection among all entries to persons who are from countries with low rates of immigration to the United States.';
  static const int maxStoredPhotos = 50;
  static const int maxBackupAge = 30; // days
  static const bool enableAnalytics = false;
  static const bool enableCrashReporting = true;

  // URLs and links (if needed for future features)
  static const Map<String, String> externalLinks = {
    'dv_official':
        'https://travel.state.gov/content/travel/en/us-visas/immigrate/diversity-visa-program-entry.html',
    'photo_requirements':
        'https://travel.state.gov/content/travel/en/us-visas/visa-information-resources/photos.html',
    'dv_instructions':
        'https://travel.state.gov/content/travel/en/us-visas/immigrate/diversity-visa-program-entry/dv-program-instructions.html',
    'support_email': 'support@dvphototool.com',
    'privacy_policy': 'https://dvphototool.com/privacy',
    'terms_of_service': 'https://dvphototool.com/terms',
  };

  // Direct URL access
  static const String officialDVUrl =
      'https://travel.state.gov/content/travel/en/us-visas/immigrate/diversity-visa-program-entry.html';
  static const String privacyPolicyUrl = 'https://dvphototool.com/privacy';

  // Cache settings
  static const Map<String, int> cacheSettings = {
    'max_cache_size_mb': 100,
    'cache_expiry_days': 7,
    'max_thumbnails': 200,
    'thumbnail_size': 150,
  };

  // Performance settings
  static const Map<String, dynamic> performanceSettings = {
    'enable_hardware_acceleration': true,
    'max_concurrent_validations': 3,
    'validation_timeout_seconds': 30,
    'camera_preview_fps': 30,
    'image_processing_quality': 'high',
  };

  // Accessibility settings
  static const Map<String, dynamic> accessibilitySettings = {
    'minimum_touch_target_size': 44.0,
    'high_contrast_mode': false,
    'voice_guidance': false,
    'large_text_support': true,
    'screen_reader_support': true,
  };

  // Feature flags
  static const Map<String, bool> featureFlags = {
    'enable_baby_mode': true,
    'enable_batch_processing': true,
    'enable_advanced_validation': true,
    'enable_export_to_gallery': true,
    'enable_photo_enhancement': true,
    'enable_backup_restore': true,
    'enable_usage_analytics': false,
    'enable_cloud_sync': false,
  };

  // Validation scoring weights
  static const Map<String, double> validationWeights = {
    'dimensions': 20.0,
    'file_size': 15.0,
    'background': 20.0,
    'face_detection': 25.0,
    'lighting': 15.0,
    'shadows': 5.0,
  };

  // Default settings
  static const Map<String, dynamic> defaultSettings = {
    'flash_mode': 'auto',
    'camera_lens': 'front',
    'grid_lines': true,
    'save_originals': false,
    'auto_enhance': true,
    'show_tips': true,
    'vibrate_on_capture': true,
    'play_sounds': true,
  };
}
