class VoiceLimitsConfig {
  /// Максимальная длительность записи голосового сообщения в секундах (3 минуты)
  static const int maxDurationSeconds = 180;

  /// Время в секундах до окончания записи, когда нужно показать предупреждение (10 секунд)
  static const int warningThresholdSeconds = 10;
}
