import 'package:firebase_database/firebase_database.dart';

class SleepEntry {
  final String timestamp;
  final String status;
  final bool isCrying;
  final double? babyTemp;
  final double? envTemp;
  final double? envHum;
  final String position;
  final bool notiPosition;

  SleepEntry({
    required this.timestamp,
    required this.status,
    required this.isCrying,
    this.babyTemp,
    this.envTemp,
    this.envHum,
    required this.position,
    required this.notiPosition,
  });

  factory SleepEntry.fromMap(Map data) {
    return SleepEntry(
      timestamp: data['timestamp'] ?? '',
      status: data['status'] ?? 'N/A',
      isCrying: data['isCrying'] ?? false,
      babyTemp: (data['babyTemperature'] as num?)?.toDouble() ?? 0.0,
      envTemp: (data['environmentTemperature'] as num?)?.toDouble() ?? 0.0,
      envHum: (data['environmentHumidity'] as num?)?.toDouble() ?? 0.0,
      position: data['sleepPosition'] ?? 'N/A',
      notiPosition: data['notiPosition'] ?? false,
    );
  }
}

class DataService {
  final _db = FirebaseDatabase.instance.ref();
  final String deviceId;

  DataService({required this.deviceId});

  Stream<SleepEntry?> get latestEntryStream {
    return _db.child('sleepData/$deviceId').limitToLast(1).onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) return null;

      final rawData = event.snapshot.value;
      if (rawData is! Map) return null;

      final dataMap = Map<dynamic, dynamic>.from(rawData);
      if (dataMap.isEmpty) return null;

      final latestData = dataMap.values.first;
      return SleepEntry.fromMap(Map<dynamic, dynamic>.from(latestData));
    });
  }

  Stream<List<SleepEntry>> get historyStream {
    return _db.child('sleepData/$deviceId').limitToLast(36).onValue.map((
      event,
    ) {
      if (!event.snapshot.exists || event.snapshot.value == null) return [];

      final rawData = event.snapshot.value;
      if (rawData is! Map) return [];

      final data = Map<dynamic, dynamic>.from(rawData);
      final sortedEntries = data.entries.toList();

      sortedEntries.sort((a, b) {
        final timestampA = (a.value as Map)['timestamp'] ?? '';
        final timestampB = (b.value as Map)['timestamp'] ?? '';
        return timestampA.compareTo(timestampB);
      });

      return sortedEntries.map((entry) {
        return SleepEntry.fromMap(
          Map<dynamic, dynamic>.from(entry.value as Map),
        );
      }).toList();
    });
  }
}
