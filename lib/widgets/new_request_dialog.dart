import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/hr_models.dart';
import '../providers/attendance_provider.dart';
import 'glass_dialog.dart';

List<CompanyEmployee> _getSubordinatesList(AttendanceProvider provider) {
  final currentUser = provider.currentEmployee;
  final isHR =
      currentUser?.role == 'hr' ||
      currentUser?.role == 'admin' ||
      provider.canEditCompanyInfo ||
      provider.employeeId == 'emp_2';

  if (isHR) {
    final currentId = currentUser?.id ?? provider.employeeId;
    return provider.employees.where((e) => e.id != currentId).toList();
  }

  if (currentUser == null) return [];

  if (currentUser.role == 'supervisor') {
    final Set<String> subordinateIds = {};
    final List<CompanyEmployee> list = [];

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

    // Fallback: Lookup by current user's structureId
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

void _addNewRequestHelper({
  required BuildContext context,
  required AttendanceProvider provider,
  required String type,
  required String date,
  required String duration,
  String? targetShiftId,
  CompanyEmployee? targetEmployee,
  String? note,
  VoidCallback? onSubmitted,
}) {
  final emp = targetEmployee ?? provider.currentEmployee;

  if (type == 'Missing Punch') {
    try {
      final parsedDate = DateFormat(
        'MMMM d, yyyy',
      ).parse(date.split(' - ').first);

      int count = 0;
      final targetReqs = (emp != null)
          ? provider.requests.where((r) => r.employeeId == emp.id).toList()
          : provider.requests;

      for (var req in targetReqs) {
        if (req.type == 'Missing Punch') {
          try {
            final reqDate = DateFormat(
              'MMMM d, yyyy',
            ).parse(req.date.split(' - ').first);
            if (reqDate.year == parsedDate.year &&
                reqDate.month == parsedDate.month) {
              count++;
            }
          } catch (_) {}
        }
      }

      if (emp != null) {
        final groupId = provider.getGroupIdForDate(emp, parsedDate);
        final group = provider.groups.firstWhere(
          (g) => g.id == groupId,
          orElse: () => EmployeeGroup(
            id: '',
            name: 'None',
            shiftId: '',
            overtimeAllowed: false,
            minOvertimeMinutes: 0,
            maxOvertimeMinutes: 0,
          ),
        );
        final limit = group.missedPunchLimitPerMonth;

        if (limit > 0 && count >= limit) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Limit reached: You can only submit $limit Missed Punch requests per month.',
              ),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }
    } catch (e) {
      debugPrint('Error checking missed punch limit: $e');
    }
  }

  if (type == 'Annual Leave') {
    try {
      final parsedDate = DateFormat(
        'MMMM d, yyyy',
      ).parse(date.split(' - ').first);

      if (emp != null) {
        final groupId = provider.getGroupIdForDate(emp, parsedDate);
        final group = provider.groups.firstWhere(
          (g) => g.id == groupId,
          orElse: () => EmployeeGroup(
            id: '',
            name: 'None',
            shiftId: '',
            overtimeAllowed: false,
            minOvertimeMinutes: 0,
            maxOvertimeMinutes: 0,
          ),
        );
        final limit = group.annualLeaveRequestDeadlineDays;

        if (limit > 0) {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final reqDate = DateTime(
            parsedDate.year,
            parsedDate.month,
            parsedDate.day,
          );

          final difference = today.difference(reqDate).inDays;

          if (difference > limit) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Deadline passed: You can only submit Annual Leave requests up to $limit days after the date.',
                ),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking annual leave deadline: $e');
    }
  }

  provider.submitRequest(
    type,
    date,
    duration,
    targetShiftId: targetShiftId,
    employeeId: emp?.id,
    note: note,
  );

  onSubmitted?.call();
}

Future<void> showNewRequestDialog({
  required BuildContext context,
  required AttendanceProvider provider,
  VoidCallback? onSubmitted,
}) {
  final currentUser =
      provider.currentEmployee ??
      provider.employees.firstWhere(
        (e) => e.email == provider.email || e.name == provider.userName,
        orElse: () => CompanyEmployee(
          id: provider.employeeId,
          name: provider.userName,
          email: provider.email,
          position: provider.position,
        ),
      );

  final subordinates = _getSubordinatesList(provider);
  final canSubmitForOthers =
      currentUser.role == 'hr' ||
      currentUser.role == 'admin' ||
      currentUser.role == 'supervisor' ||
      provider.canEditCompanyInfo;

  final List<CompanyEmployee> selectableEmployees = [
    currentUser,
    ...subordinates.where((e) => e.id != currentUser.id),
  ];

  CompanyEmployee selectedEmployee = currentUser;

  String selectedType = 'Annual Leave';
  String? selectedShiftId =
      provider.shifts.isNotEmpty ? provider.shifts.first.id : null;
  bool isClockIn = true;
  String? errorMessage;
  final dateController = TextEditingController(
    text: 'June 20 - June 22, 2026',
  );
  final durController = TextEditingController(text: '2 Days');
  final timeController = TextEditingController(
    text: DateFormat('HH:mm').format(DateTime.now()),
  );
  final fromTimeController = TextEditingController(text: '17:00');
  final toTimeController = TextEditingController(text: '19:00');
  final noteController = TextEditingController();

  return showGlassDialog(
    context: context,
    title: provider.translate('new_request'),
    subtitle: 'Submit a new request for approval',
    icon: Icons.edit_calendar,
    iconBackgroundColor: const [Color(0xFF2E65FF), Color(0xFF8236FE)],
    content: StatefulBuilder(
      builder: (context, setDialogState) {
        final isOvertime = selectedType == 'Overtime Approval';
        final group = provider.groups.firstWhere(
          (g) => g.id == selectedEmployee.groupId,
          orElse: () => EmployeeGroup(
            id: '',
            name: 'None',
            shiftId: '',
            overtimeAllowed: false,
            minOvertimeMinutes: 0,
            maxOvertimeMinutes: 0,
          ),
        );

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (errorMessage != null)
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFF87171),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        errorMessage!,
                        style: const TextStyle(
                          color: Color(0xFFFCA5A5),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (canSubmitForOthers && selectableEmployees.length > 1) ...[
              _buildDropdownFieldWidget(
                context: context,
                label: provider.translate('employee') != 'employee'
                    ? provider.translate('employee')
                    : 'Submit Request For',
                value: selectedEmployee.id,
                items: selectableEmployees.map((emp) {
                  final isSelf = emp.id == currentUser.id;
                  final label = isSelf
                      ? '${emp.name} (${provider.translate('myself') != 'myself' ? provider.translate('myself') : "Myself"})'
                      : '${emp.name} (${emp.position})';
                  return DropdownMenuItem(
                    value: emp.id,
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isSelf
                            ? const Color(0xFF2EBD96)
                            : ((Theme.of(context).textTheme.bodyLarge?.color ??
                                Colors.black)),
                        fontWeight:
                            isSelf ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() {
                      selectedEmployee = selectableEmployees.firstWhere(
                        (e) => e.id == val,
                      );
                      errorMessage = null;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
            ],
            _buildDropdownFieldWidget(
              context: context,
              label: provider.translate('request_type'),
              value: selectedType,
              items: [
                DropdownMenuItem(
                  value: 'Annual Leave',
                  child: Text(provider.translate('vacation_leave')),
                ),
                DropdownMenuItem(
                  value: 'Sick Leave',
                  child: Text(provider.translate('sick_leave')),
                ),
                DropdownMenuItem(
                  value: 'Overtime Approval',
                  child: Text(provider.translate('overtime_approval')),
                ),
                DropdownMenuItem(
                  value: 'Hourly Leave',
                  child: Text(
                    provider.translate('hourly_leave') != 'hourly_leave'
                        ? provider.translate('hourly_leave')
                        : 'Hourly Leave',
                  ),
                ),
                DropdownMenuItem(
                  value: 'Missing Punch',
                  child: Text(provider.translate('missing_punch')),
                ),
                DropdownMenuItem(
                  value: 'Change Shift',
                  child: Text(
                    provider.translate('change_shift') != 'change_shift'
                        ? provider.translate('change_shift')
                        : 'Change Shift',
                  ),
                ),
              ],
              onChanged: (val) {
                if (val != null) {
                  setDialogState(() {
                    selectedType = val;
                    if (selectedType == 'Annual Leave') {
                      dateController.text = 'June 20 - June 22, 2026';
                      durController.text = '2 Days';
                    } else if (selectedType == 'Sick Leave') {
                      dateController.text = 'June 3, 2026';
                      durController.text = '1 Day';
                    } else if (selectedType == 'Missing Punch') {
                      dateController.text = 'June 2, 2026';
                      timeController.text =
                          DateFormat('HH:mm').format(DateTime.now());
                    } else if (selectedType == 'Change Shift') {
                      dateController.text =
                          DateFormat('MMMM d, yyyy').format(DateTime.now());
                      durController.text = '1 Day';
                    } else if (selectedType == 'Hourly Leave') {
                      dateController.text = 'June 3, 2026';
                      durController.text = '2 Hours';
                    } else if (selectedType == 'Overtime Approval') {
                      dateController.text =
                          DateFormat('MMMM d, yyyy').format(DateTime.now());
                      fromTimeController.text = '17:00';
                      toTimeController.text = '19:00';
                      durController.text = '120';
                    }
                  });
                }
              },
            ),
            if (selectedType == 'Change Shift' &&
                provider.shifts.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildDropdownFieldWidget(
                context: context,
                label: provider.translate('target_shift') != 'target_shift'
                    ? provider.translate('target_shift')
                    : 'Target Shift',
                value: selectedShiftId ?? provider.shifts.first.id,
                items: provider.shifts
                    .map(
                      (s) => DropdownMenuItem(value: s.id, child: Text(s.name)),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() {
                      selectedShiftId = val;
                    });
                  }
                },
              ),
            ],
            const SizedBox(height: 16),
            _buildDialogFieldWidget(
              context: context,
              label: isOvertime
                  ? provider.translate('date')
                  : provider.translate('dates'),
              controller: dateController,
              readOnly: true,
              onTap: () async {
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate:
                      DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  builder: (context, child) {
                    return Theme(
                      data: ThemeData.dark().copyWith(
                        colorScheme: ColorScheme.dark(
                          primary: const Color(0xFF2E65FF),
                          onPrimary:
                              ((Theme.of(context).textTheme.bodyLarge?.color ??
                                  Colors.black)),
                          surface: const Color(0xFF1E293B),
                          onSurface:
                              ((Theme.of(context).textTheme.bodyLarge?.color ??
                                  Colors.black)),
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (picked != null) {
                  setDialogState(() {
                    if (picked.start == picked.end) {
                      dateController.text =
                          DateFormat('MMMM d, yyyy').format(picked.start);
                      durController.text = '1 Day';
                    } else {
                      dateController.text =
                          '${DateFormat('MMMM d').format(picked.start)} - ${DateFormat('MMMM d, yyyy').format(picked.end)}';
                      final days =
                          picked.end.difference(picked.start).inDays + 1;
                      durController.text = '$days Days';
                    }
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            if (selectedType == 'Missing Punch') ...[
              Row(
                children: [
                  Text(
                    'Punch Type:',
                    style: TextStyle(
                      color:
                          ((Theme.of(context).textTheme.bodyLarge?.color ??
                                  Colors.black)
                              .withValues(alpha: 0.6)),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 16),
                  ToggleButtons(
                    isSelected: [isClockIn, !isClockIn],
                    onPressed: (index) {
                      setDialogState(() {
                        isClockIn = index == 0;
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    selectedColor:
                        ((Theme.of(context).textTheme.bodyLarge?.color ??
                        Colors.black)),
                    fillColor: const Color(0xFF2E65FF).withValues(alpha: 0.8),
                    color: Colors.white70,
                    constraints: const BoxConstraints(minHeight: 36),
                    children: const [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('Clock In'),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('Clock Out'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildDialogFieldWidget(
                context: context,
                label: 'Requested Time',
                controller: timeController,
                readOnly: true,
                onTap: () async {
                  final TimeOfDay? picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                    builder: (context, child) {
                      return Theme(
                        data: ThemeData.dark().copyWith(
                          colorScheme: ColorScheme.dark(
                            primary: const Color(0xFF2E65FF),
                            onPrimary:
                                ((Theme.of(context).textTheme.bodyLarge?.color ??
                                    Colors.black)),
                            surface: const Color(0xFF1E293B),
                            onSurface:
                                ((Theme.of(context).textTheme.bodyLarge?.color ??
                                    Colors.black)),
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null) {
                    setDialogState(() {
                      final now = DateTime.now();
                      final dt = DateTime(
                        now.year,
                        now.month,
                        now.day,
                        picked.hour,
                        picked.minute,
                      );
                      timeController.text = DateFormat('HH:mm').format(dt);
                    });
                  }
                },
              ),
            ] else if (isOvertime) ...[
              Row(
                children: [
                  Expanded(
                    child: _buildDialogFieldWidget(
                      context: context,
                      label: provider.translate('from_hour') != 'from_hour'
                          ? provider.translate('from_hour')
                          : 'From Hour',
                      controller: fromTimeController,
                      readOnly: true,
                      onTap: () async {
                        final TimeOfDay? picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay(
                            hour: int.tryParse(
                                  fromTimeController.text.split(':')[0],
                                ) ??
                                17,
                            minute: int.tryParse(
                                  fromTimeController.text.split(':')[1],
                                ) ??
                                0,
                          ),
                          builder: (context, child) {
                            return Theme(
                              data: ThemeData.dark().copyWith(
                                colorScheme: ColorScheme.dark(
                                  primary: const Color(0xFF2E65FF),
                                  onPrimary: (Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.color ??
                                      Colors.black),
                                  surface: const Color(0xFF1E293B),
                                  onSurface: (Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.color ??
                                      Colors.black),
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setDialogState(() {
                            final now = DateTime.now();
                            final dt = DateTime(
                              now.year,
                              now.month,
                              now.day,
                              picked.hour,
                              picked.minute,
                            );
                            fromTimeController.text =
                                DateFormat('HH:mm').format(dt);

                            try {
                              final fParts =
                                  fromTimeController.text.split(':');
                              final tParts = toTimeController.text.split(':');
                              final fMins = int.parse(fParts[0]) * 60 +
                                  int.parse(fParts[1]);
                              final tMins = int.parse(tParts[0]) * 60 +
                                  int.parse(tParts[1]);
                              int diff = tMins - fMins;
                              if (diff < 0) diff += 24 * 60;
                              durController.text = diff.toString();
                            } catch (_) {}
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildDialogFieldWidget(
                      context: context,
                      label: provider.translate('to_hour') != 'to_hour'
                          ? provider.translate('to_hour')
                          : 'To Hour',
                      controller: toTimeController,
                      readOnly: true,
                      onTap: () async {
                        final TimeOfDay? picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay(
                            hour: int.tryParse(
                                  toTimeController.text.split(':')[0],
                                ) ??
                                19,
                            minute: int.tryParse(
                                  toTimeController.text.split(':')[1],
                                ) ??
                                0,
                          ),
                          builder: (context, child) {
                            return Theme(
                              data: ThemeData.dark().copyWith(
                                colorScheme: ColorScheme.dark(
                                  primary: const Color(0xFF2E65FF),
                                  onPrimary: (Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.color ??
                                      Colors.black),
                                  surface: const Color(0xFF1E293B),
                                  onSurface: (Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.color ??
                                      Colors.black),
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setDialogState(() {
                            final now = DateTime.now();
                            final dt = DateTime(
                              now.year,
                              now.month,
                              now.day,
                              picked.hour,
                              picked.minute,
                            );
                            toTimeController.text =
                                DateFormat('HH:mm').format(dt);

                            try {
                              final fParts =
                                  fromTimeController.text.split(':');
                              final tParts = toTimeController.text.split(':');
                              final fMins = int.parse(fParts[0]) * 60 +
                                  int.parse(fParts[1]);
                              final tMins = int.parse(tParts[0]) * 60 +
                                  int.parse(tParts[1]);
                              int diff = tMins - fMins;
                              if (diff < 0) diff += 24 * 60;
                              durController.text = diff.toString();
                            } catch (_) {}
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildDialogFieldWidget(
                context: context,
                label: provider.translate('calculated_duration') !=
                        'calculated_duration'
                    ? provider.translate('calculated_duration')
                    : 'Calculated Duration (Minutes)',
                controller: durController,
                readOnly: true,
              ),
            ] else ...[
              _buildDialogFieldWidget(
                context: context,
                label: provider.translate('duration_description'),
                controller: durController,
                keyboardType: TextInputType.text,
              ),
            ],
            if (isOvertime) ...[
              const SizedBox(height: 12),
              if (group.overtimeAllowed)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Color(0xFF34D399),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          provider
                              .translate('allowed_limits')
                              .replaceAll(
                                '{min}',
                                group.minOvertimeMinutes.toString(),
                              )
                              .replaceAll(
                                '{max}',
                                group.maxOvertimeMinutes.toString(),
                              ),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFF87171),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          provider
                              .translate('overtime_disabled')
                              .replaceAll('{groupName}', group.name),
                          style: const TextStyle(
                            color: Color(0xFFFCA5A5),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 16),
            _buildDialogFieldWidget(
              context: context,
              label: 'Note (Optional)',
              controller: noteController,
              keyboardType: TextInputType.multiline,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    provider.translate('cancel'),
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E65FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    final type = selectedType;
                    final dateVal = dateController.text.trim();
                    final isMissingPunch = type == 'Missing Punch';
                    final timeStr = timeController.text.trim();
                    final durVal = isMissingPunch
                        ? '${isClockIn ? "Clock In" : "Clock Out"}: $timeStr'
                        : durController.text.trim();

                    if (dateVal.isEmpty || durVal.isEmpty) {
                      setDialogState(() {
                        errorMessage =
                            provider.translate('fill_fields_error');
                      });
                      return;
                    }

                    if (type == 'Annual Leave') {
                      final match = RegExp(r'(\d+)').firstMatch(durVal);
                      int days = 1;
                      if (match != null) {
                        days = int.tryParse(match.group(1)!) ?? 1;
                      }

                      final shift = provider.shifts.firstWhere(
                        (s) => s.id == group.shiftId,
                        orElse: () => WorkShift(
                          id: '',
                          name: 'Default',
                          startTime: '09:00',
                          endTime: '17:00',
                        ),
                      );

                      DateTime reqDate = DateTime.now();
                      try {
                        reqDate = DateFormat('yyyy-MM-dd').parse(dateVal);
                      } catch (_) {}

                      final startTimeStr = shift.getStartTimeForDate(reqDate);
                      final endTimeStr = shift.getEndTimeForDate(reqDate);

                      final partsStart = startTimeStr.split(':');
                      final partsEnd = endTimeStr.split(':');
                      final startMins = partsStart.length >= 2
                          ? int.parse(partsStart[0]) * 60 +
                              int.parse(partsStart[1])
                          : 540;
                      final endMins = partsEnd.length >= 2
                          ? int.parse(partsEnd[0]) * 60 +
                              int.parse(partsEnd[1])
                          : 1020;
                      int expected = endMins >= startMins
                          ? endMins - startMins
                          : (24 * 60 - startMins + endMins);
                      int netMins =
                          expected - shift.getBreakDurationForDate(reqDate);
                      double hoursPerDay = netMins / 60.0;
                      double requestedHours = days * hoursPerDay;

                      if (requestedHours >
                          selectedEmployee.annualLeaveBalance) {
                        setDialogState(() {
                          errorMessage =
                              '${selectedEmployee.name} does not have enough balance for this request. (Requested: ${requestedHours.toStringAsFixed(1)}h, Balance: ${selectedEmployee.annualLeaveBalance.toStringAsFixed(1)}h)';
                        });
                        return;
                      }
                    }

                    if (type == 'Overtime Approval') {
                      if (!group.overtimeAllowed) {
                        setDialogState(() {
                          errorMessage = provider
                              .translate('overtime_blocked_group')
                              .replaceAll('{groupName}', group.name);
                        });
                        return;
                      }

                      final minutes = int.tryParse(durVal);
                      if (minutes == null) {
                        setDialogState(() {
                          errorMessage =
                              provider.translate('invalid_duration_error');
                        });
                        return;
                      }

                      if (minutes < group.minOvertimeMinutes ||
                          minutes > group.maxOvertimeMinutes) {
                        setDialogState(() {
                          errorMessage = provider
                              .translate('overtime_limit_error')
                              .replaceAll(
                                '{min}',
                                group.minOvertimeMinutes.toString(),
                              )
                              .replaceAll(
                                '{max}',
                                group.maxOvertimeMinutes.toString(),
                              );
                        });
                        return;
                      }

                      try {
                        final fParts = fromTimeController.text.split(':');
                        final tParts = toTimeController.text.split(':');
                        if (fParts.length < 2 || tParts.length < 2) {
                          setDialogState(
                            () => errorMessage = 'Invalid time format.',
                          );
                          return;
                        }
                        int reqStartMins =
                            int.parse(fParts[0]) * 60 + int.parse(fParts[1]);
                        int reqEndMins =
                            int.parse(tParts[0]) * 60 + int.parse(tParts[1]);
                        if (reqEndMins < reqStartMins) {
                          reqEndMins += 24 * 60;
                        }

                        DateTime reqDate = DateTime.now();
                        try {
                          reqDate =
                              DateFormat('MMMM d, yyyy').parse(dateVal);
                        } catch (_) {}

                        final records = await provider.firebaseService
                            .getUserRecords(selectedEmployee.id);
                        final dayRecords = provider.getRecordsForDate(
                          reqDate,
                          emp: selectedEmployee,
                          recordsPool: records,
                        );

                        if (dayRecords.isEmpty) {
                          setDialogState(
                            () => errorMessage =
                                'No attendance records found for this date. Cannot request overtime.',
                          );
                          return;
                        }

                        final activeGroupId = provider.getGroupIdForDate(
                          selectedEmployee,
                          reqDate,
                        );
                        final activeGroup = provider.groups.firstWhere(
                          (g) => g.id == activeGroupId,
                          orElse: () => group,
                        );
                        final activeShift = provider.shifts.firstWhere(
                          (s) => s.id == activeGroup.shiftId,
                          orElse: () => WorkShift(
                            id: '',
                            name: '',
                            startTime: '09:00',
                            endTime: '17:00',
                          ),
                        );

                        final sParts = activeShift
                            .getStartTimeForDate(reqDate)
                            .split(':');
                        final eParts =
                            activeShift.getEndTimeForDate(reqDate).split(':');
                        final shiftStartMins = sParts.length >= 2
                            ? int.parse(sParts[0]) * 60 + int.parse(sParts[1])
                            : 540;
                        final shiftEndMins = eParts.length >= 2
                            ? int.parse(eParts[0]) * 60 + int.parse(eParts[1])
                            : 1020;

                        bool validOvertime = false;

                        for (var rec in dayRecords) {
                          int cInMins =
                              rec.checkIn.hour * 60 + rec.checkIn.minute;
                          int cOutMins = rec.checkOut != null
                              ? rec.checkOut!.hour * 60 +
                                  rec.checkOut!.minute
                              : cInMins;
                          if (cOutMins < cInMins) cOutMins += 24 * 60;

                          if (activeShift.isWorkingDay(reqDate)) {
                            if (cInMins < shiftStartMins) {
                              int eBeforeEnd = cOutMins < shiftStartMins
                                  ? cOutMins
                                  : shiftStartMins;
                              if (reqStartMins >= cInMins &&
                                  reqEndMins <= eBeforeEnd) {
                                validOvertime = true;
                                break;
                              }
                            }
                            if (cOutMins > shiftEndMins) {
                              int sAfterStart = cInMins > shiftEndMins
                                  ? cInMins
                                  : shiftEndMins;
                              if (reqStartMins >= sAfterStart &&
                                  reqEndMins <= cOutMins) {
                                validOvertime = true;
                                break;
                              }
                            }
                          } else {
                            if (reqStartMins >= cInMins &&
                                reqEndMins <= cOutMins) {
                              validOvertime = true;
                              break;
                            }
                          }
                        }

                        if (!validOvertime) {
                          setDialogState(
                            () => errorMessage =
                                'Requested time does not fall within actual extra time worked.',
                          );
                          return;
                        }
                      } catch (e) {
                        setDialogState(
                          () =>
                              errorMessage = 'Error validating overtime: $e',
                        );
                        return;
                      }

                      if (!context.mounted) return;
                      final double hoursVal = minutes / 60;
                      final durationFormatted =
                          'From ${fromTimeController.text} to ${toTimeController.text} (${hoursVal.toStringAsFixed(1).replaceAll('.0', '')} Hours)';

                      _addNewRequestHelper(
                        context: context,
                        provider: provider,
                        type: type,
                        date: dateVal,
                        duration: durationFormatted,
                        targetEmployee: selectedEmployee,
                        note: noteController.text.trim().isNotEmpty
                            ? noteController.text.trim()
                            : null,
                        onSubmitted: onSubmitted,
                      );
                    } else if (type == 'Change Shift') {
                      _addNewRequestHelper(
                        context: context,
                        provider: provider,
                        type: type,
                        date: dateVal,
                        duration: durVal,
                        targetShiftId: selectedShiftId,
                        targetEmployee: selectedEmployee,
                        note: noteController.text.trim().isNotEmpty
                            ? noteController.text.trim()
                            : null,
                        onSubmitted: onSubmitted,
                      );
                    } else {
                      _addNewRequestHelper(
                        context: context,
                        provider: provider,
                        type: type,
                        date: dateVal,
                        duration: durVal,
                        targetEmployee: selectedEmployee,
                        note: noteController.text.trim().isNotEmpty
                            ? noteController.text.trim()
                            : null,
                        onSubmitted: onSubmitted,
                      );
                    }

                    if (!context.mounted) return;
                    Navigator.pop(context);
                    final isForSelf =
                        selectedEmployee.id == currentUser.id;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isForSelf
                              ? provider.translate('submit_success')
                              : 'Request submitted successfully for ${selectedEmployee.name}',
                        ),
                        backgroundColor: const Color(0xFF2EBD96),
                      ),
                    );
                  },
                  child: Text(
                    provider.translate('submit'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    ),
  );
}

Widget _buildDropdownFieldWidget({
  required BuildContext context,
  required String label,
  required String value,
  required List<DropdownMenuItem<String>> items,
  required ValueChanged<String?> onChanged,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          color:
              ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)
                  .withValues(alpha: 0.6)),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      Theme(
        data: Theme.of(context).copyWith(
          canvasColor: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1E293B)
              : Colors.white,
        ),
        child: DropdownButton<String>(
          value: value,
          items: items,
          onChanged: onChanged,
          isExpanded: true,
          underline: Container(
            height: 1,
            color: (Theme.of(context).textTheme.bodyLarge?.color ??
                    Colors.black)
                .withValues(alpha: 0.2),
          ),
          icon: Icon(
            Icons.arrow_drop_down,
            color: (Theme.of(context).textTheme.bodyLarge?.color ??
                    Colors.black)
                .withValues(alpha: 0.6),
          ),
          style: TextStyle(
            color:
                ((Theme.of(context).textTheme.bodyLarge?.color ??
                Colors.black)),
            fontSize: 14,
          ),
        ),
      ),
    ],
  );
}

Widget _buildDialogFieldWidget({
  required BuildContext context,
  required String label,
  required TextEditingController controller,
  TextInputType keyboardType = TextInputType.text,
  bool readOnly = false,
  VoidCallback? onTap,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          color:
              ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)
                  .withValues(alpha: 0.6)),
          fontSize: 12,
        ),
      ),
      TextField(
        controller: controller,
        keyboardType: keyboardType,
        readOnly: readOnly,
        onTap: onTap,
        style: TextStyle(
          color:
              ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)),
          fontSize: 14,
        ),
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 8),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF2E65FF)),
          ),
        ),
      ),
    ],
  );
}
