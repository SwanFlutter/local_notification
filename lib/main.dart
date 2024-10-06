// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:local_notification/notification/notification_service.dart';
import 'package:local_notification/screen.dart';
import 'package:timezone/data/latest.dart' as tz;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();
  FlutterForegroundTask.initCommunicationPort();

  // Initialize notification service
  final NotificationService notificationService = NotificationService();
  await notificationService.initNotification();

  // Initialize time zones
  tz.initializeTimeZones();

  await initializeDateFormatting('fa', null);

  runApp(const MyApp());
}

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(MyTaskHandler());
}

class MyTaskHandler extends TaskHandler {
  final box = GetStorage();
  Timer? _timer;

  @override
  Future<void> onStart(DateTime timestamp) async {
    debugPrint('Service started at: $timestamp');

    // Schedule repeating tasks
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      await _fetchAndNotify();
    });
  }

  Future<void> _fetchAndNotify() async {
    String apiUrl = "http://192.168.1.103/notification/index.php";

    try {
      Response response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        var jsonData = jsonDecode(response.body);
        bool success = jsonData['success'];

        if (success) {
          List<dynamic> data = jsonData['data'];
          debugPrint("Received data: ${jsonEncode(data)}");

          List<Map<String, dynamic>> fetchList = List<Map<String, dynamic>>.from(data);
          debugPrint("Number of items: ${fetchList.length}");

          for (var item in fetchList) {
            await _processNotificationItem(item);
          }
        } else {
          String message = jsonData['message'];
          debugPrint("Operation failed: $message");
        }
      } else {
        debugPrint("Error fetching data. Status code: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("An error occurred: $e");
    }
  }

  Future<void> _processNotificationItem(Map<String, dynamic> item) async {
    final notificationService = NotificationService(); // استفاده از Singleton
    int id = int.parse(item['id']);
    String title = item['title'];
    String body = item['body'];

    debugPrint("Processing notification - ID: $id, Title: $title, Body: $body");

    await notificationService.showNotification(
      id: id,
      title: title,
      body: body,
    );

    debugPrint("Notification sent - ID: $id");
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    _timer?.cancel();
    debugPrint('Service destroyed at: $timestamp');
  }

  @override
  void onNotificationButtonPressed(String id) {
    debugPrint('Notification button pressed: $id');
  }

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp('/');
    debugPrint('Notification pressed');
  }

  @override
  void onRepeatEvent(DateTime timestamp) {}
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.orange,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final box = GetStorage();
  String storedMessage = "No message yet";

  @override
  void initState() {
    super.initState();
    storedMessage = box.read('message') ?? "No message yet";
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestPermissions();
      _initService();
    });
  }

  Future<void> _requestPermissions() async {
    final NotificationPermission notificationPermissionStatus = await FlutterForegroundTask.checkNotificationPermission();
    if (notificationPermissionStatus != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
  }

  Future<void> _initService() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'my_foreground',
        channelName: 'MY FOREGROUND SERVICE',
        channelDescription: 'This channel is used for important notifications.',
        channelImportance: NotificationChannelImportance.HIGH,
        priority: NotificationPriority.HIGH,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: true,
        eventAction: ForegroundTaskEventAction.repeat(5000), // تنظیم فراخوانی تکرار هر 5 ثانیه
      ),
    );
  }

  Future<ServiceRequestResult> _startService() async {
    if (await FlutterForegroundTask.isRunningService) {
      return FlutterForegroundTask.restartService();
    } else {
      return FlutterForegroundTask.startService(
        notificationTitle: 'Foreground Service is running',
        notificationText: 'Tap to return to the app',
        callback: startCallback,
      );
    }
  }

  Future<ServiceRequestResult> _stopService() async {
    return FlutterForegroundTask.stopService();
  }

  Future<void> fetchData() async {
    String apiUrl = "http://192.168.1.103/notification/index.php";

    try {
      Response response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        var jsonData = jsonDecode(response.body);
        bool success = jsonData['success'];

        if (success) {
          List<dynamic> data = jsonData['data'];
          debugPrint(jsonEncode(data));

          List<Map<String, dynamic>> fetchList = List<Map<String, dynamic>>.from(data);
          debugPrint("تعداد آیتم‌ها: ${fetchList.length}");

          for (var item in fetchList) {
            debugPrint("عنوان: ${item['title']}");
          }
        } else {
          String message = jsonData['message'];
          debugPrint("عملیات ناموفق بود: $message");
        }
      } else {
        debugPrint("خطا در دریافت داده‌ها. کد وضعیت: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("خطایی رخ داد: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return WithForegroundTask(
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Flutter Notifications"),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _startService,
                child: const Text('Start Service'),
              ),
              ElevatedButton(
                onPressed: _stopService,
                child: const Text('Stop Service'),
              ),
              Text(storedMessage),
              const SizedBox(height: 10.0),
              ElevatedButton(
                onPressed: () {
                  fetchData();
                },
                child: const Text('Fetch Data'),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const Screen(),
              ),
            );
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}



/*import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();
  FlutterForegroundTask.initCommunicationPort();
  runApp(const MyApp());
}

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(MyTaskHandler());
}

class MyTaskHandler extends TaskHandler {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final box = GetStorage();
  Timer? _timer;

  @override
  Future<void> onStart(DateTime timestamp) async {
    print('Service started at: $timestamp');

    // Initialize notifications
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'my_foreground',
      'MY FOREGROUND SERVICE',
      description: 'This channel is used for important notifications.',
      importance: Importance.high,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      iOS: DarwinInitializationSettings(),
      android: AndroidInitializationSettings('@mipmap/app_icon'),
    );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Schedule repeating tasks
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      await _fetchAndNotify();
    });
  }

  Future<void> _fetchAndNotify() async {
    String apiUrl = "http://192.168.1.103/notification/index.php";

    try {
      Response response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        var jsonData = jsonDecode(response.body);
        bool success = jsonData['success'];

        if (success) {
          List<dynamic> data = jsonData['data'];
          debugPrint("Received data: ${jsonEncode(data)}");

          List<Map<String, dynamic>> fetchList =
              List<Map<String, dynamic>>.from(data);
          debugPrint("Number of items: ${fetchList.length}");

          for (var item in fetchList) {
            await _processNotificationItem(item);
          }
        } else {
          String message = jsonData['message'];
          debugPrint("Operation failed: $message");
        }
      } else {
        debugPrint("Error fetching data. Status code: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("An error occurred: $e");
    }
  }

  Future<void> _processNotificationItem(Map<String, dynamic> item) async {
    int id = int.parse(item['id']);
    String title = item['title'];
    String body = item['body'];

    debugPrint("Processing notification - ID: $id, Title: $title, Body: $body");

    await Future.delayed(const Duration(seconds: 20));

    await flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'my_foreground',
          'MY FOREGROUND SERVICE',
          icon: '@mipmap/app_icon',
          importance: Importance.high,
          playSound: true,
          enableLights: false,
          priority: Priority.high,
          sound: RawResourceAndroidNotificationSound('notification_sound'),
        ),
      ),
    );

    debugPrint("Notification sent - ID: $id");
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    _timer?.cancel();
    print('Service destroyed at: $timestamp');
  }

  @override
  void onNotificationButtonPressed(String id) {
    print('Notification button pressed: $id');
  }

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp('/');
    print('Notification pressed');
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // TODO: implement onRepeatEvent
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final box = GetStorage();
  String storedMessage = "No message yet";

  @override
  void initState() {
    super.initState();
    storedMessage = box.read('message') ?? "No message yet";
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestPermissions();
      _initService();
    });
  }

  Future<void> _requestPermissions() async {
    final NotificationPermission notificationPermissionStatus =
        await FlutterForegroundTask.checkNotificationPermission();
    if (notificationPermissionStatus != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
  }

  Future<void> _initService() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'my_foreground',
        channelName: 'MY FOREGROUND SERVICE',
        channelDescription: 'This channel is used for important notifications.',
        channelImportance: NotificationChannelImportance.HIGH,
        priority: NotificationPriority.HIGH,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: true,
        eventAction: ForegroundTaskEventAction.repeat(
            5000), // تنظیم فراخوانی تکرار هر 5 ثانیه
      ),
    );
  }

  Future<ServiceRequestResult> _startService() async {
    if (await FlutterForegroundTask.isRunningService) {
      return FlutterForegroundTask.restartService();
    } else {
      return FlutterForegroundTask.startService(
        notificationTitle: 'Foreground Service is running',
        notificationText: 'Tap to return to the app',
        callback: startCallback,
      );
    }
  }

  Future<ServiceRequestResult> _stopService() async {
    return FlutterForegroundTask.stopService();
  }

  Future<void> fetchData() async {
    String apiUrl = "http://192.168.1.103/notification/index.php";

    try {
      Response response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        var jsonData = jsonDecode(response.body);
        bool success = jsonData['success'];

        if (success) {
          List<dynamic> data = jsonData['data'];
          // چاپ فقط بخش data
          debugPrint(jsonEncode(data));

          // اگر می‌خواهید با داده‌ها کار کنید:
          List<Map<String, dynamic>> fetchList =
              List<Map<String, dynamic>>.from(data);
          debugPrint("تعداد آیتم‌ها: ${fetchList.length}");

          // مثال: چاپ عنوان هر آیتم
          for (var item in fetchList) {
            debugPrint("عنوان: ${item['title']}");
          }
        } else {
          String message = jsonData['message'];
          debugPrint("عملیات ناموفق بود: $message");
        }
      } else {
        debugPrint("خطا در دریافت داده‌ها. کد وضعیت: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("خطایی رخ داد: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return WithForegroundTask(
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Flutter Notifications"),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _startService,
                child: const Text('Start Service'),
              ),
              ElevatedButton(
                onPressed: _stopService,
                child: const Text('Stop Service'),
              ),
              Text(storedMessage),
              const SizedBox(height: 10.0),
              ElevatedButton(
                onPressed: () {
                  fetchData();
                },
                child: const Text('Fetch Data'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
 */
