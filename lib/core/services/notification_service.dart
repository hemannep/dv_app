// lib/core/services/notification_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone data
    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );
    _initialized = true;
  }

  static void _onNotificationResponse(NotificationResponse response) {
    // Handle notification tap
    print('Notification tapped: ${response.payload}');
  }

  static Future<bool> requestPermissions() async {
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final iosPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();

    bool permissionGranted = true;

    if (androidPlugin != null) {
      permissionGranted =
          await androidPlugin.requestNotificationsPermission() ?? false;
    }

    if (iosPlugin != null) {
      permissionGranted =
          await iosPlugin.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }

    return permissionGranted;
  }

  static Future<void> scheduleDVReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'dv_reminders',
          'DV Lottery Reminders',
          channelDescription: 'Reminders for DV lottery deadlines',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(categoryIdentifier: 'dv_reminders'),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );
  }

  static Future<void> schedulePhotoReminder() async {
    await scheduleDVReminder(
      id: 1,
      title: 'Complete Your DV Photo',
      body: 'Don\'t forget to take compliant photos for your DV application',
      scheduledDate: DateTime.now().add(const Duration(hours: 24)),
      payload: 'photo_reminder',
    );
  }

  static Future<void> scheduleDVDeadlineReminder() async {
    // DV lottery typically opens in October
    final now = DateTime.now();
    final currentYear = now.year;
    final dvOpenDate = DateTime(
      now.month >= 10 ? currentYear + 1 : currentYear,
      10, // October
      1,
      9, // 9 AM
    );

    // Schedule reminder 1 week before
    final reminderDate = dvOpenDate.subtract(const Duration(days: 7));

    if (reminderDate.isAfter(now)) {
      await scheduleDVReminder(
        id: 2,
        title: 'DV Lottery Opening Soon!',
        body:
            'The DV Lottery registration opens in 1 week. Prepare your documents and photos now.',
        scheduledDate: reminderDate,
        payload: 'deadline_reminder',
      );
    }
  }

  static Future<void> scheduleRecurringPhotoCheckReminder() async {
    // Schedule a weekly reminder to check photos
    final nextWeek = DateTime.now().add(const Duration(days: 7));

    await _notifications.zonedSchedule(
      3,
      'Photo Quality Check',
      'Review your DV photos to ensure they meet all requirements',
      tz.TZDateTime.from(nextWeek, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          'photo_check',
          'Photo Quality Reminders',
          channelDescription: 'Weekly reminders to check photo quality',
          importance: Importance.high,
          priority: Priority.defaultPriority,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: 'photo_check',
    );
  }

  static Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await _notifications.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'instant_notifications',
          'Instant Notifications',
          channelDescription: 'Immediate notifications',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: payload,
    );
  }

  static Future<void> showPhotoSavedNotification() async {
    await showInstantNotification(
      id: 100,
      title: 'Photo Saved Successfully',
      body: 'Your DV-compliant photo has been saved to the gallery',
      payload: 'photo_saved',
    );
  }

  static Future<void> showPhotoValidationNotification({
    required bool isValid,
    required double complianceScore,
  }) async {
    if (isValid) {
      await showInstantNotification(
        id: 101,
        title: 'Photo Validation Passed',
        body:
            'Great! Your photo meets DV requirements (${complianceScore.toInt()}% compliance)',
        payload: 'validation_success',
      );
    } else {
      await showInstantNotification(
        id: 102,
        title: 'Photo Needs Improvement',
        body: 'Photo validation failed. Check the requirements and try again.',
        payload: 'validation_failed',
      );
    }
  }

  static Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  static Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  static Future<List<PendingNotificationRequest>>
  getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  static Future<void> cancelPhotoReminders() async {
    await cancelNotification(1); // Photo reminder
    await cancelNotification(3); // Recurring photo check
  }

  static Future<void> setupDefaultReminders() async {
    // Cancel existing reminders
    await cancelAllNotifications();

    // Setup new reminders
    await schedulePhotoReminder();
    await scheduleDVDeadlineReminder();
    await scheduleRecurringPhotoCheckReminder();
  }
}
