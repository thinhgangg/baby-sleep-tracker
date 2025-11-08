import 'package:firebase_database/firebase_database.dart';

class DatabaseServiceUser {
  final String uid;
  DatabaseServiceUser(this.uid);

  DatabaseReference get userRef => FirebaseDatabase.instance.ref('users/$uid');

  Future<String?> getDeviceId() async {
    final snapshot = await userRef.child('deviceId').get();
    if (snapshot.exists) {
      return snapshot.value as String?;
    }
    return null;
  }
}
