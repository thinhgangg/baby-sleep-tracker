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
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Bỏ qua lỗi nếu Firebase đã được khởi tạo
  }

  StreamSubscription<DatabaseEvent>? _dataSubscription;
  Timer? _timer;

  service.on('stopService').listen((event) {
    print("🛑 Nhận lệnh dừng Service...");
    _dataSubscription?.cancel();
    _timer?.cancel();
    service.stopSelf();
  });

  _timer = Timer.periodic(const Duration(seconds: 5), (timer) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    final String? uid = prefs.getString('user_uid');

    if (uid != null) {
      print("✅ Background Service: Đã tìm thấy UID: $uid -> Bắt đầu giám sát");
      timer.cancel();

      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: "Baby Sleep Tracker",
          content: "Đang giám sát giấc ngủ của bé...",
        );
      }

      _dataSubscription = await _startListeningToFirebase(uid);
    } else {
      print("⏳ Background Service: Chưa thấy User UID. Đang chờ...");
    }
  });
}

Future<StreamSubscription<DatabaseEvent>?> _startListeningToFirebase(
  String uid,
) async {
  try {
    // 1. Lấy Device ID
    final userRef = FirebaseDatabase.instance.ref("users/$uid");
    final snapshot = await userRef.get();

    final userData = snapshot.value as Map?;
    if (userData != null && userData.containsKey('deviceId')) {
      final String deviceId = userData['deviceId'];
      print("📱 Device ID tìm thấy: $deviceId -> Bắt đầu lắng nghe data...");

      // 2. Lắng nghe dữ liệu tại sleepData/$deviceId
      Query dataQuery = FirebaseDatabase.instance
          .ref("sleepData/$deviceId")
          .orderByKey()
          .limitToLast(1);

      // Trả về Subscription để onStart quản lý
      return dataQuery.onValue.listen((event) {
        final rawMap = event.snapshot.value as Map?;

        if (rawMap != null && rawMap.isNotEmpty) {
          final latestData = rawMap.values.first;
          print("📡 Dữ liệu nền nhận được: $latestData");
          _processSensorData(latestData);
        }
      });
    } else {
      print("❌ User này chưa có Device ID");
      return null;
    }
  } catch (e) {
    print("❌ Lỗi Background Service: $e");
    return null;
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
