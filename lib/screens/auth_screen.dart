import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthScreen extends StatefulWidget {
  final String initialStep;
  const AuthScreen({super.key, this.initialStep = 'phone'});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  final _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _deviceIdController = TextEditingController();

  bool _loading = false;
  String _verificationId = '';
  late String _currentStep;
  String _currentPhoneNumber = '';

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _currentStep = widget.initialStep;

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _deviceIdController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.warning_amber_rounded : Icons.check_circle,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.orange[700] : Colors.green[700],
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _formatPhoneNumber(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');

    if (cleaned.startsWith('0')) {
      return '+84${cleaned.substring(1)}';
    } else if (cleaned.startsWith('84')) {
      return '+$cleaned';
    } else if (cleaned.startsWith('+84')) {
      return cleaned;
    }
    return '+84$cleaned';
  }

  // 1. GỬI OTP
  Future<void> _sendOTP() async {
    if (!_formKey.currentState!.validate()) return;

    final phone = _phoneController.text.trim();
    final formattedPhone = _formatPhoneNumber(phone);

    setState(() => _loading = true);

    await _authService.sendOTP(
      phoneNumber: formattedPhone,
      onCodeSent: (verificationId) {
        if (mounted) {
          setState(() {
            _verificationId = verificationId;
            _currentPhoneNumber = formattedPhone;
            _currentStep = 'otp';
            _loading = false;
            _otpController.clear();
          });
          _showSnackBar('Mã OTP đã được gửi đến ${_phoneController.text}');
        }
      },
      onError: (error) {
        if (mounted) {
          _showSnackBar(error, isError: true);
          setState(() => _loading = false);
        }
      },
    );
  }

  // 2. XÁC THỰC OTP
  Future<void> _verifyOTP() async {
    if (!_formKey.currentState!.validate()) return;

    final otp = _otpController.text.trim();
    if (_verificationId.isEmpty) {
      _showSnackBar('Vui lòng gửi lại mã OTP', isError: true);
      return;
    }

    setState(() => _loading = true);

    try {
      final user = await _authService.verifyOTP(
        verificationId: _verificationId,
        otp: otp,
      );

      if (user != null && mounted) {
        // Kiểm tra xem user đã có Device ID chưa
        final hasDevice = await _authService.hasDeviceId(user.uid);

        if (hasDevice) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_uid', user.uid);
          print("💾 Đã lưu User UID vào SharedPreferences: ${user.uid}");

          // User cũ -> AuthGate sẽ tự động chuyển đến Dashboard
          setState(() => _loading = false);
          _showSnackBar('Đăng nhập thành công!');
        } else {
          // User mới -> Yêu cầu nhập Device ID để hoàn tất đăng ký
          setState(() {
            _currentStep = 'device_id';
            _loading = false;
          });
          _showSnackBar(
            'Vui lòng nhập ID thiết bị để hoàn tất đăng ký',
            isError: false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(e.toString(), isError: true);
        setState(() => _loading = false);
      }
    }
  }

  // 3. ĐĂNG KÝ DEVICE ID
  Future<void> _registerDeviceAndComplete() async {
    if (!_formKey.currentState!.validate()) return;

    final deviceId = _deviceIdController.text.trim();

    setState(() => _loading = true);

    try {
      final user = _authService.currentUser;
      if (user != null) {
        await _authService.registerDeviceId(
          uid: user.uid,
          deviceId: deviceId,
          phoneNumber: user.phoneNumber ?? _currentPhoneNumber,
        );

        await _authService.saveFCMToken(user.uid);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_uid', user.uid);
        print("💾 Đã lưu User UID vào SharedPreferences: ${user.uid}");

        if (mounted) {
          _showSnackBar('Đăng ký thiết bị thành công!');
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(e.toString(), isError: true);
        setState(() => _loading = false);
      }
    }
  }

  Widget _buildCurrentStepContent() {
    Widget content;
    String title;
    String subtitle;
    VoidCallback onSubmit;

    switch (_currentStep) {
      case 'phone':
        content = _buildPhoneInput();
        title = "Đăng nhập";
        subtitle = "Nhập số điện thoại để nhận mã OTP";
        onSubmit = _sendOTP;
        break;
      case 'otp':
        content = _buildOTPInput();
        title = "Xác thực OTP";
        subtitle = "Nhập mã OTP đã được gửi đến ${_phoneController.text}";
        onSubmit = _verifyOTP;
        break;
      case 'device_id':
        content = _buildDeviceIdInput();
        title = "Hoàn tất đăng ký";
        subtitle = "Nhập ID thiết bị để bắt đầu theo dõi";
        onSubmit = _registerDeviceAndComplete;
        break;
      default:
        content = _buildPhoneInput();
        title = "Đăng nhập";
        subtitle = "Nhập số điện thoại để nhận mã OTP";
        onSubmit = _sendOTP;
        break;
    }

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          content,

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _loading ? null : onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF667EEA),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey[300],
                elevation: _loading ? 0 : 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_getButtonIcon(), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          _getButtonText(title),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 12),
          if (_currentStep == 'otp' && !_loading)
            TextButton(
              onPressed: () {
                setState(() => _currentStep = 'phone');
                _otpController.clear();
              },
              child: const Text(
                "Gửi lại mã OTP",
                style: TextStyle(
                  color: Color(0xFF667EEA),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPhoneInput() {
    return TextFormField(
      controller: _phoneController,
      enabled: !_loading,
      keyboardType: TextInputType.phone,
      decoration: InputDecoration(
        labelText: "Số điện thoại",
        prefixIcon: const Icon(Icons.phone_outlined, color: Color(0xFF764BA2)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      validator: (val) {
        if (val == null || val.isEmpty) {
          return 'Vui lòng nhập số điện thoại.';
        }
        final cleaned = val.replaceAll(RegExp(r'[^\d]'), '');
        if (cleaned.length < 9 || cleaned.length > 12) {
          return 'Số điện thoại không hợp lệ.';
        }
        return null;
      },
      onFieldSubmitted: (_) => _sendOTP(),
    );
  }

  Widget _buildOTPInput() {
    return TextFormField(
      controller: _otpController,
      enabled: !_loading,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: "Mã OTP",
        prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF764BA2)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      validator: (val) {
        if (val == null || val.length != 6) {
          return 'Mã xác thực phải gồm 6 chữ số.';
        }
        return null;
      },
      onFieldSubmitted: (_) => _verifyOTP(),
    );
  }

  Widget _buildDeviceIdInput() {
    return TextFormField(
      controller: _deviceIdController,
      enabled: !_loading,
      decoration: InputDecoration(
        labelText: "ID Thiết bị",
        prefixIcon: const Icon(Icons.devices_other, color: Color(0xFF764BA2)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      validator: (val) {
        if (val == null || val.isEmpty) {
          return 'Vui lòng nhập ID thiết bị.';
        }
        return null;
      },
      onFieldSubmitted: (_) => _registerDeviceAndComplete(),
    );
  }

  IconData _getButtonIcon() {
    switch (_currentStep) {
      case 'phone':
        return Icons.send;
      case 'otp':
        return Icons.verified;
      case 'device_id':
        return Icons.check_circle;
      default:
        return Icons.arrow_forward;
    }
  }

  String _getButtonText(String currentTitle) {
    switch (_currentStep) {
      case 'phone':
        return 'GỬI MÃ OTP';
      case 'otp':
        return 'XÁC THỰC';
      case 'device_id':
        return 'HOÀN TẤT ĐĂNG KÝ';
      default:
        return 'TIẾP TỤC';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
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
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.child_care,
                        size: 64,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Baby Sleep Tracker",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                          shadows: [
                            Shadow(
                              color: Colors.black38,
                              offset: Offset(0, 2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Card(
                          elevation: 8,
                          shadowColor: Colors.black.withOpacity(0.3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: _buildCurrentStepContent(),
                              transitionBuilder:
                                  (Widget child, Animation<double> animation) {
                                    final offsetAnimation = Tween<Offset>(
                                      begin: const Offset(1.0, 0.0),
                                      end: Offset.zero,
                                    ).animate(animation);
                                    return SlideTransition(
                                      position: offsetAnimation,
                                      child: child,
                                    );
                                  },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      Text(
                        "© 2025 Baby Sleep Tracker",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
