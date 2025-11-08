import 'package:baby_sleep_tracker/screens/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'screens/auth_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        // 1. Nếu chưa đăng nhập, hiển thị màn hình Auth
        if (!authSnapshot.hasData || authSnapshot.data == null) {
          return const AuthScreen();
        }

        // Người dùng đã đăng nhập (currentUser != null)
        final User user = authSnapshot.data!;

        // 2. TẠO Stream để kiểm tra dữ liệu DB (deviceId)
        final DatabaseReference userRef = FirebaseDatabase.instance.ref(
          'users/${user.uid}',
        );

        // Lắng nghe sự thay đổi của node users/$uid
        return StreamBuilder<DatabaseEvent>(
          stream: userRef.onValue,
          builder: (context, userDbSnapshot) {
            if (userDbSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            // Dùng onValue nên value là DatabaseEvent, cần lấy snapshot.value
            final userData =
                userDbSnapshot.data?.snapshot.value as Map<dynamic, dynamic>?;

            // 3. KIỂM TRA ĐIỀU KIỆN CHUYỂN MÀN HÌNH: Đã đăng nhập VÀ có deviceId
            if (userData != null && userData.containsKey('deviceId')) {
              // ĐÃ HOÀN TẤT ĐĂNG KÝ VÀ CÓ DEVICE ID -> CHUYỂN ĐẾN DASHBOARD
              return DashboardScreen();
            } else {
              // ĐÃ ĐĂNG NHẬP NHƯNG CHƯA HOÀN TẤT ĐĂNG KÝ DEVICE ID -> BUỘC TRỞ LẠI AUTHSCREEN
              // Truyền initialStep để AuthScreen biết phải hiển thị bước nhập Device ID
              return const AuthScreen(initialStep: 'device_id');
            }
          },
        );
      },
    );
  }
}
