import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/attendance_provider.dart';
import '../models/hr_models.dart';
import '../models/attendance_record.dart';
import '../models/request_model.dart';
import '../widgets/glass_container.dart';

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

  List<CompanyEmployee> _getSubordinates(AttendanceProvider provider) {
    final currentUser = provider.currentEmployee;
    if (currentUser == null) return [];

    if (currentUser.role == 'hr') {
      // HR sees all other employees
      return provider.employees.where((e) => e.id != currentUser.id).toList();
    }

    if (currentUser.role == 'supervisor') {
      final Set<String> subordinateIds = {};
      final List<CompanyEmployee> list = [];

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

    return [];
  }

  void _loadSubordinateRecords(
    AttendanceProvider provider,
    String empId,
  ) async {
    setState(() {
      _isLoadingSubordinate = true;
      _selectedEmployeeId = empId;
    });

    final records = await provider.getEmployeeRecords(empId);
    final requests = await provider.getEmployeeRequests(empId);

    setState(() {
      _subordinateRecords = records;
      _subordinateRequests = requests;
      _isLoadingSubordinate = false;
    });
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
      final totalDays = DateUtils.getDaysInMonth(_reportMonth.year, _reportMonth.month);
      final List<DateTime> datesInPeriod = List.generate(
        totalDays,
        (index) => DateTime(_reportMonth.year, _reportMonth.month, index + 1),
      );

      final isCurrentUser = _selectedEmployeeId == null || _selectedEmployeeId == provider.currentEmployee?.id;
      final recordsToCompile = isCurrentUser ? provider.records : _subordinateRecords;
      final requestsToCompile = isCurrentUser ? provider.requests : _subordinateRequests;

      // Resolve Employee and Shift
      final emp = isCurrentUser
          ? provider.currentEmployee!
          : provider.employees.firstWhere(
              (e) => e.id == _selectedEmployeeId,
              orElse: () => provider.currentEmployee!,
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
          if (req.status == 'Approved' && req.type == 'Change Shift' && req.targetShiftId != null) {
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

              if ((target.isAtSameMomentAs(startOnly) || target.isAfter(startOnly)) &&
                  (target.isAtSameMomentAs(endOnly) || target.isBefore(endOnly))) {
                shift = provider.shifts.firstWhere((s) => s.id == req.targetShiftId);
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


        final dateRecords = recordsToCompile.where(
          (rec) =>
              rec.checkIn.year == date.year &&
              rec.checkIn.month == date.month &&
              rec.checkIn.day == date.day,
        ).toList();

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
        for (var req in requestsToCompile) {
          if (req.status != 'Approved') continue;
          if (req.type == 'Missing Punch') continue; // Handled separately
          
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

            if ((target.isAtSameMomentAs(startOnly) || target.isAfter(startOnly)) &&
                (target.isAtSameMomentAs(endOnly) || target.isBefore(endOnly))) {
              dateApprovedRequests.add(req);
              if (req.type.contains('Leave')) {
                hasLeaveRequest = true;
              }
            }
          } catch (e) {
            // Ignore parsing errors
          }
        }

        final dateStrForMissingPunch = DateFormat('MMMM d, yyyy').format(date);
        final missingPunchReqs = requestsToCompile.where((req) =>
            req.type == 'Missing Punch' &&
            req.date == dateStrForMissingPunch &&
            req.status == 'Approved').toList();
        final hasApprovedMissingPunch = missingPunchReqs.isNotEmpty;

        List<String> missingPunchTimes = [];
        for (var req in missingPunchReqs) {
          final duration = req.duration;
          if (duration.contains('Clock In:') || duration.contains('Clock Out:')) {
            final timeStr = duration.replaceAll('Clock In:', '').replaceAll('Clock Out:', '').trim();
            try {
              final parsedTime = timeStr.contains('AM') || timeStr.contains('PM')
                  ? DateFormat('hh:mm a').parse(timeStr)
                  : DateFormat('HH:mm').parse(timeStr);
              missingPunchTimes.add(DateFormat('HH:mm').format(parsedTime));
            } catch (_) {}
          }
        }

        if (hasApprovedMissingPunch && !hasRecord) {
          final missingPunchReq = missingPunchReqs.first;
          final duration = missingPunchReq.duration;
          if (duration.contains('Clock In:') && duration.contains('Clock Out:')) {
            final inTime = duration.split('Clock Out:')[0].replaceAll('Clock In:', '').trim();
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
            final startStr = isMissedCheckIn ? '--:--' : DateFormat('HH:mm').format(rec.checkIn);
            final endStr = rec.checkOut != null
                ? DateFormat('HH:mm').format(rec.checkOut!)
                : (isToday ? provider.translate('active') : provider.translate('missing'));
            sessionTimes.add('$startStr - $endStr');
          }
          clockTimeStr = sessionTimes.join('\n');

          int totalExcusedRestMinutes = 0;

          final breakStartStr = shift.getBreakStartForDate(date);
          final breakEndStr = shift.getBreakEndForDate(date);
          final allowedBreakDuration = shift.getBreakDurationForDate(date);

          DateTime? bStart;
          DateTime? bEnd;
          if (breakStartStr.isNotEmpty && breakEndStr.isNotEmpty && allowedBreakDuration > 0) {
            final bsParts = breakStartStr.split(':');
            final beParts = breakEndStr.split(':');
            if (bsParts.length >= 2 && beParts.length >= 2) {
              bStart = DateTime(date.year, date.month, date.day, int.parse(bsParts[0]), int.parse(bsParts[1]));
              bEnd = DateTime(date.year, date.month, date.day, int.parse(beParts[0]), int.parse(beParts[1]));
              if (bEnd.isBefore(bStart)) {
                bEnd = bEnd.add(const Duration(days: 1));
              }
            }
          }

          // Calculate rest minutes (gap between sessions)
          if (sortedRecords.length > 1) {
            for (int i = 0; i < sortedRecords.length - 1; i++) {
              final currentOut = sortedRecords[i].checkOut;
              final nextIn = sortedRecords[i+1].checkIn;
              if (currentOut != null && nextIn.isAfter(currentOut)) {
                final gapDuration = nextIn.difference(currentOut).inMinutes;
                if (bStart != null && bEnd != null) {
                  // Find intersection of gap with break window
                  final intersectStart = currentOut.isAfter(bStart) ? currentOut : bStart;
                  final intersectEnd = nextIn.isBefore(bEnd) ? nextIn : bEnd;
                  
                  int excusedInGap = 0;
                  if (intersectEnd.isAfter(intersectStart)) {
                    excusedInGap = intersectEnd.difference(intersectStart).inMinutes;
                  }
                  
                  // Limit total excused across all gaps to allowedBreakDuration
                  if (totalExcusedRestMinutes + excusedInGap > allowedBreakDuration) {
                    excusedInGap = allowedBreakDuration - totalExcusedRestMinutes;
                    if (excusedInGap < 0) excusedInGap = 0;
                  }
                  
                  totalExcusedRestMinutes += excusedInGap;
                  restMinutes += excusedInGap; // Only count excused rest time in the UI column
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
            final rawEnd = rec.checkOut ?? (isToday ? DateTime.now() : rawStart);
            
            final sessionStart = DateTime(rawStart.year, rawStart.month, rawStart.day, rawStart.hour, rawStart.minute);
            final sessionEnd = DateTime(rawEnd.year, rawEnd.month, rawEnd.day, rawEnd.hour, rawEnd.minute);

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

            final intersectStart = sessionStart.isAfter(shiftStart) ? sessionStart : shiftStart;
            final intersectEnd = sessionEnd.isBefore(shiftEnd) ? sessionEnd : shiftEnd;

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
                final endForBefore = sessionEnd.isBefore(shiftStart) ? sessionEnd : shiftStart;
                extraTimeMinutes += endForBefore.difference(sessionStart).inMinutes;
              }
              if (sessionEnd.isAfter(shiftEnd)) {
                final startForAfter = sessionStart.isAfter(shiftEnd) ? sessionStart : shiftEnd;
                extraTimeMinutes += sessionEnd.difference(startForAfter).inMinutes;
              }
            }
          }

          final isWeekendForDelay = !shift.isWorkingDay(date);
          if (!isWeekendForDelay) {
            final hasOnlyOnePunch = sortedRecords.length == 1 && (sortedRecords.first.checkIn == sortedRecords.first.checkOut || sortedRecords.first.checkOut == null);

            // 3. Delay Minutes (late arrival on the first session)
            final firstRec = sortedRecords.first;
            final isMissedCheckIn = firstRec.checkIn == firstRec.checkOut;
            if (!isMissedCheckIn && !hasOnlyOnePunch) {
              final checkInMinutes = firstRec.checkIn.hour * 60 + firstRec.checkIn.minute;
              final delay = checkInMinutes - shiftStartMinutes;
              if (delay > shift.forgivenessOfDelay) {
                delayMinutes = delay;
              }
            }

            // 4. Early Exit Minutes (leaving early on the last completed session)
            final lastRec = sortedRecords.last;
            if (lastRec.checkOut != null && !hasOnlyOnePunch) {
              final checkOutMinutes = lastRec.checkOut!.hour * 60 + lastRec.checkOut!.minute;
              final earlyExit = shiftEndMinutes - checkOutMinutes;
              if (earlyExit > shift.earlyExit) {
                earlyExitMinutes = earlyExit;
              }
            }
          }

          // 5. Overtime calculation (based on extra time minutes and approved overtime requests)
          final dateStr = DateFormat('MMMM d, yyyy').format(date);
          final hasApprovedOt = requestsToCompile.any((req) =>
              req.type == 'Overtime Approval' &&
              req.date == dateStr &&
              req.status == 'Approved');

          if (extraTimeMinutes > 0 && hasApprovedOt) {
            final isOvertimeAllowed = group?.overtimeAllowed ?? true;
            if (isOvertimeAllowed) {
              final minOt = group?.minOvertimeMinutes ?? 0;
              final maxOt = group?.maxOvertimeMinutes ?? 480;
              if (extraTimeMinutes >= minOt) {
                final baseOt = extraTimeMinutes.clamp(0, maxOt);
                final isWeekend = !shift.isWorkingDay(date);
                if (isWeekend) {
                  overtimeMinutes = (baseOt * (group?.weekendOvertimeRatio ?? 1.5)).toInt();
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
              if (delayMinutes >= g.delayTier1Min && delayMinutes <= g.delayTier1Max) {
                delayPenalty = g.delayTier1Penalty;
              } else if (delayMinutes >= g.delayTier2Min && delayMinutes <= g.delayTier2Max) {
                delayPenalty = g.delayTier2Penalty;
              } else if (delayMinutes >= g.delayTier3Min) {
                delayPenalty = g.delayTier3Penalty;
              }
            }
          }

          double earlyExitPenalty = 0.0;
          if (earlyExitMinutes > 0 && (group?.earlyExitPenaltiesEnabled ?? true)) {
            final g = group;
            if (g != null) {
              if (earlyExitMinutes >= g.earlyExitTier1Min && earlyExitMinutes <= g.earlyExitTier1Max) {
                earlyExitPenalty = g.earlyExitTier1Penalty;
              } else if (earlyExitMinutes >= g.earlyExitTier2Min && earlyExitMinutes <= g.earlyExitTier2Max) {
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
          final requestTypes = dateApprovedRequests.map((r) {
            if (r.type == 'Annual Leave') return provider.translate('vacation_leave');
            if (r.type == 'Sick Leave') return provider.translate('sick_leave');
            if (r.type == 'Overtime Approval') return provider.translate('overtime_approval');
            if (r.type == 'Hourly Leave') {
              final hl = provider.translate('hourly_leave');
              return hl != 'hourly_leave' ? hl : 'Hourly Leave';
            }
            return r.type;
          }).join('\n');

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

        int deficitMinutes = delayMinutes + earlyExitMinutes + unexcusedRestMinutes;
        final isWeekendDay = !shift.isWorkingDay(date);
        final isFutureDay = date.isAfter(DateTime.now());
        
        if (!isWeekendDay && !hasLeaveRequest && holiday == null && !hasApprovedMissingPunch && !isFutureDay) {
          int shiftDur = shiftEndMinutes - shiftStartMinutes;
          if (shiftDur < 0) shiftDur += 24 * 60;

          int missingPunchDeficit = 0;
          final hasOnlyOnePunch = dateRecords.length == 1 && (dateRecords.first.checkIn == dateRecords.first.checkOut || dateRecords.first.checkOut == null);
          if (hasOnlyOnePunch) {
              missingPunchDeficit = shiftDur;
          } else {
              for (var r in dateRecords) {
                  if (r.checkIn == r.checkOut) {
                      final outMinutes = r.checkOut!.hour * 60 + r.checkOut!.minute;
                      final clampedOut = outMinutes > shiftEndMinutes ? shiftEndMinutes : outMinutes;
                      if (clampedOut > shiftStartMinutes) {
                          missingPunchDeficit += (clampedOut - shiftStartMinutes);
                      }
                  } else if (r.checkOut == null) {
                      final isToday = DateUtils.isSameDay(date, DateTime.now());
                      if (!isToday) {
                          final inMinutes = r.checkIn.hour * 60 + r.checkIn.minute;
                          final clampedIn = inMinutes < shiftStartMinutes ? shiftStartMinutes : inMinutes;
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
              // Page Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 8.0),
                child: Text(
                  provider.translate('attendance_history'),
                  style: TextStyle(
                    color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)),
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
              ),

              // Employee Dropdown
              if (provider.currentEmployee != null) ...[
                _buildEmployeeDropdown(provider, [provider.currentEmployee!, ...subordinates]),
                SizedBox(height: 10),
              ],

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
                                  _buildMonthSelector(),
                                  _buildSummaryCards(compiledData),
                                  SizedBox(height: 14),
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

  Widget _buildClockTimeWidget(String text, List<String> highlights, bool isLeave) {
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
          color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)),
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
          color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)),
        ),
      );
    }

    int lastMatchEnd = 0;
    List<TextSpan> spans = [];

    for (var match in matches) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(text: text.substring(lastMatchEnd, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(0),
        style: TextStyle(color: Color(0xFF5B9BFF), fontWeight: FontWeight.bold),
      ));
      lastMatchEnd = match.end;
    }
    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastMatchEnd)));
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(fontSize: 12, height: 1.2, color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black))),
        children: spans,
      ),
    );
  }

  Widget _buildMonthSelector() {
    final monthStr = DateFormat('MMMM yyyy').format(_reportMonth);
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: kIsWeb ? 400 : double.infinity),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left, color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)), size: 20),
            onPressed: () {
              setState(() {
                _reportMonth = DateTime(_reportMonth.year, _reportMonth.month - 1);
              });
            },
          ),
          Text(
            monthStr,
            style: TextStyle(
              color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)),
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            icon: Icon(Icons.chevron_right, color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)), size: 20),
            onPressed: () {
              setState(() {
                _reportMonth = DateTime(_reportMonth.year, _reportMonth.month + 1);
              });
            },
          ),
        ],
      ),
        ),
      ),
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

    final String totalAttendanceStr = '${totalAttendance ~/ 60}h ${totalAttendance % 60}m';
    final String totalDutyStr = '${totalDuty ~/ 60}h ${totalDuty % 60}m';
    final String totalRestStr = '${totalRest ~/ 60}h ${totalRest % 60}m';
    final String totalOvertimeStr = '${totalOvertime ~/ 60}h ${totalOvertime % 60}m';
    final String totalDeficitStr = '${totalDeficit ~/ 60}h ${totalDeficit % 60}m';

    return Container(
      height: 70,
      margin: const EdgeInsets.only(top: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        children: [
          _buildMiniSummaryCard(provider.translate('duty_days'), '$activeDays days', const Color(0xFF2E65FF)),
          SizedBox(width: 10),
          _buildMiniSummaryCard(provider.translate('total_attendance'), totalAttendanceStr, const Color(0xFF2EBD96)),
          SizedBox(width: 10),
          _buildMiniSummaryCard(provider.translate('rest_time'), totalRestStr, const Color(0xFF2EBD96)),
          SizedBox(width: 10),
          _buildMiniSummaryCard(provider.translate('total_duty'), totalDutyStr, const Color(0xFF5B9BFF)),
          SizedBox(width: 10),
          _buildMiniSummaryCard(provider.translate('overtime'), totalOvertimeStr, const Color(0xFF00FF87)),
          SizedBox(width: 10),
          _buildMiniSummaryCard(provider.translate('delay'), '${totalDelay}m', const Color(0xFFFF5C5C)),
          SizedBox(width: 10),
          _buildMiniSummaryCard(provider.translate('early_exit'), '${totalEarlyExit}m', const Color(0xFFFF5C5C)),
          SizedBox(width: 10),
          _buildMiniSummaryCard('Deficit', totalDeficitStr, const Color(0xFFFF5C5C)),
          SizedBox(width: 10),
          _buildMiniSummaryCard(provider.translate('penalty'), '${NumberFormat('#,##0').format(totalPenalties)} IQD', const Color(0xFFFF5C5C)),
        ],
      ),
    );
  }

  Widget _buildMiniSummaryCard(String label, String value, Color accentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.05)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.08))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.4)),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)),
              fontSize: 13,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  color: accentColor.withValues(alpha: 0.45),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportTable(List<Map<String, dynamic>> compiledData) {
    final provider = Provider.of<AttendanceProvider>(context);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: GlassContainer(
          padding: EdgeInsets.zero,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              physics: const BouncingScrollPhysics(),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 40),
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.08)),
                    ),
                    child: DataTable(
                    columnSpacing: 22,
                    headingRowColor: WidgetStateProperty.all(((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.06))),
                    headingRowHeight: 46,
                    dataRowMinHeight: 44,
                    dataRowMaxHeight: 64,
                    columns: [
                      DataColumn(label: Text(provider.translate('date'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                      DataColumn(label: Text(provider.translate('clock_time'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF5B9BFF)))),
                      DataColumn(label: Text(provider.translate('attendance'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                      DataColumn(label: Text(provider.translate('rest_time'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF2EBD96)))),
                      DataColumn(label: Text(provider.translate('duty'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                      DataColumn(label: Text(provider.translate('delay'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFFF5C5C)))),
                      DataColumn(label: Text(provider.translate('early_exit'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFFF5C5C)))),
                      DataColumn(label: Text('Deficit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFFF5C5C)))),
                      DataColumn(label: Text(provider.translate('extra_time'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFFF9800)))),
                      DataColumn(label: Text(provider.translate('overtime'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF00FF87)))),
                      DataColumn(label: Text(provider.translate('penalty'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFFF5C5C)))),
                    ],
                    rows: compiledData.map((row) {
                      final date = row['date'] as DateTime;
                      final dayNameEng = DateFormat('EEEE').format(date).toLowerCase();
                      final translatedDay = provider.translate(dayNameEng);
                      final dateStr = '$translatedDay\n${DateFormat('dd MMM').format(date)}';
                      final isWeekend = row['isWeekend'] as bool;
                      
                      final attendanceStr = formatMinutes(row['attendance'] as int);
                      final restStr = formatMinutes((row['rest'] ?? 0) as int);
                      final dutyStr = formatMinutes(row['duty'] as int);
                      final delayStr = formatMinutes(row['delay'] as int);
                      final earlyExitStr = formatMinutes(row['earlyExit'] as int);
                      final extraTimeStr = formatMinutes(row['extraTime'] as int);
                      final overtimeStr = formatMinutes(row['overtime'] as int);
                      final penaltyVal = row['penalty'] as double;
                      final penaltyStr = penaltyVal > 0 
                          ? '${NumberFormat('#,##0').format(penaltyVal)} IQD' 
                          : '-';

                      final rowColor = isWeekend 
                          ? ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.02)) 
                          : Colors.transparent;

                      return DataRow(
                        color: WidgetStateProperty.all(rowColor),
                        cells: [
                          DataCell(Text(
                            dateStr,
                            style: TextStyle(
                              color: isWeekend 
                                  ? (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.38) 
                                  : (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.7),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              height: 1.2,
                            ),
                          )),
                          DataCell(
                            _buildClockTimeWidget(
                              row['clockTime'] as String,
                              row['missingPunchTimes'] as List<String>? ?? [],
                              row['isLeave'] as bool? ?? false,
                            ),
                          ),
                          DataCell(Text((row['isLeave'] as bool? ?? false) && !(row['hasRecord'] as bool) ? '-' : attendanceStr, style: TextStyle(fontSize: 12))),
                          DataCell(Text((row['isLeave'] as bool? ?? false) && !(row['hasRecord'] as bool) ? '-' : restStr, style: TextStyle(fontSize: 12, color: Color(0xFF2EBD96)))),
                          DataCell(Text((row['isLeave'] as bool? ?? false) && !(row['hasRecord'] as bool) ? '-' : dutyStr, style: TextStyle(fontSize: 12))),
                          DataCell(Text(
                            delayStr,
                            style: TextStyle(
                              color: row['delay'] as int > 0 ? const Color(0xFFFF5C5C) : (Theme.of(context).brightness == Brightness.dark ? Colors.white60 : Colors.black54),
                              fontWeight: row['delay'] as int > 0 ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12,
                            ),
                          )),
                          DataCell(Text(
                            earlyExitStr,
                            style: TextStyle(
                              color: row['earlyExit'] as int > 0 ? const Color(0xFFFF5C5C) : (Theme.of(context).brightness == Brightness.dark ? Colors.white60 : Colors.black54),
                              fontWeight: row['earlyExit'] as int > 0 ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12,
                            ),
                          )),
                          DataCell(Text(
                            formatMinutes((row['deficit'] as int?) ?? 0),
                            style: TextStyle(
                              color: ((row['deficit'] as int?) ?? 0) > 0 ? const Color(0xFFFF5C5C) : (Theme.of(context).brightness == Brightness.dark ? Colors.white60 : Colors.black54),
                              fontWeight: ((row['deficit'] as int?) ?? 0) > 0 ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12,
                            ),
                          )),
                          DataCell(Text(
                            extraTimeStr,
                            style: TextStyle(
                              color: row['extraTime'] as int > 0 ? const Color(0xFFFF9800) : (Theme.of(context).brightness == Brightness.dark ? Colors.white60 : Colors.black54),
                              fontSize: 12,
                            ),
                          )),
                          DataCell(Text(
                            overtimeStr,
                            style: TextStyle(
                              color: row['overtime'] as int > 0 ? const Color(0xFF00FF87) : (Theme.of(context).brightness == Brightness.dark ? Colors.white60 : Colors.black54),
                              fontWeight: row['overtime'] as int > 0 ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12,
                            ),
                          )),
                          DataCell(Text(
                            penaltyStr,
                            style: TextStyle(
                              color: penaltyVal > 0 ? const Color(0xFFFF5C5C) : (Theme.of(context).brightness == Brightness.dark ? Colors.white60 : Colors.black54),
                              fontWeight: penaltyVal > 0 ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12,
                            ),
                          )),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: GlassContainer(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
        child: Theme(
          data: ThemeData.dark().copyWith(canvasColor: const Color(0xFF1E293B)),
          child: DropdownMenu<String>(
            initialSelection: _selectedEmployeeId ?? provider.currentEmployee?.id,
            enableFilter: true,
            enableSearch: true,
            expandedInsets: EdgeInsets.zero,
            menuStyle: MenuStyle(
              backgroundColor: WidgetStateProperty.all(
                (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B).withValues(alpha: 0.98) : Colors.white.withValues(alpha: 0.98))
              ),
              elevation: WidgetStateProperty.all(8),
              shape: WidgetStateProperty.all(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.1),
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
              color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)),
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
                if (val == provider.currentEmployee?.id) {
                  setState(() {
                    _selectedEmployeeId = val;
                    _isLoadingSubordinate = false;
                  });
                } else {
                  _loadSubordinateRecords(provider, val);
                }
              }
            },
          ),
        ),
      ),
    );
  }


}
