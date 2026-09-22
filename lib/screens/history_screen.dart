import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/attendance_provider.dart';
import '../models/hr_models.dart';
import '../models/attendance_record.dart';
import '../models/request_model.dart';
import '../widgets/glass_container.dart';
import '../services/export_service.dart';
import '../widgets/new_request_dialog.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String? _selectedEmployeeId;
  List<AttendanceRecord> _subordinateRecords = [];
  List<Request> _subordinateRequests = [];
  bool _isLoadingSubordinate = false;
  DateTime _reportMonth = DateTime.now();
  DateTime? _selectedDate;

  final ScrollController _tableHorizontalController = ScrollController();
  final ScrollController _tableVerticalController = ScrollController();

  @override
  void initState() {
    super.initState();
    if (_selectedEmployeeId != null && _selectedEmployeeId!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final provider = Provider.of<AttendanceProvider>(context, listen: false);
        _loadSubordinateRecords(provider, _selectedEmployeeId!);
      });
    }
  }

  @override
  void dispose() {
    _tableHorizontalController.dispose();
    _tableVerticalController.dispose();
    super.dispose();
  }

  List<CompanyEmployee> _getSubordinates(AttendanceProvider provider) {
    final currentUser = provider.currentEmployee;
    if (currentUser == null) return [];

    if (currentUser.role == 'hr' || currentUser.role == 'admin' || provider.canEditCompanyInfo) {
      final list = <CompanyEmployee>[currentUser];
      for (var e in provider.employees) {
        if (e.id != currentUser.id) {
          list.add(e);
        }
      }
      return list;
    }

    if (currentUser.role == 'supervisor') {
      final Set<String> subordinateIds = {};
      final List<CompanyEmployee> list = [currentUser];

      // 1. Get employees in structures supervised directly by this user
      final supervisedStructures = provider.structures
          .where((s) => s.supervisorId == currentUser.id)
          .map((s) => s.id)
          .toList();

      for (var structId in supervisedStructures) {
        final emps = provider.employees.where(
          (e) => e.id != currentUser.id && e.structureId == structId,
        );
        for (var e in emps) {
          if (subordinateIds.add(e.id)) {
            list.add(e);
          }
        }
      }

      // 2. Fallback: Lookup by current user's structureId
      if (currentUser.structureId != null &&
          currentUser.structureId!.isNotEmpty) {
        final emps = provider.employees.where(
          (e) =>
              e.id != currentUser.id &&
              e.structureId == currentUser.structureId &&
              e.role == 'employee',
        );
        for (var e in emps) {
          if (subordinateIds.add(e.id)) {
            list.add(e);
          }
        }
      }

      return list;
    }

    return [currentUser];
  }

  String? _currentlyLoadingId;

  void _loadSubordinateRecords(
    AttendanceProvider provider,
    String empId,
  ) async {
    if (_isLoadingSubordinate && _currentlyLoadingId == empId) return;

    setState(() {
      _isLoadingSubordinate = true;
      _currentlyLoadingId = empId;
      _selectedEmployeeId = empId;
    });

    try {
      final records = await provider.getEmployeeRecords(empId);
      final requests = await provider.getEmployeeRequests(empId);

      if (mounted) {
        setState(() {
          _subordinateRecords = records;
          _subordinateRequests = requests;
          _isLoadingSubordinate = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingSubordinate = false;
        });
      }
    }
  }

  String formatMinutes(int minutes) {
    if (minutes <= 0) return '-';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AttendanceProvider>(context);

    final subordinates = _getSubordinates(provider);

    // Monthly Report Data Compilation Logic
    List<Map<String, dynamic>> compiledData = [];
    {
      final totalDays = DateUtils.getDaysInMonth(
        _reportMonth.year,
        _reportMonth.month,
      );
      final List<DateTime> datesInPeriod = List.generate(
        totalDays,
        (index) => DateTime(_reportMonth.year, _reportMonth.month, index + 1),
      );

      final activeEmpId = _selectedEmployeeId ?? provider.currentEmployee?.id ?? provider.employeeId;
      final isCurrentUser = activeEmpId == provider.currentEmployee?.id;
      final recordsToCompile = _subordinateRecords.isNotEmpty
          ? _subordinateRecords
          : (isCurrentUser && provider.records.isNotEmpty
              ? provider.records
              : _subordinateRecords);
      final requestsToCompile = _subordinateRequests.isNotEmpty
          ? _subordinateRequests
          : (isCurrentUser && provider.requests.isNotEmpty
              ? provider.requests
              : _subordinateRequests);

      // Resolve Employee and Shift
      final emp = provider.employees.firstWhere(
        (e) => e.id == activeEmpId,
        orElse: () => provider.currentEmployee ?? CompanyEmployee(id: activeEmpId, name: 'Employee', email: '', position: ''),
      );

      for (var date in datesInPeriod) {
        final activeGroupId = provider.getGroupIdForDate(emp, date);
        EmployeeGroup? group;
        WorkShift? shift;
        try {
          group = provider.groups.firstWhere((g) => g.id == activeGroupId);
          shift = provider.shifts.firstWhere((s) => s.id == group!.shiftId);
        } catch (_) {}

        // Override shift if there's an approved Change Shift request
        for (var req in requestsToCompile) {
          if (req.status == 'Approved' &&
              req.type == 'Change Shift' &&
              req.targetShiftId != null) {
            try {
              final dateStr = req.date;
              DateTime start;
              DateTime end;
              if (dateStr.contains(' - ')) {
                final parts = dateStr.split(' - ');
                end = DateFormat('MMMM d, yyyy').parse(parts[1].trim());
                String startStr = parts[0].trim();
                if (!startStr.contains(',')) {
                  startStr = '$startStr, ${end.year}';
                }
                start = DateFormat('MMMM d, yyyy').parse(startStr);
              } else {
                start = DateFormat('MMMM d, yyyy').parse(dateStr.trim());
                end = start;
              }

              final target = DateTime(date.year, date.month, date.day);
              final startOnly = DateTime(start.year, start.month, start.day);
              final endOnly = DateTime(end.year, end.month, end.day);

              if ((target.isAtSameMomentAs(startOnly) ||
                      target.isAfter(startOnly)) &&
                  (target.isAtSameMomentAs(endOnly) ||
                      target.isBefore(endOnly))) {
                shift = provider.shifts.firstWhere(
                  (s) => s.id == req.targetShiftId,
                );
                break;
              }
            } catch (_) {}
          }
        }

        shift ??= WorkShift(
          id: 'default',
          name: 'Standard Shift',
          startTime: '09:00',
          endTime: '17:00',
          forgivenessOfDelay: 15,
          earlyExit: 10,
          breakDurationMinutes: 60,
        );

        final startTimeStr = shift.getStartTimeForDate(date);
        final endTimeStr = shift.getEndTimeForDate(date);
        final partsStart = startTimeStr.split(':');
        final partsEnd = endTimeStr.split(':');
        final shiftStartMinutes = partsStart.length >= 2
            ? int.parse(partsStart[0]) * 60 + int.parse(partsStart[1])
            : 540; // Default 09:00
        final shiftEndMinutes = partsEnd.length >= 2
            ? int.parse(partsEnd[0]) * 60 + int.parse(partsEnd[1])
            : 1020; // Default 17:00

        final dateRecords = recordsToCompile
            .where(
              (rec) =>
                  rec.checkIn.year == date.year &&
                  rec.checkIn.month == date.month &&
                  rec.checkIn.day == date.day,
            )
            .toList();

        int totalActualMinutes = 0;
        int dutyMinutes = 0;
        int restMinutes = 0;
        int unexcusedRestMinutes = 0;
        int delayMinutes = 0;
        int earlyExitMinutes = 0;
        int extraTimeMinutes = 0;
        int overtimeMinutes = 0;
        String clockTimeStr = '-';
        double penaltyAmount = 0.0;
        bool hasRecord = dateRecords.isNotEmpty;
        List<Request> dateApprovedRequests = [];
        bool hasLeaveRequest = false;
        List<Request> allDayRequests = [];
        for (var req in requestsToCompile) {
          try {
            final dateStr = req.date;
            DateTime start;
            DateTime end;

            if (dateStr.contains(' - ')) {
              final parts = dateStr.split(' - ');
              end = DateFormat('MMMM d, yyyy').parse(parts[1].trim());
              String startStr = parts[0].trim();
              if (!startStr.contains(',')) {
                startStr = '$startStr, ${end.year}';
              }
              start = DateFormat('MMMM d, yyyy').parse(startStr);
            } else {
              start = DateFormat('MMMM d, yyyy').parse(dateStr.trim());
              end = start;
            }

            final target = DateTime(date.year, date.month, date.day);
            final startOnly = DateTime(start.year, start.month, start.day);
            final endOnly = DateTime(end.year, end.month, end.day);

            if ((target.isAtSameMomentAs(startOnly) ||
                    target.isAfter(startOnly)) &&
                (target.isAtSameMomentAs(endOnly) ||
                    target.isBefore(endOnly))) {
              allDayRequests.add(req);
              if (req.status == 'Approved' && req.type != 'Missing Punch') {
                dateApprovedRequests.add(req);
                if (req.type.contains('Leave')) {
                  hasLeaveRequest = true;
                }
              }
            }
          } catch (e) {
            // Ignore parsing errors
          }
        }

        final dateStrForMissingPunch = DateFormat('MMMM d, yyyy').format(date);
        final missingPunchReqs = requestsToCompile
            .where(
              (req) =>
                  req.type == 'Missing Punch' &&
                  req.date == dateStrForMissingPunch &&
                  req.status == 'Approved',
            )
            .toList();
        final hasApprovedMissingPunch = missingPunchReqs.isNotEmpty;

        List<String> missingPunchTimes = [];
        for (var req in missingPunchReqs) {
          final duration = req.duration;
          if (duration.contains('Clock In:') ||
              duration.contains('Clock Out:')) {
            final timeStr = duration
                .replaceAll('Clock In:', '')
                .replaceAll('Clock Out:', '')
                .trim();
            try {
              final parsedTime =
                  timeStr.contains('AM') || timeStr.contains('PM')
                  ? DateFormat('hh:mm a').parse(timeStr)
                  : DateFormat('HH:mm').parse(timeStr);
              missingPunchTimes.add(DateFormat('HH:mm').format(parsedTime));
            } catch (_) {}
          }
        }

        if (hasApprovedMissingPunch && !hasRecord) {
          final missingPunchReq = missingPunchReqs.first;
          final duration = missingPunchReq.duration;
          if (duration.contains('Clock In:') &&
              duration.contains('Clock Out:')) {
            final inTime = duration
                .split('Clock Out:')[0]
                .replaceAll('Clock In:', '')
                .trim();
            final outTime = duration.split('Clock Out:')[1].trim();
            clockTimeStr = '$inTime - $outTime';
          } else {
            clockTimeStr = duration;
          }
        }

        if (hasRecord) {
          final sortedRecords = List<AttendanceRecord>.from(dateRecords)
            ..sort((a, b) => a.checkIn.compareTo(b.checkIn));

          // Format session times
          final List<String> sessionTimes = [];
          final isToday = DateUtils.isSameDay(date, DateTime.now());
          for (var rec in sortedRecords) {
            final isMissedCheckIn = rec.checkIn == rec.checkOut;
            final startStr = isMissedCheckIn
                ? '--:--'
                : DateFormat('HH:mm').format(rec.checkIn);
            final endStr = rec.checkOut != null
                ? DateFormat('HH:mm').format(rec.checkOut!)
                : (isToday
                      ? provider.translate('active')
                      : provider.translate('missing'));
            sessionTimes.add('$startStr - $endStr');
          }
          clockTimeStr = sessionTimes.join('\n');

          int totalExcusedRestMinutes = 0;

          final breakStartStr = shift.getBreakStartForDate(date);
          final breakEndStr = shift.getBreakEndForDate(date);
          final allowedBreakDuration = shift.getBreakDurationForDate(date);

          DateTime? bStart;
          DateTime? bEnd;
          if (breakStartStr.isNotEmpty &&
              breakEndStr.isNotEmpty &&
              allowedBreakDuration > 0) {
            final bsParts = breakStartStr.split(':');
            final beParts = breakEndStr.split(':');
            if (bsParts.length >= 2 && beParts.length >= 2) {
              bStart = DateTime(
                date.year,
                date.month,
                date.day,
                int.parse(bsParts[0]),
                int.parse(bsParts[1]),
              );
              bEnd = DateTime(
                date.year,
                date.month,
                date.day,
                int.parse(beParts[0]),
                int.parse(beParts[1]),
              );
              if (bEnd.isBefore(bStart)) {
                bEnd = bEnd.add(const Duration(days: 1));
              }
            }
          }

          // Calculate rest minutes (gap between sessions)
          if (sortedRecords.length > 1) {
            for (int i = 0; i < sortedRecords.length - 1; i++) {
              final currentOut = sortedRecords[i].checkOut;
              final nextIn = sortedRecords[i + 1].checkIn;
              if (currentOut != null && nextIn.isAfter(currentOut)) {
                final gapDuration = nextIn.difference(currentOut).inMinutes;
                if (bStart != null && bEnd != null) {
                  // Find intersection of gap with break window
                  final intersectStart = currentOut.isAfter(bStart)
                      ? currentOut
                      : bStart;
                  final intersectEnd = nextIn.isBefore(bEnd) ? nextIn : bEnd;

                  int excusedInGap = 0;
                  if (intersectEnd.isAfter(intersectStart)) {
                    excusedInGap = intersectEnd
                        .difference(intersectStart)
                        .inMinutes;
                  }

                  // Limit total excused across all gaps to allowedBreakDuration
                  if (totalExcusedRestMinutes + excusedInGap >
                      allowedBreakDuration) {
                    excusedInGap =
                        allowedBreakDuration - totalExcusedRestMinutes;
                    if (excusedInGap < 0) excusedInGap = 0;
                  }

                  totalExcusedRestMinutes += excusedInGap;
                  restMinutes +=
                      excusedInGap; // Only count excused rest time in the UI column
                  unexcusedRestMinutes += (gapDuration - excusedInGap);
                } else {
                  unexcusedRestMinutes += gapDuration;
                }
              }
            }
          }

          // 1. Sum Attendance (all worked minutes on this day)
          for (var rec in dateRecords) {
            totalActualMinutes += rec.duration.inMinutes;
          }

          // 2. Duty Time (worked minutes that fall within the shift bounds)
          for (var rec in dateRecords) {
            final rawStart = rec.checkIn;
            final rawEnd =
                rec.checkOut ?? (isToday ? DateTime.now() : rawStart);

            final sessionStart = DateTime(
              rawStart.year,
              rawStart.month,
              rawStart.day,
              rawStart.hour,
              rawStart.minute,
            );
            final sessionEnd = DateTime(
              rawEnd.year,
              rawEnd.month,
              rawEnd.day,
              rawEnd.hour,
              rawEnd.minute,
            );

            final shiftStart = DateTime(
              date.year,
              date.month,
              date.day,
              shiftStartMinutes ~/ 60,
              shiftStartMinutes % 60,
            );
            var shiftEnd = DateTime(
              date.year,
              date.month,
              date.day,
              shiftEndMinutes ~/ 60,
              shiftEndMinutes % 60,
            );
            if (shiftEnd.isBefore(shiftStart)) {
              shiftEnd = shiftEnd.add(const Duration(days: 1));
            }

            final intersectStart = sessionStart.isAfter(shiftStart)
                ? sessionStart
                : shiftStart;
            final intersectEnd = sessionEnd.isBefore(shiftEnd)
                ? sessionEnd
                : shiftEnd;

            if (intersectEnd.isAfter(intersectStart)) {
              dutyMinutes += intersectEnd.difference(intersectStart).inMinutes;
            }

            // Calculate Extra Time
            final isWeekend = !shift.isWorkingDay(date);
            if (isWeekend) {
              extraTimeMinutes += sessionEnd.difference(sessionStart).inMinutes;
            } else {
              // Calculate Extra Time (only worked minutes outside of shift bounds)
              if (sessionStart.isBefore(shiftStart)) {
                final endForBefore = sessionEnd.isBefore(shiftStart)
                    ? sessionEnd
                    : shiftStart;
                extraTimeMinutes += endForBefore
                    .difference(sessionStart)
                    .inMinutes;
              }
              if (sessionEnd.isAfter(shiftEnd)) {
                final startForAfter = sessionStart.isAfter(shiftEnd)
                    ? sessionStart
                    : shiftEnd;
                extraTimeMinutes += sessionEnd
                    .difference(startForAfter)
                    .inMinutes;
              }
            }
          }

          final isWeekendForDelay = !shift.isWorkingDay(date);
          if (!isWeekendForDelay) {
            final hasOnlyOnePunch =
                sortedRecords.length == 1 &&
                (sortedRecords.first.checkIn == sortedRecords.first.checkOut ||
                    sortedRecords.first.checkOut == null);

            // 3. Delay Minutes (late arrival on the first session)
            final firstRec = sortedRecords.first;
            final isMissedCheckIn = firstRec.checkIn == firstRec.checkOut;
            if (!isMissedCheckIn && !hasOnlyOnePunch) {
              final checkInMinutes =
                  firstRec.checkIn.hour * 60 + firstRec.checkIn.minute;
              final delay = checkInMinutes - shiftStartMinutes;
              if (delay > shift.forgivenessOfDelay) {
                delayMinutes = delay;
              }
            }

            // 4. Early Exit Minutes (leaving early on the last completed session)
            final lastRec = sortedRecords.last;
            if (lastRec.checkOut != null && !hasOnlyOnePunch) {
              final checkOutMinutes =
                  lastRec.checkOut!.hour * 60 + lastRec.checkOut!.minute;
              final earlyExit = shiftEndMinutes - checkOutMinutes;
              if (earlyExit > shift.earlyExit) {
                earlyExitMinutes = earlyExit;
              }
            }
          }

          // 5. Overtime calculation (based on extra time minutes and approved overtime requests)
          final dateStr = DateFormat('MMMM d, yyyy').format(date);
          final hasApprovedOt = requestsToCompile.any(
            (req) =>
                req.type == 'Overtime Approval' &&
                req.date == dateStr &&
                req.status == 'Approved',
          );

          if (extraTimeMinutes > 0 && hasApprovedOt) {
            final isOvertimeAllowed = group?.overtimeAllowed ?? true;
            if (isOvertimeAllowed) {
              final minOt = group?.minOvertimeMinutes ?? 0;
              final maxOt = group?.maxOvertimeMinutes ?? 480;
              if (extraTimeMinutes >= minOt) {
                final baseOt = extraTimeMinutes.clamp(0, maxOt);
                final isWeekend = !shift.isWorkingDay(date);
                if (isWeekend) {
                  overtimeMinutes =
                      (baseOt * (group?.weekendOvertimeRatio ?? 1.5)).toInt();
                } else {
                  overtimeMinutes = baseOt;
                }
              }
            }
          }

          // 6. Penalty calculations by Group rules
          double delayPenalty = 0.0;
          if (delayMinutes > 0 && (group?.delayPenaltiesEnabled ?? true)) {
            final g = group;
            if (g != null) {
              if (delayMinutes >= g.delayTier1Min &&
                  delayMinutes <= g.delayTier1Max) {
                delayPenalty = g.delayTier1Penalty;
              } else if (delayMinutes >= g.delayTier2Min &&
                  delayMinutes <= g.delayTier2Max) {
                delayPenalty = g.delayTier2Penalty;
              } else if (delayMinutes >= g.delayTier3Min) {
                delayPenalty = g.delayTier3Penalty;
              }
            }
          }

          double earlyExitPenalty = 0.0;
          if (earlyExitMinutes > 0 &&
              (group?.earlyExitPenaltiesEnabled ?? true)) {
            final g = group;
            if (g != null) {
              if (earlyExitMinutes >= g.earlyExitTier1Min &&
                  earlyExitMinutes <= g.earlyExitTier1Max) {
                earlyExitPenalty = g.earlyExitTier1Penalty;
              } else if (earlyExitMinutes >= g.earlyExitTier2Min &&
                  earlyExitMinutes <= g.earlyExitTier2Max) {
                earlyExitPenalty = g.earlyExitTier2Penalty;
              } else if (earlyExitMinutes >= g.earlyExitTier3Min) {
                earlyExitPenalty = g.earlyExitTier3Penalty;
              }
            }
          }

          penaltyAmount = delayPenalty + earlyExitPenalty;
        }

        final holiday = provider.getHolidayForEmployee(date, group?.id);

        if (holiday != null) {
          if (!hasRecord) {
            clockTimeStr = holiday.name;
          } else {
            clockTimeStr = '${holiday.name}\n$clockTimeStr';
          }
          delayMinutes = 0;
          earlyExitMinutes = 0;
          penaltyAmount = 0.0;
        }

        if (dateApprovedRequests.isNotEmpty) {
          final requestTypes = dateApprovedRequests
              .map((r) {
                if (r.type == 'Annual Leave') {
                  return provider.translate('vacation_leave');
                }
                if (r.type == 'Sick Leave') {
                  return provider.translate('sick_leave');
                }
                if (r.type == 'Overtime Approval') {
                  return provider.translate('overtime_approval');
                }
                if (r.type == 'Hourly Leave') {
                  final hl = provider.translate('hourly_leave');
                  return hl != 'hourly_leave' ? hl : 'Hourly Leave';
                }
                return r.type;
              })
              .join('\n');

          if (clockTimeStr == '-' || clockTimeStr.isEmpty) {
            clockTimeStr = requestTypes;
          } else {
            clockTimeStr = '$clockTimeStr\n$requestTypes';
          }

          if (hasLeaveRequest) {
            delayMinutes = 0;
            earlyExitMinutes = 0;
            penaltyAmount = 0.0;
          }
        }

        int deficitMinutes =
            delayMinutes + earlyExitMinutes + unexcusedRestMinutes;
        final isWeekendDay = !shift.isWorkingDay(date);
        final isFutureDay = date.isAfter(DateTime.now());

        if (!isWeekendDay &&
            !hasLeaveRequest &&
            holiday == null &&
            !hasApprovedMissingPunch &&
            !isFutureDay) {
          int shiftDur = shiftEndMinutes - shiftStartMinutes;
          if (shiftDur < 0) shiftDur += 24 * 60;

          int missingPunchDeficit = 0;
          final hasOnlyOnePunch =
              dateRecords.length == 1 &&
              (dateRecords.first.checkIn == dateRecords.first.checkOut ||
                  dateRecords.first.checkOut == null);
          if (hasOnlyOnePunch) {
            missingPunchDeficit = shiftDur;
          } else {
            for (var r in dateRecords) {
              if (r.checkIn == r.checkOut) {
                final outMinutes = r.checkOut!.hour * 60 + r.checkOut!.minute;
                final clampedOut = outMinutes > shiftEndMinutes
                    ? shiftEndMinutes
                    : outMinutes;
                if (clampedOut > shiftStartMinutes) {
                  missingPunchDeficit += (clampedOut - shiftStartMinutes);
                }
              } else if (r.checkOut == null) {
                final isToday = DateUtils.isSameDay(date, DateTime.now());
                if (!isToday) {
                  final inMinutes = r.checkIn.hour * 60 + r.checkIn.minute;
                  final clampedIn = inMinutes < shiftStartMinutes
                      ? shiftStartMinutes
                      : inMinutes;
                  if (shiftEndMinutes > clampedIn) {
                    missingPunchDeficit += (shiftEndMinutes - clampedIn);
                  }
                }
              }
            }
          }

          if (!hasRecord) {
            missingPunchDeficit += shiftDur;
          }

          deficitMinutes += missingPunchDeficit;
        }

        compiledData.add({
          'date': date,
          'hasRecord': hasRecord,
          'attendance': totalActualMinutes,
          'duty': dutyMinutes,
          'rest': restMinutes,
          'delay': delayMinutes,
          'earlyExit': earlyExitMinutes,
          'deficit': deficitMinutes,
          'extraTime': extraTimeMinutes,
          'overtime': overtimeMinutes,
          'clockTime': clockTimeStr,
          'penalty': penaltyAmount,
          'isLeave': hasLeaveRequest || holiday != null,
          'isMissingPunch': hasApprovedMissingPunch,
          'missingPunchTimes': missingPunchTimes,
          'isWeekend': isWeekendDay,
          'requests': allDayRequests,
        });
      }
    }

    return Directionality(
      textDirection: provider.currentLanguageDirection,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Controls (Dropdown, Month Selector, Export, Add Request)
              Padding(
                padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 8.0),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth >= 860) {
                      return Row(
                        children: [
                          Expanded(
                            child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: provider.currentEmployee != null
                                  ? ConstrainedBox(
                                      constraints: const BoxConstraints(maxWidth: 320),
                                      child: _buildEmployeeDropdown(provider, [
                                        provider.currentEmployee!,
                                        ...subordinates,
                                      ]),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ),
                          _buildMonthSelector(),
                          Expanded(
                            child: Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildDayRequestsButton(provider, compiledData),
                                  const SizedBox(width: 10),
                                  _buildExportButton(provider, compiledData),
                                  const SizedBox(width: 12),
                                  _buildAddRequestButton(provider),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    } else {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              if (provider.currentEmployee != null)
                                Expanded(
                                  child: _buildEmployeeDropdown(provider, [
                                    provider.currentEmployee!,
                                    ...subordinates,
                                  ]),
                                ),
                              const SizedBox(width: 8),
                              _buildDayRequestsButton(
                                provider,
                                compiledData,
                                isCompact: true,
                              ),
                              const SizedBox(width: 8),
                              _buildExportButton(provider, compiledData),
                              const SizedBox(width: 12),
                              _buildAddRequestButton(provider),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: _buildMonthSelector(),
                          ),
                        ],
                      );
                    }
                  },
                ),
              ),
              const SizedBox(height: 10),

              // Main content area
              Expanded(
                child: _isLoadingSubordinate
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF2E65FF),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildSummaryCards(compiledData),
                          const SizedBox(height: 14),
                          _buildReportTable(compiledData),
                        ],
                      ),
              ),
              // Spacer for bottom nav bar
              if (!kIsWeb) SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClockTimeWidget(
    String text,
    List<String> highlights,
    bool isLeave,
  ) {
    if (isLeave) {
      return Text(
        text,
        style: TextStyle(
          fontSize: 12,
          height: 1.2,
          color: Color(0xFF5B9BFF),
          fontWeight: FontWeight.bold,
        ),
      );
    }

    if (highlights.isEmpty) {
      return Text(
        text,
        style: TextStyle(
          fontSize: 12,
          height: 1.2,
          color:
              ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)),
        ),
      );
    }

    final pattern = highlights.map((t) => RegExp.escape(t)).join('|');
    final regex = RegExp('($pattern)');
    final matches = regex.allMatches(text);

    if (matches.isEmpty) {
      return Text(
        text,
        style: TextStyle(
          fontSize: 12,
          height: 1.2,
          color:
              ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)),
        ),
      );
    }

    int lastMatchEnd = 0;
    List<TextSpan> spans = [];

    for (var match in matches) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(text: text.substring(lastMatchEnd, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(0),
          style: TextStyle(
            color: Color(0xFF5B9BFF),
            fontWeight: FontWeight.bold,
          ),
        ),
      );
      lastMatchEnd = match.end;
    }
    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastMatchEnd)));
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: 12,
          height: 1.2,
          color:
              ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)),
        ),
        children: spans,
      ),
    );
  }

  Widget _buildMonthSelector() {
    final monthStr = DateFormat('MMMM yyyy').format(_reportMonth);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          color: textColor,
          iconSize: 22,
          splashRadius: 20,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          onPressed: () {
            setState(() {
              _reportMonth = DateTime(
                _reportMonth.year,
                _reportMonth.month - 1,
              );
              _selectedDate = null;
            });
          },
        ),
        const SizedBox(width: 20),
        Text(
          monthStr,
          style: TextStyle(
            color: textColor,
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(width: 20),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          color: textColor,
          iconSize: 22,
          splashRadius: 20,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          onPressed: () {
            setState(() {
              _reportMonth = DateTime(
                _reportMonth.year,
                _reportMonth.month + 1,
              );
              _selectedDate = null;
            });
          },
        ),
      ],
    );
  }

  Widget _buildSummaryCards(List<Map<String, dynamic>> compiledData) {
    final provider = Provider.of<AttendanceProvider>(context);
    int totalAttendance = 0;
    int totalDuty = 0;
    int totalRest = 0;
    int totalDelay = 0;
    int totalEarlyExit = 0;
    int totalDeficit = 0;
    int totalOvertime = 0;
    double totalPenalties = 0.0;
    int activeDays = 0;

    for (var row in compiledData) {
      final hasRecord = row['hasRecord'] as bool;
      final isWeekend = row['isWeekend'] as bool;

      if (hasRecord && (row['attendance'] as int) > 0) {
        activeDays++;
        totalAttendance += row['attendance'] as int;
        totalDuty += row['duty'] as int;
        totalRest += (row['rest'] ?? 0) as int;
        totalDelay += row['delay'] as int;
        totalEarlyExit += row['earlyExit'] as int;
        totalOvertime += row['overtime'] as int;
        totalPenalties += row['penalty'] as double;
      }

      if (!isWeekend || hasRecord) {
        totalDeficit += (row['deficit'] as int?) ?? 0;
      }
    }

    final String totalAttendanceStr =
        '${totalAttendance ~/ 60}h ${totalAttendance % 60}m';
    final String totalDutyStr = '${totalDuty ~/ 60}h ${totalDuty % 60}m';
    final String totalRestStr = '${totalRest ~/ 60}h ${totalRest % 60}m';
    final String totalOvertimeStr =
        '${totalOvertime ~/ 60}h ${totalOvertime % 60}m';
    final String totalDeficitStr =
        '${totalDeficit ~/ 60}h ${totalDeficit % 60}m';

    final cards = [
      _buildMiniSummaryCard(
        provider.translate('duty_days'),
        '$activeDays days',
        const Color(0xFF2E65FF),
      ),
      _buildMiniSummaryCard(
        provider.translate('total_attendance'),
        totalAttendanceStr,
        const Color(0xFF2EBD96),
      ),
      _buildMiniSummaryCard(
        provider.translate('rest_time'),
        totalRestStr,
        const Color(0xFF2EBD96),
      ),
      _buildMiniSummaryCard(
        provider.translate('total_duty'),
        totalDutyStr,
        const Color(0xFF5B9BFF),
      ),
      _buildMiniSummaryCard(
        provider.translate('overtime'),
        totalOvertimeStr,
        const Color(0xFF00FF87),
      ),
      _buildMiniSummaryCard(
        provider.translate('delay'),
        '${totalDelay}m',
        const Color(0xFFFF5C5C),
      ),
      _buildMiniSummaryCard(
        provider.translate('early_exit'),
        '${totalEarlyExit}m',
        const Color(0xFFFF5C5C),
      ),
      _buildMiniSummaryCard(
        'Deficit',
        totalDeficitStr,
        const Color(0xFFFF5C5C),
      ),
      _buildMiniSummaryCard(
        provider.translate('penalty'),
        '${NumberFormat('#,##0').format(totalPenalties)} IQD',
        const Color(0xFFFF5C5C),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 900) {
            return Row(
              children: [
                for (int i = 0; i < cards.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(child: cards[i]),
                ],
              ],
            );
          } else {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  for (int i = 0; i < cards.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    cards[i],
                  ],
                ],
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildMiniSummaryCard(String label, String value, Color accentColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isDark ? Colors.white54 : const Color(0xFF64748B),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: accentColor,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(
    String title, {
    Color? color,
    TextAlign textAlign = TextAlign.start,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 12.0),
      child: Text(
        title,
        textAlign: textAlign,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          color: color ??
              ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)),
        ),
      ),
    );
  }

  Widget _buildReportTable(List<Map<String, dynamic>> compiledData) {
    final provider = Provider.of<AttendanceProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bodyTextColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final dividerColor = bodyTextColor.withValues(alpha: 0.08);
    final headerBgColor = bodyTextColor.withValues(alpha: 0.06);

    const columnWidths = <int, TableColumnWidth>{
      0: FlexColumnWidth(1.2),  // Date
      1: FlexColumnWidth(2.2),  // Clock Time
      2: FlexColumnWidth(1.1),  // Attendance
      3: FlexColumnWidth(1.0),  // Rest Time
      4: FlexColumnWidth(1.0),  // Duty
      5: FlexColumnWidth(0.9),  // Delay
      6: FlexColumnWidth(0.9),  // Early Exit
      7: FlexColumnWidth(0.95), // Deficit
      8: FlexColumnWidth(1.0),  // Extra Time
      9: FlexColumnWidth(1.0),  // Overtime
      10: FlexColumnWidth(1.15), // Penalty
    };

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: GlassContainer(
          padding: EdgeInsets.zero,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final tableWidth = math.max(constraints.maxWidth, 1200.0);

                return Scrollbar(
                  controller: _tableHorizontalController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _tableHorizontalController,
                    scrollDirection: Axis.horizontal,
                    physics: const ClampingScrollPhysics(),
                    child: SizedBox(
                      width: tableWidth,
                      height: constraints.maxHeight,
                      child: Column(
                        children: [
                          // Sticky Fixed Header
                          Container(
                            decoration: BoxDecoration(
                              color: headerBgColor,
                              border: Border(
                                bottom: BorderSide(
                                  color: dividerColor,
                                  width: 1.0,
                                ),
                              ),
                            ),
                            child: Table(
                              columnWidths: columnWidths,
                              defaultVerticalAlignment:
                                  TableCellVerticalAlignment.middle,
                              children: [
                                TableRow(
                                  children: [
                                    _buildHeaderCell(provider.translate('date')),
                                    _buildHeaderCell(
                                      provider.translate('clock_time'),
                                      color: const Color(0xFF5B9BFF),
                                    ),
                                    _buildHeaderCell(
                                      provider.translate('attendance'),
                                    ),
                                    _buildHeaderCell(
                                      provider.translate('rest_time'),
                                      color: const Color(0xFF2EBD96),
                                    ),
                                    _buildHeaderCell(provider.translate('duty')),
                                    _buildHeaderCell(
                                      provider.translate('delay'),
                                      color: const Color(0xFFFF5C5C),
                                    ),
                                    _buildHeaderCell(
                                      provider.translate('early_exit'),
                                      color: const Color(0xFFFF5C5C),
                                    ),
                                    _buildHeaderCell(
                                      'Deficit',
                                      color: const Color(0xFFFF5C5C),
                                    ),
                                    _buildHeaderCell(
                                      provider.translate('extra_time'),
                                      color: const Color(0xFFFF9800),
                                    ),
                                    _buildHeaderCell(
                                      provider.translate('overtime'),
                                      color: const Color(0xFF00FF87),
                                    ),
                                    _buildHeaderCell(
                                      provider.translate('penalty'),
                                      color: const Color(0xFFFF5C5C),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Scrollable Body
                          Expanded(
                            child: Scrollbar(
                              controller: _tableVerticalController,
                              thumbVisibility: true,
                              child: SingleChildScrollView(
                                controller: _tableVerticalController,
                                scrollDirection: Axis.vertical,
                                physics: const BouncingScrollPhysics(),
                                child: Table(
                                  columnWidths: columnWidths,
                                  defaultVerticalAlignment:
                                      TableCellVerticalAlignment.middle,
                                  border: TableBorder(
                                    horizontalInside: BorderSide(
                                      color: dividerColor,
                                      width: 1.0,
                                    ),
                                    bottom: BorderSide(
                                      color: dividerColor,
                                      width: 1.0,
                                    ),
                                  ),
                                  children: compiledData.map((row) {
                                    final date = row['date'] as DateTime;
                                    final isSelected = _selectedDate != null &&
                                        DateUtils.isSameDay(_selectedDate, date);
                                    final dayRequests =
                                        (row['requests'] as List<Request>?) ??
                                            [];
                                    final hasRequests = dayRequests.isNotEmpty;

                                    final dayNameEng = DateFormat(
                                      'EEEE',
                                    ).format(date).toLowerCase();
                                    final translatedDay =
                                        provider.translate(dayNameEng);
                                    final dateStr =
                                        '$translatedDay\n${DateFormat('dd MMM').format(date)}';
                                    final isWeekend =
                                        row['isWeekend'] as bool;

                                    final attendanceStr = formatMinutes(
                                      row['attendance'] as int,
                                    );
                                    final restStr = formatMinutes(
                                      (row['rest'] ?? 0) as int,
                                    );
                                    final dutyStr =
                                        formatMinutes(row['duty'] as int);
                                    final delayStr =
                                        formatMinutes(row['delay'] as int);
                                    final earlyExitStr = formatMinutes(
                                      row['earlyExit'] as int,
                                    );
                                    final extraTimeStr = formatMinutes(
                                      row['extraTime'] as int,
                                    );
                                    final overtimeStr = formatMinutes(
                                      row['overtime'] as int,
                                    );
                                    final penaltyVal =
                                        row['penalty'] as double;
                                    final penaltyStr = penaltyVal > 0
                                        ? '${NumberFormat('#,##0').format(penaltyVal)} IQD'
                                        : '-';

                                    final rowColor = isSelected
                                        ? (isDark
                                            ? const Color(0xFF2E65FF)
                                                .withValues(alpha: 0.22)
                                            : const Color(0xFF2E65FF)
                                                .withValues(alpha: 0.12))
                                        : (isWeekend
                                            ? bodyTextColor.withValues(
                                                alpha: 0.02,
                                              )
                                            : Colors.transparent);

                                    Widget wrapCell(Widget cell) {
                                      return MouseRegion(
                                        cursor: SystemMouseCursors.click,
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: () {
                                            setState(() {
                                              if (_selectedDate != null &&
                                                  DateUtils.isSameDay(
                                                    _selectedDate,
                                                    date,
                                                  )) {
                                                _selectedDate = null;
                                              } else {
                                                _selectedDate = date;
                                              }
                                            });
                                          },
                                          onDoubleTap: () {
                                            setState(() {
                                              _selectedDate = date;
                                            });
                                            _showDayRequestsDialog(
                                              context,
                                              provider,
                                              row,
                                            );
                                          },
                                          child: cell,
                                        ),
                                      );
                                    }

                                    return TableRow(
                                      decoration: BoxDecoration(
                                        color: rowColor,
                                      ),
                                      children: [
                                        // Date
                                        wrapCell(
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10.0,
                                              vertical: 8.0,
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              children: [
                                                if (isSelected)
                                                  Container(
                                                    width: 3.5,
                                                    height: 24,
                                                    margin:
                                                        const EdgeInsets.only(
                                                          right: 6,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                        0xFF2E65FF,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            2,
                                                          ),
                                                    ),
                                                  ),
                                                Expanded(
                                                  child: Text(
                                                    dateStr,
                                                    style: TextStyle(
                                                      color: isSelected
                                                          ? const Color(
                                                            0xFF2E65FF,
                                                          )
                                                          : (isWeekend
                                                              ? bodyTextColor
                                                                  .withValues(
                                                                    alpha: 0.38,
                                                                  )
                                                              : bodyTextColor
                                                                  .withValues(
                                                                    alpha: 0.7,
                                                                  )),
                                                      fontWeight: isSelected
                                                          ? FontWeight.bold
                                                          : FontWeight.w600,
                                                      fontSize: 12,
                                                      height: 1.2,
                                                    ),
                                                  ),
                                                ),
                                                if (hasRequests)
                                                  Container(
                                                    padding:
                                                        const EdgeInsets
                                                            .symmetric(
                                                          horizontal: 5,
                                                          vertical: 2,
                                                        ),
                                                    margin:
                                                        const EdgeInsets.only(
                                                          left: 4,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                        0xFF2E65FF,
                                                      ).withValues(alpha: 0.15),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      '${dayRequests.length}',
                                                      style: const TextStyle(
                                                        color: Color(
                                                          0xFF2E65FF,
                                                        ),
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        // Clock Time
                                        wrapCell(
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10.0,
                                              vertical: 8.0,
                                            ),
                                            child: _buildClockTimeWidget(
                                              row['clockTime'] as String,
                                              row['missingPunchTimes']
                                                      as List<String>? ??
                                                  [],
                                              row['isLeave'] as bool? ?? false,
                                            ),
                                          ),
                                        ),
                                        // Attendance
                                        wrapCell(
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10.0,
                                              vertical: 8.0,
                                            ),
                                            child: Text(
                                              (row['isLeave'] as bool? ??
                                                          false) &&
                                                      !(row['hasRecord'] as bool)
                                                  ? '-'
                                                  : attendanceStr,
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                        // Rest Time
                                        wrapCell(
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10.0,
                                              vertical: 8.0,
                                            ),
                                            child: Text(
                                              (row['isLeave'] as bool? ??
                                                          false) &&
                                                      !(row['hasRecord'] as bool)
                                                  ? '-'
                                                  : restStr,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF2EBD96),
                                              ),
                                            ),
                                          ),
                                        ),
                                        // Duty
                                        wrapCell(
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10.0,
                                              vertical: 8.0,
                                            ),
                                            child: Text(
                                              (row['isLeave'] as bool? ??
                                                          false) &&
                                                      !(row['hasRecord'] as bool)
                                                  ? '-'
                                                  : dutyStr,
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                        // Delay
                                        wrapCell(
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10.0,
                                              vertical: 8.0,
                                            ),
                                            child: Text(
                                              delayStr,
                                              style: TextStyle(
                                                color: row['delay'] as int > 0
                                                    ? const Color(0xFFFF5C5C)
                                                    : (isDark
                                                        ? Colors.white60
                                                        : Colors.black54),
                                                fontWeight:
                                                    row['delay'] as int > 0
                                                        ? FontWeight.bold
                                                        : FontWeight.normal,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                        // Early Exit
                                        wrapCell(
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10.0,
                                              vertical: 8.0,
                                            ),
                                            child: Text(
                                              earlyExitStr,
                                              style: TextStyle(
                                                color:
                                                    row['earlyExit'] as int > 0
                                                        ? const Color(
                                                          0xFFFF5C5C,
                                                        )
                                                        : (isDark
                                                            ? Colors.white60
                                                            : Colors.black54),
                                                fontWeight:
                                                    row['earlyExit'] as int > 0
                                                        ? FontWeight.bold
                                                        : FontWeight.normal,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                        // Deficit
                                        wrapCell(
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10.0,
                                              vertical: 8.0,
                                            ),
                                            child: Text(
                                              formatMinutes(
                                                (row['deficit'] as int?) ?? 0,
                                              ),
                                              style: TextStyle(
                                                color:
                                                    ((row['deficit'] as int?) ??
                                                                0) >
                                                            0
                                                        ? const Color(
                                                          0xFFFF5C5C,
                                                        )
                                                        : (isDark
                                                            ? Colors.white60
                                                            : Colors.black54),
                                                fontWeight:
                                                    ((row['deficit'] as int?) ??
                                                                0) >
                                                            0
                                                        ? FontWeight.bold
                                                        : FontWeight.normal,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                        // Extra Time
                                        wrapCell(
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10.0,
                                              vertical: 8.0,
                                            ),
                                            child: Text(
                                              extraTimeStr,
                                              style: TextStyle(
                                                color:
                                                    row['extraTime'] as int > 0
                                                        ? const Color(
                                                          0xFFFF9800,
                                                        )
                                                        : (isDark
                                                            ? Colors.white60
                                                            : Colors.black54),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                        // Overtime
                                        wrapCell(
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10.0,
                                              vertical: 8.0,
                                            ),
                                            child: Text(
                                              overtimeStr,
                                              style: TextStyle(
                                                color:
                                                    row['overtime'] as int > 0
                                                        ? const Color(
                                                          0xFF00FF87,
                                                        )
                                                        : (isDark
                                                            ? Colors.white60
                                                            : Colors.black54),
                                                fontWeight:
                                                    row['overtime'] as int > 0
                                                        ? FontWeight.bold
                                                        : FontWeight.normal,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                        // Penalty
                                        wrapCell(
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10.0,
                                              vertical: 8.0,
                                            ),
                                            child: Text(
                                              penaltyStr,
                                              style: TextStyle(
                                                color: penaltyVal > 0
                                                    ? const Color(0xFFFF5C5C)
                                                    : (isDark
                                                        ? Colors.white60
                                                        : Colors.black54),
                                                fontWeight: penaltyVal > 0
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeeDropdown(
    AttendanceProvider provider,
    List<CompanyEmployee> subordinates,
  ) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Theme(
        data: ThemeData.dark().copyWith(canvasColor: const Color(0xFF1E293B)),
        child: DropdownMenu<String>(
          initialSelection:
              _selectedEmployeeId ?? provider.currentEmployee?.id,
          enableFilter: true,
          enableSearch: true,
          expandedInsets: EdgeInsets.zero,
          menuStyle: MenuStyle(
            backgroundColor: WidgetStateProperty.all(
              (Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1E293B).withValues(alpha: 0.98)
                  : Colors.white.withValues(alpha: 0.98)),
            ),
            elevation: WidgetStateProperty.all(8),
            shape: WidgetStateProperty.all(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color:
                      (Theme.of(context).textTheme.bodyLarge?.color ??
                              Colors.black)
                          .withValues(alpha: 0.1),
                ),
              ),
            ),
          ),
          inputDecorationTheme: const InputDecorationTheme(
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
          textStyle: TextStyle(
            color:
                ((Theme.of(context).textTheme.bodyLarge?.color ??
                Colors.black)),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          dropdownMenuEntries: subordinates.map((emp) {
            return DropdownMenuEntry<String>(
              value: emp.id,
              label: '${emp.name} (${emp.position})',
            );
          }).toList(),
          onSelected: (val) {
            if (val != null) {
              setState(() {
                _selectedEmployeeId = val;
                _selectedDate = null;
              });
              _loadSubordinateRecords(provider, val);
            }
          },
        ),
      ),
    );
  }

  Widget _buildAddRequestButton(AttendanceProvider provider) {
    return SizedBox(
      height: 44,
      child: ElevatedButton.icon(
        onPressed: () {
          showNewRequestDialog(
            context: context,
            provider: provider,
          );
        },
        icon: const Icon(Icons.add, size: 20, color: Colors.white),
        label: Text(
          provider.translate('new_request'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF5C38),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          shape: const StadiumBorder(),
        ),
      ),
    );
  }

  Widget _buildExportButton(
    AttendanceProvider provider,
    List<Map<String, dynamic>> records,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () async {
            final employee = _selectedEmployeeId != null
                ? provider.employees.firstWhere(
                    (e) => e.id == _selectedEmployeeId,
                    orElse: () => provider.currentEmployee!,
                  )
                : provider.currentEmployee!;

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Exporting attendance history...')),
            );

            await ExportService.exportHistoryToPdf(
              records: records,
              employee: employee,
              month: _reportMonth,
              profile: provider.companyProfile,
            );
          },
          child: Icon(
            Icons.file_download_outlined,
            color: isDark ? Colors.white70 : const Color(0xFF64748B),
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildDayRequestsButton(
    AttendanceProvider provider,
    List<Map<String, dynamic>> compiledData, {
    bool isCompact = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _selectedDate != null;

    final selectedRow = isSelected
        ? compiledData.cast<Map<String, dynamic>?>().firstWhere(
            (r) =>
                r != null &&
                DateUtils.isSameDay(r['date'] as DateTime, _selectedDate),
            orElse: () => null,
          )
        : null;

    final List<Request> requests = selectedRow != null
        ? ((selectedRow['requests'] as List<Request>?) ?? [])
        : [];

    final count = requests.length;

    if (isCompact) {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF2E65FF)
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? const Color(0xFF2E65FF).withValues(alpha: 0.35)
                  : Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () {
              if (isSelected && selectedRow != null) {
                _showDayRequestsDialog(context, provider, selectedRow);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Click on any day row in the table first.'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.assignment_outlined,
                  color: isSelected
                      ? Colors.white
                      : (isDark
                          ? Colors.white38
                          : const Color(0xFF64748B).withValues(alpha: 0.4)),
                  size: 20,
                ),
                if (isSelected && count > 0)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF5C38),
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 14,
                        minHeight: 14,
                      ),
                      child: Text(
                        '$count',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    if (!isSelected) {
      return Tooltip(
        message: 'Click on any day row in the table to view its requests',
        child: SizedBox(
          height: 44,
          child: OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Click on any day row in the table first.'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            icon: Icon(
              Icons.assignment_outlined,
              size: 18,
              color: isDark
                  ? Colors.white38
                  : const Color(0xFF64748B).withValues(alpha: 0.5),
            ),
            label: Text(
              provider.translate('requests'),
              style: TextStyle(
                color: isDark
                    ? Colors.white38
                    : const Color(0xFF64748B).withValues(alpha: 0.5),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: (Theme.of(context).textTheme.bodyLarge?.color ??
                        Colors.black)
                    .withValues(alpha: 0.12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              shape: const StadiumBorder(),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 44,
      child: ElevatedButton.icon(
        onPressed: () {
          if (selectedRow != null) {
            _showDayRequestsDialog(context, provider, selectedRow);
          }
        },
        icon: const Icon(Icons.assignment_outlined, size: 18, color: Colors.white),
        label: Text(
          count > 0
              ? '${provider.translate('requests')} ($count)'
              : provider.translate('requests'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2E65FF),
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: const Color(0xFF2E65FF).withValues(alpha: 0.4),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: const StadiumBorder(),
        ),
      ),
    );
  }

  void _showDayRequestsDialog(
    BuildContext context,
    AttendanceProvider provider,
    Map<String, dynamic> rowData,
  ) {
    final date = rowData['date'] as DateTime;
    final dayNameEng = DateFormat('EEEE').format(date).toLowerCase();
    final translatedDay = provider.translate(dayNameEng);
    final formattedDateStr =
        '$translatedDay, ${DateFormat('d MMMM yyyy').format(date)}';
    final requests = (rowData['requests'] as List<Request>?) ?? [];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580, maxHeight: 680),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Dialog Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 20, 16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF2E65FF).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.assignment_outlined,
                            color: Color(0xFF2E65FF),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                provider.translate('requests'),
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                formattedDateStr,
                                style: TextStyle(
                                  color: textColor.withValues(alpha: 0.6),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(Icons.close),
                          splashRadius: 20,
                          color: textColor.withValues(alpha: 0.5),
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1, thickness: 1),

                  // Day Summary Strip (Attendance Context)
                  Container(
                    color: textColor.withValues(alpha: isDark ? 0.04 : 0.02),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildDialogDayStat(
                          label: provider.translate('attendance'),
                          value: (rowData['isLeave'] as bool? ?? false) &&
                                  !(rowData['hasRecord'] as bool)
                              ? '-'
                              : formatMinutes(rowData['attendance'] as int),
                          color: const Color(0xFF2E65FF),
                        ),
                        _buildDialogDayStat(
                          label: provider.translate('clock_time'),
                          value: (rowData['clockTime'] as String).replaceAll(
                            '\n',
                            ', ',
                          ),
                          color: const Color(0xFF5B9BFF),
                        ),
                        _buildDialogDayStat(
                          label: provider.translate('duty'),
                          value: formatMinutes(rowData['duty'] as int),
                          color: textColor.withValues(alpha: 0.7),
                        ),
                        _buildDialogDayStat(
                          label: provider.translate('delay'),
                          value: '${rowData['delay']}m',
                          color: (rowData['delay'] as int) > 0
                              ? const Color(0xFFFF5C5C)
                              : textColor.withValues(alpha: 0.7),
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1, thickness: 1),

                  // Requests Content
                  Flexible(
                    child: requests.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 40,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: textColor.withValues(alpha: 0.05),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.article_outlined,
                                    size: 32,
                                    color: textColor.withValues(alpha: 0.35),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  provider.translate('no_requests'),
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'No leave, shift change, or punch correction requests were submitted for this date.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: textColor.withValues(alpha: 0.5),
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.of(ctx).pop();
                                    showNewRequestDialog(
                                      context: context,
                                      provider: provider,
                                    );
                                  },
                                  icon: const Icon(Icons.add, size: 18),
                                  label: Text(
                                    provider.translate('new_request'),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFF5C38),
                                    foregroundColor: Colors.white,
                                    shape: const StadiumBorder(),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 10,
                                    ),
                                    elevation: 0,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(20),
                            itemCount: requests.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final req = requests[index];
                              return _buildRequestDetailCard(
                                req,
                                provider,
                                isDark,
                                textColor,
                              );
                            },
                          ),
                  ),

                  // Footer
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            provider.translate('close') != 'close'
                                ? provider.translate('close')
                                : 'Close',
                            style: TextStyle(
                              color: textColor.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRequestDetailCard(
    Request req,
    AttendanceProvider provider,
    bool isDark,
    Color textColor,
  ) {
    final statusColor = req.statusColor;
    final statusLabel = _translateRequestStatus(req.status, provider);
    final typeLabel = _translateRequestType(req.type, provider);

    IconData typeIcon = Icons.assignment_outlined;
    if (req.type.contains('Leave')) {
      typeIcon = Icons.beach_access_rounded;
    } else if (req.type == 'Change Shift') {
      typeIcon = Icons.swap_horiz_rounded;
    } else if (req.type == 'Missing Punch' ||
        req.type == 'Forgot to Clock Out') {
      typeIcon = Icons.fingerprint;
    } else if (req.type.contains('Overtime')) {
      typeIcon = Icons.more_time_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: textColor.withValues(alpha: isDark ? 0.12 : 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Type and Status
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(typeIcon, size: 18, color: statusColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      typeLabel,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      req.date,
                      style: TextStyle(
                        color: textColor.withValues(alpha: 0.5),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Duration or Shift details
          if (req.type == 'Change Shift' && req.targetShiftId != null) ...[
            _buildDetailRow(
              icon: Icons.schedule,
              label: provider.translate('target_shift') != 'target_shift'
                  ? provider.translate('target_shift')
                  : 'Target Shift',
              value: provider.shifts
                  .firstWhere(
                    (s) => s.id == req.targetShiftId,
                    orElse: () => WorkShift(
                      id: '',
                      name: 'Unknown',
                      startTime: '',
                      endTime: '',
                    ),
                  )
                  .name,
              textColor: textColor,
            ),
          ] else if (req.duration.isNotEmpty) ...[
            _buildDetailRow(
              icon: Icons.timer_outlined,
              label: provider.translate('duration'),
              value: req.duration
                  .replaceAll('Clock In:', provider.translate('clock_in_colon'))
                  .replaceAll('Clock Out:', provider.translate('clock_out_colon')),
              textColor: textColor,
            ),
          ],

          // Note
          if (req.note != null && req.note!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            _buildDetailRow(
              icon: Icons.notes_rounded,
              label: provider.translate('note') != 'note'
                  ? provider.translate('note')
                  : 'Note',
              value: req.note!,
              textColor: textColor,
            ),
          ],

          // Detailed Approval Workflow Timeline
          _buildWorkflowTimeline(
            req: req,
            provider: provider,
            isDark: isDark,
            textColor: textColor,
          ),
        ],
      ),
    );
  }

  Widget _buildWorkflowTimeline({
    required Request req,
    required AttendanceProvider provider,
    required bool isDark,
    required Color textColor,
  }) {
    // 1. Submitter Resolution
    String submitterName = 'Employee';
    String submitterRole = 'Staff';
    CompanyEmployee? submitterEmp;
    if (req.employeeId != null && req.employeeId!.isNotEmpty) {
      submitterEmp = provider.employees.where(
        (e) => e.id == req.employeeId || e.email == req.employeeId,
      ).firstOrNull;
      if (submitterEmp != null) {
        submitterName = submitterEmp.name;
        submitterRole = submitterEmp.position.isNotEmpty ? submitterEmp.position : submitterEmp.role;
      } else if (provider.currentEmployee != null &&
          (provider.currentEmployee!.id == req.employeeId ||
           provider.currentEmployee!.name == req.employeeId)) {
        submitterEmp = provider.currentEmployee;
        submitterName = provider.currentEmployee!.name;
        submitterRole = provider.currentEmployee!.position;
      }
    } else if (provider.currentEmployee != null) {
      submitterEmp = provider.currentEmployee;
      submitterName = provider.currentEmployee!.name;
      submitterRole = provider.currentEmployee!.position;
    }

    // 2. Submission Date & Time
    DateTime submitDate = DateTime.now();
    if (req.createdAt != null && req.createdAt!.isNotEmpty) {
      submitDate = DateTime.tryParse(req.createdAt!) ?? submitDate;
    } else {
      try {
        if (req.date.contains(' - ')) {
          submitDate = DateFormat('MMMM d, yyyy').parse(req.date.split(' - ')[0].trim());
        } else {
          submitDate = DateFormat('MMMM d, yyyy').parse(req.date.trim());
        }
        submitDate = DateTime(submitDate.year, submitDate.month, submitDate.day, 8, 30);
      } catch (_) {}
    }
    final formattedSubmitDate = DateFormat('MMM d, yyyy • hh:mm a').format(submitDate);

    // 3. Structure Supervisor Resolution
    String supervisorName = 'Supervisor';
    String supervisorRole = 'Structure Supervisor';
    if (req.supervisorActionBy != null && req.supervisorActionBy!.isNotEmpty) {
      final sMatch = provider.employees.where(
        (e) => e.id == req.supervisorActionBy || e.name.toLowerCase() == req.supervisorActionBy!.toLowerCase(),
      ).firstOrNull;
      if (sMatch != null) {
        supervisorName = sMatch.name;
        supervisorRole = sMatch.position.isNotEmpty ? sMatch.position : 'Structure Supervisor';
      }
    } else {
      // Find supervisor of the employee's structure
      if (submitterEmp?.structureId != null && submitterEmp!.structureId!.isNotEmpty) {
        final struct = provider.structures.where((s) => s.id == submitterEmp!.structureId).firstOrNull;
        if (struct?.supervisorId != null) {
          final sMatch = provider.employees.where((e) => e.id == struct!.supervisorId).firstOrNull;
          if (sMatch != null) {
            supervisorName = sMatch.name;
            supervisorRole = sMatch.position.isNotEmpty ? sMatch.position : 'Structure Supervisor';
          }
        }
      }
    }

    DateTime supervisorDate = submitDate.add(const Duration(minutes: 30));
    if (req.supervisorActionDate != null && req.supervisorActionDate!.isNotEmpty) {
      supervisorDate = DateTime.tryParse(req.supervisorActionDate!) ?? supervisorDate;
    }
    final formattedSupervisorDate = DateFormat('MMM d, yyyy • hh:mm a').format(supervisorDate);

    // 4. HR Manager Resolution
    String hrName = 'HR Manager';
    String hrRole = 'HR Management';
    final hrActionTarget = req.hrActionBy ?? (req.supervisorActionBy == null ? req.actionBy : null);
    if (hrActionTarget != null && hrActionTarget.isNotEmpty) {
      final hMatch = provider.employees.where(
        (e) => e.id == hrActionTarget || e.name.toLowerCase() == hrActionTarget.toLowerCase(),
      ).firstOrNull;
      if (hMatch != null) {
        hrName = hMatch.name;
        hrRole = hMatch.position.isNotEmpty ? hMatch.position : 'HR Management';
      }
    } else {
      final hrEmp = provider.employees.where(
        (e) => (e.role == 'hr' || e.role == 'admin') && e.id != req.employeeId,
      ).firstOrNull ?? provider.employees.where((e) => e.role == 'hr' || e.role == 'admin').firstOrNull;
      if (hrEmp != null) {
        hrName = hrEmp.name;
        hrRole = hrEmp.position.isNotEmpty ? hrEmp.position : 'HR Management';
      }
    }

    DateTime hrDate = supervisorDate.add(const Duration(minutes: 30));
    final hrDateTarget = req.hrActionDate ?? (req.supervisorActionDate == null ? req.actionDate : null);
    if (hrDateTarget != null && hrDateTarget.isNotEmpty) {
      hrDate = DateTime.tryParse(hrDateTarget) ?? hrDate;
    }
    final formattedHrDate = DateFormat('MMM d, yyyy • hh:mm a').format(hrDate);

    final isApproved = req.status == 'Approved';
    final isRejected = req.status == 'Rejected';

    // Badge status styling
    final Color overallColor = isApproved
        ? const Color(0xFF10B981)
        : (isRejected
            ? const Color(0xFFEF4444)
            : (req.status == 'Pending HR' ? const Color(0xFF8B5CF6) : const Color(0xFFF59E0B)));

    final IconData overallIcon = isApproved
        ? Icons.check_circle_rounded
        : (isRejected
            ? Icons.cancel_rounded
            : Icons.hourglass_top_rounded);

    // Determine Step 2 (Supervisor) State
    final bool isSupApproved = req.supervisorStatus == 'Approved' ||
        (req.supervisorActionBy != null && req.status != 'Rejected') ||
        (req.status == 'Pending HR' && req.supervisorActionBy != null);
    final bool isSupRejected = req.supervisorStatus == 'Rejected' ||
        (isRejected && req.supervisorActionBy != null && req.hrActionBy == null);
    final bool isSupPending = req.status == 'Pending Supervisor';
    final bool isSupBypassed = req.supervisorActionBy == null && (req.status == 'Pending HR' || req.status == 'Approved');

    Color supColor;
    IconData supIcon;
    String supTitle;
    String supSubtitle;

    if (isSupApproved) {
      supColor = const Color(0xFF10B981);
      supIcon = Icons.check_circle_rounded;
      supTitle = 'Approved by $supervisorName';
      supSubtitle = '$supervisorRole • $formattedSupervisorDate';
    } else if (isSupRejected) {
      supColor = const Color(0xFFEF4444);
      supIcon = Icons.cancel_rounded;
      supTitle = 'Rejected by $supervisorName';
      supSubtitle = '$supervisorRole • $formattedSupervisorDate';
    } else if (isSupPending) {
      supColor = const Color(0xFFF59E0B);
      supIcon = Icons.hourglass_top_rounded;
      supTitle = 'Awaiting Supervisor Review';
      supSubtitle = 'Pending review by $supervisorName ($supervisorRole)';
    } else if (isSupBypassed) {
      supColor = const Color(0xFF3B82F6);
      supIcon = Icons.check_circle_outline_rounded;
      supTitle = 'Direct to HR Review';
      supSubtitle = 'Supervisor step not required for this role';
    } else {
      supColor = textColor.withValues(alpha: 0.3);
      supIcon = Icons.radio_button_unchecked_rounded;
      supTitle = 'Supervisor Review';
      supSubtitle = 'Pending';
    }

    // Determine Step 3 (HR Manager) State
    final bool isHrApproved = isApproved;
    final bool isHrRejected = isRejected && !isSupRejected;
    final bool isHrPending = req.status == 'Pending HR';

    Color hrColor;
    IconData hrIcon;
    String hrTitle;
    String hrSubtitle;

    if (isHrApproved) {
      hrColor = const Color(0xFF10B981);
      hrIcon = Icons.check_circle_rounded;
      hrTitle = 'Approved by $hrName';
      hrSubtitle = '$hrRole • $formattedHrDate (Message sent to employee)';
    } else if (isHrRejected) {
      hrColor = const Color(0xFFEF4444);
      hrIcon = Icons.cancel_rounded;
      hrTitle = 'Rejected by $hrName';
      hrSubtitle = '$hrRole • $formattedHrDate';
    } else if (isHrPending) {
      hrColor = const Color(0xFF8B5CF6);
      hrIcon = Icons.hourglass_top_rounded;
      hrTitle = 'Awaiting HR Manager Approval';
      hrSubtitle = 'Assigned to $hrName ($hrRole)';
    } else if (isSupRejected) {
      hrColor = textColor.withValues(alpha: 0.3);
      hrIcon = Icons.block_rounded;
      hrTitle = 'HR Manager Review';
      hrSubtitle = 'Terminated due to supervisor rejection';
    } else {
      hrColor = textColor.withValues(alpha: 0.3);
      hrIcon = Icons.radio_button_unchecked_rounded;
      hrTitle = 'HR Manager Review';
      hrSubtitle = 'Pending supervisor approval first';
    }

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.7) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: textColor.withValues(alpha: isDark ? 0.1 : 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.alt_route_rounded,
                size: 16,
                color: Color(0xFF2E65FF),
              ),
              const SizedBox(width: 8),
              Text(
                'Approval Workflow',
                style: TextStyle(
                  color: textColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.2,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: overallColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(overallIcon, size: 12, color: overallColor),
                    const SizedBox(width: 4),
                    Text(
                      req.status,
                      style: TextStyle(
                        color: overallColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Step 1: Submission
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E65FF).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      size: 12,
                      color: Color(0xFF2E65FF),
                    ),
                  ),
                  Container(
                    width: 2,
                    height: 28,
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '1. Registered by $submitterName',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$submitterRole • $formattedSubmitDate',
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.55),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Step 2: Structure Supervisor Review
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: supColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      supIcon,
                      size: 13,
                      color: supColor,
                    ),
                  ),
                  Container(
                    width: 2,
                    height: 28,
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '2. $supTitle',
                        style: TextStyle(
                          color: isSupApproved || isSupRejected ? textColor : textColor.withValues(alpha: 0.75),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        supSubtitle,
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.55),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Step 3: HR Manager Final Approval
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: hrColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hrIcon,
                  size: 13,
                  color: hrColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '3. $hrTitle',
                        style: TextStyle(
                          color: isHrApproved || isHrRejected ? textColor : textColor.withValues(alpha: 0.75),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hrSubtitle,
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.55),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required Color textColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: textColor.withValues(alpha: 0.5)),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: TextStyle(
            color: textColor.withValues(alpha: 0.55),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDialogDayStat({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: color.withValues(alpha: 0.8),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _translateRequestType(String rawType, AttendanceProvider provider) {
    switch (rawType) {
      case 'Annual Leave':
        return provider.translate('vacation_leave');
      case 'Sick Leave':
        return provider.translate('sick_leave');
      case 'Overtime Approval':
        return provider.translate('overtime_approval');
      case 'Forgot to Clock Out':
        return provider.translate('forgot_to_clock_out');
      case 'Hourly Leave':
        return provider.translate('hourly_leave') != 'hourly_leave'
            ? provider.translate('hourly_leave')
            : 'Hourly Leave';
      case 'Change Shift':
        return provider.translate('change_shift') != 'change_shift'
            ? provider.translate('change_shift')
            : 'Change Shift';
      case 'Missing Punch':
        return provider.translate('missing_punch');
      default:
        return rawType;
    }
  }

  String _translateRequestStatus(
    String rawStatus,
    AttendanceProvider provider,
  ) {
    switch (rawStatus) {
      case 'Approved':
        return provider.translate('status_approved');
      case 'Pending':
        return provider.translate('status_pending');
      case 'Rejected':
        return provider.translate('status_rejected');
      default:
        return rawStatus;
    }
  }
}
