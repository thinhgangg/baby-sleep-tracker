import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// 1. TẠO CHANNEL CHO ANDROID
const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel',
  'High Importance Notifications',
  description: 'This channel is used for important notifications.',
  importance: Importance.high,
);

// 2. KHỞI TẠO PLUGIN LOCAL NOTIFICATIONS
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  // Lấy FCM token của thiết bị
  Future<String?> getToken() async {
    return await _fcm.getToken();
  }

  // Hàm khởi tạo và xin quyền
  Future<void> initialize() async {
    await _requestPermission();

    // KHỞI TẠO LOCAL NOTIFICATIONS
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    if (Platform.isAndroid) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      final android = message.notification?.android;

      if (notification != null && android != null) {
        flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channelDescription: channel.description,
              importance: Importance.high,
              priority: Priority.high,
              icon: android.smallIcon,
            ),
          ),
        );
      }
    });


    String? token = await _fcm.getToken();
    print('🔑 FCM Token: $token');
  }

  Future<void> _requestPermission() async {
    if (Platform.isIOS || Platform.isMacOS) {
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      print('📱 iOS permission: ${settings.authorizationStatus}');
    } else if (Platform.isAndroid) {
      final androidImplementation = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      final bool? granted = await androidImplementation
          ?.requestNotificationsPermission();

      print('📱 Android permission granted: $granted');
    }
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("💤 Handling a background message: ${message.messageId}");
  print('🔥 Background message received: ${message.data}');

  final FlutterLocalNotificationsPlugin bgFlutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  const AndroidInitializationSettings androidInitSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initSettings = InitializationSettings(
    android: androidInitSettings,
  );

  await bgFlutterLocalNotificationsPlugin.initialize(initSettings);

  if (Platform.isAndroid) {
    await bgFlutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  final notification = message.notification;
  final android = message.notification?.android;

  if (notification != null) {
    await bgFlutterLocalNotificationsPlugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: android?.smallIcon ?? '@mipmap/ic_launcher',
        ),
      ),
    );
  }
}

Future<void> registerFirebaseMessagingBackgroundHandler() async {
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
}
