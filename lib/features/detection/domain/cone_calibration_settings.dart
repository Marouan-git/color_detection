/// Settings for cone calibration, persisted via SharedPreferences.
class ConeCalibrationSettings {
  /// Height multiplier for the cone (1.0 = default, 0.5 = half, 2.0 = double)
  final double heightMultiplier;

  /// Rotation angle in degrees (0, 30, 60, 90, 120, 150, 180, 210, 240, 270, 300, 330)
  /// 0 = up (default), 90 = right, 180 = down, 270 = left
  final int rotationAngle;

  const ConeCalibrationSettings({
    this.heightMultiplier = 1.0,
    this.rotationAngle = 0,
  });

  ConeCalibrationSettings copyWith({
    double? heightMultiplier,
    int? rotationAngle,
  }) {
    return ConeCalibrationSettings(
      heightMultiplier: heightMultiplier ?? this.heightMultiplier,
      rotationAngle: rotationAngle ?? this.rotationAngle,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'heightMultiplier': heightMultiplier,
      'rotationAngle': rotationAngle,
    };
  }

  factory ConeCalibrationSettings.fromJson(Map<String, dynamic> json) {
    return ConeCalibrationSettings(
      heightMultiplier: (json['heightMultiplier'] as num?)?.toDouble() ?? 1.0,
      rotationAngle: (json['rotationAngle'] as int?) ?? 0,
    );
  }

  @override
  String toString() =>
      'ConeCalibrationSettings(height: ${heightMultiplier}x, rotation: $rotationAngle°)';
}
