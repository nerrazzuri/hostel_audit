DateTime utcNow() => DateTime.now().toUtc();

DateTime utc8Now() => DateTime.now().toUtc().add(const Duration(hours: 8));

DateTime toUtc8(DateTime dt) => dt.toUtc().add(const Duration(hours: 8));

DateTime utc8MidnightBoundaryUtc() {
  // Compute today's midnight in UTC+8, then convert that instant back to UTC
  final nowUtc8 = utc8Now();
  final midnightUtc8 = DateTime.utc(nowUtc8.year, nowUtc8.month, nowUtc8.day);
  // midnightUtc8 is constructed in UTC, representing UTC+8 midnight components, so subtract 8h to get actual UTC instant
  return midnightUtc8.subtract(const Duration(hours: 8));
}

// Given any calendar date, return the UTC instant representing that day's midnight in UTC+8.
DateTime utc8MidnightBoundaryUtcFor(DateTime day) {
  // Treat the provided calendar components as UTC+8 date
  final midnightUtc8 = DateTime.utc(day.year, day.month, day.day);
  return midnightUtc8.subtract(const Duration(hours: 8));
}

