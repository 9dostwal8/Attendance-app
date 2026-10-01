import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/models/hr_models.dart';

void main() {
  group('3-Day Rotation Shift Tests', () {
    final shift3Day = WorkShift(
      id: 'shift_3day',
      name: '3-Day Rolling Shift',
      startTime: '08:00',
      endTime: '16:00',
      isRotation: true,
      rotationDays: 3,
      rotationStartDate: '2026-10-01', // Thursday
      rotationSchedule: {
        1: DayShiftConfig(isWorkingDay: true, startTime: '08:00', endTime: '16:00'),
        2: DayShiftConfig(isWorkingDay: true, startTime: '16:00', endTime: '00:00'),
        3: DayShiftConfig(isWorkingDay: false, startTime: '08:00', endTime: '16:00'),
      },
    );

    test('Cycle repeats correctly every 3 days', () {
      // Day 1 (Oct 1)
      final d1 = DateTime(2026, 10, 1);
      expect(shift3Day.getRotationDayForDate(d1), 1);
      expect(shift3Day.isWorkingDay(d1), isTrue);
      expect(shift3Day.getStartTimeForDate(d1), '08:00');
      expect(shift3Day.getEndTimeForDate(d1), '16:00');

      // Day 2 (Oct 2)
      final d2 = DateTime(2026, 10, 2);
      expect(shift3Day.getRotationDayForDate(d2), 2);
      expect(shift3Day.isWorkingDay(d2), isTrue);
      expect(shift3Day.getStartTimeForDate(d2), '16:00');
      expect(shift3Day.getEndTimeForDate(d2), '00:00');

      // Day 3 (Oct 3 - Off)
      final d3 = DateTime(2026, 10, 3);
      expect(shift3Day.getRotationDayForDate(d3), 3);
      expect(shift3Day.isWorkingDay(d3), isFalse);

      // Day 4 (Oct 4 - Cycles back to Day 1)
      final d4 = DateTime(2026, 10, 4);
      expect(shift3Day.getRotationDayForDate(d4), 1);
      expect(shift3Day.isWorkingDay(d4), isTrue);
      expect(shift3Day.getStartTimeForDate(d4), '08:00');

      // Day 5 (Oct 5 - Day 2)
      final d5 = DateTime(2026, 10, 5);
      expect(shift3Day.getRotationDayForDate(d5), 2);
      expect(shift3Day.isWorkingDay(d5), isTrue);

      // Day 6 (Oct 6 - Day 3 Off)
      final d6 = DateTime(2026, 10, 6);
      expect(shift3Day.getRotationDayForDate(d6), 3);
      expect(shift3Day.isWorkingDay(d6), isFalse);

      // Day 7 (Oct 7 - Day 1 again)
      final d7 = DateTime(2026, 10, 7);
      expect(shift3Day.getRotationDayForDate(d7), 1);
      expect(shift3Day.isWorkingDay(d7), isTrue);
    });

    test('Serialization toMap and fromMap preserves rotationDays & rotationStartDate', () {
      final map = shift3Day.toMap();
      expect(map['rotationDays'], 3);
      expect(map['rotationStartDate'], '2026-10-01');
      expect(map['isRotation'], isTrue);

      final restored = WorkShift.fromMap(map, 'shift_3day');
      expect(restored.rotationDays, 3);
      expect(restored.rotationStartDate, '2026-10-01');
      expect(restored.isRotation, isTrue);
      expect(restored.isWorkingDay(DateTime(2026, 10, 1)), isTrue);
      expect(restored.isWorkingDay(DateTime(2026, 10, 3)), isFalse);
      expect(restored.isWorkingDay(DateTime(2026, 10, 4)), isTrue);
    });
  });

  group('Legacy 7-Day Weekly Schedule Compatibility', () {
    test('Defaults to weekday mapping when rotationStartDate is empty', () {
      final legacyWeeklyShift = WorkShift(
        id: 'legacy_weekly',
        name: 'Legacy Weekly Shift',
        startTime: '09:00',
        endTime: '17:00',
        isRotation: true,
        rotationDays: 7,
        rotationStartDate: '', // Empty start date
        weeklySchedule: {
          DateTime.monday: DayShiftConfig(isWorkingDay: true, startTime: '09:00', endTime: '17:00'),
          DateTime.tuesday: DayShiftConfig(isWorkingDay: true, startTime: '09:00', endTime: '17:00'),
          DateTime.wednesday: DayShiftConfig(isWorkingDay: true, startTime: '09:00', endTime: '17:00'),
          DateTime.thursday: DayShiftConfig(isWorkingDay: true, startTime: '09:00', endTime: '17:00'),
          DateTime.friday: DayShiftConfig(isWorkingDay: false, startTime: '09:00', endTime: '17:00'),
          DateTime.saturday: DayShiftConfig(isWorkingDay: false, startTime: '09:00', endTime: '17:00'),
          DateTime.sunday: DayShiftConfig(isWorkingDay: true, startTime: '09:00', endTime: '17:00'),
        },
      );

      // Oct 1, 2026 is Thursday (weekday 4)
      expect(legacyWeeklyShift.isWorkingDay(DateTime(2026, 10, 1)), isTrue);
      // Oct 2, 2026 is Friday (weekday 5 - configured as false)
      expect(legacyWeeklyShift.isWorkingDay(DateTime(2026, 10, 2)), isFalse);
    });
  });
}
