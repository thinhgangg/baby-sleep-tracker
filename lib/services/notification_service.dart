import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../firebase_options.dart';

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

  Future<String?> getToken() async {
    return await _fcm.getToken();
  }

  Future<void> initialize() async {
    await _requestPermission();

    // Cấu hình icon cho Android
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // Cấu hình cho iOS
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings();

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
        );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    if (Platform.isAndroid) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);
    }

    // Xử lý tin nhắn khi app đang mở (Foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("🔔 Foreground message received: ${message.notification?.title}");
      final notification = message.notification;
      final android = message.notification?.android;

      // Chỉ hiện thông báo local nếu có notification payload
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
              icon: android.smallIcon ?? '@mipmap/ic_launcher',
            ),
            iOS: const DarwinNotificationDetails(),
          ),
        );
      }
    });

    String? token = await _fcm.getToken();
    print('🔑 FCM Token: $token');
  }

  Future<void> _requestPermission() async {
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    print('📱 User granted permission: ${settings.authorizationStatus}');
  }
}

// --- HÀM XỬ LÝ KHI APP ĐÓNG HOẶC CHẠY NGẦM (BACKGROUND/TERMINATED) ---
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  print("💤 Handling a background message: ${message.messageId}");

  final notification = message.notification;
  final android = message.notification?.android;

  if (notification != null) {
    final FlutterLocalNotificationsPlugin bgFlutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    const AndroidInitializationSettings androidInitSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings darwinInitSettings =
        DarwinInitializationSettings();

    const InitializationSettings initSettings = InitializationSettings(
      android: androidInitSettings,
      iOS: darwinInitSettings,
    );

    await bgFlutterLocalNotificationsPlugin.initialize(initSettings);

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
