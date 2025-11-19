import 'package:baby_sleep_tracker/widgets/app_card.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _monitoringKey = 'isMonitoringEnabled';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isMonitoringEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadMonitoringState();
  }

  Future<void> _loadMonitoringState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // Đặt mặc định là true nếu chưa có giá trị lưu trữ
      _isMonitoringEnabled = prefs.getBool(_monitoringKey) ?? true;
    });
  }

  Future<void> _toggleMonitoring(bool newValue) async {
    final prefs = await SharedPreferences.getInstance();

    // Lưu trạng thái mới vào SharedPreferences
    await prefs.setBool(_monitoringKey, newValue);

    setState(() {
      _isMonitoringEnabled = newValue;
    });

    final service = FlutterBackgroundService();

    if (newValue) {
      print("Tính năng giám sát đã được BẬT.");
      service.startService();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Giám sát tự động đã được bật'),
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
    } else {
      print("Tính năng giám sát đã được TẮT.");
      service.invoke("stopService");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.info, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Giám sát tự động đã được tắt'),
            ],
          ),
          backgroundColor: Colors.orange[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _signOut() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.logout, color: Colors.red),
              SizedBox(width: 12),
              Text('Xác nhận đăng xuất'),
            ],
          ),
          content: const Text(
            'Bạn có chắc chắn muốn đăng xuất khỏi ứng dụng?',
            style: TextStyle(fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Hủy',
                style: TextStyle(color: Colors.grey[600], fontSize: 15),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Đăng xuất',
                style: TextStyle(color: Colors.white, fontSize: 15),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      if (_isMonitoringEnabled) {
        await _toggleMonitoring(false);
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_uid');
      print("🗑️ Đã xóa User UID khỏi bộ nhớ");

      await FirebaseAuth.instance.signOut();

      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                            size: 24,
                          ),
                          tooltip: "Quay lại",
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Row(
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Cài đặt",
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
                                    "Quản lý ứng dụng của bạn",
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
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Card: Giám sát Tự động
          AppCard(
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
                              (_isMonitoringEnabled
                                      ? Colors.green
                                      : Colors.grey)
                                  .withOpacity(0.15),
                              (_isMonitoringEnabled
                                      ? Colors.green
                                      : Colors.grey)
                                  .withOpacity(0.15),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.bedtime,
                          color: _isMonitoringEnabled
                              ? Colors.green
                              : Colors.grey,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Text(
                          "Giám sát Tự động",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      Switch(
                        value: _isMonitoringEnabled,
                        onChanged: _toggleMonitoring,
                        activeColor: Colors.green,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color:
                          (_isMonitoringEnabled ? Colors.green : Colors.orange)
                              .withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            (_isMonitoringEnabled
                                    ? Colors.green
                                    : Colors.orange)
                                .withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _isMonitoringEnabled
                              ? Icons.check_circle_outline
                              : Icons.info_outline,
                          size: 20,
                          color: _isMonitoringEnabled
                              ? Colors.green[700]
                              : Colors.orange[700],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _isMonitoringEnabled
                                ? "Ứng dụng đang theo dõi liên tục trạng thái của bé và gửi cảnh báo khi cần thiết."
                                : "Giám sát đang tắt. Bạn sẽ không nhận được cảnh báo về tình trạng của bé.",
                            style: TextStyle(
                              color: _isMonitoringEnabled
                                  ? Colors.green[700]
                                  : Colors.orange[700],
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Card: Đăng xuất
          AppCard(
            child: InkWell(
              onTap: _signOut,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.red.withOpacity(0.15),
                            Colors.red.withOpacity(0.15),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.logout,
                        color: Colors.red,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Đăng xuất",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                              letterSpacing: 0.3,
                            ),
                          ),
                          SizedBox(height: 4),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.red[300], size: 28),
                  ],
                ),
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
      ),
    );
  }
}
