import 'package:baby_sleep_tracker/widgets/app_card.dart';
import 'package:baby_sleep_tracker/widgets/sleep_chart.dart';
import 'package:baby_sleep_tracker/services/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../services/data_service.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/data_service_user.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  DatabaseServiceUser? _userService;

  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _userService = (FirebaseAuth.instance.currentUser != null)
        ? DatabaseServiceUser(FirebaseAuth.instance.currentUser!.uid)
        : null;
    if (currentUser != null) {
      _authService.saveFCMToken(currentUser!.uid);
    }
  }

  // Hàm kiểm tra cảnh báo và hiển thị Local Notification
  void _checkForAlerts(SleepEntry entry) {
    String? alertTitle;
    String? alertBody;
    Color? alertColor;

    // KIỂM TRA CẢNH BÁO
    if (entry.isCrying == true) {
      alertTitle = "⚠️ CẢNH BÁO KHÓC!";
      alertBody = "Bé đang khóc! Hãy kiểm tra ngay.";
      alertColor = Colors.orange;
    } else if (entry.notiPosition == true) {
      alertTitle = "⚠️ CẢNH BÁO TƯ THẾ!";
      alertBody = "Bé nằm sấp quá lâu! Hãy điều chỉnh tư thế.";
      alertColor = Colors.red;
    } else if (entry.babyTemp != null &&
        (entry.babyTemp! < 35 || entry.babyTemp! > 37.5)) {
      alertTitle = "⚠️ CẢNH BÁO NHIỆT ĐỘ!";
      alertBody =
          "Bé có nhiệt độ bất thường (${entry.babyTemp}°C)! Hãy kiểm tra ngay.";
      alertColor = Colors.red;
    }

    if (alertTitle != null && mounted) {
      // CHỈ HIỂN THỊ LOCAL NOTIFICATION KHI APP ĐANG CHẠY FOREGROUND
      // Khi app ở Background/Đóng, Cloud Function sẽ gửi Push Notification
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
                const Color(0xFF667EEA).withOpacity(0.8),
                const Color(0xFF764BA2).withOpacity(0.9),
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
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.child_care,
                                color: Colors.white,
                                size: 28,
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
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          onPressed: () async =>
                              FirebaseAuth.instance.signOut(),
                          icon: const Icon(Icons.logout, color: Colors.white),
                          tooltip: "Đăng xuất",
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
              final entry = snapshot.data;

              if (!snapshot.hasData || entry == null) {
                return _buildLoadingState("Đang tải dữ liệu thiết bị...");
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
                                const Color(0xFF667EEA).withOpacity(0.15),
                                const Color(0xFF764BA2).withOpacity(0.15),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.bar_chart,
                            color: Color(0xFF667EEA),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Text(
                          "Trạng thái hiện tại",
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
                        icon: Icons.bedtime,
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
                        icon: Icons.child_care,
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
                        icon: Icons.airline_seat_recline_normal,
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
                                (entry.babyTemp! < 35 || entry.babyTemp! > 37.5)
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
                        icon: Icons.device_thermostat,
                        label: "Nhiệt độ phòng",
                        value: "${entry.envTemp}°C",
                        color:
                            entry.envTemp != null &&
                                (entry.envTemp! < 20 || entry.envTemp! > 35)
                            ? Colors.red
                            : Colors.green,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatusItem(
                        icon: Icons.water_drop,
                        label: "Độ ẩm",
                        value: "${entry.envHum}%",
                        color:
                            entry.envHum != null &&
                                (entry.envHum! < 30 || entry.envHum! > 70)
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
                  "Nhiệt độ bé (°C)",
                  Icons.thermostat,
                  Colors.red,
                  SleepLineChart(
                    data: history,
                    label: "Baby Temp",
                    valueGetter: (e) => e.babyTemp ?? 0,
                    lineColor: Colors.red,
                  ),
                ),
                const SizedBox(height: 24),
                _buildChartSection(
                  "Nhiệt độ phòng (°C)",
                  Icons.device_thermostat,
                  Colors.orange,
                  SleepLineChart(
                    data: history,
                    label: "Room Temp",
                    valueGetter: (e) => e.envTemp ?? 0,
                    lineColor: Colors.orange,
                  ),
                ),
                const SizedBox(height: 24),
                _buildChartSection(
                  "Độ ẩm phòng (%)",
                  Icons.water_drop,
                  Colors.blue,
                  SleepLineChart(
                    data: history,
                    label: "Humidity",
                    valueGetter: (e) => e.envHum ?? 0,
                    lineColor: Colors.blue,
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
                            const Color(0xFF667EEA).withOpacity(0.15),
                            const Color(0xFF764BA2).withOpacity(0.15),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.link,
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

                // Container chứa mã và nút copy
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
                              "Mã của bạn",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              "••••••••••",
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
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Row(
                                        children: [
                                          Icon(
                                            Icons.check_circle,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                          SizedBox(width: 8),
                                          Text('Đã sao chép mã vào clipboard'),
                                        ],
                                      ),
                                      backgroundColor: Colors.green[700],
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      duration: const Duration(seconds: 2),
                                    ),
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
                        "Chia sẻ mã này cho người dùng khác để liên kết cùng thiết bị và theo dõi dữ liệu chung.",
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
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
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
                        color.withOpacity(0.15),
                        color.withOpacity(0.15),
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
