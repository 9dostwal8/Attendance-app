import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/attendance_record.dart';
import '../../models/hr_models.dart';
import '../../models/request_model.dart';
import '../../providers/attendance_provider.dart';
import '../../services/export_service.dart';
import '../glass_container.dart';
import '../neu_button.dart';

class HrDailyReportTab extends StatefulWidget {
  final String searchQuery;

  const HrDailyReportTab({
    super.key,
    this.searchQuery = '',
  });

  @override
  State<HrDailyReportTab> createState() => _HrDailyReportTabState();
}

class _HrDailyReportTabState extends State<HrDailyReportTab> {
  DateTime _selectedDate = DateTime.now();
  String? _selectedStructureId;
  String? _selectedShiftId;
  String? _selectedGroupId;
  String _statusFilter = 'all'; // 'all', 'present', 'late', 'absent', 'leave'
  late TextEditingController _searchController;
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();
  Map<String, dynamic>? _selectedRow;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.searchQuery);
  }

  @override
  void didUpdateWidget(covariant HrDailyReportTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery != oldWidget.searchQuery &&
        widget.searchQuery != _searchController.text) {
      _searchController.text = widget.searchQuery;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  bool _matchesStructure(
    String? empStructureId,
    String? targetStructureId,
    List<OrgStructure> structures,
  ) {
    if (targetStructureId == null || targetStructureId == 'all') {
      return true;
    }
    if (empStructureId == null || empStructureId.isEmpty) {
      return false;
    }
    if (empStructureId.trim().toLowerCase() ==
        targetStructureId.trim().toLowerCase()) {
      return true;
    }
    // Check if empStructureId is a descendant/sub-branch of targetStructureId
    String? currentId = empStructureId;
    final visited = <String>{};
    while (currentId != null && !visited.contains(currentId)) {
      visited.add(currentId);
      final struct = structures.where((s) => s.id == currentId).firstOrNull;
      if (struct == null) break;
      if (struct.parentId == targetStructureId) {
        return true;
      }
      currentId = struct.parentId;
    }
    return false;
  }

  String _formatMinutes(int minutes) {
    if (minutes <= 0) return '-';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  /// Compiles full history-like attendance analytics for a single employee on the given date
  Map<String, dynamic> _compileEmployeeDayData({
    required CompanyEmployee emp,
    required DateTime date,
    required AttendanceProvider provider,
  }) {
    final activeGroupId = provider.getGroupIdForDate(emp, date);
    final group = provider.groups.where((g) => g.id == activeGroupId).firstOrNull;
    final shift = provider.getShiftForDate(emp, date);
    final structure = provider.structures.where((s) => s.id == emp.structureId).firstOrNull;

    final isWorkingDay = shift.isWorkingDay(date);
    final startTimeStr = shift.getStartTimeForDate(date);
    final endTimeStr = shift.getEndTimeForDate(date);

    final partsStart = startTimeStr.split(':');
    final partsEnd = endTimeStr.split(':');
    final shiftStartMinutes = partsStart.length >= 2
        ? int.parse(partsStart[0]) * 60 + int.parse(partsStart[1])
        : 540;
    final shiftEndMinutes = partsEnd.length >= 2
        ? int.parse(partsEnd[0]) * 60 + int.parse(partsEnd[1])
        : 1020;

    // Compile day requests
    final allRequests = [
      ...provider.allCompanyRequests,
      ...provider.requests,
    ];

    final dateRecords = provider.getRecordsForDate(
      date,
      emp: emp,
      requestsPool: allRequests,
    );
    final sortedRecords = List<AttendanceRecord>.from(dateRecords)
      ..sort((a, b) => a.checkIn.compareTo(b.checkIn));

    final dateStrFormatted = DateFormat('MMMM d, yyyy').format(date);
    final shortDateStr = DateFormat('MMMM d').format(date);

    final dayRequests = <Request>[];
    bool hasLeaveRequest = false;
    String leaveType = '';
    bool hasApprovedOt = false;

    for (var req in allRequests) {
      if (req.employeeId != null &&
          req.employeeId!.trim().toLowerCase() == emp.id.trim().toLowerCase()) {
        final reqDate = req.date;
        bool dateMatches = false;

        if (reqDate.contains(' - ')) {
          try {
            final parts = reqDate.split(' - ');
            final end = DateFormat('MMMM d, yyyy').parse(parts[1].trim());
            var startStr = parts[0].trim();
            if (!startStr.contains(',')) {
              startStr = '$startStr, ${end.year}';
            }
            final start = DateFormat('MMMM d, yyyy').parse(startStr);
            final target = DateTime(date.year, date.month, date.day);
            final sOnly = DateTime(start.year, start.month, start.day);
            final eOnly = DateTime(end.year, end.month, end.day);
            if ((target.isAtSameMomentAs(sOnly) || target.isAfter(sOnly)) &&
                (target.isAtSameMomentAs(eOnly) || target.isBefore(eOnly))) {
              dateMatches = true;
            }
          } catch (_) {}
        } else if (reqDate.contains(dateStrFormatted) ||
            reqDate.contains(shortDateStr)) {
          dateMatches = true;
        }

        if (dateMatches) {
          dayRequests.add(req);
          if (req.status == 'Approved') {
            if (req.type.contains('Leave')) {
              hasLeaveRequest = true;
              leaveType = req.type;
            }
            if (req.type == 'Overtime Approval') {
              hasApprovedOt = true;
            }
          }
        }
      }
    }

    final holiday = provider.getHolidayForEmployee(date, group?.id);

    int totalActualMinutes = 0;
    int dutyMinutes = 0;
    int restMinutes = 0;
    int delayMinutes = 0;
    int earlyExitMinutes = 0;
    int extraTimeMinutes = 0;
    int overtimeMinutes = 0;
    bool hasActiveSession = false;

    final isToday = DateUtils.isSameDay(date, DateTime.now());

    // 1. Session strings & actual duration
    final List<String> sessionTimes = [];
    if (sortedRecords.isNotEmpty) {
      for (var rec in sortedRecords) {
        final isMissedCheckIn = rec.checkIn == rec.checkOut;
        final startStr =
            isMissedCheckIn ? '--:--' : DateFormat('HH:mm').format(rec.checkIn);
        final endStr = rec.checkOut != null
            ? DateFormat('HH:mm').format(rec.checkOut!)
            : (isToday ? 'Active' : 'Missing');

        if (rec.checkOut == null && isToday) {
          hasActiveSession = true;
        }
        sessionTimes.add('$startStr - $endStr');
        totalActualMinutes += rec.duration.inMinutes;
      }
    }

    String clockTimeStr = sessionTimes.isNotEmpty ? sessionTimes.join('\n') : '-';

    // 2. Break / Rest calculation
    if (sortedRecords.length > 1) {
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

      int totalExcusedRest = 0;
      for (int i = 0; i < sortedRecords.length - 1; i++) {
        final currentOut = sortedRecords[i].checkOut;
        final nextIn = sortedRecords[i + 1].checkIn;
        if (currentOut != null && nextIn.isAfter(currentOut)) {
          if (bStart != null && bEnd != null) {
            final intStart = currentOut.isAfter(bStart) ? currentOut : bStart;
            final intEnd = nextIn.isBefore(bEnd) ? nextIn : bEnd;
            int excused = 0;
            if (intEnd.isAfter(intStart)) {
              excused = intEnd.difference(intStart).inMinutes;
            }
            if (totalExcusedRest + excused > allowedBreakDuration) {
              excused = allowedBreakDuration - totalExcusedRest;
              if (excused < 0) excused = 0;
            }
            totalExcusedRest += excused;
            restMinutes += excused;
          }
        }
      }
    }

    // 3. Duty Time & Extra Time
    if (sortedRecords.isNotEmpty) {
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
      if (shiftEnd.isBefore(shiftStart) || shiftEnd.isAtSameMomentAs(shiftStart) || shift.isOvernightForDate(date)) {
        shiftEnd = shiftEnd.add(const Duration(days: 1));
      }

      for (var rec in sortedRecords) {
        final rawStart = rec.checkIn;
        final rawEnd = rec.checkOut ?? (isToday ? DateTime.now() : rawStart);

        final sStart = DateTime(
          rawStart.year,
          rawStart.month,
          rawStart.day,
          rawStart.hour,
          rawStart.minute,
        );
        final sEnd = DateTime(
          rawEnd.year,
          rawEnd.month,
          rawEnd.day,
          rawEnd.hour,
          rawEnd.minute,
        );

        final intStart = sStart.isAfter(shiftStart) ? sStart : shiftStart;
        final intEnd = sEnd.isBefore(shiftEnd) ? sEnd : shiftEnd;
        if (intEnd.isAfter(intStart)) {
          dutyMinutes += intEnd.difference(intStart).inMinutes;
        }

        if (!isWorkingDay) {
          extraTimeMinutes += sEnd.difference(sStart).inMinutes;
        } else {
          if (sStart.isBefore(shiftStart)) {
            final endBefore = sEnd.isBefore(shiftStart) ? sEnd : shiftStart;
            extraTimeMinutes += endBefore.difference(sStart).inMinutes;
          }
          if (sEnd.isAfter(shiftEnd)) {
            final startAfter = sStart.isAfter(shiftEnd) ? sStart : shiftEnd;
            extraTimeMinutes += sEnd.difference(startAfter).inMinutes;
          }
        }
      }

      final isSpecial = shift.isSpecialShiftForDate(date);
      final dayShiftDurMins = shift.getShiftDurationMinutesForDate(date);

      if (isSpecial) {
        dutyMinutes = totalActualMinutes > dayShiftDurMins ? dayShiftDurMins : totalActualMinutes;
        extraTimeMinutes = totalActualMinutes > dayShiftDurMins ? (totalActualMinutes - dayShiftDurMins) : 0;
        delayMinutes = 0;
        earlyExitMinutes = 0;
      } else if (isWorkingDay && !hasLeaveRequest && holiday == null) {
        // Delay (First session arrival)
        final firstRec = sortedRecords.first;
        final isMissedCheckIn = firstRec.checkIn == firstRec.checkOut;
        if (!isMissedCheckIn) {
          final diff = firstRec.checkIn.difference(shiftStart).inMinutes;
          if (diff > shift.forgivenessOfDelay) {
            delayMinutes = diff;
          }
        }

        // Early Exit (Last session departure)
        final lastRec = sortedRecords.last;
        if (lastRec.checkOut != null) {
          final diff = shiftEnd.difference(lastRec.checkOut!).inMinutes;
          if (diff > shift.earlyExit) {
            earlyExitMinutes = diff;
          }
        }
      }

      // Overtime
      if (extraTimeMinutes > 0 && hasApprovedOt) {
        final minOt = group?.minOvertimeMinutes ?? 0;
        final maxOt = group?.maxOvertimeMinutes ?? 480;
        if (extraTimeMinutes >= minOt) {
          final baseOt = extraTimeMinutes.clamp(0, maxOt);
          if (!isWorkingDay) {
            overtimeMinutes =
                (baseOt * (group?.weekendOvertimeRatio ?? 1.5)).toInt();
          } else {
            overtimeMinutes = baseOt;
          }
        }
      }
    }

    // Status resolution
    String status = 'Present';
    Color statusColor = const Color(0xFF10B981);
    IconData statusIcon = Icons.check_circle_rounded;

    if (hasLeaveRequest) {
      status = leaveType.isNotEmpty ? leaveType : 'Leave';
      statusColor = const Color(0xFF6366F1);
      statusIcon = Icons.beach_access_rounded;
      if (clockTimeStr == '-') clockTimeStr = status;
    } else if (holiday != null) {
      status = 'Holiday';
      statusColor = const Color(0xFF00BD96);
      statusIcon = Icons.celebration_rounded;
      if (clockTimeStr == '-') clockTimeStr = holiday.name;
    } else if (sortedRecords.isNotEmpty) {
      if (hasActiveSession) {
        status = 'Active';
        statusColor = const Color(0xFF00E5CE);
        statusIcon = Icons.timer_rounded;
      } else if (delayMinutes > 0) {
        status = 'Late';
        statusColor = const Color(0xFFFF5C5C);
        statusIcon = Icons.alarm_rounded;
      } else {
        status = 'Present';
        statusColor = const Color(0xFF10B981);
        statusIcon = Icons.check_circle_rounded;
      }
    } else {
      if (!isWorkingDay) {
        status = 'Day Off';
        statusColor = const Color(0xFF64748B);
        statusIcon = Icons.hotel_rounded;
        clockTimeStr = 'Off Duty';
      } else if (date.isAfter(DateTime.now())) {
        status = 'Upcoming';
        statusColor = const Color(0xFF94A3B8);
        statusIcon = Icons.calendar_today_rounded;
        clockTimeStr = 'Scheduled';
      } else {
        status = 'Absent';
        statusColor = const Color(0xFFEF4444);
        statusIcon = Icons.cancel_rounded;
        clockTimeStr = 'No Punch';
      }
    }

    return {
      'employee': emp,
      'group': group,
      'groupName': group?.name ?? 'No Group',
      'shift': shift,
      'shiftName': '${shift.name} (${shift.getStartTimeForDate(date)} - ${shift.getEndTimeForDate(date)})',
      'structure': structure,
      'structureName': structure?.name ?? 'Head Office',
      'clockTime': clockTimeStr,
      'attendance': totalActualMinutes,
      'duty': dutyMinutes,
      'rest': restMinutes,
      'delay': delayMinutes,
      'earlyExit': earlyExitMinutes,
      'extraTime': extraTimeMinutes,
      'overtime': overtimeMinutes,
      'status': status,
      'statusColor': statusColor,
      'statusIcon': statusIcon,
      'hasRecord': sortedRecords.isNotEmpty,
      'isToday': isToday,
      'isWorkingDay': isWorkingDay,
      'records': sortedRecords,
      'requests': dayRequests,
    };
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AttendanceProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);

    final allEmployees = provider.employees;
    final structures = provider.structures;
    final shifts = provider.shifts;
    final groups = provider.groups;

    // Apply structural, shift, and group filters
    final query = _searchController.text.trim().toLowerCase();

    final filteredEmployees = allEmployees.where((emp) {
      // 1. Structure filter
      if (!_matchesStructure(emp.structureId, _selectedStructureId, structures)) {
        return false;
      }

      // 2. Group filter
      final activeGroupId = provider.getGroupIdForDate(emp, _selectedDate);
      if (_selectedGroupId != null && _selectedGroupId != 'all') {
        if (activeGroupId != _selectedGroupId) return false;
      }

      // 3. Shift filter
      final activeShift = provider.getShiftForDate(emp, _selectedDate);
      if (_selectedShiftId != null && _selectedShiftId != 'all') {
        if (activeShift.id != _selectedShiftId) return false;
      }

      // 4. Search query
      if (query.isNotEmpty) {
        final matchesName = emp.name.toLowerCase().contains(query);
        final matchesPos = emp.position.toLowerCase().contains(query);
        final matchesId = emp.id.toLowerCase().contains(query);
        final matchesEmail = emp.email.toLowerCase().contains(query);
        if (!matchesName && !matchesPos && !matchesId && !matchesEmail) {
          return false;
        }
      }

      return true;
    }).toList();

    // Compile daily attendance data for each matching employee
    final compiledRows = filteredEmployees
        .map((emp) => _compileEmployeeDayData(
              emp: emp,
              date: _selectedDate,
              provider: provider,
            ))
        .toList();

    // KPI Metrics calculation
    final totalWorkforce = compiledRows.length;
    final presentCount = compiledRows.where((r) {
      final s = (r['status'] as String).toLowerCase();
      return s == 'present' || s == 'active';
    }).length;
    final lateCount = compiledRows.where((r) {
      final s = (r['status'] as String).toLowerCase();
      return s == 'late';
    }).length;
    final absentCount = compiledRows.where((r) {
      final s = (r['status'] as String).toLowerCase();
      return s == 'absent';
    }).length;
    final leaveCount = compiledRows.where((r) {
      final s = (r['status'] as String).toLowerCase();
      return s.contains('leave') || s == 'holiday';
    }).length;
    final totalLateMinutes = compiledRows.fold<int>(
      0,
      (sum, r) => sum + (r['delay'] as int),
    );
    final totalWorkedMinutes = compiledRows.fold<int>(
      0,
      (sum, r) => sum + (r['attendance'] as int),
    );

    // Apply quick status filter
    final displayedRows = compiledRows.where((row) {
      if (_statusFilter == 'all') return true;
      final s = (row['status'] as String).toLowerCase();
      if (_statusFilter == 'present') return s == 'present' || s == 'active';
      if (_statusFilter == 'late') return s == 'late';
      if (_statusFilter == 'absent') return s == 'absent';
      if (_statusFilter == 'leave') return s.contains('leave') || s == 'holiday';
      return true;
    }).toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(20.0, 0, 20.0, kIsWeb ? 20.0 : 80.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Toolbar: Date navigation & Filters
          _buildTopToolbar(context, provider),
          const SizedBox(height: 8),

          // Summary KPI Cards (interactive: tapping a card toggles status filter)
          _buildKpiCards(
            context: context,
            totalWorkforce: totalWorkforce,
            presentCount: presentCount,
            lateCount: lateCount,
            absentCount: absentCount,
            leaveCount: leaveCount,
            totalLateMinutes: totalLateMinutes,
            totalWorkedMinutes: totalWorkedMinutes,
          ),
          const SizedBox(height: 8),

          // Search & Filter Capsule Chips
          _buildFilterBar(
            context: context,
            provider: provider,
            structures: structures,
            shifts: shifts,
            groups: groups,
            totalMatching: totalWorkforce,
            presentCount: presentCount,
            lateCount: lateCount,
            absentCount: absentCount,
            leaveCount: leaveCount,
          ),
          const SizedBox(height: 8),

          // Main Report Content: Web Table or Mobile Card List
          Expanded(
            child: displayedRows.isEmpty
                ? _buildEmptyState(context, isDark, textColor)
                : (kIsWeb || MediaQuery.of(context).size.width >= 900)
                    ? _buildWebReportTable(context, displayedRows, isDark, textColor)
                    : _buildMobileReportList(context, displayedRows, isDark, textColor),
          ),
        ],
      ),
    );
  }

  Widget _buildTopToolbar(BuildContext context, AttendanceProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final isToday = DateUtils.isSameDay(_selectedDate, DateTime.now());

    final formattedDate = DateFormat('EEEE, d MMMM yyyy').format(_selectedDate);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 750;

        final dateNavigator = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            NeuIconButton(
              size: 34,
              variant: NeuButtonVariant.whitePill,
              icon: const Icon(Icons.chevron_left_rounded, size: 20),
              onPressed: () {
                setState(() {
                  _selectedDate = _selectedDate.subtract(const Duration(days: 1));
                  _selectedRow = null;
                });
              },
            ),
            const SizedBox(width: 8),

            // Date Capsule Pill
            InkWell(
              borderRadius: BorderRadius.circular(50),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2035),
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: ColorScheme.fromSeed(
                          seedColor: const Color(0xFF00E5CE),
                          brightness: isDark ? Brightness.dark : Brightness.light,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (picked != null) {
                  setState(() {
                    _selectedDate = picked;
                    _selectedRow = null;
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                decoration: BoxDecoration(
                  gradient: isDark
                      ? const LinearGradient(
                          colors: [Color(0xFF1E283C), Color(0xFF161F2E)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : const LinearGradient(
                          colors: [Colors.white, Color(0xFFF8FAFC)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black26
                          : const Color(0xFF0D2275).withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_month_rounded,
                      size: 16,
                      color: isDark ? const Color(0xFF00F0D8) : const Color(0xFF0A2342),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      formattedDate,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Icon(
                      Icons.arrow_drop_down_rounded,
                      size: 17,
                      color: textColor.withValues(alpha: 0.6),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),

            NeuIconButton(
              size: 34,
              variant: NeuButtonVariant.whitePill,
              icon: const Icon(Icons.chevron_right_rounded, size: 20),
              onPressed: () {
                setState(() {
                  _selectedDate = _selectedDate.add(const Duration(days: 1));
                  _selectedRow = null;
                });
              },
            ),

            if (!isToday) ...[
              const SizedBox(width: 8),
              NeuButton(
                label: 'Today',
                variant: NeuButtonVariant.primary,
                height: 32,
                fontSize: 11,
                padding: const EdgeInsets.symmetric(horizontal: 11),
                onPressed: () {
                  setState(() {
                    _selectedDate = DateTime.now();
                    _selectedRow = null;
                  });
                },
              ),
            ],
          ],
        );

        final exportButtons = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            NeuButton(
              label: 'PDF',
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 15),
              variant: NeuButtonVariant.navy,
              height: 32,
              fontSize: 11.5,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              onPressed: () => _exportReport(context, provider, isPdf: true),
            ),
            const SizedBox(width: 8),
            NeuButton(
              label: 'Excel',
              icon: const Icon(Icons.table_view_outlined, size: 15),
              variant: NeuButtonVariant.whitePill,
              height: 32,
              fontSize: 11.5,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              onPressed: () => _exportReport(context, provider, isPdf: false),
            ),
          ],
        );

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: dateNavigator,
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: exportButtons,
              ),
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            dateNavigator,
            exportButtons,
          ],
        );
      },
    );
  }

  Widget _buildKpiCards({
    required BuildContext context,
    required int totalWorkforce,
    required int presentCount,
    required int lateCount,
    required int absentCount,
    required int leaveCount,
    required int totalLateMinutes,
    required int totalWorkedMinutes,
  }) {
    final cards = [
      _buildMiniKpiCard(
        title: 'Workforce',
        value: '$totalWorkforce',
        subtitle: 'Scheduled Users',
        color: const Color(0xFF00E5CE),
        icon: Icons.people_outline_rounded,
        isActive: _statusFilter == 'all',
        onTap: () => setState(() => _statusFilter = 'all'),
      ),
      _buildMiniKpiCard(
        title: 'Present',
        value: '$presentCount',
        subtitle: 'On Duty / Completed',
        color: const Color(0xFF10B981),
        icon: Icons.check_circle_outline_rounded,
        isActive: _statusFilter == 'present',
        onTap: () => setState(() => _statusFilter = 'present'),
      ),
      _buildMiniKpiCard(
        title: 'Late',
        value: '$lateCount',
        subtitle: totalLateMinutes > 0 ? '${totalLateMinutes}m delay' : 'On time',
        color: const Color(0xFFFF5C5C),
        icon: Icons.alarm_rounded,
        isActive: _statusFilter == 'late',
        onTap: () => setState(() => _statusFilter = 'late'),
      ),
      _buildMiniKpiCard(
        title: 'Absent',
        value: '$absentCount',
        subtitle: 'Unexcused / Off',
        color: const Color(0xFFEF4444),
        icon: Icons.cancel_outlined,
        isActive: _statusFilter == 'absent',
        onTap: () => setState(() => _statusFilter = 'absent'),
      ),
      _buildMiniKpiCard(
        title: 'Leave / Holiday',
        value: '$leaveCount',
        subtitle: 'Approved Off',
        color: const Color(0xFF818CF8),
        icon: Icons.beach_access_rounded,
        isActive: _statusFilter == 'leave',
        onTap: () => setState(() => _statusFilter = 'leave'),
      ),
    ];

    return LayoutBuilder(
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
                  SizedBox(width: 170, child: cards[i]),
                ],
              ],
            ),
          );
        }
      },
    );
  }

  Widget _buildMiniKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: isDark
                ? (isActive
                    ? color.withValues(alpha: 0.15)
                    : const Color(0xFF1E293B).withValues(alpha: 0.7))
                : (isActive
                    ? color.withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.9)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive
                  ? color
                  : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              width: isActive ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isActive
                    ? color.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
                blurRadius: isActive ? 8 : 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, size: 15, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : const Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          value,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        color: isActive
                            ? color
                            : (isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar({
    required BuildContext context,
    required AttendanceProvider provider,
    required List<OrgStructure> structures,
    required List<WorkShift> shifts,
    required List<EmployeeGroup> groups,
    required int totalMatching,
    required int presentCount,
    required int lateCount,
    required int absentCount,
    required int leaveCount,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);

    final bool hasActiveFilter = (_selectedStructureId != null && _selectedStructureId != 'all') ||
        (_selectedShiftId != null && _selectedShiftId != 'all') ||
        (_selectedGroupId != null && _selectedGroupId != 'all') ||
        _statusFilter != 'all' ||
        _searchController.text.trim().isNotEmpty;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Structure Filter Capsule Dropdown
        _buildCapsuleDropdown(
          label: 'Structure',
          icon: Icons.apartment_rounded,
          value: _selectedStructureId ?? 'all',
          isDark: isDark,
          items: [
            const DropdownMenuItem(
              value: 'all',
              child: Text('All Branches / Structures'),
            ),
            ...structures.map((s) => DropdownMenuItem(
                  value: s.id,
                  child: Text(s.name),
                )),
          ],
          onChanged: (val) {
            setState(() {
              _selectedStructureId = (val == 'all') ? null : val;
            });
          },
        ),

        // Shift Filter Capsule Dropdown
        _buildCapsuleDropdown(
          label: 'Shift',
          icon: Icons.schedule_rounded,
          value: _selectedShiftId ?? 'all',
          isDark: isDark,
          items: [
            const DropdownMenuItem(
              value: 'all',
              child: Text('All Shifts'),
            ),
            ...shifts.map((s) => DropdownMenuItem(
                  value: s.id,
                  child: Text('${s.name} (${s.startTime} - ${s.endTime})'),
                )),
          ],
          onChanged: (val) {
            setState(() {
              _selectedShiftId = (val == 'all') ? null : val;
            });
          },
        ),

        // Group Filter Capsule Dropdown
        _buildCapsuleDropdown(
          label: 'Group',
          icon: Icons.group_outlined,
          value: _selectedGroupId ?? 'all',
          isDark: isDark,
          items: [
            const DropdownMenuItem(
              value: 'all',
              child: Text('All Groups'),
            ),
            ...groups.map((g) => DropdownMenuItem(
                  value: g.id,
                  child: Text(g.name),
                )),
          ],
          onChanged: (val) {
            setState(() {
              _selectedGroupId = (val == 'all') ? null : val;
            });
          },
        ),

        // Search Input Capsule
        Container(
          width: 200,
          height: 32,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E283C) : Colors.white,
            borderRadius: BorderRadius.circular(50),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Icon(Icons.search, size: 15, color: isDark ? Colors.white54 : Colors.grey),
              const SizedBox(width: 5),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() {}),
                  style: TextStyle(fontSize: 11.5, color: textColor),
                  decoration: InputDecoration(
                    hintText: 'Search user...',
                    hintStyle: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? Colors.white38 : Colors.grey,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              if (_searchController.text.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    setState(() {});
                  },
                  child: Icon(Icons.close, size: 14, color: isDark ? Colors.white54 : Colors.grey),
                ),
            ],
          ),
        ),

        if (hasActiveFilter)
          NeuButton(
            label: 'Clear Filters',
            icon: const Icon(Icons.clear_all_rounded, size: 15),
            variant: NeuButtonVariant.danger,
            height: 32,
            fontSize: 11,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            onPressed: () {
              setState(() {
                _selectedStructureId = null;
                _selectedShiftId = null;
                _selectedGroupId = null;
                _statusFilter = 'all';
                _searchController.clear();
              });
            },
          ),
      ],
    );
  }

  Widget _buildCapsuleDropdown({
    required String label,
    required IconData icon,
    required String value,
    required bool isDark,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    final textColor = isDark ? const Color(0xFF00F0D8) : const Color(0xFF102B94);
    final isFiltered = value != 'all';

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E283C) : Colors.white,
        borderRadius: BorderRadius.circular(50),
        border: Border.all(
          color: isFiltered
              ? const Color(0xFF00E5CE)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          width: 1.2,
        ),
        boxShadow: [
          if (isFiltered)
            BoxShadow(
              color: const Color(0xFF00E5CE).withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.any((i) => i.value == value) ? value : 'all',
          icon: Icon(Icons.arrow_drop_down, size: 18, color: textColor),
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          style: TextStyle(
            color: textColor,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  /// High-density responsive web table matching History screen
  Widget _buildWebReportTable(
    BuildContext context,
    List<Map<String, dynamic>> rows,
    bool isDark,
    Color textColor,
  ) {
    const columnWidths = <int, TableColumnWidth>{
      0: FlexColumnWidth(1.8), // Employee
      1: FlexColumnWidth(1.3), // Structure
      2: FlexColumnWidth(1.5), // Shift
      3: FlexColumnWidth(1.1), // Group
      4: FlexColumnWidth(1.6), // Clock Time
      5: FlexColumnWidth(1.0), // Attendance
      6: FlexColumnWidth(0.9), // Rest
      7: FlexColumnWidth(0.9), // Duty
      8: FlexColumnWidth(0.9), // Delay
      9: FlexColumnWidth(0.9), // Early Exit
      10: FlexColumnWidth(0.9), // Overtime
      11: FlexColumnWidth(1.2), // Status
    };

    final headerBgColor = textColor.withValues(alpha: isDark ? 0.08 : 0.05);
    final dividerColor = textColor.withValues(alpha: isDark ? 0.08 : 0.06);

    return GlassContainer(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final tableWidth = math.max(constraints.maxWidth, 1300.0);

            return Scrollbar(
              controller: _horizontalController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _horizontalController,
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
                            bottom: BorderSide(color: dividerColor, width: 1.0),
                          ),
                        ),
                        child: Table(
                          columnWidths: columnWidths,
                          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                          children: [
                            TableRow(
                              children: [
                                _buildHeaderCell('Employee', textColor: textColor),
                                _buildHeaderCell('Branch / Structure', textColor: textColor),
                                _buildHeaderCell('Shift Timing', textColor: textColor),
                                _buildHeaderCell('Group', textColor: textColor),
                                _buildHeaderCell('Clock Time', color: const Color(0xFF5B9BFF)),
                                _buildHeaderCell('Attendance', textColor: textColor),
                                _buildHeaderCell('Rest', color: const Color(0xFF2EBD96)),
                                _buildHeaderCell('Duty', textColor: textColor),
                                _buildHeaderCell('Delay', color: const Color(0xFFFF5C5C)),
                                _buildHeaderCell('Early Exit', color: const Color(0xFFFF5C5C)),
                                _buildHeaderCell('Overtime', color: isDark ? const Color(0xFF00FF87) : const Color(0xFF00A859)),
                                _buildHeaderCell('Status', textColor: textColor),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Scrollable Body
                      Expanded(
                        child: Scrollbar(
                          controller: _verticalController,
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            controller: _verticalController,
                            scrollDirection: Axis.vertical,
                            physics: const BouncingScrollPhysics(),
                            child: Table(
                              columnWidths: columnWidths,
                              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                              border: TableBorder(
                                horizontalInside: BorderSide(color: dividerColor, width: 1.0),
                                bottom: BorderSide(color: dividerColor, width: 1.0),
                              ),
                              children: rows.map((row) {
                                final emp = row['employee'] as CompanyEmployee;
                                final isSelected = _selectedRow == row;

                                final rowColor = isSelected
                                    ? (isDark
                                        ? const Color(0xFF2E65FF).withValues(alpha: 0.22)
                                        : const Color(0xFF2E65FF).withValues(alpha: 0.12))
                                    : Colors.transparent;

                                Widget wrapCell(Widget child) {
                                  return MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () {
                                        setState(() {
                                          _selectedRow = isSelected ? null : row;
                                        });
                                      },
                                      onDoubleTap: () => _showEmployeeDayDialog(context, row),
                                      child: child,
                                    ),
                                  );
                                }

                                final statusColor = row['statusColor'] as Color;
                                final statusIcon = row['statusIcon'] as IconData;
                                final statusText = row['status'] as String;

                                final delayMins = row['delay'] as int;
                                final earlyExitMins = row['earlyExit'] as int;
                                final overtimeMins = row['overtime'] as int;

                                return TableRow(
                                  decoration: BoxDecoration(color: rowColor),
                                  children: [
                                    // 0: Employee
                                    wrapCell(
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 5),
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 14,
                                              backgroundColor: const Color(0xFF00E5CE)
                                                  .withValues(alpha: 0.15),
                                              child: Text(
                                                emp.name.isNotEmpty
                                                    ? emp.name[0].toUpperCase()
                                                    : 'U',
                                                style: const TextStyle(
                                                  color: Color(0xFF00BD96),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    emp.name,
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.w700,
                                                      fontSize: 12,
                                                      color: textColor,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  Text(
                                                    emp.position,
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: textColor.withValues(alpha: 0.5),
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    // 1: Structure
                                    wrapCell(
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 5),
                                        child: Text(
                                          row['structureName'] as String,
                                          style: TextStyle(fontSize: 12, color: textColor),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),

                                    // 2: Shift
                                    wrapCell(
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 5),
                                        child: Text(
                                          row['shiftName'] as String,
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w500,
                                            color: textColor.withValues(alpha: 0.85),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),

                                    // 3: Group
                                    wrapCell(
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 5),
                                        child: Text(
                                          row['groupName'] as String,
                                          style: TextStyle(fontSize: 12, color: textColor),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),

                                    // 4: Clock Time
                                    wrapCell(
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 5),
                                        child: Text(
                                          row['clockTime'] as String,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF5B9BFF),
                                            height: 1.2,
                                          ),
                                        ),
                                      ),
                                    ),

                                    // 5: Attendance
                                    wrapCell(
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 5),
                                        child: Text(
                                          _formatMinutes(row['attendance'] as int),
                                          style: TextStyle(fontSize: 12, color: textColor),
                                        ),
                                      ),
                                    ),

                                    // 6: Rest
                                    wrapCell(
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 5),
                                        child: Text(
                                          _formatMinutes(row['rest'] as int),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF2EBD96),
                                          ),
                                        ),
                                      ),
                                    ),

                                    // 7: Duty
                                    wrapCell(
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 5),
                                        child: Text(
                                          _formatMinutes(row['duty'] as int),
                                          style: TextStyle(fontSize: 12, color: textColor),
                                        ),
                                      ),
                                    ),

                                    // 8: Delay
                                    wrapCell(
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 5),
                                        child: Text(
                                          delayMins > 0 ? '${delayMins}m' : '-',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: delayMins > 0 ? FontWeight.bold : FontWeight.normal,
                                            color: delayMins > 0
                                                ? const Color(0xFFFF5C5C)
                                                : textColor.withValues(alpha: 0.5),
                                          ),
                                        ),
                                      ),
                                    ),

                                    // 9: Early Exit
                                    wrapCell(
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 5),
                                        child: Text(
                                          earlyExitMins > 0 ? '${earlyExitMins}m' : '-',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: earlyExitMins > 0 ? FontWeight.bold : FontWeight.normal,
                                            color: earlyExitMins > 0
                                                ? const Color(0xFFFF5C5C)
                                                : textColor.withValues(alpha: 0.5),
                                          ),
                                        ),
                                      ),
                                    ),

                                    // 10: Overtime
                                    wrapCell(
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 5),
                                        child: Text(
                                          overtimeMins > 0 ? _formatMinutes(overtimeMins) : '-',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: overtimeMins > 0 ? FontWeight.bold : FontWeight.normal,
                                            color: overtimeMins > 0
                                                ? (isDark ? const Color(0xFF00FF87) : const Color(0xFF00A859))
                                                : textColor.withValues(alpha: 0.5),
                                          ),
                                        ),
                                      ),
                                    ),

                                    // 11: Status Capsule Badge
                                    wrapCell(
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: statusColor.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(50),
                                                border: Border.all(
                                                  color: statusColor.withValues(alpha: 0.4),
                                                  width: 1,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(statusIcon, size: 12, color: statusColor),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    statusText,
                                                    style: TextStyle(
                                                      color: statusColor,
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
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
    );
  }

  Widget _buildHeaderCell(String text, {Color? color, Color? textColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.bold,
          color: color ?? textColor?.withValues(alpha: 0.85) ?? Colors.white70,
        ),
      ),
    );
  }

  /// Mobile / Compact card list matching History screen cards
  Widget _buildMobileReportList(
    BuildContext context,
    List<Map<String, dynamic>> rows,
    bool isDark,
    Color textColor,
  ) {
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      itemCount: rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final row = rows[index];
        final emp = row['employee'] as CompanyEmployee;
        final statusColor = row['statusColor'] as Color;
        final statusIcon = row['statusIcon'] as IconData;
        final statusText = row['status'] as String;

        return GlassContainer(
          padding: const EdgeInsets.all(16),
          child: InkWell(
            onTap: () => _showEmployeeDayDialog(context, row),
            borderRadius: BorderRadius.circular(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: Avatar, Name, Status Badge
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0xFF00E5CE).withValues(alpha: 0.15),
                      child: Text(
                        emp.name.isNotEmpty ? emp.name[0].toUpperCase() : 'U',
                        style: const TextStyle(
                          color: Color(0xFF00BD96),
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            emp.name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          Text(
                            emp.position,
                            style: TextStyle(
                              fontSize: 12,
                              color: textColor.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 12, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            statusText,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Department & Shift Pills
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildMiniBadge(Icons.apartment_rounded, row['structureName'] as String, isDark),
                    _buildMiniBadge(Icons.schedule_rounded, row['shiftName'] as String, isDark),
                    _buildMiniBadge(Icons.group_outlined, row['groupName'] as String, isDark),
                  ],
                ),
                const SizedBox(height: 12),

                // Clock Times Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF5B9BFF)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          row['clockTime'] as String,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF5B9BFF),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Metric Grid: Attendance, Duty, Delay, Overtime
                Row(
                  children: [
                    _buildMetricCol('Attendance', _formatMinutes(row['attendance'] as int), textColor),
                    _buildMetricCol('Duty', _formatMinutes(row['duty'] as int), textColor),
                    _buildMetricCol(
                      'Delay',
                      (row['delay'] as int) > 0 ? '${row['delay']}m' : '-',
                      (row['delay'] as int) > 0 ? const Color(0xFFFF5C5C) : textColor,
                    ),
                    _buildMetricCol(
                      'Overtime',
                      (row['overtime'] as int) > 0 ? _formatMinutes(row['overtime'] as int) : '-',
                      (row['overtime'] as int) > 0 ? const Color(0xFF00FF87) : textColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMiniBadge(IconData icon, String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(50),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: isDark ? Colors.white60 : Colors.black54),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCol(String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark, Color textColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: textColor.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_search_rounded,
                size: 48,
                color: textColor.withValues(alpha: 0.35),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No Employee Attendance Records',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try changing your date or adjusting the shift, group, or structure filters.',
              style: TextStyle(
                fontSize: 13,
                color: textColor.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Popup dialog displaying detailed punch sessions and day requests
  void _showEmployeeDayDialog(BuildContext context, Map<String, dynamic> row) {
    final provider = Provider.of<AttendanceProvider>(context, listen: false);
    final emp = row['employee'] as CompanyEmployee;
    final records = row['records'] as List<AttendanceRecord>;
    final requests = row['requests'] as List<Request>;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560, maxHeight: 650),
            child: Container(
              padding: const EdgeInsets.all(22),
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
                  // Title Row
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: const Color(0xFF00E5CE).withValues(alpha: 0.15),
                        child: Text(
                          emp.name.isNotEmpty ? emp.name[0].toUpperCase() : 'U',
                          style: const TextStyle(
                            color: Color(0xFF00BD96),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              emp.name,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            Text(
                              '${emp.position} • ${DateFormat('d MMMM yyyy').format(_selectedDate)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: textColor.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close_rounded),
                        color: textColor.withValues(alpha: 0.6),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),

                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Shift & Department specs
                          Text(
                            'Shift Configuration',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: textColor.withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                _buildDetailRow('Structure', row['structureName'] as String, textColor),
                                const SizedBox(height: 6),
                                _buildDetailRow('Shift', row['shiftName'] as String, textColor),
                                const SizedBox(height: 6),
                                _buildDetailRow('Group', row['groupName'] as String, textColor),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Session Timestamps
                          Text(
                            'Punch Sessions (${records.length})',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: textColor.withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (records.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'No biometric punch sessions found for this day.',
                                style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.5)),
                              ),
                            )
                          else
                            ...records.map((r) {
                              final inStr = DateFormat('hh:mm:ss a').format(r.checkIn);
                              final outStr = r.checkOut != null
                                  ? DateFormat('hh:mm:ss a').format(r.checkOut!)
                                  : 'Ongoing / Not Clocked Out';
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.fingerprint, size: 16, color: Color(0xFF00E5CE)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Wrap(
                                        spacing: 12,
                                        runSpacing: 4,
                                        alignment: WrapAlignment.spaceBetween,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          Text('In: $inStr', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: textColor)),
                                          Text('Out: $outStr', style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.85))),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFEF4444)),
                                      tooltip: 'Delete & Exclude from Device Sync',
                                      padding: const EdgeInsets.all(4),
                                      constraints: const BoxConstraints(),
                                      splashRadius: 16,
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (delCtx) => AlertDialog(
                                            title: const Row(
                                              children: [
                                                Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444)),
                                                SizedBox(width: 8),
                                                Text('Delete Punch Session'),
                                              ],
                                            ),
                                            content: Text(
                                              'Are you sure you want to delete this punch session for ${emp.name}?\n\n• In: $inStr\n• Out: $outStr\n\nThis will remove the session from attendance and blacklist the punch so that ZKTeco device sync will NEVER re-import it.',
                                              style: const TextStyle(fontSize: 13, height: 1.4),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.of(delCtx).pop(),
                                                child: const Text('Cancel'),
                                              ),
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFFEF4444),
                                                  foregroundColor: Colors.white,
                                                ),
                                                onPressed: () async {
                                                  Navigator.of(delCtx).pop();
                                                  Navigator.of(ctx).pop();
                                                  await provider.deletePunchSession(
                                                    employeeId: emp.id,
                                                    record: r,
                                                    reason: 'Deleted from daily report',
                                                  );
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(
                                                        content: Text('Punch session deleted and added to sync blacklist!'),
                                                        backgroundColor: Color(0xFF10B981),
                                                      ),
                                                    );
                                                  }
                                                },
                                                child: const Text('Delete & Blacklist'),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              );
                            }),
                          const SizedBox(height: 16),

                          // Requests for this day
                          Text(
                            'Day Requests (${requests.length})',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: textColor.withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (requests.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'No leave or missing punch requests submitted for this day.',
                                style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.5)),
                              ),
                            )
                          else
                            ...requests.map((req) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: req.statusColor.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.assignment_outlined, size: 18, color: req.statusColor),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            req.type,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: textColor,
                                            ),
                                          ),
                                          Text(
                                            req.duration,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: textColor.withValues(alpha: 0.6),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: req.statusColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        req.status,
                                        style: TextStyle(
                                          color: req.statusColor,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: NeuButton(
                      label: 'Close',
                      variant: NeuButtonVariant.navy,
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      onPressed: () => Navigator.of(ctx).pop(),
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

  Widget _buildDetailRow(String label, String value, Color textColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.6)),
        ),
        Text(
          value,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor),
        ),
      ],
    );
  }

  void _exportReport(BuildContext context, AttendanceProvider provider, {required bool isPdf}) async {
    final rows = provider.employees
        .map((emp) => _compileEmployeeDayData(
              emp: emp,
              date: _selectedDate,
              provider: provider,
            ))
        .toList();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Generating ${isPdf ? "PDF" : "Excel"} Daily Report...'),
        duration: const Duration(seconds: 1),
      ),
    );

    try {
      if (isPdf) {
        await ExportService.exportDailyReportToPdf(
          records: rows,
          date: _selectedDate,
          profile: provider.companyProfile,
        );
      } else {
        await ExportService.exportDailyReportToExcel(
          records: rows,
          date: _selectedDate,
          profile: provider.companyProfile,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export error: $e')),
        );
      }
    }
  }
}
