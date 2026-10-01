import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/attendance_provider.dart';
import '../../models/hr_models.dart';
import '../glass_container.dart';
import '../glass_dialog.dart';
import '../neu_button.dart';

class HrShiftsTab extends StatefulWidget {
  final String searchQuery;
  final Function(WorkShift shift)? onEdit;
  final Function(String id)? onDelete;

  const HrShiftsTab({
    super.key,
    required this.searchQuery,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<HrShiftsTab> createState() => _HrShiftsTabState();
}

class _HrShiftsTabState extends State<HrShiftsTab> {
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AttendanceProvider>(context);
    final shifts = provider.shifts;

    if (shifts.isEmpty) {
      return _buildEmptyState(context);
    }

    final filtered = widget.searchQuery.isEmpty
        ? shifts
        : shifts
            .where((s) => s.name.toLowerCase().contains(widget.searchQuery.toLowerCase()))
            .toList();

    if (filtered.isEmpty) {
      return _buildEmptyState(context);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1400
            ? 4
            : constraints.maxWidth > 950
                ? 3
                : constraints.maxWidth > 650
                    ? 2
                    : 1;

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: crossAxisCount == 1 ? 2.2 : (crossAxisCount == 2 ? 1.75 : 1.95),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            return _buildShiftCard(context, filtered[index], provider);
          },
        );
      },
    );
  }

  Widget _buildShiftCard(BuildContext context, WorkShift shift, AttendanceProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subtextColor = isDark ? Colors.white60 : Colors.grey.shade600;

    // Find groups using this shift
    final assignedGroups = provider.groups.where((g) => g.shiftId == shift.id).toList();
    final groupCount = assignedGroups.length;

    // Calculate active working days
    final List<int> weekDays = [6, 7, 1, 2, 3, 4, 5]; // Sat to Fri
    final Map<int, String> dayShort = {
      6: 'S',
      7: 'S',
      1: 'M',
      2: 'T',
      3: 'W',
      4: 'T',
      5: 'F',
    };

    int activeDaysCount = 0;
    if (shift.isRotation) {
      final totalDays = shift.rotationDays > 0 ? shift.rotationDays : 7;
      for (int i = 1; i <= totalDays; i++) {
        final cfg = shift.rotationSchedule[i] ?? shift.weeklySchedule[i];
        if (cfg?.isWorkingDay == true) activeDaysCount++;
      }
    } else {
      for (final day in weekDays) {
        if (shift.workingDays.contains(day)) activeDaysCount++;
      }
    }

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top Row: Icon badge + Title + Subtitle badge + Actions
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.25),
                  ),
                ),
                child: const Icon(
                  Icons.schedule_rounded,
                  color: Color(0xFF10B981),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shift.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: shift.isRotation
                                ? const Color(0xFF8B5CF6).withValues(alpha: 0.12)
                                : const Color(0xFF10B981).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: shift.isRotation
                                  ? const Color(0xFF8B5CF6).withValues(alpha: 0.3)
                                  : const Color(0xFF10B981).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            shift.isRotation
                                ? (shift.rotationDays == 7 && shift.rotationStartDate.isEmpty
                                    ? 'Weekly Rotation'
                                    : '${shift.rotationDays}-Day Rotation')
                                : 'Fixed Schedule',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: shift.isRotation
                                  ? const Color(0xFF8B5CF6)
                                  : const Color(0xFF10B981),
                            ),
                          ),
                        ),
                        if (shift.isRotation && shift.rotationStartDate.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              'Starts: ${shift.rotationStartDate}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF60A5FA),
                              ),
                            ),
                          ),
                        ),
                        if (shift.isOvernight || (!shift.isRotation && WorkShift.isTimeCrossMidnight(shift.startTime, shift.endTime))) ...[
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.nightlight_round, size: 10, color: Color(0xFF818CF8)),
                                const SizedBox(width: 3),
                                Text(
                                  shift.crossMidnightCutoff.isNotEmpty
                                      ? 'Overnight (${shift.crossMidnightCutoff})'
                                      : 'Overnight',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF818CF8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (!shift.isRotation) ...[
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${shift.startTime} - ${shift.endTime}',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: subtextColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Tooltip(
                    message: 'Edit Shift',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () {
                        if (widget.onEdit != null) {
                          widget.onEdit!(shift);
                        } else {
                          showShiftDialog(context, shift: shift);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(5),
                        child: Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Tooltip(
                    message: 'Delete Shift',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () {
                        if (widget.onDelete != null) {
                          widget.onDelete!(shift.id);
                        } else {
                          _showDeleteConfirm(context, shift, provider);
                        }
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(5),
                        child: Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Divider
          Divider(
            height: 14,
            thickness: 1,
            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
          ),

          // Details Grid
          Column(
            children: [
              // Row 1: Work Hours & Groups
              Row(
                children: [
                  Expanded(
                    child: _buildInfoChip(
                      icon: Icons.access_time_rounded,
                      iconColor: const Color(0xFF10B981),
                      label: shift.isRotation
                          ? 'Rotation Schedule'
                          : '${shift.startTime} - ${shift.endTime}',
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildInfoChip(
                      icon: Icons.groups_outlined,
                      iconColor: const Color(0xFF2E65FF),
                      label: groupCount > 0 ? '$groupCount Assigned Groups' : 'No Groups Assigned',
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Row 2: Break & Grace
              Row(
                children: [
                  Expanded(
                    child: _buildInfoChip(
                      icon: Icons.coffee_outlined,
                      iconColor: const Color(0xFFF59E0B),
                      label: shift.breakStart.isNotEmpty && shift.breakEnd.isNotEmpty
                          ? '${shift.breakStart} - ${shift.breakEnd} (${shift.breakDurationMinutes}m)'
                          : shift.breakDurationMinutes > 0
                              ? '${shift.breakDurationMinutes}m Break'
                              : 'No Break Configured',
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildInfoChip(
                      icon: Icons.timer_outlined,
                      iconColor: const Color(0xFF06B6D4),
                      label: 'Delay: ${shift.forgivenessOfDelay}m | Early: ${shift.earlyExit}m',
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Row 3: Working Days Indicators
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.03)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      shift.isRotation ? 'Cycle:' : 'Days:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: subtextColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: shift.isRotation
                              ? List.generate(shift.rotationDays > 0 ? shift.rotationDays : 7, (idx) {
                                  final dayNum = idx + 1;
                                  final cfg = shift.rotationSchedule[dayNum] ?? shift.weeklySchedule[dayNum];
                                  final isWork = cfg?.isWorkingDay == true;
                                  return Tooltip(
                                    message: 'Day $dayNum: ${isWork ? '${cfg?.startTime} - ${cfg?.endTime}' : 'Day Off'}',
                                    child: Container(
                                      margin: const EdgeInsets.only(right: 5),
                                      padding: const EdgeInsets.symmetric(horizontal: 6),
                                      height: 22,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(11),
                                        color: isWork
                                            ? const Color(0xFF8B5CF6)
                                            : (isDark
                                                ? Colors.white.withValues(alpha: 0.08)
                                                : Colors.grey.shade300),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        'D$dayNum',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isWork
                                              ? Colors.white
                                              : (isDark ? Colors.white38 : Colors.grey.shade600),
                                        ),
                                      ),
                                    ),
                                  );
                                })
                              : weekDays.map((dayNum) {
                                  final isWorkDay = shift.workingDays.contains(dayNum);
                                  return Container(
                                    margin: const EdgeInsets.only(right: 5),
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isWorkDay
                                          ? const Color(0xFF2E65FF)
                                          : (isDark
                                              ? Colors.white.withValues(alpha: 0.08)
                                              : Colors.grey.shade300),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      dayShort[dayNum] ?? '',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isWorkDay
                                            ? Colors.white
                                            : (isDark ? Colors.white38 : Colors.grey.shade600),
                                      ),
                                    ),
                                  );
                                }).toList(),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (shift.isRotation ? const Color(0xFF8B5CF6) : const Color(0xFF2E65FF))
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        shift.isRotation
                            ? '$activeDaysCount/${shift.rotationDays > 0 ? shift.rotationDays : 7} Days'
                            : '$activeDaysCount Days/Wk',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: shift.isRotation
                              ? const Color(0xFF8B5CF6)
                              : const Color(0xFF2E65FF),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required Color iconColor,
    required String label,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white70 : const Color(0xFF334155),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.access_time_outlined,
            size: 64,
            color: isDark ? Colors.white24 : Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No Work Shifts Found',
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.white60 : Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context, WorkShift shift, AttendanceProvider provider) {
    final assignedGroups = provider.groups.where((g) => g.shiftId == shift.id).toList();
    final hasGroups = assignedGroups.isNotEmpty;

    showGlassDialog(
      context: context,
      title: 'Delete Shift',
      subtitle: 'Remove work shift configuration',
      icon: Icons.delete_outline,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Are you sure you want to delete "${shift.name}"?'),
          if (hasGroups) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Warning: ${assignedGroups.length} employee group(s) are currently assigned to this shift.',
                      style: const TextStyle(color: Colors.amber, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        NeuButton(
          onPressed: () {
            provider.deleteShift(shift.id);
            Navigator.pop(context);
          },
          variant: NeuButtonVariant.danger,
          label: 'Delete',
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
      ],
    );
  }
}

/// Comprehensive Add/Edit WorkShift Dialog fallback
void showShiftDialog(BuildContext context, {WorkShift? shift}) {
  final provider = Provider.of<AttendanceProvider>(context, listen: false);
  final isEditing = shift != null;

  final nameController = TextEditingController(text: shift?.name ?? '');
  final startController = TextEditingController(text: shift?.startTime ?? '08:00');
  final endController = TextEditingController(text: shift?.endTime ?? '16:00');
  final delayController = TextEditingController(
    text: shift != null ? shift.forgivenessOfDelay.toString() : '15',
  );
  final earlyExitController = TextEditingController(
    text: shift != null ? shift.earlyExit.toString() : '10',
  );
  final breakStartController = TextEditingController(text: shift?.breakStart ?? '12:00');
  final breakEndController = TextEditingController(text: shift?.breakEnd ?? '13:00');
  final breakDurationController = TextEditingController(
    text: shift != null && shift.breakDurationMinutes > 0
        ? shift.breakDurationMinutes.toString()
        : '60',
  );

  List<int> workingDays = shift != null
      ? List<int>.from(shift.workingDays)
      : [6, 7, 1, 2, 3, 4, 5];

  bool isRotation = shift?.isRotation ?? false;
  int rotationDays = shift != null && shift.rotationDays > 0 ? shift.rotationDays : 3;
  final rotationStartDateController = TextEditingController(
    text: shift?.rotationStartDate.isNotEmpty == true
        ? shift!.rotationStartDate
        : '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}',
  );
  bool isOvernight = shift?.isOvernight ?? false;
  final crossMidnightCutoffController = TextEditingController(text: shift?.crossMidnightCutoff ?? '');
  
  Map<int, DayShiftConfig> rotationSchedule = {};
  if (shift != null && shift.rotationSchedule.isNotEmpty) {
    rotationSchedule = Map.from(shift.rotationSchedule);
  } else if (shift != null && shift.weeklySchedule.isNotEmpty) {
    rotationSchedule = Map.from(shift.weeklySchedule);
  } else {
    // Default 3-day cycle: Day 1 Work, Day 2 Work, Day 3 Off
    rotationSchedule = {
      1: DayShiftConfig(isWorkingDay: true, startTime: '08:00', endTime: '16:00'),
      2: DayShiftConfig(isWorkingDay: true, startTime: '08:00', endTime: '16:00'),
      3: DayShiftConfig(isWorkingDay: false, startTime: '08:00', endTime: '16:00'),
    };
  }
  for (int i = 1; i <= rotationDays; i++) {
    rotationSchedule[i] ??= DayShiftConfig(
      isWorkingDay: i != rotationDays,
      startTime: '08:00',
      endTime: '16:00',
    );
  }

  int? calculateMinutesDifference(String startStr, String endStr) {
    final startParts = startStr.trim().split(':');
    final endParts = endStr.trim().split(':');
    if (startParts.length == 2 && endParts.length == 2) {
      final startH = int.tryParse(startParts[0]);
      final startM = int.tryParse(startParts[1]);
      final endH = int.tryParse(endParts[0]);
      final endM = int.tryParse(endParts[1]);
      if (startH != null && startM != null && endH != null && endM != null) {
        final startMinutes = startH * 60 + startM;
        var endMinutes = endH * 60 + endM;
        if (endMinutes < startMinutes) {
          endMinutes += 24 * 60;
        }
        return endMinutes - startMinutes;
      }
    }
    return null;
  }

  Future<void> selectTime(
    BuildContext context,
    TextEditingController controller,
    VoidCallback? onPicked,
  ) async {
    final currentStr = controller.text;
    TimeOfDay initial = const TimeOfDay(hour: 8, minute: 0);
    if (currentStr.isNotEmpty) {
      final parts = currentStr.split(':');
      if (parts.length == 2) {
        initial = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 8,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }
    }
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked != null) {
      final hh = picked.hour.toString().padLeft(2, '0');
      final mm = picked.minute.toString().padLeft(2, '0');
      controller.text = '$hh:$mm';
      if (onPicked != null) onPicked();
    }
  }

  showGlassDialog(
    context: context,
    title: isEditing ? 'Edit Work Shift' : 'Add Work Shift',
    subtitle: isEditing ? 'Update all shift timings and rules' : 'Define shift working hours and rules',
    icon: Icons.access_time_rounded,
    content: StatefulBuilder(
      builder: (context, setDialogState) {
        void updateBreakDuration() {
          final diff = calculateMinutesDifference(
            breakStartController.text,
            breakEndController.text,
          );
          if (diff != null) {
            breakDurationController.text = diff.toString();
          }
        }

        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Shift Name *',
                  hintText: 'e.g., Morning Shift',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 16),

              // Rotation switch
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rotating Shift Cycle',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Shift schedule repeats continuously every N days (e.g. 3 days, 4 days)',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                    Switch(
                      value: isRotation,
                      activeThumbColor: const Color(0xFF8B5CF6),
                      onChanged: (val) {
                        setDialogState(() {
                          isRotation = val;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (!isRotation) ...[
                // Fixed Shift Hours
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: startController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Start Time',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.access_time_rounded),
                        ),
                        onTap: () => selectTime(context, startController, () {
                          setDialogState(() {
                            if (WorkShift.isTimeCrossMidnight(startController.text, endController.text)) {
                              isOvernight = true;
                              if (crossMidnightCutoffController.text.isEmpty) {
                                crossMidnightCutoffController.text = '03:00';
                              }
                            }
                          });
                        }),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: endController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'End Time',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.access_time_rounded),
                        ),
                        onTap: () => selectTime(context, endController, () {
                          setDialogState(() {
                            if (WorkShift.isTimeCrossMidnight(startController.text, endController.text)) {
                              isOvernight = true;
                              if (crossMidnightCutoffController.text.isEmpty) {
                                crossMidnightCutoffController.text = '03:00';
                              }
                            }
                          });
                        }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Overnight Shift (Crosses Midnight)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Checkouts up to cutoff calculate to previous date', style: TextStyle(fontSize: 11)),
                  value: isOvernight,
                  activeThumbColor: const Color(0xFF8B5CF6),
                  onChanged: (val) {
                    setDialogState(() {
                      isOvernight = val;
                      if (val && crossMidnightCutoffController.text.isEmpty) {
                        crossMidnightCutoffController.text = '03:00';
                      }
                    });
                  },
                ),
                if (isOvernight) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: crossMidnightCutoffController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Next-Day Attribution Cutoff (e.g. 03:00)',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.access_time_rounded),
                    ),
                    onTap: () => selectTime(context, crossMidnightCutoffController, () {
                      setDialogState(() {});
                    }),
                  ),
                ],
                const SizedBox(height: 16),

                // Working Days
                const Text(
                  'Working Days',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    {'label': 'Saturday', 'value': 6},
                    {'label': 'Sunday', 'value': 7},
                    {'label': 'Monday', 'value': 1},
                    {'label': 'Tuesday', 'value': 2},
                    {'label': 'Wednesday', 'value': 3},
                    {'label': 'Thursday', 'value': 4},
                    {'label': 'Friday', 'value': 5},
                  ].map((dayMap) {
                    final dayVal = dayMap['value'] as int;
                    final isSelected = workingDays.contains(dayVal);
                    return FilterChip(
                      label: Text(dayMap['label'] as String),
                      selected: isSelected,
                      selectedColor: const Color(0xFF2E65FF),
                      checkmarkColor: Colors.white,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : null,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (selected) {
                        setDialogState(() {
                          if (selected) {
                            workingDays.add(dayVal);
                          } else {
                            workingDays.remove(dayVal);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Break Time Settings
                const Text(
                  'Break Time',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: breakStartController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Break Start',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.coffee_outlined),
                        ),
                        onTap: () => selectTime(context, breakStartController, () {
                          setDialogState(() {
                            updateBreakDuration();
                          });
                        }),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: breakEndController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Break End',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.coffee_outlined),
                        ),
                        onTap: () => selectTime(context, breakEndController, () {
                          setDialogState(() {
                            updateBreakDuration();
                          });
                        }),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: breakDurationController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Duration (m)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // Rotation Cycle Settings
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.sync_rounded, color: Color(0xFF8B5CF6), size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Rotation Cycle Length',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Repeats Every $rotationDays Days',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF8B5CF6),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [2, 3, 4, 5, 6, 7].map((days) {
                                final isSelected = rotationDays == days;
                                return ChoiceChip(
                                  label: Text('$days Days'),
                                  selected: isSelected,
                                  selectedColor: const Color(0xFF8B5CF6),
                                  backgroundColor: isDark ? Colors.white10 : Colors.grey.shade200,
                                  labelStyle: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                  ),
                                  onSelected: (selected) {
                                    if (selected) {
                                      setDialogState(() {
                                        rotationDays = days;
                                        for (int i = 1; i <= rotationDays; i++) {
                                          rotationSchedule[i] ??= DayShiftConfig(
                                            isWorkingDay: i != rotationDays,
                                            startTime: '08:00',
                                            endTime: '16:00',
                                          );
                                        }
                                      });
                                    }
                                  },
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove, size: 16),
                                  onPressed: rotationDays > 2
                                      ? () {
                                          setDialogState(() {
                                            rotationDays--;
                                          });
                                        }
                                      : null,
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                  padding: EdgeInsets.zero,
                                ),
                                Text(
                                  '$rotationDays',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add, size: 16),
                                  onPressed: rotationDays < 31
                                      ? () {
                                          setDialogState(() {
                                            rotationDays++;
                                            rotationSchedule[rotationDays] ??= DayShiftConfig(
                                              isWorkingDay: false,
                                              startTime: '08:00',
                                              endTime: '16:00',
                                            );
                                          });
                                        }
                                      : null,
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                  padding: EdgeInsets.zero,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () async {
                          DateTime initial = DateTime.now();
                          if (rotationStartDateController.text.isNotEmpty) {
                            try {
                              initial = DateTime.parse(rotationStartDateController.text);
                            } catch (_) {}
                          }
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: initial,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                          );
                          if (picked != null) {
                            final y = picked.year.toString();
                            final m = picked.month.toString().padLeft(2, '0');
                            final d = picked.day.toString().padLeft(2, '0');
                            setDialogState(() {
                              rotationStartDateController.text = '$y-$m-$d';
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF8B5CF6)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Cycle Anchor Date (Day 1 starts on)',
                                      style: TextStyle(fontSize: 10, color: Colors.grey),
                                    ),
                                    Text(
                                      rotationStartDateController.text.isEmpty
                                          ? 'Select Start Date'
                                          : rotationStartDateController.text,
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.edit_calendar_outlined, size: 16, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Day 1 begins on this date. The schedule will repeat every $rotationDays days continuously.',
                        style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: isDark ? Colors.white60 : Colors.black54),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                Text(
                  'Rotation Schedule ($rotationDays-Day Cycle)',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...List.generate(rotationDays, (idx) {
                  final dayIndex = idx + 1;
                  final config = rotationSchedule[dayIndex] ??
                      DayShiftConfig(isWorkingDay: true, startTime: '08:00', endTime: '16:00');
                  final isAutoOvernight = WorkShift.isTimeCrossMidnight(config.startTime, config.endTime);
                  final isDayOvernight = config.isOvernight || isAutoOvernight;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: config.isWorkingDay
                            ? const Color(0xFF8B5CF6).withValues(alpha: 0.35)
                            : (isDark ? Colors.white12 : Colors.grey.shade300),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: config.isWorkingDay
                                    ? const Color(0xFF8B5CF6).withValues(alpha: 0.15)
                                    : Colors.grey.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Day $dayIndex',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: config.isWorkingDay
                                      ? const Color(0xFF8B5CF6)
                                      : Colors.grey,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Switch(
                              value: config.isWorkingDay,
                              activeThumbColor: const Color(0xFF8B5CF6),
                              onChanged: (val) {
                                setDialogState(() {
                                  rotationSchedule[dayIndex] = DayShiftConfig(
                                    isWorkingDay: val,
                                    startTime: config.startTime,
                                    endTime: config.endTime,
                                    breakStart: config.breakStart,
                                    breakEnd: config.breakEnd,
                                    breakDurationMinutes: config.breakDurationMinutes,
                                    isOvernight: config.isOvernight,
                                    crossMidnightCutoff: config.crossMidnightCutoff,
                                  );
                                });
                              },
                            ),
                            Text(
                              config.isWorkingDay ? 'Working' : 'Day Off',
                              style: TextStyle(
                                color: config.isWorkingDay ? (isDark ? Colors.white70 : Colors.black87) : Colors.grey,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            if (config.isWorkingDay) ...[
                              InkWell(
                                borderRadius: BorderRadius.circular(6),
                                onTap: () async {
                                  final parts = config.startTime.split(':');
                                  final init = TimeOfDay(
                                    hour: parts.length == 2 ? int.tryParse(parts[0]) ?? 8 : 8,
                                    minute: parts.length == 2 ? int.tryParse(parts[1]) ?? 0 : 0,
                                  );
                                  final picked = await showTimePicker(context: context, initialTime: init);
                                  if (picked != null) {
                                    final hh = picked.hour.toString().padLeft(2, '0');
                                    final mm = picked.minute.toString().padLeft(2, '0');
                                    setDialogState(() {
                                      final newStart = '$hh:$mm';
                                      final autoOver = WorkShift.isTimeCrossMidnight(newStart, config.endTime);
                                      rotationSchedule[dayIndex] = DayShiftConfig(
                                        isWorkingDay: true,
                                        startTime: newStart,
                                        endTime: config.endTime,
                                        breakStart: config.breakStart,
                                        breakEnd: config.breakEnd,
                                        breakDurationMinutes: config.breakDurationMinutes,
                                        isOvernight: config.isOvernight || autoOver,
                                        crossMidnightCutoff: config.crossMidnightCutoff.isNotEmpty ? config.crossMidnightCutoff : (autoOver ? '03:00' : ''),
                                      );
                                    });
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade400),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.login_rounded, size: 12, color: Colors.greenAccent),
                                      const SizedBox(width: 4),
                                      Text(config.startTime, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4),
                                child: Text('-', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              ),
                              InkWell(
                                borderRadius: BorderRadius.circular(6),
                                onTap: () async {
                                  final parts = config.endTime.split(':');
                                  final init = TimeOfDay(
                                    hour: parts.length == 2 ? int.tryParse(parts[0]) ?? 16 : 16,
                                    minute: parts.length == 2 ? int.tryParse(parts[1]) ?? 0 : 0,
                                  );
                                  final picked = await showTimePicker(context: context, initialTime: init);
                                  if (picked != null) {
                                    final hh = picked.hour.toString().padLeft(2, '0');
                                    final mm = picked.minute.toString().padLeft(2, '0');
                                    setDialogState(() {
                                      final newEnd = '$hh:$mm';
                                      final autoOver = WorkShift.isTimeCrossMidnight(config.startTime, newEnd);
                                      rotationSchedule[dayIndex] = DayShiftConfig(
                                        isWorkingDay: true,
                                        startTime: config.startTime,
                                        endTime: newEnd,
                                        breakStart: config.breakStart,
                                        breakEnd: config.breakEnd,
                                        breakDurationMinutes: config.breakDurationMinutes,
                                        isOvernight: config.isOvernight || autoOver,
                                        crossMidnightCutoff: config.crossMidnightCutoff.isNotEmpty ? config.crossMidnightCutoff : (autoOver ? '03:00' : ''),
                                      );
                                    });
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade400),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.logout_rounded, size: 12, color: Colors.orangeAccent),
                                      const SizedBox(width: 4),
                                      Text(config.endTime, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (config.isWorkingDay && isDayOvernight) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const SizedBox(width: 6),
                              const Icon(Icons.nightlight_round, size: 12, color: Color(0xFF818CF8)),
                              const SizedBox(width: 4),
                              const Text(
                                'Overnight (Crosses midnight)',
                                style: TextStyle(fontSize: 11, color: Color(0xFF818CF8), fontWeight: FontWeight.w500),
                              ),
                              const Spacer(),
                              InkWell(
                                onTap: () async {
                                  final cutoff = config.crossMidnightCutoff.isNotEmpty ? config.crossMidnightCutoff : '03:00';
                                  final parts = cutoff.split(':');
                                  final init = TimeOfDay(
                                    hour: parts.length == 2 ? int.tryParse(parts[0]) ?? 3 : 3,
                                    minute: parts.length == 2 ? int.tryParse(parts[1]) ?? 0 : 0,
                                  );
                                  final picked = await showTimePicker(context: context, initialTime: init);
                                  if (picked != null) {
                                    final hh = picked.hour.toString().padLeft(2, '0');
                                    final mm = picked.minute.toString().padLeft(2, '0');
                                    setDialogState(() {
                                      rotationSchedule[dayIndex] = DayShiftConfig(
                                        isWorkingDay: true,
                                        startTime: config.startTime,
                                        endTime: config.endTime,
                                        breakStart: config.breakStart,
                                        breakEnd: config.breakEnd,
                                        breakDurationMinutes: config.breakDurationMinutes,
                                        isOvernight: true,
                                        crossMidnightCutoff: '$hh:$mm',
                                      );
                                    });
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFF818CF8).withValues(alpha: 0.5)),
                                  ),
                                  child: Text(
                                    'Cutoff: ${config.crossMidnightCutoff.isNotEmpty ? config.crossMidnightCutoff : "03:00"}',
                                    style: const TextStyle(fontSize: 10, color: Color(0xFF818CF8)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                }),
              ],
              const SizedBox(height: 16),

              // Shift Rules
              const Text(
                'Shift Tolerance Rules',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: delayController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Delay Forgiveness (mins)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.timer_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: earlyExitController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Early Exit Allowance (mins)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.exit_to_app_rounded),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      NeuButton(
        label: isEditing ? 'Save Changes' : 'Create Shift',
        variant: NeuButtonVariant.primary,
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        onPressed: () {
          final name = nameController.text.trim();
          if (name.isEmpty) return;

          final delayMins = int.tryParse(delayController.text.trim()) ?? 0;
          final earlyMins = int.tryParse(earlyExitController.text.trim()) ?? 0;
          final breakMins = int.tryParse(breakDurationController.text.trim()) ?? 0;

          final updatedShift = WorkShift(
            id: shift?.id ?? 'shift_${DateTime.now().millisecondsSinceEpoch}',
            name: name,
            startTime: startController.text.trim(),
            endTime: endController.text.trim(),
            forgivenessOfDelay: delayMins,
            earlyExit: earlyMins,
            breakStart: breakStartController.text.trim(),
            breakEnd: breakEndController.text.trim(),
            breakDurationMinutes: breakMins,
            workingDays: workingDays,
            isRotation: isRotation,
            rotationDays: isRotation ? rotationDays : 7,
            rotationStartDate: isRotation ? rotationStartDateController.text.trim() : '',
            rotationSchedule: isRotation ? rotationSchedule : {},
            weeklySchedule: isRotation ? rotationSchedule : {},
            isOvernight: isOvernight || WorkShift.isTimeCrossMidnight(startController.text.trim(), endController.text.trim()),
            crossMidnightCutoff: crossMidnightCutoffController.text.trim(),
          );

          if (isEditing) {
            provider.updateShift(updatedShift);
          } else {
            provider.addShift(updatedShift);
          }
          Navigator.pop(context);
        },
      ),
    ],
  );
}
