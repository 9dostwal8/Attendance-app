import 'dart:async';
import 'dart:convert';
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

  // Multi-Device Configuration
  List<ZkDeviceConfig> _devices = [];

  // Global Settings
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
  AttendanceProvider? _cachedProvider;
  FirebaseService? _cachedFirebase;

  // Getters
  List<ZkDeviceConfig> get devices => List.unmodifiable(_devices);
  List<ZkDeviceConfig> get enabledDevices => _devices.where((d) => d.isEnabled).toList();

  // Backward compatibility getters (referring to the first device)
  String get deviceIp => _devices.isNotEmpty ? _devices.first.ip : '192.168.1.201';
  int get devicePort => _devices.isNotEmpty ? _devices.first.port : 4370;
  int get devicePassword => _devices.isNotEmpty ? _devices.first.password : 0;

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

  /// Initialize service and load saved devices and preferences
  Future<void> init(AttendanceProvider? provider, FirebaseService? firebase) async {
    _cachedProvider = provider;
    _cachedFirebase = firebase;
    try {
      final prefs = await SharedPreferences.getInstance();
      _autoSyncEnabled = prefs.getBool('zk_auto_sync') ?? false;
      _autoSyncIntervalMinutes = prefs.getInt('zk_auto_sync_interval') ?? 15;
      _cooldownMinutes = prefs.getInt('zk_cooldown_minutes') ?? 3;

      final lastSyncMs = prefs.getInt('zk_last_sync_ms');
      if (lastSyncMs != null) {
        _lastSyncTime = DateTime.fromMillisecondsSinceEpoch(lastSyncMs);
        _lastSyncStatus = prefs.getString('zk_last_sync_status') ?? 'Idle';
      }

      await _loadDevicesFromPrefs(prefs);

      if (_autoSyncEnabled && provider != null && firebase != null) {
        startAutoSync(provider, firebase);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing ZkTecoService: $e');
    }
  }

  Future<void> _loadDevicesFromPrefs(SharedPreferences prefs) async {
    final jsonStr = prefs.getString('zk_devices_list');
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final list = jsonDecode(jsonStr) as List<dynamic>;
        _devices = list
            .map((item) => ZkDeviceConfig.fromMap(item as Map<String, dynamic>))
            .toList();
      } catch (e) {
        debugPrint('Error loading zk_devices_list: $e');
      }
    }

    if (_devices.isEmpty) {
      // Migrate from legacy single device keys if available
      final legacyIp = prefs.getString('zk_device_ip') ?? '192.168.1.201';
      final legacyPort = prefs.getInt('zk_device_port') ?? 4370;
      final legacyPassword = prefs.getInt('zk_device_password') ?? 0;
      _devices = [
        ZkDeviceConfig(
          id: 'dev_${DateTime.now().millisecondsSinceEpoch}',
          name: 'Main Terminal',
          ip: legacyIp,
          port: legacyPort,
          password: legacyPassword,
          isEnabled: true,
        ),
      ];
      await _saveDevicesToPrefs();
    }
  }

  Future<void> _saveDevicesToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(_devices.map((d) => d.toMap()).toList());
      await prefs.setString('zk_devices_list', jsonStr);

      if (_devices.isNotEmpty) {
        final first = _devices.first;
        await prefs.setString('zk_device_ip', first.ip);
        await prefs.setInt('zk_device_port', first.port);
        await prefs.setInt('zk_device_password', first.password);
      }
    } catch (e) {
      debugPrint('Error saving zk_devices_list: $e');
    }
  }

  /// Add a new ZKTeco device
  Future<void> addDevice(ZkDeviceConfig device) async {
    _devices.add(device);
    await _saveDevicesToPrefs();
    _addLog('Added new device: "${device.name}" (${device.ip}:${device.port})');
    notifyListeners();
  }

  /// Update an existing ZKTeco device
  Future<void> updateDevice(ZkDeviceConfig device) async {
    final idx = _devices.indexWhere((d) => d.id == device.id);
    if (idx != -1) {
      _devices[idx] = device;
      await _saveDevicesToPrefs();
      _addLog('Updated device: "${device.name}" (${device.ip}:${device.port})');
      notifyListeners();
    }
  }

  /// Delete a device by ID
  Future<void> deleteDevice(String deviceId) async {
    final idx = _devices.indexWhere((d) => d.id == deviceId);
    if (idx != -1) {
      final name = _devices[idx].name;
      _devices.removeAt(idx);
      await _saveDevicesToPrefs();
      _addLog('Deleted device: "$name"');
      notifyListeners();
    }
  }

  /// Toggle device enable status
  Future<void> toggleDevice(String deviceId, bool isEnabled) async {
    final idx = _devices.indexWhere((d) => d.id == deviceId);
    if (idx != -1) {
      _devices[idx] = _devices[idx].copyWith(isEnabled: isEnabled);
      await _saveDevicesToPrefs();
      _addLog('Device "${_devices[idx].name}" is now ${isEnabled ? "enabled" : "disabled"}.');
      notifyListeners();
    }
  }

  /// Save global settings
  Future<void> saveSettings({
    String? ip,
    int? port,
    int? password,
    required bool autoSync,
    required int intervalMinutes,
    required int cooldownMinutes,
    AttendanceProvider? provider,
    FirebaseService? firebase,
  }) async {
    _autoSyncEnabled = autoSync;
    _autoSyncIntervalMinutes = intervalMinutes;
    _cooldownMinutes = cooldownMinutes;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('zk_auto_sync', _autoSyncEnabled);
    await prefs.setInt('zk_auto_sync_interval', _autoSyncIntervalMinutes);
    await prefs.setInt('zk_cooldown_minutes', _cooldownMinutes);

    if (ip != null && ip.trim().isNotEmpty) {
      if (_devices.isNotEmpty) {
        _devices[0] = _devices[0].copyWith(
          ip: ip.trim(),
          port: port ?? _devices[0].port,
          password: password ?? _devices[0].password,
        );
      } else {
        _devices.add(ZkDeviceConfig(
          id: 'dev_${DateTime.now().millisecondsSinceEpoch}',
          name: 'Main Terminal',
          ip: ip.trim(),
          port: port ?? 4370,
          password: password ?? 0,
        ));
      }
      await _saveDevicesToPrefs();
    }

    final p = provider ?? _cachedProvider;
    final f = firebase ?? _cachedFirebase;

    if (_autoSyncEnabled && p != null && f != null) {
      startAutoSync(p, f);
    } else {
      stopAutoSync();
    }

    notifyListeners();
  }

  /// Test connection to a specific device
  Future<ZkDeviceInfo> testDeviceConnection(ZkDeviceConfig device) async {
    _isConnecting = true;
    notifyListeners();

    try {
      _addLog('Testing connection to [${device.name}] (${device.ip}:${device.port})...');
      final info = await _driver.testConnection(
        ip: device.ip,
        port: device.port,
        password: device.password,
        timeoutSeconds: 8,
      );

      final idx = _devices.indexWhere((d) => d.id == device.id);
      if (idx != -1) {
        _devices[idx] = _devices[idx].copyWith(cachedInfo: info);
      }
      _cachedDeviceInfo = info;

      if (info.isConnected) {
        _addLog('✓ Connected to [${device.name}]: ${info.deviceName} (SN: ${info.serialNumber})');
      } else {
        _addLog('✗ Connection failed to [${device.name}]: ${info.errorMessage ?? "Unreachable"}');
      }
      return info;
    } catch (e) {
      final info = ZkDeviceInfo(
        isConnected: false,
        ip: device.ip,
        port: device.port,
        errorMessage: e.toString(),
      );
      final idx = _devices.indexWhere((d) => d.id == device.id);
      if (idx != -1) {
        _devices[idx] = _devices[idx].copyWith(cachedInfo: info);
      }
      _cachedDeviceInfo = info;
      _addLog('✗ Connection error for [${device.name}]: $e');
      return info;
    } finally {
      _isConnecting = false;
      notifyListeners();
    }
  }

  /// Test connection to all devices
  Future<Map<String, ZkDeviceInfo>> testAllConnections() async {
    _isConnecting = true;
    notifyListeners();

    final results = <String, ZkDeviceInfo>{};
    for (var dev in _devices) {
      try {
        _addLog('Testing [${dev.name}] (${dev.ip})...');
        final info = await _driver.testConnection(
          ip: dev.ip,
          port: dev.port,
          password: dev.password,
          timeoutSeconds: 6,
        );
        results[dev.id] = info;
        final idx = _devices.indexWhere((d) => d.id == dev.id);
        if (idx != -1) {
          _devices[idx] = _devices[idx].copyWith(cachedInfo: info);
        }
        if (info.isConnected) {
          _addLog('✓ [${dev.name}] Online: ${info.deviceName} (${info.serialNumber})');
        } else {
          _addLog('✗ [${dev.name}] Offline: ${info.errorMessage ?? "Unreachable"}');
        }
      } catch (e) {
        final errInfo = ZkDeviceInfo(
          isConnected: false,
          ip: dev.ip,
          port: dev.port,
          errorMessage: e.toString(),
        );
        results[dev.id] = errInfo;
        final idx = _devices.indexWhere((d) => d.id == dev.id);
        if (idx != -1) {
          _devices[idx] = _devices[idx].copyWith(cachedInfo: errInfo);
        }
        _addLog('✗ [${dev.name}] Error: $e');
      }
    }

    _isConnecting = false;
    notifyListeners();
    return results;
  }

  /// Backward-compatible testConnection
  Future<ZkDeviceInfo> testConnection({String? ip, int? port, int? password}) async {
    final targetIp = ip ?? deviceIp;
    final targetPort = port ?? devicePort;
    final targetPassword = password ?? devicePassword;

    final matchingDev = _devices.cast<ZkDeviceConfig?>().firstWhere(
          (d) => d != null && d.ip == targetIp,
          orElse: () => null,
        );

    final dev = matchingDev ??
        ZkDeviceConfig(
          id: 'temp',
          name: 'Device ($targetIp)',
          ip: targetIp,
          port: targetPort,
          password: targetPassword,
        );

    return testDeviceConnection(dev);
  }

  /// Fetch users registered on a specific device (or first device)
  Future<List<ZkDeviceUser>> fetchUsers({ZkDeviceConfig? device}) async {
    final target = device ?? (_devices.isNotEmpty ? _devices.first : null);
    if (target == null) {
      throw Exception('No ZKTeco device configured.');
    }

    try {
      _addLog('Fetching users from [${target.name}] (${target.ip})...');
      final users = await _driver.getUsers(
        ip: target.ip,
        port: target.port,
        password: target.password,
      );
      _cachedUsers = users;
      _addLog('Found ${users.length} users registered on [${target.name}].');
      notifyListeners();
      return users;
    } catch (e) {
      _addLog('Failed to fetch users from [${target.name}]: $e');
      rethrow;
    }
  }

  /// Sync punches from a single specific device
  Future<ZkSyncSummary> syncDevice(
    ZkDeviceConfig device, {
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
    final defaultFrom = device.lastSyncTime != null
        ? device.lastSyncTime!.subtract(const Duration(days: 7))
        : DateTime(now.year, now.month - 2, 1);
    final targetFrom = fromDate ?? defaultFrom;
    final targetTo = toDate ?? now;

    _addLog('Syncing punches from [${device.name}] (${device.ip}:${device.port})...');

    try {
      final punches = await _driver.getAttendanceLogs(
        ip: device.ip,
        port: device.port,
        password: device.password,
        fromDate: targetFrom,
        toDate: targetTo,
      );

      _addLog('[${device.name}] Fetched ${punches.length} raw punches.');

      final idx = _devices.indexWhere((d) => d.id == device.id);
      if (idx != -1) {
        _devices[idx] = _devices[idx].copyWith(
          lastSyncTime: now,
          lastSyncStatus: 'Fetched ${punches.length} logs at ${now.toString().substring(11, 16)}',
        );
      }
      await _saveDevicesToPrefs();

      if (punches.isEmpty) {
        final summary = ZkSyncSummary(
          success: true,
          totalPunchesFetched: 0,
          newRecordsCreated: 0,
          recordsUpdated: 0,
          syncTime: now,
          message: '[${device.name}] Connected. No new attendance logs found.',
        );
        _finishSync(summary);
        return summary;
      }

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
        message: '[${device.name}] Sync failed: $e',
      );
      final idx = _devices.indexWhere((d) => d.id == device.id);
      if (idx != -1) {
        _devices[idx] = _devices[idx].copyWith(
          lastSyncStatus: 'Failed: $e',
        );
      }
      await _saveDevicesToPrefs();
      _finishSync(summary);
      return summary;
    }
  }

  /// Sync attendance punches across ALL enabled ZKTeco devices simultaneously
  Future<ZkSyncSummary> syncAllDevices({
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

    final activeDevices = enabledDevices;
    if (activeDevices.isEmpty) {
      return ZkSyncSummary(
        success: false,
        syncTime: DateTime.now(),
        message: 'No enabled ZKTeco devices configured.',
      );
    }

    _isSyncing = true;
    notifyListeners();

    final now = DateTime.now();
    final defaultFrom = _lastSyncTime != null
        ? _lastSyncTime!.subtract(const Duration(days: 7))
        : DateTime(now.year, now.month - 2, 1);
    final targetFrom = fromDate ?? defaultFrom;
    final targetTo = toDate ?? now;

    _addLog('Starting multi-device sync across ${activeDevices.length} active devices...');

    final allPunches = <ZkRawPunch>[];
    final successDeviceNames = <String>[];
    final failedDeviceNames = <String>[];

    for (var dev in activeDevices) {
      try {
        _addLog('[${dev.name}] Fetching punches from ${dev.ip}:${dev.port}...');
        final punches = await _driver.getAttendanceLogs(
          ip: dev.ip,
          port: dev.port,
          password: dev.password,
          fromDate: targetFrom,
          toDate: targetTo,
        );

        allPunches.addAll(punches);
        successDeviceNames.add(dev.name);

        final idx = _devices.indexWhere((d) => d.id == dev.id);
        if (idx != -1) {
          _devices[idx] = _devices[idx].copyWith(
            lastSyncTime: now,
            lastSyncStatus: 'Fetched ${punches.length} logs at ${now.toString().substring(11, 16)}',
          );
        }
        _addLog('[${dev.name}] ✓ Fetched ${punches.length} punches.');
      } catch (e) {
        failedDeviceNames.add('${dev.name} ($e)');
        final idx = _devices.indexWhere((d) => d.id == dev.id);
        if (idx != -1) {
          _devices[idx] = _devices[idx].copyWith(
            lastSyncStatus: 'Failed: $e',
          );
        }
        _addLog('[${dev.name}] ✗ Fetch error: $e');
      }
    }

    await _saveDevicesToPrefs();

    if (allPunches.isEmpty) {
      final summary = ZkSyncSummary(
        success: failedDeviceNames.isEmpty,
        totalPunchesFetched: 0,
        newRecordsCreated: 0,
        recordsUpdated: 0,
        syncTime: now,
        message: failedDeviceNames.isEmpty
            ? 'Synced ${successDeviceNames.length} devices. No new punches found.'
            : 'Synced ${successDeviceNames.length} devices. Failed: ${failedDeviceNames.join(", ")}',
      );
      _finishSync(summary);
      return summary;
    }

    _addLog('Aggregated ${allPunches.length} total punches across ${successDeviceNames.length} devices. Running smart pairing engine...');

    final summary = await _pairAndSavePunches(
      punches: allPunches,
      provider: provider,
      firebase: firebase,
    );

    _finishSync(summary);
    return summary;
  }

  /// Backward-compatible alias for syncAllDevices
  Future<ZkSyncSummary> syncAttendances({
    required AttendanceProvider provider,
    required FirebaseService firebase,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    return syncAllDevices(
      provider: provider,
      firebase: firebase,
      fromDate: fromDate,
      toDate: toDate,
    );
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

          provider.upsertRecordLocally(newRec);

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

          if (elapsed.isNegative) {
            continue;
          }

          if (elapsed.inMinutes < _cooldownMinutes) {
            continue;
          }

          final workDate = DateTime(
            currentOpenRecord.checkIn.year,
            currentOpenRecord.checkIn.month,
            currentOpenRecord.checkIn.day,
          );
          final shift = provider.getShiftForDate(emp, workDate);
          final isOvernight = shift.isOvernightForDate(workDate);
          final isSpecial = shift.isSpecialShiftForDate(workDate);

          // Pairing window: Special shifts (12h or 24h) pair up to 48 hours; overnight 32h; standard 18h
          final maxAllowedHours = isSpecial ? 48 : (isOvernight ? 32 : 18);

          if (elapsed.inHours <= maxAllowedHours) {
            // Clock Out
            final completedRecord = currentOpenRecord.copyWith(
              checkOut: pTime,
              employeeId: emp.id,
            );

            final idx = existingRecords.indexOf(currentOpenRecord);
            if (idx != -1) {
              existingRecords[idx] = completedRecord;
            }
            provider.upsertRecordLocally(completedRecord);

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

            currentOpenRecord = null;
          } else {
            // Expired open session -> new Clock In
            currentOpenRecord = null;

            final newRec = AttendanceRecord(
              checkIn: pTime,
              checkOut: null,
              employeeId: emp.id,
            );
            currentOpenRecord = newRec;
            existingRecords.add(newRec);
            provider.upsertRecordLocally(newRec);

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

  CompanyEmployee? _findMatchingEmployee(String deviceUserId, List<CompanyEmployee> employees) {
    final cleanId = deviceUserId.trim().toLowerCase();

    for (var emp in employees) {
      if (emp.id.trim().toLowerCase() == cleanId) return emp;
    }

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
          debugPrint('Auto-syncing all ZKTeco devices...');
          await syncAllDevices(provider: provider, firebase: firebase);
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
