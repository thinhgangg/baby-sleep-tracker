import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import '../models/alert_settings.dart';
import '../widgets/app_card.dart';

class AlertSettingsScreen extends StatefulWidget {
  const AlertSettingsScreen({super.key});

  @override
  State<AlertSettingsScreen> createState() => _AlertSettingsScreenState();
}

class _AlertSettingsScreenState extends State<AlertSettingsScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  late DatabaseReference _settingsRef;

  AlertSettings _settings = AlertSettings();
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (user != null) {
      _settingsRef = FirebaseDatabase.instance.ref(
        'users/${user!.uid}/settings',
      );
      _loadSettings();
    }
  }

  Future<void> _loadSettings() async {
    final snapshot = await _settingsRef.get();
    if (snapshot.exists) {
      setState(() {
        _settings = AlertSettings.fromMap(snapshot.value as Map?);
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    await _settingsRef.set(_settings.toMap());
    if (mounted) {
      setState(() => _isSaving = false);
      _showSnackBar(message: 'Đã lưu cài đặt thành công', isSuccess: true);
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) Navigator.pop(context);
    }
  }

  void _showSnackBar({required String message, required bool isSuccess}) {
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

  Future<void> _showInputDialog({
    required String title,
    required double currentValue,
    required double minLimit,
    required double maxLimit,
    required String unit,
    required Function(double) onSave,
  }) async {
    final TextEditingController controller = TextEditingController(
      text: currentValue.toStringAsFixed(1),
    );

    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Khoảng cho phép: ${minLimit.toStringAsFixed(1)} - ${maxLimit.toStringAsFixed(1)} $unit",
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                autofocus: true,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  suffix: Text(
                    unit,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF667EEA),
                      width: 2,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!, width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF667EEA),
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Hủy', style: TextStyle(color: Colors.grey[600])),
            ),
            ElevatedButton(
              onPressed: () {
                final double? newValue = double.tryParse(controller.text);
                if (newValue == null) {
                  _showSnackBar(
                    message: 'Vui lòng nhập số hợp lệ',
                    isSuccess: false,
                  );
                  return;
                }

                if (newValue < minLimit || newValue > maxLimit) {
                  _showSnackBar(
                    message:
                        'Giá trị phải từ ${minLimit.toStringAsFixed(1)} đến ${maxLimit.toStringAsFixed(1)} $unit',
                    isSuccess: false,
                  );
                  return;
                }

                onSave(double.parse(newValue.toStringAsFixed(1)));
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF667EEA),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text('Xác nhận'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Scaffold(body: Center(child: Text("Vui lòng đăng nhập")));
    }

    return Stack(
      children: [
        Scaffold(
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
                              "Ngưỡng nhiệt độ & độ ẩm",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            SizedBox(height: 2),
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
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _buildInfoCard(),
                          const SizedBox(height: 20),
                          _buildSectionHeader("NHIỆT ĐỘ BÉ"),
                          _buildSliderGroup(
                            icon: Icons.child_care,
                            iconColor: Colors.pink,
                            title: "Nhiệt độ cơ thể bé",
                            unit: "°C",
                            currentMin: _settings.minBabyTemp,
                            currentMax: _settings.maxBabyTemp,
                            minLimit: 30,
                            maxLimit: 42,
                            onChanged: (min, max) {
                              setState(() {
                                _settings.minBabyTemp = min;
                                _settings.maxBabyTemp = max;
                              });
                            },
                          ),
                          const SizedBox(height: 20),
                          _buildSectionHeader("MÔI TRƯỜNG PHÒNG"),
                          _buildSliderGroup(
                            icon: Icons.thermostat,
                            iconColor: Colors.orange,
                            title: "Nhiệt độ phòng",
                            unit: "°C",
                            currentMin: _settings.minEnvTemp,
                            currentMax: _settings.maxEnvTemp,
                            minLimit: 10,
                            maxLimit: 40,
                            onChanged: (min, max) {
                              setState(() {
                                _settings.minEnvTemp = min;
                                _settings.maxEnvTemp = max;
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildSliderGroup(
                            icon: Icons.water_drop,
                            iconColor: Colors.blue,
                            title: "Độ ẩm phòng",
                            unit: "%",
                            currentMin: _settings.minHum,
                            currentMax: _settings.maxHum,
                            minLimit: 0,
                            maxLimit: 100,
                            onChanged: (min, max) {
                              setState(() {
                                _settings.minHum = min;
                                _settings.maxHum = max;
                              });
                            },
                          ),
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                    _buildSaveButton(),
                  ],
                ),
        ),
        if (_isSaving)
          Container(
            color: Colors.black.withValues(alpha: 0.3),
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
      ],
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

  Widget _buildInfoCard() {
    return AppCard(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.withValues(alpha: 0.1),
              Colors.purple.withValues(alpha: 0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.info_outline,
                color: Colors.blue,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Lưu ý quan trọng",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Ứng dụng sẽ gửi cảnh báo khi các chỉ số vượt ngoài ngưỡng bạn thiết lập. Hãy cân nhắc kỹ trước khi thay đổi.",
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderGroup({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String unit,
    required double currentMin,
    required double currentMax,
    required double minLimit,
    required double maxLimit,
    required Function(double, double) onChanged,
  }) {
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
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildValueChip(
                  label: "Tối thiểu",
                  value: currentMin.toStringAsFixed(1),
                  unit: unit,
                  color: Colors.blue,
                  onTap: () => _showInputDialog(
                    title: "Nhập giá trị tối thiểu",
                    currentValue: currentMin,
                    minLimit: minLimit,
                    maxLimit: currentMax - 0.5,
                    unit: unit,
                    onSave: (value) {
                      onChanged(value, currentMax);
                    },
                  ),
                ),
                _buildValueChip(
                  label: "Tối đa",
                  value: currentMax.toStringAsFixed(1),
                  unit: unit,
                  color: Colors.red,
                  onTap: () => _showInputDialog(
                    title: "Nhập giá trị tối đa",
                    currentValue: currentMax,
                    minLimit: currentMin + 0.5,
                    maxLimit: maxLimit,
                    unit: unit,
                    onSave: (value) {
                      onChanged(currentMin, value);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                activeTrackColor: iconColor,
                inactiveTrackColor: Colors.grey[300],
                thumbColor: iconColor,
                overlayColor: iconColor.withValues(alpha: 0.2),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
                showValueIndicator: ShowValueIndicator.never,
              ),
              child: RangeSlider(
                values: RangeValues(currentMin, currentMax),
                min: minLimit,
                max: maxLimit,
                divisions: (maxLimit - minLimit).toInt() * 10,
                onChanged: (RangeValues values) {
                  if (values.end - values.start >= 0.5) {
                    onChanged(
                      double.parse(values.start.toStringAsFixed(1)),
                      double.parse(values.end.toStringAsFixed(1)),
                    );
                  }
                },
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "$minLimit$unit",
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
                Text(
                  "$maxLimit$unit",
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildValueChip({
    required String label,
    required String value,
    required String unit,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.edit, size: 12, color: Colors.grey[500]),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(width: 2),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    unit,
                    style: TextStyle(
                      fontSize: 13,
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveSettings,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667EEA),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
              disabledBackgroundColor: Colors.grey[300],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(width: 8),
                Text(
                  _isSaving ? "Đang lưu..." : "Lưu thay đổi",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
