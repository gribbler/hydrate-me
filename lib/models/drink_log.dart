class DrinkLog {
  final int? id;
  final DateTime timestamp;
  final double amountMl;

  const DrinkLog({
    this.id,
    required this.timestamp,
    required this.amountMl,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'timestamp': timestamp.toIso8601String(),
        'amountMl': amountMl,
      };

  factory DrinkLog.fromMap(Map<String, dynamic> map) => DrinkLog(
        id: map['id'] as int?,
        timestamp: DateTime.parse(map['timestamp'] as String),
        amountMl: (map['amountMl'] as num).toDouble(),
      );
}
