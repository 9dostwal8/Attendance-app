class OrgStructure {
  final String id;
  final String name;
  final String location;
  final int capacity;
  final String? parentId;
  final String? supervisorId;
  final double? latitude;
  final double? longitude;
  final double? radius;

  OrgStructure({
    required this.id,
    required this.name,
    required this.location,
    required this.capacity,
    this.parentId,
    this.supervisorId,
    this.latitude,
    this.longitude,
    this.radius,
  });

  OrgStructure copyWith({
    String? id,
    String? name,
    String? location,
    int? capacity,
    String? parentId,
    bool overrideParentId = false,
    String? supervisorId,
    bool overrideSupervisorId = false,
    double? latitude,
    bool overrideLatitude = false,
    double? longitude,
    bool overrideLongitude = false,
    double? radius,
    bool overrideRadius = false,
  }) {
    return OrgStructure(
      id: id ?? this.id,
      name: name ?? this.name,
      location: location ?? this.location,
      capacity: capacity ?? this.capacity,
      parentId: overrideParentId ? parentId : (parentId ?? this.parentId),
      supervisorId: overrideSupervisorId ? supervisorId : (supervisorId ?? this.supervisorId),
      latitude: overrideLatitude ? latitude : (latitude ?? this.latitude),
      longitude: overrideLongitude ? longitude : (longitude ?? this.longitude),
      radius: overrideRadius ? radius : (radius ?? this.radius),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'location': location,
      'capacity': capacity,
      'parentId': parentId,
      'supervisorId': supervisorId,
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
    };
  }

  factory OrgStructure.fromMap(Map<String, dynamic> map, String docId) {
    return OrgStructure(
      id: map['id'] ?? docId,
      name: map['name'] ?? '',
      location: map['location'] ?? '',
      capacity: (map['capacity'] as num?)?.toInt() ?? 0,
      parentId: map['parentId'],
      supervisorId: map['supervisorId'],
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      radius: (map['radius'] as num?)?.toDouble(),
    );
  }
}

class SalaryHistoryEntry {
  final double basicSalary;
  final double workingHours;
  final String currency; // 'USD' or 'IQD'
  final String startDate; // 'yyyy-MM-dd'
  final String? endDate; // 'yyyy-MM-dd' or null
  final double foodAllowance;
  final double transportationAllowance;
  final double otherAllowance;

  SalaryHistoryEntry({
    required this.basicSalary,
    required this.workingHours,
    required this.currency,
    required this.startDate,
    this.endDate,
    this.foodAllowance = 0.0,
    this.transportationAllowance = 0.0,
    this.otherAllowance = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'basicSalary': basicSalary,
      'workingHours': workingHours,
      'currency': currency,
      'startDate': startDate,
      'endDate': endDate,
      'foodAllowance': foodAllowance,
      'transportationAllowance': transportationAllowance,
      'otherAllowance': otherAllowance,
    };
  }

  factory SalaryHistoryEntry.fromMap(Map<String, dynamic> map) {
    return SalaryHistoryEntry(
      basicSalary: (map['basicSalary'] as num?)?.toDouble() ?? 0.0,
      workingHours: (map['workingHours'] as num?)?.toDouble() ?? 0.0,
      currency: map['currency'] ?? 'USD',
      startDate: map['startDate'] ?? '',
      endDate: map['endDate'],
      foodAllowance: (map['foodAllowance'] as num?)?.toDouble() ?? 0.0,
      transportationAllowance: (map['transportationAllowance'] as num?)?.toDouble() ?? 0.0,
      otherAllowance: (map['otherAllowance'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class DayShiftConfig {
  final bool isWorkingDay;
  final String startTime;
  final String endTime;
  final String breakStart;
  final String breakEnd;
  final int breakDurationMinutes;
  final bool isOvernight;
  final String crossMidnightCutoff; // "HH:mm" e.g., "03:00"

  DayShiftConfig({
    required this.isWorkingDay,
    this.startTime = '09:00',
    this.endTime = '17:00',
    this.breakStart = '',
    this.breakEnd = '',
    this.breakDurationMinutes = 0,
    this.isOvernight = false,
    this.crossMidnightCutoff = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'isWorkingDay': isWorkingDay,
      'startTime': startTime,
      'endTime': endTime,
      'breakStart': breakStart,
      'breakEnd': breakEnd,
      'breakDurationMinutes': breakDurationMinutes,
      'isOvernight': isOvernight,
      'crossMidnightCutoff': crossMidnightCutoff,
    };
  }

  factory DayShiftConfig.fromMap(Map<String, dynamic> map) {
    final start = map['startTime'] ?? '09:00';
    final end = map['endTime'] ?? '17:00';
    final autoOvernight = WorkShift.isTimeCrossMidnight(start, end);
    return DayShiftConfig(
      isWorkingDay: map['isWorkingDay'] ?? true,
      startTime: start,
      endTime: end,
      breakStart: map['breakStart'] ?? '',
      breakEnd: map['breakEnd'] ?? '',
      breakDurationMinutes: (map['breakDurationMinutes'] as num?)?.toInt() ?? 0,
      isOvernight: map['isOvernight'] ?? autoOvernight,
      crossMidnightCutoff: map['crossMidnightCutoff'] ?? '',
    );
  }
}

class WorkShift {
  final String id;
  final String name;
  final String startTime; // "HH:mm" e.g., "09:00" (Fallback for non-rotation)
  final String endTime;   // "HH:mm" e.g., "17:00" (Fallback for non-rotation)
  final int forgivenessOfDelay; // in minutes, e.g. 15
  final int earlyExit;          // in minutes, e.g. 10
  final String breakStart; // "HH:mm" e.g., "12:00"
  final String breakEnd;   // "HH:mm" e.g., "14:00"
  final int breakDurationMinutes; // duration in minutes, e.g. 60
  final List<int> workingDays; // list of weekdays, e.g. [1, 2, 3, 4, 5] (Fallback for non-rotation)
  
  final bool isRotation;
  final Map<int, DayShiftConfig> weeklySchedule; // 1 (Mon) to 7 (Sun)
  final bool isOvernight;
  final String crossMidnightCutoff; // "HH:mm" e.g., "03:00" (Checkouts up to this cutoff calculate to previous date)

  WorkShift({
    required this.id,
    required this.name,
    required this.startTime,
    required this.endTime,
    this.forgivenessOfDelay = 0,
    this.earlyExit = 0,
    this.breakStart = '',
    this.breakEnd = '',
    this.breakDurationMinutes = 0,
    this.workingDays = const [1, 2, 3, 4, 5],
    this.isRotation = false,
    this.weeklySchedule = const {},
    this.isOvernight = false,
    this.crossMidnightCutoff = '',
  });

  static bool isTimeCrossMidnight(String start, String end) {
    final sParts = start.trim().split(':');
    final eParts = end.trim().split(':');
    if (sParts.length >= 2 && eParts.length >= 2) {
      final sMins = (int.tryParse(sParts[0]) ?? 0) * 60 + (int.tryParse(sParts[1]) ?? 0);
      final eMins = (int.tryParse(eParts[0]) ?? 0) * 60 + (int.tryParse(eParts[1]) ?? 0);
      return eMins < sMins;
    }
    return false;
  }

  bool isOvernightForDate(DateTime date) {
    if (isRotation) {
      final config = weeklySchedule[date.weekday];
      if (config != null) {
        return config.isOvernight || isTimeCrossMidnight(config.startTime, config.endTime);
      }
    }
    return isOvernight || isTimeCrossMidnight(startTime, endTime);
  }

  String getCrossMidnightCutoffForDate(DateTime date) {
    if (isRotation) {
      final config = weeklySchedule[date.weekday];
      if (config != null && config.crossMidnightCutoff.isNotEmpty) {
        return config.crossMidnightCutoff;
      }
    }
    if (crossMidnightCutoff.isNotEmpty) {
      return crossMidnightCutoff;
    }
    // Default fallback: 1 hour after end time if cross-midnight, or '03:00'
    final endStr = getEndTimeForDate(date);
    final eParts = endStr.trim().split(':');
    if (eParts.length >= 2) {
      final eH = int.tryParse(eParts[0]) ?? 2;
      final eM = int.tryParse(eParts[1]) ?? 0;
      final cutoffMins = eH * 60 + eM + 60;
      final cH = (cutoffMins ~/ 60) % 24;
      final cM = cutoffMins % 60;
      return '${cH.toString().padLeft(2, '0')}:${cM.toString().padLeft(2, '0')}';
    }
    return '03:00';
  }

  bool isWorkingDay(DateTime date) {
    if (!isRotation) {
      return workingDays.contains(date.weekday);
    }
    final config = weeklySchedule[date.weekday];
    return config?.isWorkingDay ?? false;
  }

  String getStartTimeForDate(DateTime date) {
    if (!isRotation) return startTime;
    final config = weeklySchedule[date.weekday];
    return config?.startTime ?? '00:00';
  }

  String getEndTimeForDate(DateTime date) {
    if (!isRotation) {
      return endTime;
    }
    final config = weeklySchedule[date.weekday];
    return config?.endTime ?? endTime;
  }

  String getBreakStartForDate(DateTime date) {
    if (!isRotation) {
      return breakStart;
    }
    final config = weeklySchedule[date.weekday];
    return config?.breakStart ?? breakStart;
  }

  String getBreakEndForDate(DateTime date) {
    if (!isRotation) {
      return breakEnd;
    }
    final config = weeklySchedule[date.weekday];
    return config?.breakEnd ?? breakEnd;
  }

  int getBreakDurationForDate(DateTime date) {
    if (!isRotation) {
      return breakDurationMinutes;
    }
    final config = weeklySchedule[date.weekday];
    return config?.breakDurationMinutes ?? breakDurationMinutes;
  }

  WorkShift copyWith({
    String? id,
    String? name,
    String? startTime,
    String? endTime,
    int? forgivenessOfDelay,
    int? earlyExit,
    String? breakStart,
    String? breakEnd,
    int? breakDurationMinutes,
    List<int>? workingDays,
    bool? isRotation,
    Map<int, DayShiftConfig>? weeklySchedule,
    bool? isOvernight,
    String? crossMidnightCutoff,
  }) {
    return WorkShift(
      id: id ?? this.id,
      name: name ?? this.name,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      forgivenessOfDelay: forgivenessOfDelay ?? this.forgivenessOfDelay,
      earlyExit: earlyExit ?? this.earlyExit,
      breakStart: breakStart ?? this.breakStart,
      breakEnd: breakEnd ?? this.breakEnd,
      breakDurationMinutes: breakDurationMinutes ?? this.breakDurationMinutes,
      workingDays: workingDays ?? this.workingDays,
      isRotation: isRotation ?? this.isRotation,
      weeklySchedule: weeklySchedule ?? this.weeklySchedule,
      isOvernight: isOvernight ?? this.isOvernight,
      crossMidnightCutoff: crossMidnightCutoff ?? this.crossMidnightCutoff,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'startTime': startTime,
      'endTime': endTime,
      'forgivenessOfDelay': forgivenessOfDelay,
      'earlyExit': earlyExit,
      'breakStart': breakStart,
      'breakEnd': breakEnd,
      'breakDurationMinutes': breakDurationMinutes,
      'workingDays': workingDays,
      'isRotation': isRotation,
      'weeklySchedule': weeklySchedule.map((key, value) => MapEntry(key.toString(), value.toMap())),
      'isOvernight': isOvernight,
      'crossMidnightCutoff': crossMidnightCutoff,
    };
  }

  factory WorkShift.fromMap(Map<String, dynamic> map, String docId) {
    Map<int, DayShiftConfig> parsedWeeklySchedule = {};
    if (map['weeklySchedule'] != null) {
      final wsMap = map['weeklySchedule'] as Map<String, dynamic>;
      wsMap.forEach((key, value) {
        parsedWeeklySchedule[int.parse(key)] = DayShiftConfig.fromMap(Map<String, dynamic>.from(value));
      });
    }

    final start = map['startTime'] ?? '';
    final end = map['endTime'] ?? '';
    final autoOvernight = isTimeCrossMidnight(start, end);

    return WorkShift(
      id: map['id'] ?? docId,
      name: map['name'] ?? '',
      startTime: start,
      endTime: end,
      forgivenessOfDelay: (map['forgivenessOfDelay'] as num?)?.toInt() ?? 0,
      earlyExit: (map['earlyExit'] as num?)?.toInt() ?? 0,
      breakStart: map['breakStart'] ?? '',
      breakEnd: map['breakEnd'] ?? '',
      breakDurationMinutes: (map['breakDurationMinutes'] as num?)?.toInt() ?? 0,
      workingDays: List<int>.from(map['workingDays'] ?? [1, 2, 3, 4, 5]),
      isRotation: map['isRotation'] ?? false,
      weeklySchedule: parsedWeeklySchedule,
      isOvernight: map['isOvernight'] ?? autoOvernight,
      crossMidnightCutoff: map['crossMidnightCutoff'] ?? '',
    );
  }
}

class EmployeeGroup {
  final String id;
  final String name;
  final String shiftId; // Refers to WorkShift
  
  // Permissions
  final bool canEditCompanyInfo;
  
  // Annual Leave Config
  final String annualLeaveAdditionType; // 'None', 'Monthly', 'Yearly'
  final double annualLeaveAdditionHours;
  
  // Missed Punch Limit
  final int missedPunchLimitPerMonth;
  
  // Annual Leave Request Deadline
  final int annualLeaveRequestDeadlineDays;
  
  // Specific rules
  final bool overtimeAllowed;
  final int minOvertimeMinutes;
  final int maxOvertimeMinutes;
  final double holidayOvertimeRatio;
  final double weekendOvertimeRatio;

  // Penalty switches
  final bool delayPenaltiesEnabled;
  final bool earlyExitPenaltiesEnabled;

  // Delay penalty rules
  final int delayTier1Min;
  final int delayTier1Max;
  final double delayTier1Penalty;
  final int delayTier2Min;
  final int delayTier2Max;
  final double delayTier2Penalty;
  final int delayTier3Min;
  final double delayTier3Penalty;

  // Early exit penalty rules
  final int earlyExitTier1Min;
  final int earlyExitTier1Max;
  final double earlyExitTier1Penalty;
  final int earlyExitTier2Min;
  final int earlyExitTier2Max;
  final double earlyExitTier2Penalty;
  final int earlyExitTier3Min;
  final double earlyExitTier3Penalty;

  EmployeeGroup({
    required this.id,
    required this.name,
    required this.shiftId,
    this.annualLeaveAdditionType = 'None',
    this.annualLeaveAdditionHours = 0.0,
    this.missedPunchLimitPerMonth = 3,
    this.annualLeaveRequestDeadlineDays = 0,
    this.overtimeAllowed = false,
    this.minOvertimeMinutes = 0,
    this.maxOvertimeMinutes = 0,
    this.holidayOvertimeRatio = 1.5,
    this.weekendOvertimeRatio = 1.5,
    this.delayPenaltiesEnabled = true,
    this.earlyExitPenaltiesEnabled = true,
    this.delayTier1Min = 0,
    this.delayTier1Max = 0,
    this.delayTier1Penalty = 0.0,
    this.delayTier2Min = 0,
    this.delayTier2Max = 0,
    this.delayTier2Penalty = 0.0,
    this.delayTier3Min = 0,
    this.delayTier3Penalty = 0.0,
    this.earlyExitTier1Min = 0,
    this.earlyExitTier1Max = 0,
    this.earlyExitTier1Penalty = 0.0,
    this.earlyExitTier2Min = 0,
    this.earlyExitTier2Max = 0,
    this.earlyExitTier2Penalty = 0.0,
    this.earlyExitTier3Min = 0,
    this.earlyExitTier3Penalty = 0.0,
    this.canEditCompanyInfo = false,
  });

  EmployeeGroup copyWith({
    String? id,
    String? name,
    String? shiftId,
    bool? canEditCompanyInfo,
    String? annualLeaveAdditionType,
    double? annualLeaveAdditionHours,
    int? missedPunchLimitPerMonth,
    int? annualLeaveRequestDeadlineDays,
    bool? overtimeAllowed,
    int? minOvertimeMinutes,
    int? maxOvertimeMinutes,
    double? holidayOvertimeRatio,
    double? weekendOvertimeRatio,
    bool? delayPenaltiesEnabled,
    bool? earlyExitPenaltiesEnabled,
    int? delayTier1Min,
    int? delayTier1Max,
    double? delayTier1Penalty,
    int? delayTier2Min,
    int? delayTier2Max,
    double? delayTier2Penalty,
    int? delayTier3Min,
    double? delayTier3Penalty,
    int? earlyExitTier1Min,
    int? earlyExitTier1Max,
    double? earlyExitTier1Penalty,
    int? earlyExitTier2Min,
    int? earlyExitTier2Max,
    double? earlyExitTier2Penalty,
    int? earlyExitTier3Min,
    double? earlyExitTier3Penalty,
  }) {
    return EmployeeGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      shiftId: shiftId ?? this.shiftId,
      canEditCompanyInfo: canEditCompanyInfo ?? this.canEditCompanyInfo,
      annualLeaveAdditionType: annualLeaveAdditionType ?? this.annualLeaveAdditionType,
      annualLeaveAdditionHours: annualLeaveAdditionHours ?? this.annualLeaveAdditionHours,
      missedPunchLimitPerMonth: missedPunchLimitPerMonth ?? this.missedPunchLimitPerMonth,
      annualLeaveRequestDeadlineDays: annualLeaveRequestDeadlineDays ?? this.annualLeaveRequestDeadlineDays,
      overtimeAllowed: overtimeAllowed ?? this.overtimeAllowed,
      minOvertimeMinutes: minOvertimeMinutes ?? this.minOvertimeMinutes,
      maxOvertimeMinutes: maxOvertimeMinutes ?? this.maxOvertimeMinutes,
      holidayOvertimeRatio: holidayOvertimeRatio ?? this.holidayOvertimeRatio,
      weekendOvertimeRatio: weekendOvertimeRatio ?? this.weekendOvertimeRatio,
      delayPenaltiesEnabled: delayPenaltiesEnabled ?? this.delayPenaltiesEnabled,
      earlyExitPenaltiesEnabled: earlyExitPenaltiesEnabled ?? this.earlyExitPenaltiesEnabled,
      delayTier1Min: delayTier1Min ?? this.delayTier1Min,
      delayTier1Max: delayTier1Max ?? this.delayTier1Max,
      delayTier1Penalty: delayTier1Penalty ?? this.delayTier1Penalty,
      delayTier2Min: delayTier2Min ?? this.delayTier2Min,
      delayTier2Max: delayTier2Max ?? this.delayTier2Max,
      delayTier2Penalty: delayTier2Penalty ?? this.delayTier2Penalty,
      delayTier3Min: delayTier3Min ?? this.delayTier3Min,
      delayTier3Penalty: delayTier3Penalty ?? this.delayTier3Penalty,
      earlyExitTier1Min: earlyExitTier1Min ?? this.earlyExitTier1Min,
      earlyExitTier1Max: earlyExitTier1Max ?? this.earlyExitTier1Max,
      earlyExitTier1Penalty: earlyExitTier1Penalty ?? this.earlyExitTier1Penalty,
      earlyExitTier2Min: earlyExitTier2Min ?? this.earlyExitTier2Min,
      earlyExitTier2Max: earlyExitTier2Max ?? this.earlyExitTier2Max,
      earlyExitTier2Penalty: earlyExitTier2Penalty ?? this.earlyExitTier2Penalty,
      earlyExitTier3Min: earlyExitTier3Min ?? this.earlyExitTier3Min,
      earlyExitTier3Penalty: earlyExitTier3Penalty ?? this.earlyExitTier3Penalty,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'shiftId': shiftId,
      'canEditCompanyInfo': canEditCompanyInfo,
      'annualLeaveAdditionType': annualLeaveAdditionType,
      'annualLeaveAdditionHours': annualLeaveAdditionHours,
      'missedPunchLimitPerMonth': missedPunchLimitPerMonth,
      'annualLeaveRequestDeadlineDays': annualLeaveRequestDeadlineDays,
      'overtimeAllowed': overtimeAllowed,
      'minOvertimeMinutes': minOvertimeMinutes,
      'maxOvertimeMinutes': maxOvertimeMinutes,
      'holidayOvertimeRatio': holidayOvertimeRatio,
      'weekendOvertimeRatio': weekendOvertimeRatio,
      'delayPenaltiesEnabled': delayPenaltiesEnabled,
      'earlyExitPenaltiesEnabled': earlyExitPenaltiesEnabled,
      'delayTier1Min': delayTier1Min,
      'delayTier1Max': delayTier1Max,
      'delayTier1Penalty': delayTier1Penalty,
      'delayTier2Min': delayTier2Min,
      'delayTier2Max': delayTier2Max,
      'delayTier2Penalty': delayTier2Penalty,
      'delayTier3Min': delayTier3Min,
      'delayTier3Penalty': delayTier3Penalty,
      'earlyExitTier1Min': earlyExitTier1Min,
      'earlyExitTier1Max': earlyExitTier1Max,
      'earlyExitTier1Penalty': earlyExitTier1Penalty,
      'earlyExitTier2Min': earlyExitTier2Min,
      'earlyExitTier2Max': earlyExitTier2Max,
      'earlyExitTier2Penalty': earlyExitTier2Penalty,
      'earlyExitTier3Min': earlyExitTier3Min,
      'earlyExitTier3Penalty': earlyExitTier3Penalty,
    };
  }

  factory EmployeeGroup.fromMap(Map<String, dynamic> map, String docId) {
    return EmployeeGroup(
      id: map['id'] ?? docId,
      name: map['name'] ?? '',
      shiftId: map['shiftId'] ?? '',
      canEditCompanyInfo: map['canEditCompanyInfo'] ?? false,
      annualLeaveAdditionType: map['annualLeaveAdditionType'] ?? 'None',
      annualLeaveAdditionHours: (map['annualLeaveAdditionHours'] as num?)?.toDouble() ?? 0.0,
      missedPunchLimitPerMonth: (map['missedPunchLimitPerMonth'] as num?)?.toInt() ?? 3,
      annualLeaveRequestDeadlineDays: (map['annualLeaveRequestDeadlineDays'] as num?)?.toInt() ?? 0,
      overtimeAllowed: map['overtimeAllowed'] ?? false,
      minOvertimeMinutes: (map['minOvertimeMinutes'] as num?)?.toInt() ?? 0,
      maxOvertimeMinutes: (map['maxOvertimeMinutes'] as num?)?.toInt() ?? 0,
      holidayOvertimeRatio: (map['holidayOvertimeRatio'] as num?)?.toDouble() ?? 1.5,
      weekendOvertimeRatio: (map['weekendOvertimeRatio'] as num?)?.toDouble() ?? 1.5,
      delayPenaltiesEnabled: map['delayPenaltiesEnabled'] ?? true,
      earlyExitPenaltiesEnabled: map['earlyExitPenaltiesEnabled'] ?? true,
      delayTier1Min: (map['delayTier1Min'] as num?)?.toInt() ?? 0,
      delayTier1Max: (map['delayTier1Max'] as num?)?.toInt() ?? 0,
      delayTier1Penalty: (map['delayTier1Penalty'] as num?)?.toDouble() ?? 0.0,
      delayTier2Min: (map['delayTier2Min'] as num?)?.toInt() ?? 0,
      delayTier2Max: (map['delayTier2Max'] as num?)?.toInt() ?? 0,
      delayTier2Penalty: (map['delayTier2Penalty'] as num?)?.toDouble() ?? 0.0,
      delayTier3Min: (map['delayTier3Min'] as num?)?.toInt() ?? 0,
      delayTier3Penalty: (map['delayTier3Penalty'] as num?)?.toDouble() ?? 0.0,
      earlyExitTier1Min: (map['earlyExitTier1Min'] as num?)?.toInt() ?? 0,
      earlyExitTier1Max: (map['earlyExitTier1Max'] as num?)?.toInt() ?? 0,
      earlyExitTier1Penalty: (map['earlyExitTier1Penalty'] as num?)?.toDouble() ?? 0.0,
      earlyExitTier2Min: (map['earlyExitTier2Min'] as num?)?.toInt() ?? 0,
      earlyExitTier2Max: (map['earlyExitTier2Max'] as num?)?.toInt() ?? 0,
      earlyExitTier2Penalty: (map['earlyExitTier2Penalty'] as num?)?.toDouble() ?? 0.0,
      earlyExitTier3Min: (map['earlyExitTier3Min'] as num?)?.toInt() ?? 0,
      earlyExitTier3Penalty: (map['earlyExitTier3Penalty'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class PositionHistoryEntry {
  final String position;
  final String startDate;
  final String endDate;

  PositionHistoryEntry({
    required this.position,
    required this.startDate,
    required this.endDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'position': position,
      'startDate': startDate,
      'endDate': endDate,
    };
  }

  factory PositionHistoryEntry.fromMap(Map<String, dynamic> map) {
    return PositionHistoryEntry(
      position: map['position'] ?? '',
      startDate: map['startDate'] ?? '',
      endDate: map['endDate'] ?? '',
    );
  }
}

class GroupHistoryEntry {
  final String groupId;
  final String startDate;
  final String endDate;

  GroupHistoryEntry({
    required this.groupId,
    required this.startDate,
    required this.endDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'startDate': startDate,
      'endDate': endDate,
    };
  }

  factory GroupHistoryEntry.fromMap(Map<String, dynamic> map) {
    return GroupHistoryEntry(
      groupId: map['groupId'] ?? '',
      startDate: map['startDate'] ?? '',
      endDate: map['endDate'] ?? '',
    );
  }
}

class CompanyEmployee {
  final String id;
  final String name;
  final String email;
  final String position;
  final String? groupId; // Refers to EmployeeGroup (null if none)
  final String? structureId; // Refers to OrgStructure directly
  final String role; // 'employee', 'supervisor', 'hr'
  final String phoneNumber;
  final String startDate;
  final String? endDate;
  final bool disabled;
  final String positionStartDate;
  final List<PositionHistoryEntry> positionHistory;
  final String groupStartDate;
  final List<GroupHistoryEntry> groupHistory;
  final String? avatarUrl;
  
  final double annualLeaveBalance;
  
  final double basicSalary;
  final double workingHours;
  final String salaryCurrency;
  final List<SalaryHistoryEntry> salaryHistory;
  final double foodAllowance;
  final double transportationAllowance;
  final double otherAllowance;
  
  final List<double>? faceEmbedding;
  final String themePreference; // 'dark' or 'light'
  final String? fcmToken;
  final String? password;

  CompanyEmployee({
    required this.id,
    required this.name,
    required this.email,
    required this.position,
    this.groupId,
    this.structureId,
    this.role = 'employee',
    this.phoneNumber = '',
    this.startDate = '',
    this.endDate,
    this.disabled = false,
    this.positionStartDate = '',
    this.positionHistory = const [],
    this.groupStartDate = '',
    this.groupHistory = const [],
    this.avatarUrl,
    this.annualLeaveBalance = 0.0,
    this.basicSalary = 0.0,
    this.workingHours = 0.0,
    this.salaryCurrency = 'USD',
    this.salaryHistory = const [],
    this.foodAllowance = 0.0,
    this.transportationAllowance = 0.0,
    this.otherAllowance = 0.0,
    this.faceEmbedding,
    this.themePreference = 'dark',
    this.fcmToken,
    this.password,
  });

  CompanyEmployee copyWith({
    String? id,
    String? name,
    String? email,
    String? position,
    String? groupId,
    bool overrideGroupId = false,
    String? structureId,
    bool overrideStructureId = false,
    String? role,
    String? phoneNumber,
    String? startDate,
    String? endDate,
    bool overrideEndDate = false,
    bool? disabled,
    String? positionStartDate,
    List<PositionHistoryEntry>? positionHistory,
    String? groupStartDate,
    List<GroupHistoryEntry>? groupHistory,
    String? avatarUrl,
    bool overrideAvatarUrl = false,
    double? annualLeaveBalance,
    double? basicSalary,
    double? workingHours,
    String? salaryCurrency,
    List<SalaryHistoryEntry>? salaryHistory,
    double? foodAllowance,
    double? transportationAllowance,
    double? otherAllowance,
    List<double>? faceEmbedding,
    bool overrideFaceEmbedding = false,
    String? themePreference,
    String? fcmToken,
    bool overrideFcmToken = false,
    String? password,
    bool overridePassword = false,
  }) {
    return CompanyEmployee(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      position: position ?? this.position,
      groupId: overrideGroupId ? groupId : (groupId ?? this.groupId),
      structureId: overrideStructureId ? structureId : (structureId ?? this.structureId),
      role: role ?? this.role,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      startDate: startDate ?? this.startDate,
      endDate: overrideEndDate ? endDate : (endDate ?? this.endDate),
      disabled: disabled ?? this.disabled,
      positionStartDate: positionStartDate ?? this.positionStartDate,
      positionHistory: positionHistory ?? this.positionHistory,
      groupStartDate: groupStartDate ?? this.groupStartDate,
      groupHistory: groupHistory ?? this.groupHistory,
      avatarUrl: overrideAvatarUrl ? avatarUrl : (avatarUrl ?? this.avatarUrl),
      annualLeaveBalance: annualLeaveBalance ?? this.annualLeaveBalance,
      basicSalary: basicSalary ?? this.basicSalary,
      workingHours: workingHours ?? this.workingHours,
      salaryCurrency: salaryCurrency ?? this.salaryCurrency,
      salaryHistory: salaryHistory ?? this.salaryHistory,
      foodAllowance: foodAllowance ?? this.foodAllowance,
      transportationAllowance: transportationAllowance ?? this.transportationAllowance,
      otherAllowance: otherAllowance ?? this.otherAllowance,
      faceEmbedding: overrideFaceEmbedding ? faceEmbedding : (faceEmbedding ?? this.faceEmbedding),
      themePreference: themePreference ?? this.themePreference,
      password: overridePassword ? password : (password ?? this.password),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'position': position,
      'groupId': groupId,
      'structureId': structureId,
      'role': role,
      'phoneNumber': phoneNumber,
      'startDate': startDate,
      'endDate': endDate,
      'disabled': disabled,
      'positionStartDate': positionStartDate,
      'positionHistory': positionHistory.map((e) => e.toMap()).toList(),
      'groupStartDate': groupStartDate,
      'groupHistory': groupHistory.map((e) => e.toMap()).toList(),
      'avatarUrl': avatarUrl,
      'annualLeaveBalance': annualLeaveBalance,
      'basicSalary': basicSalary,
      'workingHours': workingHours,
      'salaryCurrency': salaryCurrency,
      'salaryHistory': salaryHistory.map((e) => e.toMap()).toList(),
      'foodAllowance': foodAllowance,
      'transportationAllowance': transportationAllowance,
      'otherAllowance': otherAllowance,
      'faceEmbedding': faceEmbedding,
      'themePreference': themePreference,
      'fcmToken': fcmToken,
      'password': password,
    };
  }

  factory CompanyEmployee.fromMap(Map<String, dynamic> map, String docId) {
    var historyList = map['positionHistory'] as List?;
    List<PositionHistoryEntry> history = historyList != null
        ? historyList
            .map((e) => PositionHistoryEntry.fromMap(Map<String, dynamic>.from(e)))
            .toList()
        : [];

    var groupHistoryList = map['groupHistory'] as List?;
    List<GroupHistoryEntry> gHistory = groupHistoryList != null
        ? groupHistoryList
            .map((e) => GroupHistoryEntry.fromMap(Map<String, dynamic>.from(e)))
            .toList()
        : [];

    return CompanyEmployee(
      id: map['id'] ?? docId,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      position: map['position'] ?? '',
      groupId: map['groupId'],
      structureId: map['structureId'],
      role: map['role'] ?? 'employee',
      phoneNumber: map['phoneNumber'] ?? '',
      startDate: map['startDate'] ?? '',
      endDate: map['endDate'],
      disabled: map['disabled'] ?? false,
      positionStartDate: map['positionStartDate'] ?? '',
      positionHistory: history,
      groupStartDate: map['groupStartDate'] ?? '',
      groupHistory: gHistory,
      avatarUrl: map['avatarUrl'],
      annualLeaveBalance: (map['annualLeaveBalance'] as num?)?.toDouble() ?? 0.0,
      basicSalary: (map['basicSalary'] as num?)?.toDouble() ?? 0.0,
      workingHours: (map['workingHours'] as num?)?.toDouble() ?? 0.0,
      salaryCurrency: map['salaryCurrency'] ?? 'USD',
      salaryHistory: (map['salaryHistory'] as List?)
              ?.map((e) => SalaryHistoryEntry.fromMap(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
      foodAllowance: (map['foodAllowance'] as num?)?.toDouble() ?? 0.0,
      transportationAllowance: (map['transportationAllowance'] as num?)?.toDouble() ?? 0.0,
      otherAllowance: (map['otherAllowance'] as num?)?.toDouble() ?? 0.0,
      faceEmbedding: map['faceEmbedding'] != null 
          ? List<double>.from((map['faceEmbedding'] as List).map((e) => (e as num).toDouble()))
          : null,
      themePreference: map['themePreference'] ?? 'dark',
      fcmToken: map['fcmToken'],
      password: map['password'],
    );
  }
}

class Holiday {
  final String id;
  final String name;
  final String fromDate; // yyyy-MM-dd
  final String toDate;   // yyyy-MM-dd
  final List<String> groupIds;

  Holiday({
    required this.id,
    required this.name,
    required this.fromDate,
    required this.toDate,
    this.groupIds = const [],
  });

  Holiday copyWith({
    String? id,
    String? name,
    String? fromDate,
    String? toDate,
    List<String>? groupIds,
  }) {
    return Holiday(
      id: id ?? this.id,
      name: name ?? this.name,
      fromDate: fromDate ?? this.fromDate,
      toDate: toDate ?? this.toDate,
      groupIds: groupIds ?? this.groupIds,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'fromDate': fromDate,
      'toDate': toDate,
      'groupIds': groupIds,
    };
  }

  factory Holiday.fromMap(Map<String, dynamic> map, String docId) {
    return Holiday(
      id: map['id'] ?? docId,
      name: map['name'] ?? '',
      fromDate: map['fromDate'] ?? '',
      toDate: map['toDate'] ?? '',
      groupIds: List<String>.from(map['groupIds'] ?? []),
    );
  }
}

class WorkLocation {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double radius;
  final List<String> groupIds;

  WorkLocation({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radius,
    this.groupIds = const [],
  });

  WorkLocation copyWith({
    String? id,
    String? name,
    double? latitude,
    double? longitude,
    double? radius,
    List<String>? groupIds,
  }) {
    return WorkLocation(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radius: radius ?? this.radius,
      groupIds: groupIds ?? this.groupIds,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
      'groupIds': groupIds,
    };
  }

  factory WorkLocation.fromMap(Map<String, dynamic> map, String docId) {
    return WorkLocation(
      id: map['id'] ?? docId,
      name: map['name'] ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      radius: (map['radius'] as num?)?.toDouble() ?? 0.0,
      groupIds: List<String>.from(map['groupIds'] ?? []),
    );
  }
}

class CompanyProfile {
  final String name;
  final String address;
  final String? email;
  final String? phone;
  final String? logoBase64;

  CompanyProfile({
    required this.name,
    required this.address,
    this.email,
    this.phone,
    this.logoBase64,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
      'email': email,
      'phone': phone,
      'logoBase64': logoBase64,
    };
  }

  factory CompanyProfile.fromMap(Map<String, dynamic> map) {
    return CompanyProfile(
      name: map['name'] ?? '',
      address: map['address'] ?? '',
      email: map['email'],
      phone: map['phone'],
      logoBase64: map['logoBase64'],
    );
  }
}

class PayrollAdjustment {
  final String id;
  final String employeeId;
  final String type; // 'addition' or 'deduction'
  final String category; // 'Bonus', 'Commission', 'Loan Repayment', 'Fine', etc.
  final double amount;
  final String currency; // 'USD' or 'IQD'
  final String date; // 'yyyy-MM-dd'
  final String month; // 'yyyy-MM'
  final String reason;
  final String? createdBy;
  final DateTime createdAt;

  PayrollAdjustment({
    required this.id,
    required this.employeeId,
    required this.type,
    required this.category,
    required this.amount,
    required this.currency,
    required this.date,
    required this.month,
    this.reason = '',
    this.createdBy,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  PayrollAdjustment copyWith({
    String? id,
    String? employeeId,
    String? type,
    String? category,
    double? amount,
    String? currency,
    String? date,
    String? month,
    String? reason,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return PayrollAdjustment(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      type: type ?? this.type,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      date: date ?? this.date,
      month: month ?? this.month,
      reason: reason ?? this.reason,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employeeId': employeeId,
      'type': type,
      'category': category,
      'amount': amount,
      'currency': currency,
      'date': date,
      'month': month,
      'reason': reason,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory PayrollAdjustment.fromMap(Map<String, dynamic> map, String docId) {
    final dStr = map['date'] ?? '';
    final mStr = map['month'] ?? (dStr.length >= 7 ? dStr.substring(0, 7) : '');
    return PayrollAdjustment(
      id: map['id'] ?? docId,
      employeeId: map['employeeId'] ?? '',
      type: map['type'] ?? 'addition',
      category: map['category'] ?? 'Bonus',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      currency: map['currency'] ?? 'USD',
      date: dStr,
      month: mStr,
      reason: map['reason'] ?? '',
      createdBy: map['createdBy'],
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

