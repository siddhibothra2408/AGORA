import 'package:cloud_firestore/cloud_firestore.dart';

/// Safe Date Parser utility for Firestore / JSON serialization
abstract final class DateParser {
  static DateTime parse(dynamic value, [DateTime? fallback]) {
    if (value == null) return fallback ?? DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) {
      return DateTime.tryParse(value) ?? (fallback ?? DateTime.now());
    }
    return fallback ?? DateTime.now();
  }

  static dynamic toFirestore(DateTime date) {
    return Timestamp.fromDate(date);
  }
}
