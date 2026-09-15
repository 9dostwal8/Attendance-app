import 'package:flutter/foundation.dart';
import 'package:attendance_app/providers/attendance_provider.dart';

void main() {
  final provider = AttendanceProvider();
  for (var group in provider.groups) {
    debugPrint(group.annualLeaveAdditionType);
  }
}
