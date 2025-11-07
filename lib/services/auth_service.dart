import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<User?> signIn(String email, String password) async {
    try {
      final userCred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      return userCred.user;
    } catch (e) {
      if (e is FirebaseAuthException) {
        throw _handleFirebaseError(e);
      }
      throw Exception('Lỗi hệ thống: ${e.toString()}');
    }
  }

  Future<User?> signUp(String email, String password, String deviceId) async {
    try {
      final userCred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await _db.ref('user/${userCred.user!.uid}').set({
        'deviceId': deviceId.trim(),
        'email': email,
      });

      return userCred.user;
    } catch (e) {
      if (e is FirebaseAuthException) {
        throw _handleFirebaseError(e);
      }
      throw Exception('Lỗi hệ thống: ${e.toString()}');
    }
  }

  Future<void> signOut() async => await _auth.signOut();

  String _handleFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
        return 'Email hoặc mật khẩu không đúng.';
      case 'invalid-email':
        return 'Email không hợp lệ.';
      case 'user-disabled':
        return 'Tài khoản đã bị vô hiệu hóa.';
      case 'email-already-in-use':
        return 'Email này đã được sử dụng.';
      case 'weak-password':
        return 'Mật khẩu quá yếu (tối thiểu 6 ký tự).';
      case 'too-many-requests':
        return 'Quá nhiều yêu cầu. Vui lòng thử lại sau.';
      default:
        return e.message ?? 'Đã xảy ra lỗi. Vui lòng thử lại.';
    }
  }
}
