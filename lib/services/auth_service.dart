import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _db = FirebaseDatabase.instance;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  FirebaseDatabase get db => _db;
  User? get currentUser => _auth.currentUser;

  // 1. GỬI OTP
  Future<void> sendOTP({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _auth.signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          onError(_handleFirebaseError(e));
        },
        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      onError('Lỗi hệ thống: ${e.toString()}');
    }
  }

  // 2. XÁC THỰC OTP
  Future<User?> verifyOTP({
    required String verificationId,
    required String otp,
  }) async {
    if (verificationId.isEmpty) {
      throw 'Verification ID bị thiếu. Vui lòng gửi OTP lại.';
    }

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );

      final userCred = await _auth.signInWithCredential(credential);
      return userCred.user;
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseError(e);
    } catch (e) {
      throw 'Lỗi hệ thống: ${e.toString()}';
    }
  }

  // 3. ĐĂNG KÝ DEVICE ID
  Future<void> registerDeviceId({
    required String uid,
    required String deviceId,
    required String phoneNumber,
  }) async {
    await _db.ref('users/$uid').update({
      'deviceId': deviceId.trim(),
      'phone': phoneNumber,
    });
  }

  Future<void> saveFCMToken(String uid) async {
    final fcmToken = await _fcm.getToken();
    if (fcmToken != null) {
      await _db.ref('users/$uid').update({'fcmToken': fcmToken});
    }
  }

  // 4. KIỂM TRA DEVICE ID
  Future<bool> hasDeviceId(String uid) async {
    final snapshot = await _db.ref('users/$uid/deviceId').get();
    return snapshot.exists && snapshot.value != null;
  }

  Future<void> signOut() async => await _auth.signOut();

  String _handleFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'Số điện thoại không hợp lệ.';
      case 'quota-exceeded':
        return 'Đã vượt quá hạn mức yêu cầu OTP. Vui lòng thử lại sau.';
      case 'session-expired':
        return 'Mã xác thực đã hết hạn. Vui lòng gửi lại.';
      case 'invalid-verification-code':
        return 'Mã xác thực không đúng. Vui lòng kiểm tra lại.';
      default:
        return 'Lỗi Firebase: ${e.message}';
    }
  }

  Future<bool> checkDeviceExist(String deviceId) async {
    final snapshot = await _db.ref('sleepData/$deviceId').limitToLast(1).get();
    return snapshot.exists;
  }
}
