import 'dart:async';
import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../firebase_options.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel foregroundChannel =
      AndroidNotificationChannel(
        'my_foreground',
        'Baby Monitor Service',
        description: 'Running in background',
        importance: Importance.low,
      );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(foregroundChannel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: 'my_foreground',
      initialNotificationTitle: 'Baby Sleep Tracker',
      initialNotificationContent: 'Đang chờ kết nối...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(autoStart: true, onForeground: onStart),
  );
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  Timer.periodic(const Duration(seconds: 5), (timer) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final String? uid = prefs.getString('user_uid');

    if (uid != null) {
      // đã có UID người dùng
      timer.cancel();

      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: "Baby Sleep Tracker",
          content: "Đang giám sát bé...",
        );
      }

      _findDeviceAndListen(uid);
    } else {
      print("⏳ Background Service: Đang chờ User Login...");
    }
  });
}

void _findDeviceAndListen(String uid) async {
  try {
    // 1. Lấy Device ID
    final userRef = FirebaseDatabase.instance.ref("users/$uid");
    final snapshot = await userRef.get();

    final userData = snapshot.value as Map?;
    if (userData != null && userData.containsKey('deviceId')) {
      final String deviceId = userData['deviceId'];
      print("📱 Device ID tìm thấy: $deviceId -> Bắt đầu lắng nghe data...");

      // 2. Lắng nghe dữ liệu tại sleepData/$deviceId
      // Dùng limitToLast(1) để chỉ lấy bản ghi mới nhất
      Query dataQuery = FirebaseDatabase.instance
          .ref("sleepData/$deviceId")
          .orderByKey()
          .limitToLast(1);

      dataQuery.onValue.listen((event) {
        final rawMap = event.snapshot.value as Map?;

        if (rawMap != null && rawMap.isNotEmpty) {
          final latestData = rawMap.values.first;

          print("📡 Dữ liệu nền nhận được: $latestData");
          _processSensorData(latestData);
        }
      });
    } else {
      print("❌ User này chưa có Device ID");
    }
  } catch (e) {
    print("❌ Lỗi Background Service: $e");
  }
}

void _processSensorData(dynamic data) {
  if (data is! Map) return;

  final bool isCrying = data['isCrying'] == true;
  final bool notiPosition = data['notiPosition'] == true;
  final num? babyTempNum = data['babyTemperature'];
  final double? babyTemp = babyTempNum?.toDouble();

  if (isCrying) {
    _showAlarmNotification(
      "CẢNH BÁO KHÓC!",
      "Bé đang khóc! Hãy kiểm tra ngay.",
    );
  } else if (notiPosition) {
    _showAlarmNotification(
      "CẢNH BÁO TƯ THẾ!",
      "Bé nằm sấp quá lâu! Hãy điều chỉnh tư thế.",
    );
  } else if (babyTemp != null && (babyTemp < 35 || babyTemp > 37.5)) {
    _showAlarmNotification(
      "CẢNH BÁO NHIỆT ĐỘ!",
      "Nhiệt độ bé bất thường ($babyTemp°C)! Hãy kiểm tra ngay.",
    );
  }
}

void _showAlarmNotification(String title, String body) async {
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
        'high_importance_channel',
        'High Importance Notifications',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        color: Color(0xFFFF0000),
      );

  const NotificationDetails platformChannelSpecifics = NotificationDetails(
    android: androidPlatformChannelSpecifics,
  );

  await flutterLocalNotificationsPlugin.show(
    0,
    title,
    body,
    platformChannelSpecifics,
  );
}
