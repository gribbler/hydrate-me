enum Gender { male, female }

enum ActivityLevel { sedentary, moderate, active }

enum UnitSystem { metric, imperial }

class UserProfile {
  final Gender gender;
  final double weightKg;
  final double heightCm;
  final int wakeHour;
  final int wakeMinute;
  final int sleepHour;
  final int sleepMinute;
  final ActivityLevel activityLevel;
  final UnitSystem unitSystem;
  final double cupSizeMl;

  const UserProfile({
    required this.gender,
    required this.weightKg,
    required this.heightCm,
    required this.wakeHour,
    required this.wakeMinute,
    required this.sleepHour,
    required this.sleepMinute,
    required this.activityLevel,
    required this.unitSystem,
    required this.cupSizeMl,
  });

  UserProfile copyWith({
    Gender? gender,
    double? weightKg,
    double? heightCm,
    int? wakeHour,
    int? wakeMinute,
    int? sleepHour,
    int? sleepMinute,
    ActivityLevel? activityLevel,
    UnitSystem? unitSystem,
    double? cupSizeMl,
  }) {
    return UserProfile(
      gender: gender ?? this.gender,
      weightKg: weightKg ?? this.weightKg,
      heightCm: heightCm ?? this.heightCm,
      wakeHour: wakeHour ?? this.wakeHour,
      wakeMinute: wakeMinute ?? this.wakeMinute,
      sleepHour: sleepHour ?? this.sleepHour,
      sleepMinute: sleepMinute ?? this.sleepMinute,
      activityLevel: activityLevel ?? this.activityLevel,
      unitSystem: unitSystem ?? this.unitSystem,
      cupSizeMl: cupSizeMl ?? this.cupSizeMl,
    );
  }

  Map<String, dynamic> toMap() => {
        'gender': gender.index,
        'weightKg': weightKg,
        'heightCm': heightCm,
        'wakeHour': wakeHour,
        'wakeMinute': wakeMinute,
        'sleepHour': sleepHour,
        'sleepMinute': sleepMinute,
        'activityLevel': activityLevel.index,
        'unitSystem': unitSystem.index,
        'cupSizeMl': cupSizeMl,
      };

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
        gender: Gender.values[map['gender'] as int],
        weightKg: (map['weightKg'] as num).toDouble(),
        heightCm: (map['heightCm'] as num).toDouble(),
        wakeHour: map['wakeHour'] as int,
        wakeMinute: map['wakeMinute'] as int,
        sleepHour: map['sleepHour'] as int,
        sleepMinute: map['sleepMinute'] as int,
        activityLevel: ActivityLevel.values[map['activityLevel'] as int],
        unitSystem: UnitSystem.values[map['unitSystem'] as int],
        cupSizeMl: (map['cupSizeMl'] as num).toDouble(),
      );

  static UserProfile get defaults => const UserProfile(
        gender: Gender.male,
        weightKg: 80,
        heightCm: 175,
        wakeHour: 7,
        wakeMinute: 0,
        sleepHour: 22,
        sleepMinute: 0,
        activityLevel: ActivityLevel.moderate,
        unitSystem: UnitSystem.metric,
        cupSizeMl: 250,
      );
}
