import 'package:baby_sleep_tracker/screens/dashboard_screen.dart';
import 'package:baby_sleep_tracker/services/notification_service.dart';
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
  @override
  void initState() {
    super.initState();
    NotificationService().initialize();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (!authSnapshot.hasData || authSnapshot.data == null) {
          return const AuthScreen();
        }

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

            final userData =
                userDbSnapshot.data?.snapshot.value as Map<dynamic, dynamic>?;

            if (userData != null && userData.containsKey('deviceId')) {
              return const DashboardScreen();
            } else {
              return const AuthScreen(initialStep: 'device_id');
            }
          },
        );
      },
    );
  }
}
