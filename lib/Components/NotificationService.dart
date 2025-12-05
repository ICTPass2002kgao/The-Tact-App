import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:ttact/Components/BibleVerseRepository.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    // 1. Initialize Timezones
    tz.initializeTimeZones();

    // 2. Android Settings
    // Ensure 'ic_notification.png' exists in android/app/src/main/res/drawable/
    // It should be a transparent image with white lines/shapes for best results.
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('ic_notification');

    // 3. iOS Settings
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // 4. Initialize the plugin
    await _notificationsPlugin.initialize(settings);

    // 5. ⭐️ EXPLICITLY REQUEST ANDROID 13+ PERMISSIONS
    // This is required for newer Android phones (API 33+) to show the popup.
    final platform = _notificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
        
    if (platform != null) {
      await platform.requestNotificationsPermission();
    }
  }

  // --- DAILY SCHEDULING LOGIC ---
  static Future<void> scheduleDailyVerses() async {
    // Clear old queue to prevent duplicates
    await _notificationsPlugin.cancelAll();

    final now = DateTime.now();

    // Schedule verses for the next 30 days
    for (int i = 0; i < 30; i++) {
      final targetDate = now.add(Duration(days: i));
      final verse = BibleVerseRepository.getDailyVerse(date: targetDate);

      await _scheduleNotification(
        id: i, // Unique ID for each day (0-29)
        title: "Verse of the Day: ${verse['category']}",
        body: '"${verse['text']}" - ${verse['ref']}',
        scheduledDate: targetDate,
      );
    }
  }

  static Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    
    // Set to 8:00 AM
    var scheduledTime = tz.TZDateTime(
      tz.local,
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day,
      8, // Hour (8 AM)
      00, // Minute
    );

    // If 8:00 AM has already passed for today, do not schedule for today.
    if (scheduledTime.isBefore(tz.TZDateTime.now(tz.local))) {
      return; 
    }

    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      scheduledTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_verse_channel',
          'Daily Bible Verses',
          channelDescription: 'Word of the day biblical',
          importance: Importance.max,
          priority: Priority.high,
          // Used for the image on the right side (must exist in drawable)
          largeIcon: DrawableResourceAndroidBitmap('ic_notification'), 
          styleInformation: BigTextStyleInformation(''),
        ),
        iOS: DarwinNotificationDetails(),
      ),
      
      // ⭐️ FIX: Use inexact mode to prevent crash on Android 12+
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
       
    );
  }

  // --- 🧪 TEST FUNCTION (Call this from HomePage to verify it works) ---
  static Future<void> showInstantTest() async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'test_channel',
      'Test Notifications',
      importance: Importance.max,
      priority: Priority.high,
      largeIcon: DrawableResourceAndroidBitmap('ic_notification'),
      styleInformation: BigTextStyleInformation(''),
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails, 
      iOS: DarwinNotificationDetails()
    );

    await _notificationsPlugin.show(
      999,
      'Testing DANKIE Notifications',
      'If you can see this, your Bible Verses will arrive safely at 8:00 AM!',
      details,
    );
  }
}