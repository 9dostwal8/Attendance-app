class AttendanceRecord {
  final DateTime checkIn;
  final DateTime? checkOut;
  final String? employeeId;

  AttendanceRecord({
    required DateTime checkIn,
    DateTime? checkOut,
    this.employeeId,
  }) : checkIn = DateTime(checkIn.year, checkIn.month, checkIn.day, checkIn.hour, checkIn.minute),
       checkOut = checkOut != null ? DateTime(checkOut.year, checkOut.month, checkOut.day, checkOut.hour, checkOut.minute) : null;

  bool get isCompleted => checkOut != null;

  Duration get duration {
    final tIn = DateTime(checkIn.year, checkIn.month, checkIn.day, checkIn.hour, checkIn.minute);
    if (checkOut == null) {
      final now = DateTime.now();
      final isToday = checkIn.year == now.year && checkIn.month == now.month && checkIn.day == now.day;
      if (!isToday) {
        return Duration.zero;
      }
      final tNow = DateTime(now.year, now.month, now.day, now.hour, now.minute);
      return tNow.difference(tIn);
    }
    final tOut = DateTime(checkOut!.year, checkOut!.month, checkOut!.day, checkOut!.hour, checkOut!.minute);
    return tOut.difference(tIn);
  }

  String get durationString {
    final dur = duration;
    final hours = dur.inHours;
    final minutes = dur.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  AttendanceRecord copyWith({
    DateTime? checkIn,
    DateTime? checkOut,
    String? employeeId,
  }) {
    return AttendanceRecord(
      checkIn: checkIn ?? this.checkIn,
      checkOut: checkOut ?? this.checkOut,
      employeeId: employeeId ?? this.employeeId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'checkIn': checkIn.toIso8601String(),
      'checkOut': checkOut?.toIso8601String(),
      'employeeId': employeeId,
    };
  }

  factory AttendanceRecord.fromMap(Map<String, dynamic> map, [String? employeeId]) {
    DateTime parsedIn = DateTime.now();
    if (map['checkIn'] != null && map['checkIn'].toString().isNotEmpty) {
      parsedIn = DateTime.tryParse(map['checkIn'].toString()) ?? DateTime.now();
    }
    DateTime? parsedOut;
    if (map['checkOut'] != null && map['checkOut'].toString().isNotEmpty) {
      parsedOut = DateTime.tryParse(map['checkOut'].toString());
    }
    final empId = (map['employeeId'] != null && map['employeeId'].toString().isNotEmpty)
        ? map['employeeId'].toString()
        : employeeId;
    return AttendanceRecord(
      checkIn: parsedIn,
      checkOut: parsedOut,
      employeeId: empId,
    );
  }
}
