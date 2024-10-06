// ignore_for_file: public_member_api_docs, sort_constructors_first, depend_on_referenced_packages
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  final FlutterLocalNotificationsPlugin notificationPlugin =
      FlutterLocalNotificationsPlugin();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  Future<void> initNotification() async {
    await _requestNotificationPermission();

    const AndroidInitializationSettings initializationAndroidSettings =
        AndroidInitializationSettings('@mipmap/app_icon');

    final DarwinInitializationSettings initializationSettingIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      defaultPresentSound: true,
      defaultPresentAlert: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      onDidReceiveLocalNotification: (id, title, body, payload) async {
        debugPrint('Received local notification: $id, $title, $body, $payload');
      },
    );

    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationAndroidSettings,
      iOS: initializationSettingIOS,
    );

    await notificationPlugin.initialize(
      initializationSettings,
      onDidReceiveBackgroundNotificationResponse:
          backgroundNotificationResponseHandler,
    );
  }

  Future<void> _requestNotificationPermission() async {
    if (await Permission.notification.isGranted) {
      debugPrint('Notification permission already granted.');
    } else {
      var status = await Permission.notification.request();
      if (status.isGranted) {
        debugPrint('Notification permission granted.');
      } else {
        debugPrint('Notification permission denied.');
        return; // اگر پرمیشن داده نشود، از ادامه دادن جلوگیری کنید
      }
    }
  }

  Future<void> showNotification({
    int id = 0,
    String? title,
    String? body,
    String? payload,
  }) async {
    debugPrint('Showing notification: $id, $title, $body, $payload');
    try {
      await notificationPlugin.show(
        id,
        title,
        body,
        await _notificationDetails(),
        payload: payload,
      );
    } catch (e) {
      debugPrint('Error showing notification: $e');
    }
  }

  Future<NotificationDetails> _notificationDetails() async {
    return const NotificationDetails(
      iOS: DarwinNotificationDetails(),
      android: AndroidNotificationDetails(
        'channelId',
        'channelName',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/app_icon',
      ),
    );
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    try {
      await notificationPlugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledDate, tz.local), // تنظیم زمان محلی
        await _notificationDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // تنظیم کامپوننت زمان
      );

      debugPrint('Scheduled notification for: $scheduledDate');
    } catch (e) {
      debugPrint('Error scheduling notification: $e');
    }
  }
}

void backgroundNotificationResponseHandler(
    NotificationResponse notification) async {
  debugPrint('Received background notification response: $notification');
}
