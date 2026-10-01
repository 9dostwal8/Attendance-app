import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/attendance_record.dart';
import '../models/hr_models.dart';
import '../providers/attendance_provider.dart';
import 'firebase_service.dart';
import 'zkteco/zkteco_driver.dart';
import 'zkteco/zkteco_driver_factory.dart';
import 'zkteco/zkteco_models.dart';

export 'zkteco/zkteco_models.dart';

class ZkTecoService extends ChangeNotifier {
  static final ZkTecoService instance = ZkTecoService._internal();

  ZkTecoService._internal() {
    _driver = createZkDriver();
  }

  late final ZkDeviceDriver _driver;

  // Configuration
  String _deviceIp = '192.168.1.201';
  int _devicePort = 4370;
  int _devicePassword = 0;
  bool _autoSyncEnabled = false;
  int _autoSyncIntervalMinutes = 15;
  int _cooldownMinutes = 3;

  // Status
  bool _isConnecting = false;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  String _lastSyncStatus = 'Not synced yet';
  ZkDeviceInfo? _cachedDeviceInfo;
  ZkSyncSummary? _lastSummary;
  List<ZkDeviceUser> _cachedUsers = [];
  final List<String> _syncLogs = [];

  Timer? _autoSyncTimer;

  // Getters
  String get deviceIp => _deviceIp;
  int get devicePort => _devicePort;
  int get devicePassword => _devicePassword;
  bool get autoSyncEnabled => _autoSyncEnabled;
  int get autoSyncIntervalMinutes => _autoSyncIntervalMinutes;
  int get cooldownMinutes => _cooldownMinutes;

  bool get isConnecting => _isConnecting;
  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;
  String get lastSyncStatus => _lastSyncStatus;
  ZkDeviceInfo? get cachedDeviceInfo => _cachedDeviceInfo;
  ZkSyncSummary? get lastSummary => _lastSummary;
  List<ZkDeviceUser> get cachedUsers => _cachedUsers;
  List<String> get syncLogs => List.unmodifiable(_syncLogs);

  /// Initialize service and load saved preferences
  Future<void> init(AttendanceProvider? provider, FirebaseService? firebase) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _deviceIp = prefs.getString('zk_device_ip') ?? '192.168.1.201';
      _devicePort = prefs.getInt('zk_device_port') ?? 4370;
      _devicePassword = prefs.getInt('zk_device_password') ?? 0;
      _autoSyncEnabled = prefs.getBool('zk_auto_sync') ?? false;
      _autoSyncIntervalMinutes = prefs.getInt('zk_auto_sync_interval') ?? 15;
      _cooldownMinutes = prefs.getInt('zk_cooldown_minutes') ?? 3;

      final lastSyncMs = prefs.getInt('zk_last_sync_ms');
      if (lastSyncMs != null) {
        _lastSyncTime = DateTime.fromMillisecondsSinceEpoch(lastSyncMs);
        _lastSyncStatus = prefs.getString('zk_last_sync_status') ?? 'Idle';
      }

      if (_autoSyncEnabled && provider != null && firebase != null) {
        startAutoSync(provider, firebase);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing ZkTecoService: $e');
    }
  }

  /// Save settings
  Future<void> saveSettings({
    required String ip,
    required int port,
    required int password,
    required bool autoSync,
    required int intervalMinutes,
    required int cooldownMinutes,
    AttendanceProvider? provider,
    FirebaseService? firebase,
  }) async {
    _deviceIp = ip.trim();
    _devicePort = port;
    _devicePassword = password;
    _autoSyncEnabled = autoSync;
    _autoSyncIntervalMinutes = intervalMinutes;
    _cooldownMinutes = cooldownMinutes;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('zk_device_ip', _deviceIp);
    await prefs.setInt('zk_device_port', _devicePort);
    await prefs.setInt('zk_device_password', _devicePassword);
    await prefs.setBool('zk_auto_sync', _autoSyncEnabled);
    await prefs.setInt('zk_auto_sync_interval', _autoSyncIntervalMinutes);
    await prefs.setInt('zk_cooldown_minutes', _cooldownMinutes);

    if (_autoSyncEnabled && provider != null && firebase != null) {
      startAutoSync(provider, firebase);
    } else {
      stopAutoSync();
    }

    notifyListeners();
  }

  /// Test connection to the ZKTeco device
  Future<ZkDeviceInfo> testConnection({String? ip, int? port, int? password}) async {
    _isConnecting = true;
    notifyListeners();

    final targetIp = (ip ?? _deviceIp).trim();
    final targetPort = port ?? _devicePort;
    final targetPassword = password ?? _devicePassword;

    try {
      _addLog('Testing connection to $targetIp:$targetPort...');
      final info = await _driver.testConnection(
        ip: targetIp,
        port: targetPort,
        password: targetPassword,
        timeoutSeconds: 8,
      );

      _cachedDeviceInfo = info;
      if (info.isConnected) {
        _addLog('Connected successfully to ${info.deviceName} (SN: ${info.serialNumber})');
      } else {
        _addLog('Connection failed: ${info.errorMessage ?? "Unknown error"}');
      }
      return info;
    } catch (e) {
      final info = ZkDeviceInfo(
        isConnected: false,
        ip: targetIp,
        port: targetPort,
        errorMessage: e.toString(),
      );
      _cachedDeviceInfo = info;
      _addLog('Connection error: $e');
      return info;
    } finally {
      _isConnecting = false;
      notifyListeners();
    }
  }

  /// Fetch users registered on the device
  Future<List<ZkDeviceUser>> fetchUsers() async {
    try {
      _addLog('Fetching users from device at $_deviceIp...');
      final users = await _driver.getUsers(
        ip: _deviceIp,
        port: _devicePort,
        password: _devicePassword,
      );
      _cachedUsers = users;
      _addLog('Found ${users.length} users registered on device.');
      notifyListeners();
      return users;
    } catch (e) {
      _addLog('Failed to fetch users: $e');
      rethrow;
    }
  }

  /// Sync attendance punches from the ZKTeco device
  Future<ZkSyncSummary> syncAttendances({
    required AttendanceProvider provider,
    required FirebaseService firebase,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    if (_isSyncing) {
      return ZkSyncSummary(
        success: false,
        syncTime: DateTime.now(),
        message: 'Sync is already in progress.',
      );
    }

    _isSyncing = true;
    notifyListeners();

    final now = DateTime.now();
    final defaultFrom = _lastSyncTime != null
        ? _lastSyncTime!.subtract(const Duration(days: 2)) // buffer for overnight shifts
        : DateTime(now.year, now.month, 1);
    final targetFrom = fromDate ?? defaultFrom;
    final targetTo = toDate ?? now;

    _addLog('Starting attendance sync from ${targetFrom.toLocal()} to ${targetTo.toLocal()}...');

    try {
      // 1. Fetch raw punch logs from the machine
      final punches = await _driver.getAttendanceLogs(
        ip: _deviceIp,
        port: _devicePort,
        password: _devicePassword,
        fromDate: targetFrom,
        toDate: targetTo,
      );

      _addLog('Fetched ${punches.length} raw punches from device.');

      if (punches.isEmpty) {
        final summary = ZkSyncSummary(
          success: true,
          totalPunchesFetched: 0,
          newRecordsCreated: 0,
          recordsUpdated: 0,
          syncTime: now,
          message: 'Device connected. No new attendance logs found.',
        );
        _finishSync(summary);
        return summary;
      }

      // 2. Run smart shift-aware pairing engine
      final summary = await _pairAndSavePunches(
        punches: punches,
        provider: provider,
        firebase: firebase,
      );

      _finishSync(summary);
      return summary;
    } catch (e) {
      final summary = ZkSyncSummary(
        success: false,
        syncTime: DateTime.now(),
        message: 'Sync failed: $e',
      );
      _finishSync(summary);
      return summary;
    }
  }

  /// Smart shift-aware punch pairing engine
  Future<ZkSyncSummary> _pairAndSavePunches({
    required List<ZkRawPunch> punches,
    required AttendanceProvider provider,
    required FirebaseService firebase,
  }) async {
    int newRecordsCreated = 0;
    int recordsUpdated = 0;
    final details = <String>[];

    // Group punches by userId
    final Map<String, List<ZkRawPunch>> userPunches = {};
    for (var p in punches) {
      userPunches.putIfAbsent(p.userId.trim(), () => []).add(p);
    }

    // Sort punches chronologically for each user
    userPunches.forEach((key, list) {
      list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    });

    // Map device userId to CompanyEmployee
    final employees = provider.employees;

    for (var entry in userPunches.entries) {
      final deviceUserId = entry.key;
      final rawList = entry.value;

      // Find matching employee
      final emp = _findMatchingEmployee(deviceUserId, employees);
      if (emp == null) {
        details.add('User ID $deviceUserId on device has no matching employee in app. Skipped.');
        continue;
      }

      // Filter out duplicate / rapid bounce punches
      final cleanPunches = <ZkRawPunch>[];
      for (var p in rawList) {
        if (cleanPunches.isEmpty) {
          cleanPunches.add(p);
        } else {
          final diff = p.timestamp.difference(cleanPunches.last.timestamp).inMinutes.abs();
          if (diff >= _cooldownMinutes) {
            cleanPunches.add(p);
          }
        }
      }

      if (cleanPunches.isEmpty) continue;

      // Get existing records for this employee
      final existingRecords = List<AttendanceRecord>.from(
        provider.allCompanyRecords.where((r) =>
            r.employeeId != null &&
            r.employeeId!.trim().toLowerCase() == emp.id.trim().toLowerCase()),
      );

      // Process each clean punch into sessions
      AttendanceRecord? currentOpenRecord = existingRecords.cast<AttendanceRecord?>().firstWhere(
            (r) => r != null && r.checkOut == null,
            orElse: () => null,
          );

      for (var punch in cleanPunches) {
        final pTime = punch.timestamp;

        if (currentOpenRecord == null) {
          // Check if there is already a record whose checkIn matches this punch exactly
          final exists = existingRecords.any((r) =>
              r.checkIn.year == pTime.year &&
              r.checkIn.month == pTime.month &&
              r.checkIn.day == pTime.day &&
              r.checkIn.hour == pTime.hour &&
              r.checkIn.minute == pTime.minute);

          if (exists) {
            // Already recorded, find it to see if it's open
            final rec = existingRecords.firstWhere((r) =>
                r.checkIn.year == pTime.year &&
                r.checkIn.month == pTime.month &&
                r.checkIn.day == pTime.day &&
                r.checkIn.hour == pTime.hour &&
                r.checkIn.minute == pTime.minute);
            if (rec.checkOut == null) {
              currentOpenRecord = rec;
            }
            continue;
          }

          // Open a new session (Clock In)
          final newRec = AttendanceRecord(
            checkIn: pTime,
            checkOut: null,
            employeeId: emp.id,
          );
          currentOpenRecord = newRec;
          existingRecords.add(newRec);

          if (firebase.isAvailable) {
            try {
              await firebase.saveRecord(emp.id, newRec);
              newRecordsCreated++;
              details.add('${emp.name}: Clock In at ${pTime.toString().substring(0, 16)}');
            } catch (e) {
              debugPrint('Error saving record: $e');
            }
          }
        } else {
          // An open session exists
          final elapsed = pTime.difference(currentOpenRecord.checkIn);

          // If punch is after checkIn
          if (elapsed.isNegative) {
            continue;
          }

          // If punch is within cooldown of checkIn, ignore
          if (elapsed.inMinutes < _cooldownMinutes) {
            continue;
          }

          // Get shift for the day of checkIn
          final workDate = DateTime(
            currentOpenRecord.checkIn.year,
            currentOpenRecord.checkIn.month,
            currentOpenRecord.checkIn.day,
          );
          final shift = provider.getShiftForDate(emp, workDate);
          final isOvernight = shift.isOvernightForDate(workDate);

          // Maximum reasonable shift span:
          // Standard shift: max 18 hours.
          // Overnight / 24h shift: max 30 hours.
          final maxAllowedHours = isOvernight ? 32 : 18;

          if (elapsed.inHours <= maxAllowedHours) {
            // This punch pairs as Clock Out!
            final completedRecord = currentOpenRecord.copyWith(
              checkOut: pTime,
              employeeId: emp.id,
            );

            // Update in list
            final idx = existingRecords.indexOf(currentOpenRecord);
            if (idx != -1) {
              existingRecords[idx] = completedRecord;
            }

            if (firebase.isAvailable) {
              try {
                await firebase.saveRecord(emp.id, completedRecord);
                recordsUpdated++;
                details.add(
                    '${emp.name}: Clock Out at ${pTime.toString().substring(0, 16)} (${completedRecord.durationString})');
              } catch (e) {
                debugPrint('Error updating record: $e');
              }
            }

            currentOpenRecord = null; // Session closed!
          } else {
            // The open session was too long ago (> 32 hours), meaning the employee
            // forgot to punch out yesterday. Do not merge with this new punch!
            // Start a new Clock In session instead:
            currentOpenRecord = null;

            final newRec = AttendanceRecord(
              checkIn: pTime,
              checkOut: null,
              employeeId: emp.id,
            );
            currentOpenRecord = newRec;
            existingRecords.add(newRec);

            if (firebase.isAvailable) {
              try {
                await firebase.saveRecord(emp.id, newRec);
                newRecordsCreated++;
                details.add('${emp.name}: New Clock In at ${pTime.toString().substring(0, 16)}');
              } catch (e) {
                debugPrint('Error saving record: $e');
              }
            }
          }
        }
      }
    }

    provider.recalculateAllStats();

    return ZkSyncSummary(
      success: true,
      totalPunchesFetched: punches.length,
      newRecordsCreated: newRecordsCreated,
      recordsUpdated: recordsUpdated,
      syncTime: DateTime.now(),
      message: 'Synced ${punches.length} punches ($newRecordsCreated created, $recordsUpdated completed).',
      details: details,
    );
  }

  /// Match device User ID with CompanyEmployee
  CompanyEmployee? _findMatchingEmployee(String deviceUserId, List<CompanyEmployee> employees) {
    final cleanId = deviceUserId.trim().toLowerCase();

    // 1. Direct ID match
    for (var emp in employees) {
      if (emp.id.trim().toLowerCase() == cleanId) return emp;
    }

    // 2. Numeric match (e.g. device has "1" or "001", emp has "emp_1" or "1")
    final numericOnly = cleanId.replaceAll(RegExp(r'[^0-9]'), '');
    if (numericOnly.isNotEmpty) {
      final parsedNum = int.tryParse(numericOnly);
      for (var emp in employees) {
        final empNum = emp.id.replaceAll(RegExp(r'[^0-9]'), '');
        if (empNum.isNotEmpty && int.tryParse(empNum) == parsedNum) {
          return emp;
        }
      }
    }

    // 3. Name match
    for (var emp in employees) {
      if (emp.name.trim().toLowerCase() == cleanId) return emp;
    }

    return null;
  }

  void _finishSync(ZkSyncSummary summary) async {
    _isSyncing = false;
    _lastSyncTime = summary.syncTime;
    _lastSyncStatus = summary.message;
    _lastSummary = summary;
    _addLog(summary.message);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('zk_last_sync_ms', _lastSyncTime!.millisecondsSinceEpoch);
    await prefs.setString('zk_last_sync_status', _lastSyncStatus);

    notifyListeners();
  }

  void _addLog(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    _syncLogs.insert(0, '[$timestamp] $message');
    if (_syncLogs.length > 100) {
      _syncLogs.removeLast();
    }
  }

  void startAutoSync(AttendanceProvider provider, FirebaseService firebase) {
    stopAutoSync();
    _autoSyncTimer = Timer.periodic(
      Duration(minutes: _autoSyncIntervalMinutes),
      (_) async {
        if (!_isSyncing) {
          debugPrint('Auto-syncing ZKTeco punches...');
          await syncAttendances(provider: provider, firebase: firebase);
        }
      },
    );
    debugPrint('ZKTeco auto-sync scheduled every $_autoSyncIntervalMinutes minutes.');
  }

  void stopAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
  }

  @override
  void dispose() {
    stopAutoSync();
    super.dispose();
  }
}
