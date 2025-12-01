class AlertSettings {
  double minBabyTemp;
  double maxBabyTemp;
  double minEnvTemp;
  double maxEnvTemp;
  double minHum;
  double maxHum;

  AlertSettings({
    this.minBabyTemp = 36.5,
    this.maxBabyTemp = 37.5,
    this.minEnvTemp = 20.0,
    this.maxEnvTemp = 30.0,
    this.minHum = 40.0,
    this.maxHum = 60.0,
  });

  factory AlertSettings.fromMap(Map<dynamic, dynamic>? data) {
    if (data == null) return AlertSettings();
    return AlertSettings(
      minBabyTemp: (data['minBabyTemp'] as num?)?.toDouble() ?? 36.0,
      maxBabyTemp: (data['maxBabyTemp'] as num?)?.toDouble() ?? 37.5,
      minEnvTemp: (data['minEnvTemp'] as num?)?.toDouble() ?? 20.0,
      maxEnvTemp: (data['maxEnvTemp'] as num?)?.toDouble() ?? 30.0,
      minHum: (data['minHum'] as num?)?.toDouble() ?? 40.0,
      maxHum: (data['maxHum'] as num?)?.toDouble() ?? 70.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'minBabyTemp': minBabyTemp,
      'maxBabyTemp': maxBabyTemp,
      'minEnvTemp': minEnvTemp,
      'maxEnvTemp': maxEnvTemp,
      'minHum': minHum,
      'maxHum': maxHum,
    };
  }
}
