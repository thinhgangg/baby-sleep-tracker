import 'dart:async';
import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../firebase_options.dart';
import '../models/alert_settings.dart';
import '../services/notification_prefs.dart';

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
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'my_foreground',
      initialNotificationTitle: 'Baby Sleep Tracker',
      initialNotificationContent: 'Đang chờ kết nối...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(autoStart: false, onForeground: onStart),
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
  StreamSubscription<DatabaseEvent>? _settingsSubscription;
  Timer? _timer;

  // Biến lưu cài đặt hiện tại của Service
  AlertSettings _currentSettings = AlertSettings();

  service.on('stopService').listen((event) {
    print("🛑 Nhận lệnh dừng Service...");
    _dataSubscription?.cancel();
    _settingsSubscription?.cancel();
    _timer?.cancel();
    service.stopSelf();
  });

  _timer = Timer.periodic(const Duration(seconds: 5), (timer) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    final String? uid = prefs.getString('user_uid');

    if (uid != null) {
      print("✅ Background Service: Đã tìm thấy UID: $uid -> Bắt đầu thiết lập");
      timer.cancel();

      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: "Baby Sleep Tracker",
          content: "Đang giám sát giấc ngủ của bé...",
        );
      }

      final userRef = FirebaseDatabase.instance.ref("users/$uid");
      final snapshot = await userRef.get();
      final userData = snapshot.value as Map?;

      if (userData != null && userData.containsKey('deviceId')) {
        final String deviceId = userData['deviceId'];
        print("📱 Device ID: $deviceId");

        // --- 1. LẮNG NGHE SETTINGS THAY ĐỔI ---
        final settingsRef = FirebaseDatabase.instance.ref(
          "users/$uid/settings",
        );

        _settingsSubscription?.cancel();

        _settingsSubscription = settingsRef.onValue.listen((event) {
          if (event.snapshot.exists) {
            final val = event.snapshot.value as Map?;
            _currentSettings = AlertSettings.fromMap(val);
            print(
              "⚙️ Background Service: Cập nhật Settings mới: "
              "Temp: ${_currentSettings.minBabyTemp}-${_currentSettings.maxBabyTemp}",
            );
          } else {
            print("⚠️ Không tìm thấy Settings tùy chỉnh, dùng mặc định.");
          }
        });

        // --- 2. LẮNG NGHE DỮ LIỆU CẢM BIẾN ---
        print("📡 Bắt đầu lắng nghe dữ liệu Sleep Data...");
        Query dataQuery = FirebaseDatabase.instance
            .ref("sleepData/$deviceId")
            .orderByKey()
            .limitToLast(1);

        _dataSubscription?.cancel();
        _dataSubscription = dataQuery.onValue.listen((event) async {
          final rawMap = event.snapshot.value as Map?;
          if (rawMap != null && rawMap.isNotEmpty) {
            final latestData = rawMap.values.first;
            _processSensorData(latestData, _currentSettings);
          }
        });
      } else {
        print("❌ User này chưa có Device ID, service sẽ chờ...");
      }
    } else {
      print("⏳ Background Service: Chưa thấy User UID. Đang chờ...");
    }
  });
}

void _processSensorData(dynamic data, AlertSettings settings) async {
  if (data is! Map) return;

  final prefs = await SharedPreferences.getInstance();

  await prefs.reload();

  final bool allowCrying =
      prefs.getBool(NotificationPrefs.keyNotifyCrying) ??
      NotificationPrefs.defaultCrying;
  final bool allowPosition =
      prefs.getBool(NotificationPrefs.keyNotifyPosition) ??
      NotificationPrefs.defaultPosition;
  final bool allowTemp =
      prefs.getBool(NotificationPrefs.keyNotifyTemp) ??
      NotificationPrefs.defaultTemp;

  print(
    "⚙️ BG Check - Khóc: $allowCrying | Tư thế: $allowPosition | Nhiệt độ: $allowTemp",
  );

  final bool isCrying = data['isCrying'] == true;
  final bool notiPosition = data['notiPosition'] == true;
  final double? babyTemp = data['babyTemperature'] != null
      ? double.tryParse(data['babyTemperature'].toString())
      : null;
  final double? envTemp = data['environmentTemperature'] != null
      ? double.tryParse(data['environmentTemperature'].toString())
      : null;
  final double? envHum = data['environmentHumidity'] != null
      ? double.tryParse(data['environmentHumidity'].toString())
      : null;

  if (isCrying && allowCrying) {
    _showAlarmNotification(
      "CẢNH BÁO KHÓC!",
      "Bé đang khóc! Hãy kiểm tra ngay.",
    );
  } else if (notiPosition && allowPosition) {
    _showAlarmNotification(
      "CẢNH BÁO TƯ THẾ!",
      "Bé nằm sấp quá lâu! Hãy điều chỉnh tư thế.",
    );
  } else if (babyTemp != null &&
      (babyTemp < settings.minBabyTemp || babyTemp > settings.maxBabyTemp)) {
    if (allowTemp) {
      _showAlarmNotification(
        "CẢNH BÁO NHIỆT ĐỘ!",
        "Nhiệt độ bé bất thường ($babyTemp°C)! Hãy kiểm tra ngay.",
      );
    }
  } else if (envTemp != null &&
      (envTemp < settings.minEnvTemp || envTemp > settings.maxEnvTemp)) {
    _showAlarmNotification(
      "CẢNH BÁO NHIỆT ĐỘ MÔI TRƯỜNG!",
      "Nhiệt độ môi trường bất thường ($envTemp°C)! Hãy kiểm tra ngay.",
    );
  } else if (envHum != null &&
      (envHum < settings.minHum || envHum > settings.maxHum)) {
    _showAlarmNotification(
      "CẢNH BÁO ĐỘ ẨM MÔI TRƯỜNG!",
      "Độ ẩm môi trường bất thường ($envHum%)! Hãy kiểm tra ngay.",
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
