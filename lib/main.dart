import 'dart:async';
import 'package:baby_sleep_tracker/screens/dashboard_screen.dart';
import 'package:baby_sleep_tracker/services/notification_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'screens/auth_screen.dart';
import 'services/background_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await NotificationService().initialize();
  await registerFirebaseMessagingBackgroundHandler();
  await initializeService();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Baby Sleep Tracker',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF764BA2)),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  // Biến lưu trạng thái mạng
  List<ConnectivityResult> _connectionStatus = [ConnectivityResult.none];
  final Connectivity _connectivity = Connectivity();
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    NotificationService().initialize();
    _initConnectivity();

    // Lắng nghe sự thay đổi trạng thái mạng (Bật/Tắt WiFi, 4G)
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _updateConnectionStatus,
    );
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  // Hàm kiểm tra mạng lần đầu khi mở app
  Future<void> _initConnectivity() async {
    late List<ConnectivityResult> result;
    try {
      result = await _connectivity.checkConnectivity();
    } catch (e) {
      result = [ConnectivityResult.none];
    }

    if (!mounted) return;

    // Cập nhật trạng thái và tắt loading
    setState(() {
      _connectionStatus = result;
      _isChecking = false;
    });
  }

  void _updateConnectionStatus(List<ConnectivityResult> result) {
    if (mounted) {
      setState(() {
        _connectionStatus = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Nếu đang kiểm tra mạng lần đầu thì hiện loading
    if (_isChecking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // 2. Nếu KHÔNG CÓ MẠNG -> Hiển thị màn hình lỗi ngay lập tức
    // Chặn không cho vào AuthScreen hay DashboardScreen
    if (_connectionStatus.contains(ConnectivityResult.none) ||
        _connectionStatus.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.wifi_off_rounded, size: 80, color: Colors.grey[400]),
                const SizedBox(height: 24),
                const Text(
                  "Mất kết nối Internet",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF764BA2),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Vui lòng kiểm tra WiFi hoặc dữ liệu di động để tiếp tục sử dụng ứng dụng.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () async {
                    setState(() => _isChecking = true);
                    await _initConnectivity();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text("Thử lại"),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                    backgroundColor: const Color(0xFF667EEA),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 3. Nếu CÓ MẠNG -> Mới bắt đầu luồng xác thực (Vào AuthScreen hoặc Dashboard)
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        // Đang chờ Firebase xác thực
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Chưa đăng nhập -> Vào AuthScreen
        if (!authSnapshot.hasData || authSnapshot.data == null) {
          return const AuthScreen();
        }

        // Đã đăng nhập -> Kiểm tra Device ID để vào Dashboard
        final User user = authSnapshot.data!;
        final DatabaseReference userRef = FirebaseDatabase.instance.ref(
          'users/${user.uid}',
        );

        return StreamBuilder<DatabaseEvent>(
          stream: userRef.onValue,
          builder: (context, userDbSnapshot) {
            if (userDbSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            // Xử lý lỗi Firebase (nếu có)
            if (userDbSnapshot.hasError) {
              return const AuthScreen(); // Fallback về Auth nếu lỗi data
            }

            final userData =
                userDbSnapshot.data?.snapshot.value as Map<dynamic, dynamic>?;

            if (userData != null && userData.containsKey('deviceId')) {
              return const DashboardScreen();
            } else {
              // Có user nhưng chưa có deviceId -> Quay lại AuthScreen bước nhập ID
              return const AuthScreen(initialStep: 'device_id');
            }
          },
        );
      },
    );
  }
}
