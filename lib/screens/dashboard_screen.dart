import 'dart:async';
import 'package:baby_sleep_tracker/screens/settings_screen.dart';
import 'package:baby_sleep_tracker/widgets/app_card.dart';
import 'package:baby_sleep_tracker/widgets/sleep_chart.dart';
import 'package:baby_sleep_tracker/services/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../services/data_service.dart';
import '../services/auth_service.dart';
import '../services/data_service_user.dart';
import '../services/notification_prefs.dart';
import '../models/alert_settings.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  DatabaseServiceUser? _userService;

  StreamSubscription<DatabaseEvent>? _settingsSub;
  AlertSettings _currentSettings = AlertSettings();

  final AuthService _authService = AuthService();

  bool _allowCrying = true;
  bool _allowPosition = true;
  bool _allowTemp = true;

  @override
  void initState() {
    super.initState();
    _userService = (FirebaseAuth.instance.currentUser != null)
        ? DatabaseServiceUser(FirebaseAuth.instance.currentUser!.uid)
        : null;
    if (currentUser != null) {
      _authService.saveFCMToken(currentUser!.uid);
      _saveUserToPrefs(currentUser!.uid);
    }
    _startBackgroundServiceIfNeeded();
    _listenToSettings();
    _loadNotificationPrefs();
  }

  // alert settings
  void _listenToSettings() {
    if (currentUser == null) return;
    final settingsRef = FirebaseDatabase.instance.ref(
      'users/${currentUser!.uid}/settings',
    );
    _settingsSub = settingsRef.onValue.listen((event) {
      if (event.snapshot.exists) {
        if (mounted) {
          setState(() {
            _currentSettings = AlertSettings.fromMap(
              event.snapshot.value as Map?,
            );
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _settingsSub?.cancel();
    super.dispose();
  }

  // notification prefs
  Future<void> _loadNotificationPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _allowCrying =
            prefs.getBool(NotificationPrefs.keyNotifyCrying) ??
            NotificationPrefs.defaultCrying;
        _allowPosition =
            prefs.getBool(NotificationPrefs.keyNotifyPosition) ??
            NotificationPrefs.defaultPosition;
        _allowTemp =
            prefs.getBool(NotificationPrefs.keyNotifyTemp) ??
            NotificationPrefs.defaultTemp;
      });
    }
  }

  Future<void> _saveUserToPrefs(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_uid', uid);
    print("✅ Đã lưu User UID vào SharedPreferences: $uid");
  }

  // Khôi phục trạng thái Service khi mở app
  Future<void> _startBackgroundServiceIfNeeded() async {
    if (currentUser == null) return;

    final prefs = await SharedPreferences.getInstance();
    final String userKey = 'isMonitoringEnabled_${currentUser!.uid}';
    final bool shouldRun = prefs.getBool(userKey) ?? true;

    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();

    if (shouldRun) {
      if (!isRunning) {
        print("🚀 Dashboard: Đang khởi động Background Service...");
        await service.startService();
      }
    } else {
      if (isRunning) {
        service.invoke("stopService");
      }
    }
  }

  // Hàm kiểm tra cảnh báo và hiển thị Local Notification
  void _checkForAlerts(SleepEntry entry) {
    String? alertTitle;
    String? alertBody;
    Color? alertColor;

    // KIỂM TRA CẢNH BÁO
    if (entry.isCrying == true && _allowCrying) {
      alertTitle = "CẢNH BÁO KHÓC!";
      alertBody = "Bé đang khóc! Hãy kiểm tra ngay.";
      alertColor = Colors.orange;
    } else if (entry.notiPosition == true && _allowPosition) {
      alertTitle = "CẢNH BÁO TƯ THẾ!";
      alertBody = "Bé nằm sấp quá lâu! Hãy điều chỉnh tư thế.";
      alertColor = Colors.red;
    } else if (entry.babyTemp != null &&
        (entry.babyTemp! < _currentSettings.minBabyTemp ||
            entry.babyTemp! > _currentSettings.maxBabyTemp)) {
      if (_allowTemp) {
        alertTitle = "CẢNH BÁO NHIỆT ĐỘ!";
        alertBody =
            "Nhiệt độ bé bất thường (${entry.babyTemp}°C)! Hãy kiểm tra ngay.";
        alertColor = Colors.red;
      }
    } else if (entry.envTemp != null &&
        (entry.envTemp! < _currentSettings.minEnvTemp ||
            entry.envTemp! > _currentSettings.maxEnvTemp)) {
      alertTitle = "CẢNH BÁO NHIỆT ĐỘ PHÒNG!";
      alertBody =
          "Nhiệt độ phòng bất thường (${entry.envTemp}°C)! Hãy kiểm tra ngay.";
      alertColor = Colors.red;
    } else if (entry.envHum != null &&
        (entry.envHum! < _currentSettings.minHum ||
            entry.envHum! > _currentSettings.maxHum)) {
      alertTitle = "CẢNH BÁO ĐỘ ẨM PHÒNG!";
      alertBody =
          "Độ ẩm phòng bất thường (${entry.envHum}%)! Hãy kiểm tra ngay.";
      alertColor = Colors.red;
    }

    if (alertTitle != null && mounted) {
      flutterLocalNotificationsPlugin.show(
        0,
        alertTitle,
        alertBody,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            importance: Importance.high,
            priority: Priority.high,
            color: alertColor,
          ),
        ),
      );
    }
  }

  Future<String?> _getDeviceId() async {
    if (_userService == null) return null;
    return await _userService!.getDeviceId();
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return const Center(child: Text("Lỗi: Người dùng chưa đăng nhập."));
    }

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF667EEA).withValues(alpha: 0.8),
                const Color(0xFF764BA2).withValues(alpha: 0.9),
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.child_care,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    "Baby Sleep Tracker",
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    "Theo dõi giấc ngủ của bé",
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          onPressed: () {
                            Navigator.of(context)
                                .push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const SettingsScreen(),
                                  ),
                                )
                                .then((_) {
                                  if (mounted) {
                                    _loadNotificationPrefs();
                                    print(
                                      "🔄 Đã cập nhật lại tùy chọn thông báo",
                                    );
                                  }
                                });
                          },
                          icon: const Icon(
                            Icons.settings,
                            color: Colors.white,
                            size: 32,
                          ),
                          tooltip: "Cài đặt",
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: FutureBuilder<String?>(
        future: _getDeviceId(),
        builder: (context, deviceIdSnapshot) {
          if (deviceIdSnapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingState("Đang xác định thiết bị...");
          }

          final String? deviceId = deviceIdSnapshot.data;

          if (!deviceIdSnapshot.hasData || deviceId == null) {
            return _buildLoadingState("Không tìm thấy ID thiết bị.");
          }

          final DataService dataService = DataService(deviceId: deviceId);

          return StreamBuilder<SleepEntry?>(
            stream: dataService.latestEntryStream,
            builder: (context, snapshot) {
              // 1. Kiểm tra nếu có lỗi (để hiện lỗi đỏ thay vì xoay vòng)
              if (snapshot.hasError) {
                return Center(child: Text("Lỗi dữ liệu: ${snapshot.error}"));
              }

              // 2. Kiểm tra trạng thái đang tải
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildLoadingState("Đang tải dữ liệu thiết bị...");
              }

              final entry = snapshot.data;

              // 3. Nếu dữ liệu null (Thiết bị mới chưa có data)
              if (entry == null) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text("Thiết bị chưa gửi dữ liệu nào."),
                      Text(
                        "ID: $deviceId",
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              _checkForAlerts(entry);
              return _buildDashboardContent(
                context,
                entry,
                dataService,
                deviceId,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildLoadingState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardContent(
    BuildContext context,
    SleepEntry entry,
    DataService dataService,
    String? deviceId,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Card: Trạng thái hiện tại
        AppCard(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    const double breakpoint = 500;
                    final bool isCompact = constraints.maxWidth < breakpoint;

                    final titleWidget = Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF667EEA).withValues(alpha: 0.15),
                                const Color(0xFF764BA2).withValues(alpha: 0.15),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.podcasts,
                            color: Color(0xFF667EEA),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Text(
                          "TRẠNG THÁI HIỆN TẠI",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    );

                    final timeWidget = Text(
                      'Cập nhật: ${_formatTime(entry.timestamp)}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    );

                    if (isCompact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          titleWidget,
                          const SizedBox(height: 6),
                          timeWidget,
                          const SizedBox(height: 20),
                        ],
                      );
                    } else {
                      return Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [titleWidget, timeWidget],
                          ),
                          const SizedBox(height: 20),
                        ],
                      );
                    }
                  },
                ),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatusItem(
                        icon: entry.status == "sleeping"
                            ? Icons.bedtime
                            : Icons.wb_sunny,
                        label: "Trạng thái",
                        value: entry.status == "sleeping" ? "Ngủ" : "Thức",
                        color: entry.status == "sleeping"
                            ? Colors.green
                            : Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatusItem(
                        icon: Icons.volume_up,
                        label: "Khóc",
                        value: entry.isCrying ? "Có" : "Không",
                        color: entry.isCrying ? Colors.red : Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatusItem(
                        icon: Icons.accessibility_new,
                        label: "Tư thế",
                        value: entry.position == "prone"
                            ? "Nằm sấp"
                            : "Nằm ngửa",
                        color: entry.position == "prone"
                            ? Colors.red
                            : Colors.green,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatusItem(
                        icon: Icons.thermostat,
                        label: "Nhiệt độ bé",
                        value: "${entry.babyTemp}°C",
                        color:
                            entry.babyTemp != null &&
                                (entry.babyTemp! <
                                        _currentSettings.minBabyTemp ||
                                    entry.babyTemp! >
                                        _currentSettings.maxBabyTemp)
                            ? Colors.red
                            : Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatusItem(
                        icon: Icons.thermostat_auto,
                        label: "Nhiệt độ phòng",
                        value: "${entry.envTemp}°C",
                        color:
                            entry.envTemp != null &&
                                (entry.envTemp! < _currentSettings.minEnvTemp ||
                                    entry.envTemp! >
                                        _currentSettings.maxEnvTemp)
                            ? Colors.red
                            : Colors.green,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatusItem(
                        icon: Icons.opacity,
                        label: "Độ ẩm",
                        value: "${entry.envHum}%",
                        color:
                            entry.envHum != null &&
                                (entry.envHum! < _currentSettings.minHum ||
                                    entry.envHum! > _currentSettings.maxHum)
                            ? Colors.red
                            : Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Biểu đồ lịch sử
        StreamBuilder<List<SleepEntry>>(
          stream: dataService.historyStream,
          builder: (context, snapshot) {
            final history = snapshot.data ?? [];

            return Column(
              children: [
                const SizedBox(height: 24),
                _buildChartSection(
                  "NHIỆT ĐỘ BÉ (°C)",
                  Icons.thermostat,
                  Colors.red,
                  SleepLineChart(
                    data: history,
                    label: "Baby Temp",
                    valueGetter: (e) => e.babyTemp ?? 0,
                    lineColor: Colors.red,
                    safeMin: _currentSettings.minBabyTemp,
                    safeMax: _currentSettings.maxBabyTemp,
                  ),
                ),
                const SizedBox(height: 24),
                _buildChartSection(
                  "NHIỆT ĐỘ PHÒNG (°C)",
                  Icons.thermostat_auto,
                  Colors.orange,
                  SleepLineChart(
                    data: history,
                    label: "Room Temp",
                    valueGetter: (e) => e.envTemp ?? 0,
                    lineColor: Colors.orange,
                    safeMin: _currentSettings.minEnvTemp,
                    safeMax: _currentSettings.maxEnvTemp,
                  ),
                ),
                const SizedBox(height: 24),
                _buildChartSection(
                  "ĐỘ ẨM PHÒNG (%)",
                  Icons.opacity,
                  Colors.blue,
                  SleepLineChart(
                    data: history,
                    label: "Humidity",
                    valueGetter: (e) => e.envHum ?? 0,
                    lineColor: Colors.blue,
                    safeMin: _currentSettings.minHum,
                    safeMax: _currentSettings.maxHum,
                  ),
                ),
                const SizedBox(height: 20),
              ],
            );
          },
        ),

        // Card: Mã liên kết thiết bị
        AppCard(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tiêu đề với icon
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF667EEA).withValues(alpha: 0.15),
                            const Color(0xFF764BA2).withValues(alpha: 0.15),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.qr_code,
                        color: Color(0xFF667EEA),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text(
                        "Mã liên kết thiết bị",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Container chứa QR code và nút copy
                Center(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!, width: 1),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: QrImageView(
                      data: 'babysleep://link/device?id=$deviceId',
                      version: QrVersions.auto,
                      size: 200.0,
                      gapless: false,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Color(0xFF667EEA),
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Color(0xFF764BA2),
                      ),
                      embeddedImage: const AssetImage('assets/logo.png'),
                      embeddedImageStyle: QrEmbeddedImageStyle(
                        size: const Size(40, 40),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Mã ID thô và nút Copy
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!, width: 1),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "ID thiết bị",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              "••••••••",
                              style: TextStyle(
                                fontSize: 20,
                                letterSpacing: 2.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF667EEA),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Material(
                        color: const Color(0xFF667EEA),
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          onTap: deviceId != null
                              ? () {
                                  Clipboard.setData(
                                    ClipboardData(text: deviceId),
                                  );
                                }
                              : null,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.copy, color: Colors.white, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  "Sao chép",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Mô tả
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 18, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Quét mã QR hoặc chia sẻ ID thiết bị để người thân liên kết với thiết bị theo dõi.",
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Footer
        Center(
          child: Text(
            "© 2025 Baby Sleep Tracker",
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ),

        const SizedBox(height: 16),
      ],
    );
  }

  String _formatTime(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      return DateFormat('HH:mm:ss dd/MM/yyyy').format(dateTime.toLocal());
    } catch (e) {
      return 'Giờ không hợp lệ';
    }
  }

  Widget _buildStatusItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection(
    String title,
    IconData icon,
    Color color,
    Widget chart,
  ) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withValues(alpha: 0.15),
                        color.withValues(alpha: 0.15),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 14),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            chart,
          ],
        ),
      ),
    );
  }
}
