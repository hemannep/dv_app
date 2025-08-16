class AppConstants {
  // App Info
  static const String appName = 'DV Lottery Helper';
  static const String appVersion = '1.0.0';
  static const String appDescription =
      'Your guide to US Diversity Visa application';

  // URLs
  static const String officialDVUrl = 'https://dvprogram.state.gov/';
  static const String dvRegistrationUrl = 'https://dvprogram.state.gov/';
  static const String privacyPolicyUrl = 'https://dvprogram.state.gov/privacy';

  // DV Photo Requirements
  static const int photoWidth = 600;
  static const int photoHeight = 600;
  static const String photoFormat = 'JPEG';
  static const int maxPhotoSizeKB = 240;
  static const int minPhotoSizeKB = 10;

  // Face detection ratios (percentage of total image height)
  static const double minFaceRatio = 0.50; // 50%
  static const double maxFaceRatio = 0.69; // 69%

  // Animation Durations
  static const Duration splashDuration = Duration(seconds: 2);
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration longAnimationDuration = Duration(milliseconds: 500);

  // Spacing
  static const double smallSpacing = 8.0;
  static const double mediumSpacing = 16.0;
  static const double largeSpacing = 24.0;
  static const double extraLargeSpacing = 32.0;

  // Border Radius
  static const double smallRadius = 8.0;
  static const double mediumRadius = 12.0;
  static const double largeRadius = 16.0;
  static const double extraLargeRadius = 24.0;

  // Icon Sizes
  static const double smallIconSize = 16.0;
  static const double mediumIconSize = 24.0;
  static const double largeIconSize = 32.0;
  static const double extraLargeIconSize = 48.0;

  // DV Program Information
  static const String dvProgramDescription = '''
The Diversity Visa (DV) Program provides up to 55,000 immigrant visas annually to persons from countries with historically low rates of immigration to the United States.
  ''';

  static const List<String> photoRequirements = [
    '600 x 600 pixels resolution',
    'JPEG format only',
    'File size between 10KB - 240KB',
    'Plain white or off-white background',
    'Recent photo (within 6 months)',
    'No glasses or headwear (except religious)',
    'Natural facial expression',
    'Face must be 50-69% of photo',
    'Neutral expression with both eyes open',
    'No shadows on face',
    'Head positioned straight',
  ];

  static const List<String> babyPhotoTips = [
    'Use natural lighting',
    'Keep baby calm and comfortable',
    'White sheet as background',
    'Face should be clearly visible',
    'No toys or other people in photo',
    'Eyes should be open (if possible)',
    'Minimal shadows on face',
    'Head positioned straight',
  ];

  static const List<String> eligibilityCountries = [
    'All countries except: Bangladesh, Brazil, Canada, China, Colombia, Dominican Republic, El Salvador, Haiti, Honduras, India, Jamaica, Mexico, Nigeria, Pakistan, Philippines, South Korea, United Kingdom, Venezuela, Vietnam',
  ];

  // Photo validation error messages
  static const Map<String, String> photoErrors = {
    'invalid_size': 'Photo must be exactly 600x600 pixels',
    'invalid_format': 'Photo must be in JPEG format',
    'file_too_large': 'File size must be less than 240KB',
    'file_too_small': 'File size must be at least 10KB',
    'no_face_detected': 'No face detected in the photo',
    'multiple_faces': 'Only one face should be visible',
    'face_too_small': 'Face is too small (must be 50-69% of image height)',
    'face_too_large': 'Face is too large (must be 50-69% of image height)',
    'poor_lighting': 'Lighting is not balanced - face the light source',
    'background_not_plain': 'Background must be plain white or off-white',
    'shadows_detected': 'Shadows detected on face',
    'glasses_detected': 'Remove glasses unless medically required',
    'head_tilted': 'Keep head straight and level',
    'eyes_closed': 'Both eyes must be open and visible',
  };
}
