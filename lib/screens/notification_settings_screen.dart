import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_prefs.dart';
import '../widgets/app_card.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _notifyCrying = true;
  bool _notifyPosition = true;
  bool _notifyTemp = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notifyCrying =
          prefs.getBool(NotificationPrefs.keyNotifyCrying) ??
          NotificationPrefs.defaultCrying;
      _notifyPosition =
          prefs.getBool(NotificationPrefs.keyNotifyPosition) ??
          NotificationPrefs.defaultPosition;
      _notifyTemp =
          prefs.getBool(NotificationPrefs.keyNotifyTemp) ??
          NotificationPrefs.defaultTemp;
      _isLoading = false;
    });
  }

  Future<void> _updatePreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    setState(() {
      if (key == NotificationPrefs.keyNotifyCrying) _notifyCrying = value;
      if (key == NotificationPrefs.keyNotifyPosition) _notifyPosition = value;
      if (key == NotificationPrefs.keyNotifyTemp) _notifyTemp = value;
    });

    _showSnackBar(
      message: value ? 'Đã bật thông báo' : 'Đã tắt thông báo',
      isSuccess: value,
      duration: const Duration(milliseconds: 500),
    );
  }

  void _showSnackBar({
    required String message,
    required bool isSuccess,
    required Duration duration,
  }) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.info_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isSuccess ? Colors.green[700] : Colors.orange[800],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
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
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
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
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text(
                          "Cài đặt thông báo",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
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
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF667EEA)),
            )
          : ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 20.0,
              ),
              children: [
                _buildSectionHeader("LOẠI THÔNG BÁO"),

                _buildNotificationCard(
                  title: "Cảnh báo Khóc",
                  subtitle: "Nhận thông báo khi phát hiện tiếng khóc của bé",
                  icon: Icons.volume_up,
                  iconColor: Colors.orange,
                  value: _notifyCrying,
                  onChanged: (val) =>
                      _updatePreference(NotificationPrefs.keyNotifyCrying, val),
                ),
                const SizedBox(height: 16),

                _buildNotificationCard(
                  title: "Cảnh báo Tư thế",
                  subtitle: "Nhận thông báo khi bé nằm sấp quá lâu",
                  icon: Icons.accessibility_new,
                  iconColor: Colors.red,
                  value: _notifyPosition,
                  onChanged: (val) => _updatePreference(
                    NotificationPrefs.keyNotifyPosition,
                    val,
                  ),
                ),
                const SizedBox(height: 16),

                _buildNotificationCard(
                  title: "Cảnh báo Nhiệt độ",
                  subtitle:
                      "Nhận thông báo khi nhiệt độ bé vượt ngưỡng an toàn",
                  icon: Icons.thermostat,
                  iconColor: Colors.blue,
                  value: _notifyTemp,
                  onChanged: (val) =>
                      _updatePreference(NotificationPrefs.keyNotifyTemp, val),
                ),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildNotificationCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeTrackColor: const Color(0xFF667EEA),
            ),
          ],
        ),
      ),
    );
  }
}
