import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/providers/attendance_provider.dart';

void main() {
  test('Find null field', () {
    final provider = AttendanceProvider();
    for (var group in provider.groups) {
      debugPrint('Group ID: ${group.id}');
      try {
        group.name;
        group.annualLeaveAdditionType;
        group.shiftId;
      } catch (e, st) {
        debugPrint('Error in group properties: $e\n$st');
      }
    }
  });
}
