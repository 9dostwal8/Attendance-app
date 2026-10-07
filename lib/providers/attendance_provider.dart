import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:geolocator/geolocator.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/attendance_record.dart';
import '../models/hr_models.dart';
import '../models/request_model.dart';
import '../models/translation_keys.dart';
import '../services/firebase_service.dart';
import '../models/chat_message.dart';
import '../models/app_notification.dart';
import '../services/web_notification_helper.dart';
import '../widgets/web_notification_toast.dart';
import '../main.dart';
import '../screens/chat_room_screen.dart';
import '../services/face_recognition_service.dart';
import '../services/fcm_push_service.dart';

class AttendanceProvider with ChangeNotifier {
  // User Profile Data
  String _userName = 'Jane Smith';
  String _userTitle = 'HR Manager';
  String _employeeId =
      'emp_2'; // Aligned to emp_2 (HR Manager) to match Firestore seed
  String _email = 'jane.smith@company.com';
  String _department = 'Human Resources';
  String _position = 'HR Manager';
  String? _avatarPath;

  String _role = 'hr';

  final FirebaseService _firebaseService = FirebaseService();
  final Map<String, List<Request>> _allRequestsMap = {};
  String _currentLanguage = 'en';
  String _themePreference = 'light';
  bool _isLoading = false;
  bool _isLoggedIn = false;
  final List<StreamSubscription> _subscriptions = [];

  bool get isLoggedIn => _isLoggedIn;

  void _syncCurrentEmployeeInfo() {
    if (_employees.isNotEmpty && _employeeId.isNotEmpty) {
      CompanyEmployee? match;
      for (var e in _employees) {
        if (e.id == _employeeId) {
          match = e;
          break;
        }
      }
      if (match != null) {
        _userName = match.name;
        _userTitle = match.position;
        _position = match.position;
        _email = match.email;
        _role = match.role;
        _department = match.structureId ?? match.position;
        if (match.avatarUrl != null && match.avatarUrl!.isNotEmpty) {
          _avatarPath = match.avatarUrl;
        }
        final langPref = match.languagePreference;
        if (langPref.isNotEmpty && _currentLanguage != langPref) {
          _currentLanguage = langPref;
          SharedPreferences.getInstance().then((prefs) {
            prefs.setString('app_language', langPref);
          });
        }
        final themePref = match.themePreference;
        if (themePref.isNotEmpty && _themePreference != themePref) {
          _themePreference = themePref;
          SharedPreferences.getInstance().then((prefs) {
            prefs.setString('app_theme_preference', themePref);
          });
        }
        if (_isLoggedIn) {
          _saveAuthSession(
            true,
            match.id,
            name: match.name,
            email: match.email,
            position: match.position,
            role: match.role,
            department: match.structureId ?? match.position,
            avatarUrl: match.avatarUrl,
            themePreference: match.themePreference,
          );
        }
      }
      // Note: If match is null (e.g. employee list still streaming from Firestore),
      // we purposefully preserve _employeeId so it is not hijacked or replaced.
    }
  }

  Future<void> _saveAuthSession(
    bool loggedIn,
    String empId, {
    String? name,
    String? email,
    String? position,
    String? role,
    String? department,
    String? avatarUrl,
    String? themePreference,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', loggedIn);
      await prefs.setString('app_language', _currentLanguage);
      await prefs.setString('app_theme_preference', _themePreference);
      if (loggedIn) {
        await prefs.setString('loggedInEmployeeId', empId);
        if (name != null) await prefs.setString('loggedInUserName', name);
        if (email != null) await prefs.setString('loggedInEmail', email);
        if (position != null) {
          await prefs.setString('loggedInPosition', position);
        }
        if (role != null) {
          await prefs.setString('loggedInRole', role);
        }
        if (department != null) {
          await prefs.setString('loggedInDepartment', department);
        }
        if (avatarUrl != null) {
          await prefs.setString('user_avatar_$empId', avatarUrl);
        }
        if (themePreference != null && themePreference.isNotEmpty) {
          await prefs.setString('app_theme_preference', themePreference);
          _themePreference = themePreference;
        }
      } else {
        await prefs.remove('loggedInEmployeeId');
        await prefs.remove('loggedInUserName');
        await prefs.remove('loggedInEmail');
        await prefs.remove('loggedInPosition');
        await prefs.remove('loggedInRole');
        await prefs.remove('loggedInDepartment');
      }
    } catch (e) {
      debugPrint('Error saving auth session: $e');
    }
  }

  Future<void> _loadAuthSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLang = prefs.getString('app_language');
      if (savedLang != null && savedLang.isNotEmpty) {
        _currentLanguage = savedLang;
      }
      final savedTheme = prefs.getString('app_theme_preference');
      if (savedTheme != null && savedTheme.isNotEmpty) {
        _themePreference = savedTheme;
      }
      final isLoggedInSaved = prefs.getBool('isLoggedIn') ?? false;
      final savedEmployeeId = prefs.getString('loggedInEmployeeId');
      final savedName = prefs.getString('loggedInUserName');
      final savedEmail = prefs.getString('loggedInEmail');
      final savedPosition = prefs.getString('loggedInPosition');
      final savedRole = prefs.getString('loggedInRole');
      final savedDepartment = prefs.getString('loggedInDepartment');

      if (isLoggedInSaved) {
        _isLoggedIn = true;
        if (savedEmployeeId != null && savedEmployeeId.isNotEmpty) {
          _employeeId = savedEmployeeId;
        }
        if (savedName != null && savedName.isNotEmpty) {
          _userName = savedName;
        }
        if (savedEmail != null && savedEmail.isNotEmpty) {
          _email = savedEmail;
        }
        if (savedPosition != null && savedPosition.isNotEmpty) {
          _position = savedPosition;
          _userTitle = savedPosition;
        }
        if (savedRole != null && savedRole.isNotEmpty) {
          _role = savedRole;
        }
        if (savedDepartment != null && savedDepartment.isNotEmpty) {
          _department = savedDepartment;
        }
        final savedAvatar = prefs.getString('user_avatar_$_employeeId');
        if (savedAvatar != null && savedAvatar.isNotEmpty) {
          _avatarPath = savedAvatar;
        }
        _syncCurrentEmployeeInfo();
        notifyListeners();
      } else if ((savedLang != null && savedLang.isNotEmpty) || (savedTheme != null && savedTheme.isNotEmpty)) {
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading auth session: $e');
    }
  }

  Future<bool> login({
    required String identifier,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final input = identifier.trim().toLowerCase();
      final matchIndex = _employees.indexWhere(
        (e) =>
            (e.email.toLowerCase() == input ||
                e.id.toLowerCase() == input ||
                e.name.toLowerCase() == input) &&
            (e.password == null || e.password == password),
      );

      if (matchIndex != -1) {
        final match = _employees[matchIndex];
        _employeeId = match.id;
        _userName = match.name;
        _userTitle = match.position;
        _position = match.position;
        _email = match.email;
        if (match.languagePreference.isNotEmpty) {
          _currentLanguage = match.languagePreference;
        }
        if (match.themePreference.isNotEmpty) {
          _themePreference = match.themePreference;
        }
        _role = match.role;
        _department = match.structureId ?? match.position;
        if (match.avatarUrl != null && match.avatarUrl!.isNotEmpty) {
          _avatarPath = match.avatarUrl;
        }
        _isLoggedIn = true;
        _isLoading = false;
        await _saveAuthSession(
          true,
          _employeeId,
          name: _userName,
          email: _email,
          position: _position,
          role: match.role,
          department: match.structureId ?? match.position,
          avatarUrl: match.avatarUrl,
          themePreference: match.themePreference,
        );

        _records.clear();
        await _setupFirestoreListeners();
        recalculateAllStats();
        notifyListeners();
        return true;
      }

      // If no exact match, login fails
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('Login error: $e');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> loginAsEmployee(CompanyEmployee employee) async {
    _employeeId = employee.id;
    _userName = employee.name;
    _userTitle = employee.position;
    _position = employee.position;
    _email = employee.email;
    _role = employee.role;
    _department = employee.structureId ?? employee.position;
    if (employee.avatarUrl != null && employee.avatarUrl!.isNotEmpty) {
      _avatarPath = employee.avatarUrl;
    }
    if (employee.languagePreference.isNotEmpty) {
      _currentLanguage = employee.languagePreference;
    }
    if (employee.themePreference.isNotEmpty) {
      _themePreference = employee.themePreference;
    }
    _isLoggedIn = true;
    await _saveAuthSession(
      true,
      _employeeId,
      name: _userName,
      email: _email,
      position: _position,
      role: employee.role,
      department: employee.structureId ?? employee.position,
      avatarUrl: employee.avatarUrl,
      themePreference: employee.themePreference,
    );

    _records.clear();
    await _setupFirestoreListeners();
    recalculateAllStats();
    notifyListeners();
  }

  void logout() {
    _isLoggedIn = false;
    _saveAuthSession(false, '');
    notifyListeners();
  }

  // Chat state
  final Map<String, List<ChatMessage>> _chatMessagesMap = {};
  final Map<String, StreamSubscription> _chatSubscriptionsMap = {};

  // In-app Notifications
  List<AppNotification>? _notifications;
  List<AppNotification> get notifications => _notifications ??= [];

  int get unreadNotificationCount {
    _notifications ??= [];
    int count = _notifications!.where((n) => !n.isRead).length;
    final myId = _employeeId.trim().toLowerCase();
    if (myId.isNotEmpty) {
      for (var messages in _chatMessagesMap.values) {
        if (messages.any((m) => m.receiverId.trim().toLowerCase() == myId && !m.isRead)) {
          count++;
        }
      }
    }
    return count;
  }

  void markNotificationAsRead(String id) {
    _notifications ??= [];
    final index = _notifications!.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notifications![index].isRead = true;
      notifyListeners();
    }
  }

  void markAllNotificationsAsRead() {
    _notifications ??= [];
    for (var n in _notifications!) {
      n.isRead = true;
    }
    notifyListeners();
  }

  bool get hasUnreadMessages {
    final myId = _employeeId.trim().toLowerCase();
    if (myId.isEmpty) return false;
    for (var messages in _chatMessagesMap.values) {
      if (messages.any((m) => m.receiverId.trim().toLowerCase() == myId && !m.isRead)) {
        return true;
      }
    }
    return false;
  }

  int getUnreadCountForContact(dynamic contactId) {
    final cId = contactId.toString().trim().toLowerCase();
    final myId = _employeeId.trim().toLowerCase();
    if (cId.isEmpty || myId.isEmpty) return 0;
    
    // Look up in chat messages map by exact key or case-insensitive match
    List<ChatMessage>? messages = _chatMessagesMap[contactId.toString()];
    if (messages == null) {
      for (var entry in _chatMessagesMap.entries) {
        if (entry.key.trim().toLowerCase() == cId) {
          messages = entry.value;
          break;
        }
      }
    }
    if (messages == null) return 0;
    return messages.where((m) => m.receiverId.trim().toLowerCase() == myId && !m.isRead).length;
  }

  // Clock State
  bool _isClockedIn = false;
  AttendanceRecord? _activeRecord;
  final List<AttendanceRecord> _records = [];

  final List<AttendanceRecord> _allCompanyRecords = [];
  final List<Request> _allCompanyRequests = [];

  // Selected Month for Payroll/History
  DateTime _selectedMonth = DateTime.now();

  // Statistics Baseline (from screenshots)
  double _weeklyHours = 38.5;
  double _monthlyEarnings = 3240.0;
  int _daysWorked = 18;
  double _overtimeHours = 4.5;
  double _monthlyPenalties = 0.0;
  double _incrementalSalary = 0.0;
  double _decrementalSalary = 0.0;
  double _salaryCalcByDay = 0.0;
  double _overtimeValue = 0.0;
  double _attendanceDeficit = 0.0;
  double _attendanceDeficitHours = 0.0;
  double _hourlyRate = 0.0;

  double _foodAllowance = 0.0;
  double _transportationAllowance = 0.0;
  double _otherAllowance = 0.0;

  // HR System Lists
  final List<OrgStructure> _structures = [];
  final List<WorkShift> _shifts = [];
  final List<EmployeeGroup> _groups = [];
  final List<CompanyEmployee> _employees = [];
  final List<Holiday> _holidays = [];
  final List<WorkLocation> _locations = [];
  final List<PayrollAdjustment> _payrollAdjustments = [];
  CompanyProfile? _companyProfile;

  // Getters
  List<PayrollAdjustment> get payrollAdjustments => _payrollAdjustments;
  String get userName => _userName;
  String get userTitle => _userTitle;
  String get employeeId => _employeeId;
  String get email => _email;
  String get department {
    if (_department.isNotEmpty) {
      final struct = _structures.where((s) => s.id == _department).firstOrNull;
      if (struct != null) return struct.name;
      if (!_department.startsWith('struct_')) return _department;
    }
    final emp = currentEmployee;
    if (emp?.structureId != null && emp!.structureId!.isNotEmpty) {
      final struct = _structures.where((s) => s.id == emp.structureId).firstOrNull;
      if (struct != null) return struct.name;
    }
    return _position.isNotEmpty ? _position : 'General';
  }
  String get position => _position;
  String? get avatarPath => _avatarPath ?? currentEmployee?.avatarUrl;

  bool get isClockedIn => _isClockedIn;
  AttendanceRecord? get activeRecord => _activeRecord;
  List<AttendanceRecord> get records => _records;
  List<AttendanceRecord> get allCompanyRecords => _allCompanyRecords;
  List<Request> get allCompanyRequests => _allCompanyRequests;
  DateTime get selectedMonth => _selectedMonth;

  void setSelectedMonth(DateTime month) {
    _selectedMonth = month;
    recalculateAllStats();
    notifyListeners();
  }

  double get weeklyHours => _weeklyHours;
  double get monthlyEarnings => _monthlyEarnings;
  int get daysWorked => _daysWorked;
  double get overtimeHours => _overtimeHours;
  double get monthlyPenalties => _monthlyPenalties;

  double get incrementalSalary => _incrementalSalary;
  double get decrementalSalary => _decrementalSalary;
  double get salaryCalcByDay => _salaryCalcByDay;
  double get overtimeValue => _overtimeValue;
  double get attendanceDeficit => _attendanceDeficit;
  double get attendanceDeficitHours => _attendanceDeficitHours;
  double get hourlyRate => _hourlyRate;
  double get foodAllowance => _foodAllowance;
  double get transportationAllowance => _transportationAllowance;
  double get otherAllowance => _otherAllowance;

  List<OrgStructure> get structures => _structures;
  List<WorkShift> get shifts => _shifts;
  List<EmployeeGroup> get groups => _groups;
  List<CompanyEmployee> get employees => _employees;
  List<Holiday> get holidays => _holidays;
  List<WorkLocation> get locations => _locations;
  List<Request> get requests => _allRequestsMap[_employeeId] ?? [];
  String get currentLanguage => _currentLanguage;
  bool get isLoading => _isLoading;
  FirebaseService get firebaseService => _firebaseService;
  CompanyProfile? get companyProfile => _companyProfile;

  CompanyEmployee? get currentEmployee {
    for (var e in _employees) {
      if (e.id == _employeeId) return e;
    }
    if (_isLoggedIn && _employeeId.isNotEmpty) {
      return CompanyEmployee(
        id: _employeeId,
        name: _userName,
        email: _email,
        position: _position,
        role: _role,
        structureId: _department,
        avatarUrl: _avatarPath,
        themePreference: _themePreference,
        languagePreference: _currentLanguage,
      );
    }
    return null;
  }

  List<CompanyEmployee> getSubordinates(CompanyEmployee supervisor) {
    List<CompanyEmployee> subordinates = [];
    final Set<String> subordinateIds = {};

    // Direct supervised structures
    final supervisedStructures = _structures
        .where((s) => s.supervisorId == supervisor.id)
        .map((s) => s.id)
        .toList();

    for (var structId in supervisedStructures) {
      final emps = _employees.where(
        (e) => e.id != supervisor.id && e.structureId == structId,
      );
      for (var e in emps) {
        if (subordinateIds.add(e.id)) {
          subordinates.add(e);
        }
      }
    }

    // Co-workers in same structure if supervisor is just regular employee (wait, only supervisors)
    if (supervisor.structureId != null && supervisor.structureId!.isNotEmpty) {
      final emps = _employees.where(
        (e) =>
            e.id != supervisor.id &&
            e.structureId == supervisor.structureId &&
            e.role == 'employee',
      );
      for (var e in emps) {
        if (subordinateIds.add(e.id)) {
          subordinates.add(e);
        }
      }
    }

    return subordinates;
  }

  bool get canEditCompanyInfo {
    final emp = currentEmployee;
    if (emp == null) return false;
    if (emp.role == 'hr' || emp.role == 'admin') return true;

    // Check group permission
    final groupId = getGroupIdForDate(emp, DateTime.now());
    final group = _groups.firstWhere(
      (g) => g.id == groupId,
      orElse: () => EmployeeGroup(id: '', name: '', shiftId: ''),
    );
    return group.canEditCompanyInfo;
  }

  /// Whether the logged-in user is an HR manager/admin who can register/delete Face ID
  bool get isHRManager {
    final emp = currentEmployee;
    if (emp == null) return false;
    final role = emp.role.toLowerCase().trim();
    if (role == 'hr' || role == 'admin') return true;
    final pos = emp.position.toLowerCase();
    if (pos.contains('hr') || pos.contains('human resource')) return true;
    return canEditCompanyInfo;
  }

  bool get isDarkMode {
    if (currentEmployee != null && currentEmployee!.themePreference.isNotEmpty) {
      return currentEmployee!.themePreference == 'dark';
    }
    return _themePreference == 'dark';
  }

  TextDirection get currentLanguageDirection {
    return (_currentLanguage == 'ar' || _currentLanguage == 'ku')
        ? TextDirection.rtl
        : TextDirection.ltr;
  }

  String translate(String key) {
    final dictionary =
        TranslationKeys.translations[_currentLanguage] ??
        TranslationKeys.translations['en']!;
    return dictionary[key] ?? key;
  }

  Future<void> setLanguage(String langCode) async {
    _currentLanguage = langCode;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_language', langCode);

      final emp = currentEmployee;
      if (emp != null) {
        final updatedEmp = emp.copyWith(languagePreference: langCode);
        final index = _employees.indexWhere((e) => e.id == emp.id);
        if (index != -1) {
          _employees[index] = updatedEmp;
        }
        await _firebaseService.saveEmployee(updatedEmp);
      }
    } catch (e) {
      debugPrint('Error saving language preference: $e');
    }
  }

  Future<void> toggleTheme() async {
    final newPreference = isDarkMode ? 'light' : 'dark';
    _themePreference = newPreference;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_theme_preference', newPreference);

      final emp = currentEmployee;
      if (emp != null) {
        final updatedEmp = emp.copyWith(themePreference: newPreference);
        final index = _employees.indexWhere((e) => e.id == emp.id);
        if (index != -1) {
          _employees[index] = updatedEmp;
        }
        await _firebaseService.saveEmployee(updatedEmp);
      }
    } catch (e) {
      debugPrint('Error persisting theme preference: $e');
    }
  }

  AttendanceProvider({
    String initialThemePreference = 'light',
    String initialLanguage = 'en',
    bool initialLoggedIn = false,
    String? initialEmployeeId,
    String? initialUserName,
    String? initialEmail,
    String? initialPosition,
    String? initialRole,
    String? initialDepartment,
    String? initialAvatarPath,
  }) {
    _themePreference = initialThemePreference;
    if (initialLanguage.isNotEmpty) {
      _currentLanguage = initialLanguage;
    }
    _isLoggedIn = initialLoggedIn;
    if (initialEmployeeId != null && initialEmployeeId.isNotEmpty) {
      _employeeId = initialEmployeeId;
    }
    if (initialUserName != null && initialUserName.isNotEmpty) {
      _userName = initialUserName;
    }
    if (initialEmail != null && initialEmail.isNotEmpty) {
      _email = initialEmail;
    }
    if (initialPosition != null && initialPosition.isNotEmpty) {
      _position = initialPosition;
      _userTitle = initialPosition;
    }
    if (initialRole != null && initialRole.isNotEmpty) {
      _role = initialRole;
    }
    if (initialDepartment != null && initialDepartment.isNotEmpty) {
      _department = initialDepartment;
    }
    if (initialAvatarPath != null && initialAvatarPath.isNotEmpty) {
      _avatarPath = initialAvatarPath;
    }
    _isLoading = _firebaseService.isAvailable;
    _initializeMockData();
    _initializeHRMockData();
    _initializeMockChats();
    _loadAuthSession();
    _initializeFirebaseAndSync();
    recalculateAllStats();
  }

  @override
  void dispose() {
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    for (var sub in _chatSubscriptionsMap.values) {
      sub.cancel();
    }
    _chatSubscriptionsMap.clear();
    super.dispose();
  }

  Future<void> _initializeFirebaseAndSync() async {
    await _loadAuthSession();
    if (!_firebaseService.isAvailable) {
      debugPrint('Firebase is not available. Using local mock data fallback.');
      _initializeMockRequests();
      _isLoading = false;
      notifyListeners();
      return;
    }

    debugPrint('Firebase is available. Syncing database...');
    _isLoading = true;

    // 1. Prepare default requests to seed if empty
    final defaultRequests = [
      Request(
        id: 'req_1',
        type: 'Sick Leave',
        date: 'May 14, 2026',
        duration: '1 Day',
        status: 'Approved',
      ),
      Request(
        id: 'req_2',
        type: 'Annual Leave',
        date: 'June 15 - June 18, 2026',
        duration: '4 Days',
        status: 'Pending',
      ),
      Request(
        id: 'req_3',
        type: 'Overtime Approval',
        date: 'May 28, 2026',
        duration: '2.5 Hours',
        status: 'Approved',
      ),
      Request(
        id: 'req_4',
        type: 'Forgot to Clock Out',
        date: 'May 08, 2026',
        duration: 'Correction',
        status: 'Approved',
      ),
    ];

    // Always ensure Super Admin is available in seed list if database needs initial seeding
    final seedEmployees = List<CompanyEmployee>.from(_employees);
    if (!seedEmployees.any((e) => e.email == 'admin@company.com')) {
      seedEmployees.add(
        CompanyEmployee(
          id: 'admin_super_account',
          name: 'Super Admin',
          email: 'admin@company.com',
          position: 'Super Administrator',
          role: 'admin',
          startDate: DateTime.now().toIso8601String().split('T')[0],
          positionStartDate: DateTime.now().toIso8601String().split('T')[0],
          groupStartDate: DateTime.now().toIso8601String().split('T')[0],
          positionHistory: [],
          groupHistory: [],
          salaryHistory: [],
        ),
      );
    }

    // 2. Query Firestore and update state immediately for fast, smooth startup
    try {
      await _setupFirestoreListeners();
    } catch (e) {
      debugPrint('Error loading data from Firestore: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    // 3. Seed empty Firestore tables asynchronously in background without blocking startup
    unawaited(
      _firebaseService
          .seedDefaultMockData(
            structures: _structures,
            shifts: _shifts,
            groups: _groups,
            employees: seedEmployees,
            userRecords: _records,
            testUserId: _employeeId,
            userRequests: defaultRequests,
            locations: _locations,
          )
          .catchError((e) {
            debugPrint('Background seeding Firestore database completed/handled: $e');
          }),
    );
  }

  Future<void> _setupFirestoreListeners() async {
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();

    try {
      _subscriptions.add(
        _firebaseService.streamCompanyProfile().listen((data) {
          _companyProfile = data;
          notifyListeners();
        }),
      );

      _subscriptions.add(
        _firebaseService.streamStructures().listen((data) {
          _structures.clear();
          _structures.addAll(data);
          loadChatsForCurrentUser();
          notifyListeners();
        }),
      );

      _subscriptions.add(
        _firebaseService.streamShifts().listen((data) {
          _shifts.clear();
          _shifts.addAll(data);
          notifyListeners();
        }),
      );

      _subscriptions.add(
        _firebaseService.streamGroups().listen((data) {
          _groups.clear();
          _groups.addAll(data);
          notifyListeners();
        }),
      );

      _subscriptions.add(
        _firebaseService.streamEmployees().listen((data) {
          _employees.clear();
          for (var emp in data) {
            // Auto-heal: If employee has basicSalary configured but empty salaryHistory, synthesize initial entry and persist
            if ((emp.basicSalary > 0 || emp.workingHours > 0) && emp.salaryHistory.isEmpty) {
              final initialEntry = SalaryHistoryEntry(
                basicSalary: emp.basicSalary,
                workingHours: emp.workingHours > 0 ? emp.workingHours : 160.0,
                currency: emp.salaryCurrency.isNotEmpty ? emp.salaryCurrency : 'USD',
                startDate: emp.startDate.isNotEmpty ? emp.startDate : '2024-01-01',
                endDate: null,
                foodAllowance: emp.foodAllowance,
                transportationAllowance: emp.transportationAllowance,
                otherAllowance: emp.otherAllowance,
              );
              final healedEmp = emp.copyWith(
                workingHours: emp.workingHours > 0 ? emp.workingHours : 160.0,
                salaryHistory: [initialEntry],
              );
              _employees.add(healedEmp);
              _firebaseService.saveEmployee(healedEmp);
            } else {
              _employees.add(emp);
            }
          }

          // --- ENSURE SUPER ADMIN REMAINS PERMANENTLY ---
          if (!_employees.any((e) => e.email == 'admin@company.com')) {
            final superAdmin = CompanyEmployee(
              id: 'admin_super_account',
              name: 'Super Admin',
              email: 'admin@company.com',
              position: 'Super Administrator',
              role: 'admin',
              password: 'admin123',
              startDate: DateTime.now().toIso8601String().split('T')[0],
              positionStartDate: DateTime.now().toIso8601String().split('T')[0],
              groupStartDate: DateTime.now().toIso8601String().split('T')[0],
              positionHistory: [],
              groupHistory: [],
              salaryHistory: [],
            );
            _employees.add(superAdmin);
            _firebaseService.saveEmployee(superAdmin);
          }

          _syncCurrentEmployeeInfo();
          _avatarPath = currentEmployee?.avatarUrl;
          loadChatsForCurrentUser();
          notifyListeners();
        }),
      );

      _subscriptions.add(
        _firebaseService.streamHolidays().listen((data) {
          _holidays.clear();
          _holidays.addAll(data);
          notifyListeners();
        }),
      );

      _subscriptions.add(
        _firebaseService.streamLocations().listen((data) {
          _locations.clear();
          _locations.addAll(data);
          notifyListeners();
        }),
      );

      _subscriptions.add(
        _firebaseService.streamPayrollAdjustments().listen((data) {
          _payrollAdjustments.clear();
          _payrollAdjustments.addAll(data);
          recalculateAllStats();
          notifyListeners();
        }),
      );

      _subscriptions.add(
        _firebaseService.streamUserRecords(_employeeId).listen((data) {
          _records.clear();
          _records.addAll(data);
          _restoreActiveRecordFromRecords();
          recalculateAllStats();
          notifyListeners();
        }),
      );

      _subscriptions.add(
        _firebaseService.streamUserRequests(_employeeId).listen((data) {
          _allRequestsMap[_employeeId] = data;
          notifyListeners();
        }),
      );

      _subscriptions.add(
        _firebaseService.streamAllRecords().listen((data) {
          _allCompanyRecords.clear();
          _allCompanyRecords.addAll(data);
          notifyListeners();
        }),
      );

      try {
        final initialRequests = await _firebaseService.getAllRequests();
        if (initialRequests.isNotEmpty) {
          _allCompanyRequests.clear();
          _allCompanyRequests.addAll(initialRequests);
          for (var req in initialRequests) {
            if (req.employeeId != null) {
              _allRequestsMap[req.employeeId!] ??= [];
              final existingIdx = _allRequestsMap[req.employeeId!]!.indexWhere(
                (r) => r.id == req.id,
              );
              if (existingIdx != -1) {
                _allRequestsMap[req.employeeId!]![existingIdx] = req;
              } else {
                _allRequestsMap[req.employeeId!]!.add(req);
              }
            }
          }
          notifyListeners();
        }
      } catch (e) {
        debugPrint('Error getting initial requests: $e');
      }

      _subscriptions.add(
        _firebaseService.streamAllRequests().listen((data) {
          _allCompanyRequests.clear();
          _allCompanyRequests.addAll(data);
          for (var req in data) {
            if (req.employeeId != null) {
              _allRequestsMap[req.employeeId!] ??= [];
              final existingIdx = _allRequestsMap[req.employeeId!]!.indexWhere(
                (r) => r.id == req.id,
              );
              if (existingIdx != -1) {
                _allRequestsMap[req.employeeId!]![existingIdx] = req;
              } else {
                _allRequestsMap[req.employeeId!]!.add(req);
              }
            }
          }
          notifyListeners();
        }),
      );

      await loadChatsForCurrentUser();
      if (!kIsWeb) {
        await _setupPushNotifications();
      }
    } catch (e) {
      debugPrint('Error setting up Firestore listeners: $e');
      rethrow;
    }
  }

  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> _setupPushNotifications() async {
    if (kIsWeb) return;
    try {
      final messaging = FirebaseMessaging.instance;

      // Request permission
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      // Initialize local notifications for foreground and register high-priority notification channel
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings();
      const InitializationSettings initializationSettings =
          InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: initializationSettingsIOS,
          );
      await _localNotificationsPlugin.initialize(
        settings: initializationSettings,
      );

      // Create high-priority notification channel for Android system tray
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'chat_channel_id',
        'Chat Messages',
        description: 'Notifications for new messages and attendance alerts',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );
      await _localNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      // Get token
      String? token = await messaging.getToken();
      if (token != null &&
          currentEmployee != null &&
          currentEmployee!.fcmToken != token) {
        final updatedEmp = currentEmployee!.copyWith(
          fcmToken: token,
          overrideFcmToken: true,
        );
        await updateEmployee(updatedEmp);
      }

      // Listen to token refresh
      messaging.onTokenRefresh.listen((newToken) async {
        if (currentEmployee != null && currentEmployee!.fcmToken != newToken) {
          final updatedEmp = currentEmployee!.copyWith(
            fcmToken: newToken,
            overrideFcmToken: true,
          );
          await updateEmployee(updatedEmp);
        }
      });

      // Setup foreground notification display
      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        debugPrint('Got a message whilst in the foreground!');
        debugPrint('Message data: ${message.data}');

        if (message.notification != null) {
          debugPrint(
            'Message also contained a notification: ${message.notification}',
          );

          const AndroidNotificationDetails androidDetails =
              AndroidNotificationDetails(
                'chat_channel_id',
                'Chat Messages',
                importance: Importance.max,
                priority: Priority.high,
              );
          const NotificationDetails platformDetails = NotificationDetails(
            android: androidDetails,
          );

          await _localNotificationsPlugin.show(
            id: DateTime.now().millisecond,
            title: message.notification!.title,
            body: message.notification!.body,
            notificationDetails: platformDetails,
          );
        }
      });
    } catch (e) {
      debugPrint('Error setting up push notifications: $e');
    }
  }

  Future<void> _showLocalChatNotification(
    String senderName,
    String messageText, {
    String? senderId,
  }) async {
    if (kIsWeb) {
      showBrowserNotification('Message from $senderName', messageText);

      _notifications ??= [];
      _notifications!.insert(
        0,
        AppNotification(
          id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
          title: 'Message from $senderName',
          body: messageText,
          timestamp: DateTime.now(),
          type: NotificationType.chat,
          relatedId: senderId,
          isRead: false,
        ),
      );

      // Show redesigned compact floating toast at top-right on Web
      showWebNotificationToast(
        senderName: senderName,
        messageText: messageText,
        senderId: senderId,
        onReply: () {
          if (senderId != null) {
            final contact = _employees
                .where((e) => e.id == senderId)
                .firstOrNull;
            if (contact != null && rootNavigatorKey.currentState != null) {
              rootNavigatorKey.currentState!.push(
                MaterialPageRoute(
                  builder: (context) => ChatRoomScreen(contact: contact),
                ),
              );
            }
          }
        },
      );

      notifyListeners();
      return;
    }

    try {
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            'chat_channel_id',
            'Chat Messages',
            importance: Importance.max,
            priority: Priority.high,
          );
      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
      );

      await _localNotificationsPlugin.show(
        id: DateTime.now().millisecond,
        title: 'Message from $senderName',
        body: messageText,
        notificationDetails: platformDetails,
      );
    } catch (e) {
      debugPrint('Error showing local notification: $e');
    }
  }

  Future<void> refreshData() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _setupFirestoreListeners();
    } catch (e) {
      debugPrint('Error refreshing data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _restoreActiveRecordFromRecords() {
    final now = DateTime.now();
    try {
      final active = _records.firstWhere(
        (r) =>
            r.checkOut == null &&
            now.difference(r.checkIn).inHours.abs() < 24 &&
            r.checkIn.isBefore(now.add(const Duration(minutes: 5))),
      );
      _isClockedIn = true;
      _activeRecord = active;
      debugPrint(
        'Restored active clock-in session from Firestore: ${active.checkIn}',
      );
    } catch (_) {
      _isClockedIn = false;
      _activeRecord = null;
    }
  }

  SalaryHistoryEntry getActiveSalaryConfig(CompanyEmployee emp, DateTime date) {
    // 1. Check history for a matching date range
    final sortedHistory = List<SalaryHistoryEntry>.from(emp.salaryHistory)
      ..sort((a, b) => b.startDate.compareTo(a.startDate));

    for (var entry in sortedHistory) {
      DateTime start = DateTime.parse(entry.startDate);
      DateTime? end = entry.endDate != null
          ? DateTime.parse(entry.endDate!)
          : null;

      if (date.isAtSameMomentAs(start) || date.isAfter(start)) {
        if (end == null || date.isBefore(end) || date.isAtSameMomentAs(end)) {
          return entry;
        }
      }
    }
    // 2. If history exists but no match is found (e.g., date is before the first entry), salary is 0
    if (emp.salaryHistory.isNotEmpty) {
      return SalaryHistoryEntry(
        basicSalary: 0.0,
        workingHours: 0.0,
        currency: emp.salaryCurrency,
        startDate: '',
        foodAllowance: 0.0,
        transportationAllowance: 0.0,
        otherAllowance: 0.0,
      );
    }

    // 3. Fallback to base configuration if no history matches
    return SalaryHistoryEntry(
      basicSalary: emp.basicSalary,
      workingHours: emp.workingHours > 0 ? emp.workingHours : 160.0,
      currency: emp.salaryCurrency.isNotEmpty ? emp.salaryCurrency : 'USD',
      startDate: '',
      foodAllowance: emp.foodAllowance,
      transportationAllowance: emp.transportationAllowance,
      otherAllowance: emp.otherAllowance,
    );
  }

  DateTime? _parseFlexibleDateOnly(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return null;
    final s = dateStr.trim();
    try {
      final dt = DateTime.parse(s);
      return DateTime(dt.year, dt.month, dt.day);
    } catch (_) {}

    if (s.contains('/')) {
      final parts = s.split('/');
      if (parts.length == 3) {
        final p0 = int.tryParse(parts[0]);
        final p1 = int.tryParse(parts[1]);
        final p2 = int.tryParse(parts[2]);
        if (p0 != null && p1 != null && p2 != null) {
          if (parts[2].length == 4) {
            return DateTime(p2, p1, p0);
          } else if (parts[0].length == 4) {
            return DateTime(p0, p1, p2);
          }
        }
      }
    }

    final formats = [
      'MMMM d, yyyy',
      'MMM d, yyyy',
      'yyyy-MM-dd',
      'd MMMM yyyy',
      'd MMM yyyy',
      'dd-MM-yyyy',
    ];
    for (var f in formats) {
      try {
        final dt = DateFormat(f).parse(s);
        return DateTime(dt.year, dt.month, dt.day);
      } catch (_) {}
    }
    return null;
  }

  WorkShift getShiftForDate(CompanyEmployee emp, DateTime date) {
    final target = DateTime(date.year, date.month, date.day);

    // 1. Check if there's an approved Change Shift request for this employee covering this date
    final approvedShiftRequests = _allCompanyRequests.where(
      (r) =>
          (r.employeeId == emp.id ||
              (_employeeId == emp.id && r.employeeId == null)) &&
          r.status == 'Approved' &&
          r.type == 'Change Shift' &&
          r.targetShiftId != null &&
          r.targetShiftId!.isNotEmpty,
    );

    for (var req in approvedShiftRequests) {
      final dateStr = req.date.trim();
      DateTime? start;
      DateTime? end;

      if (dateStr.contains(' - ')) {
        final parts = dateStr.split(' - ');
        end = _parseFlexibleDateOnly(parts[1].trim());
        String startStr = parts[0].trim();
        if (!startStr.contains(',') && end != null) {
          startStr = '$startStr, ${end.year}';
        }
        start = _parseFlexibleDateOnly(startStr);
      } else {
        start = _parseFlexibleDateOnly(dateStr);
        end = start;
      }

      if (start != null && end != null) {
        if ((target.isAtSameMomentAs(start) || target.isAfter(start)) &&
            (target.isAtSameMomentAs(end) || target.isBefore(end))) {
          final foundShift =
              _shifts.where((s) => s.id == req.targetShiftId).firstOrNull;
          if (foundShift != null) {
            return foundShift;
          }
        }
      }
    }

    // 2. Resolve via active group for date
    final activeGroupId = getGroupIdForDate(emp, date);
    final group = _groups.firstWhere(
      (g) => g.id == activeGroupId,
      orElse: () => EmployeeGroup(
        id: '',
        name: 'None',
        shiftId: '',
        overtimeAllowed: false,
        minOvertimeMinutes: 0,
        maxOvertimeMinutes: 0,
      ),
    );
    return _shifts.firstWhere(
      (s) => s.id == group.shiftId,
      orElse: () => WorkShift(
        id: '',
        name: 'Default Shift',
        startTime: '09:00',
        endTime: '17:00',
      ),
    );
  }

  DateTime getEffectiveDateForRecord(AttendanceRecord rec, CompanyEmployee emp) {
    final checkIn = rec.checkIn;
    final dayOfCheckIn = DateTime(checkIn.year, checkIn.month, checkIn.day);
    final prevDay = dayOfCheckIn.subtract(const Duration(days: 1));
    final prevShift = getShiftForDate(emp, prevDay);
    if (prevShift.isOvernightForDate(prevDay)) {
      final cutoffStr = prevShift.getCrossMidnightCutoffForDate(prevDay);
      final cParts = cutoffStr.split(':');
      if (cParts.length >= 2) {
        final cH = int.tryParse(cParts[0]) ?? 3;
        final cM = int.tryParse(cParts[1]) ?? 0;
        final cutoffDateTime = DateTime(dayOfCheckIn.year, dayOfCheckIn.month, dayOfCheckIn.day, cH, cM);
        if (checkIn.isBefore(cutoffDateTime)) {
          return prevDay;
        }
      }
    }
    return dayOfCheckIn;
  }

  List<AttendanceRecord> getRecordsForDate(
    DateTime date, {
    required CompanyEmployee emp,
    List<AttendanceRecord>? recordsPool,
    List<Request>? requestsPool,
  }) {
    final pool = recordsPool ??
        ((emp.id == _employeeId)
            ? _records
            : _allCompanyRecords
                .where((r) =>
                    r.employeeId != null &&
                    (r.employeeId!.trim().toLowerCase() == emp.id.trim().toLowerCase() ||
                     r.employeeId!.trim().toLowerCase() == emp.name.trim().toLowerCase() ||
                     r.employeeId!.trim().toLowerCase() == emp.email.trim().toLowerCase()))
                .toList());

    return pool.where((rec) {
      final effDate = getEffectiveDateForRecord(rec, emp);
      return effDate.year == date.year &&
          effDate.month == date.month &&
          effDate.day == date.day;
    }).toList();
  }

  PayrollReport generatePayrollReport(
    CompanyEmployee emp,
    DateTime targetMonth, {
    List<AttendanceRecord>? customRecords,
  }) {
    final config = getActiveSalaryConfig(emp, targetMonth);
    final basicSalary = config.basicSalary;
    final configWorkingHours = config.workingHours > 0
        ? config.workingHours
        : 160.0;
    final hourlyRate = configWorkingHours > 0
        ? (basicSalary / configWorkingHours)
        : 0.0;
    final currency = config.currency;

    final foodAllowance = config.foodAllowance;
    final transportationAllowance = config.transportationAllowance;
    final otherAllowance = config.otherAllowance;
    final totalAllowances =
        foodAllowance + transportationAllowance + otherAllowance;

    // We will look up the group & shift per-day inside the loop.

    // Records for this employee
    final employeeRecords =
        customRecords ??
        ((emp.id == _employeeId)
            ? _records
            : _allCompanyRecords
                .where((r) =>
                    r.employeeId != null &&
                    (r.employeeId!.trim().toLowerCase() == emp.id.trim().toLowerCase() ||
                     r.employeeId!.trim().toLowerCase() == emp.name.trim().toLowerCase() ||
                     r.employeeId!.trim().toLowerCase() == emp.email.trim().toLowerCase()))
                .toList());
    final employeeRequests = _allRequestsMap[emp.id] ??
        _allCompanyRequests
            .where((r) =>
                r.employeeId != null &&
                (r.employeeId!.trim().toLowerCase() == emp.id.trim().toLowerCase() ||
                 r.employeeId!.trim().toLowerCase() == emp.name.trim().toLowerCase() ||
                 r.employeeId!.trim().toLowerCase() == emp.email.trim().toLowerCase()))
            .toList();

    final daysInMonth = DateUtils.getDaysInMonth(
      targetMonth.year,
      targetMonth.month,
    );

    int totalDutyMinutes = 0;
    int totalOvertimeMinutes = 0;
    int totalDeficitMinutes = 0;
    double totalPenalties = 0.0;
    int daysWorked = 0;

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(targetMonth.year, targetMonth.month, day);
      final activeGroupId = getGroupIdForDate(emp, date);
      final group = _groups.firstWhere(
        (g) => g.id == activeGroupId,
        orElse: () => EmployeeGroup(
          id: '',
          name: 'None',
          shiftId: '',
          overtimeAllowed: false,
          minOvertimeMinutes: 0,
          maxOvertimeMinutes: 0,
        ),
      );
      final shift = getShiftForDate(emp, date);

      final isWorkingDay = shift.isWorkingDay(date);

      // Get records on this day
      final dayRecords = getRecordsForDate(
        date,
        emp: emp,
        recordsPool: employeeRecords,
      );

      final hasRecord = dayRecords.isNotEmpty;

      // Approved requests on this day
      final dateStr = DateFormat('MMMM d, yyyy').format(date);
      final dayApprovedRequests = employeeRequests
          .where(
            (req) =>
                req.status == 'Approved' &&
                (req.date == dateStr ||
                    req.date.contains(DateFormat('MMMM d').format(date))),
          )
          .toList();

      final hasLeave = dayApprovedRequests.any(
        (r) =>
            r.type == 'Annual Leave' ||
            r.type == 'Sick Leave' ||
            r.type == 'Hourly Leave',
      );
      final hasApprovedOt = dayApprovedRequests.any(
        (r) => r.type == 'Overtime Approval',
      );

      final holiday = _holidays.firstWhere(
        (h) {
          final isForGroup =
              h.groupIds.isEmpty ||
              (activeGroupId != null && h.groupIds.contains(activeGroupId));
          if (!isForGroup) return false;
          try {
            final from = DateTime.parse(
              h.fromDate,
            ).subtract(const Duration(days: 1));
            final to = DateTime.parse(h.toDate).add(const Duration(days: 1));
            return date.isAfter(from) && date.isBefore(to);
          } catch (_) {
            return false;
          }
        },
        orElse: () => Holiday(
          id: '',
          name: '',
          fromDate: '2099-01-01',
          toDate: '2099-01-01',
        ),
      );
      final isHoliday = holiday.id.isNotEmpty;

      if (hasRecord) {
        daysWorked++;
        int dayDuty = 0;
        int dayExtra = 0;
        int dayActualMinutes = 0;

        final startTimeStr = shift.getStartTimeForDate(date);
        final endTimeStr = shift.getEndTimeForDate(date);
        final sParts = startTimeStr.split(':');
        final eParts = endTimeStr.split(':');
        final shiftStartMins = sParts.length >= 2
            ? int.parse(sParts[0]) * 60 + int.parse(sParts[1])
            : 540;
        final shiftEndMins = eParts.length >= 2
            ? int.parse(eParts[0]) * 60 + int.parse(eParts[1])
            : 1020;

        final shiftStart = DateTime(
          date.year,
          date.month,
          date.day,
          shiftStartMins ~/ 60,
          shiftStartMins % 60,
        );
        var shiftEnd = DateTime(
          date.year,
          date.month,
          date.day,
          shiftEndMins ~/ 60,
          shiftEndMins % 60,
        );
        if (shiftEnd.isBefore(shiftStart) || shiftEnd.isAtSameMomentAs(shiftStart) || shift.isOvernightForDate(date)) {
          shiftEnd = shiftEnd.add(const Duration(days: 1));
        }

        for (var rec in dayRecords) {
          final rawIn = rec.checkIn;
          final rawOut = rec.checkOut ?? rawIn;
          final cIn = DateTime(
            rawIn.year,
            rawIn.month,
            rawIn.day,
            rawIn.hour,
            rawIn.minute,
          );
          final cOut = DateTime(
            rawOut.year,
            rawOut.month,
            rawOut.day,
            rawOut.hour,
            rawOut.minute,
          );

          final intStart = cIn.isAfter(shiftStart) ? cIn : shiftStart;
          final intEnd = cOut.isBefore(shiftEnd) ? cOut : shiftEnd;
          if (intEnd.isAfter(intStart)) {
            dayDuty += intEnd.difference(intStart).inMinutes;
          }

          if (!isWorkingDay) {
            dayExtra += cOut.difference(cIn).inMinutes;
          } else {
            if (cIn.isBefore(shiftStart)) {
              final eBefore = cOut.isBefore(shiftStart) ? cOut : shiftStart;
              dayExtra += eBefore.difference(cIn).inMinutes;
            }
            if (cOut.isAfter(shiftEnd)) {
              final sAfter = cIn.isAfter(shiftEnd) ? cIn : shiftEnd;
              dayExtra += cOut.difference(sAfter).inMinutes;
            }
          }
          dayActualMinutes += cOut.difference(cIn).inMinutes;
        }

        totalDutyMinutes += dayDuty;

        // Delay & Early Exit
        final isSpecial = shift.isSpecialShiftForDate(date);
        final shiftDur = shift.getShiftDurationMinutesForDate(date);

        int dayDelay = 0;
        int dayEarlyExit = 0;
        int unexcusedRestMinutes = 0;

        if (isSpecial) {
          dayDelay = 0;
          dayEarlyExit = 0;
          dayDuty = dayActualMinutes > shiftDur ? shiftDur : dayActualMinutes;
          dayExtra = dayActualMinutes > shiftDur ? (dayActualMinutes - shiftDur) : 0;
        } else if (isWorkingDay && !hasLeave && !isHoliday) {
          final sorted = List<AttendanceRecord>.from(dayRecords)
            ..sort((a, b) => a.checkIn.compareTo(b.checkIn));
          final firstRec = sorted.first;
          final delay = firstRec.checkIn.difference(shiftStart).inMinutes;
          if (delay > shift.forgivenessOfDelay) {
            dayDelay = delay;
          }

          final lastRec = sorted.last;
          if (lastRec.checkOut != null) {
            final earlyExit = shiftEnd.difference(lastRec.checkOut!).inMinutes;
            if (earlyExit > shift.earlyExit) {
              dayEarlyExit = earlyExit;
            }
          }

          // Calculate Unexcused Rest Time
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

          if (sorted.length > 1) {
            for (int i = 0; i < sorted.length - 1; i++) {
              final currentOut = sorted[i].checkOut;
              final nextIn = sorted[i + 1].checkIn;
              if (currentOut != null && nextIn.isAfter(currentOut)) {
                final gapDuration = nextIn.difference(currentOut).inMinutes;

                if (bStart != null && bEnd != null) {
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

                  if (totalExcusedRestMinutes + excusedInGap >
                      allowedBreakDuration) {
                    excusedInGap =
                        allowedBreakDuration - totalExcusedRestMinutes;
                    if (excusedInGap < 0) excusedInGap = 0;
                  }

                  totalExcusedRestMinutes += excusedInGap;
                  unexcusedRestMinutes += (gapDuration - excusedInGap);
                } else {
                  unexcusedRestMinutes += gapDuration;
                }
              }
            }
          }
        }

        // Removed unused delay & early exit accumulators

        // Penalties
        double delayPenalty = 0.0;
        if (dayDelay > 0 && group.delayPenaltiesEnabled) {
          if (dayDelay >= group.delayTier1Min &&
              dayDelay <= group.delayTier1Max) {
            delayPenalty = group.delayTier1Penalty;
          } else if (dayDelay >= group.delayTier2Min &&
              dayDelay <= group.delayTier2Max) {
            delayPenalty = group.delayTier2Penalty;
          } else if (dayDelay >= group.delayTier3Min) {
            delayPenalty = group.delayTier3Penalty;
          }
        }

        double earlyExitPenalty = 0.0;
        if (dayEarlyExit > 0 && group.earlyExitPenaltiesEnabled) {
          if (dayEarlyExit >= group.earlyExitTier1Min &&
              dayEarlyExit <= group.earlyExitTier1Max) {
            earlyExitPenalty = group.earlyExitTier1Penalty;
          } else if (dayEarlyExit >= group.earlyExitTier2Min &&
              dayEarlyExit <= group.earlyExitTier2Max) {
            earlyExitPenalty = group.earlyExitTier2Penalty;
          } else if (dayEarlyExit >= group.earlyExitTier3Min) {
            earlyExitPenalty = group.earlyExitTier3Penalty;
          }
        }

        totalPenalties += (delayPenalty + earlyExitPenalty);

        // Overtime
        if (dayExtra > 0 && hasApprovedOt && group.overtimeAllowed) {
          if (dayExtra >= group.minOvertimeMinutes) {
            final baseOt = dayExtra.clamp(0, group.maxOvertimeMinutes);
            if (!isWorkingDay) {
              totalOvertimeMinutes += (baseOt * group.weekendOvertimeRatio)
                  .toInt();
            } else {
              totalOvertimeMinutes += baseOt;
            }
          }
        }

        // Deficit on active day
        int dayDeficit = 0;
        if (isSpecial) {
          if (isWorkingDay && !hasLeave && !isHoliday) {
            if (dayActualMinutes < shiftDur) {
              dayDeficit = shiftDur - dayActualMinutes;
            }
          }
        } else {
          dayDeficit = dayDelay + dayEarlyExit + unexcusedRestMinutes;
        }
        totalDeficitMinutes += dayDeficit;
      } else {
        // No record on this day
        // Since Gross Salary is based on Days Worked (salaryCalcByDay),
        // completely missing a day naturally reduces the gross.
        // We do not add the missing shift to the deficit to avoid double-deduction.
      }
    }

    final double workingHours = totalDutyMinutes / 60.0;
    final double overtimeHours = totalOvertimeMinutes / 60.0;
    final double overtimeValue = overtimeHours * hourlyRate * 1.5;
    final double attendanceDeficitHours = totalDeficitMinutes / 60.0;
    final double attendanceDeficit = attendanceDeficitHours * hourlyRate;

    // Salary calculation by day / attendance
    // Standard HR practice: calculate daily rate based on 30 days regardless of the actual month length
    final double dailyRate = basicSalary / 30.0;
    final double salaryCalcByDay = daysWorked * dailyRate;

    // Monthly additions & deductions for this employee in this target month
    final targetMonthStr = DateFormat('yyyy-MM').format(targetMonth);
    final empAdjustments = _payrollAdjustments.where((adj) {
      final matchesEmp = adj.employeeId.trim().toLowerCase() == emp.id.trim().toLowerCase() ||
          adj.employeeId.trim().toLowerCase() == emp.name.trim().toLowerCase() ||
          adj.employeeId.trim().toLowerCase() == emp.email.trim().toLowerCase();
      final matchesMonth = adj.month == targetMonthStr ||
          (adj.date.length >= 7 && adj.date.substring(0, 7) == targetMonthStr);
      return matchesEmp && matchesMonth;
    }).toList();

    final double monthlyAdditions = empAdjustments
        .where((adj) => adj.type.toLowerCase() == 'addition')
        .fold(0.0, (sum, adj) => sum + adj.amount);

    final double monthlyDeductions = empAdjustments
        .where((adj) => adj.type.toLowerCase() == 'deduction')
        .fold(0.0, (sum, adj) => sum + adj.amount);

    final double incrementalSalary =
        salaryCalcByDay +
        overtimeValue +
        (daysWorked > 0 ? totalAllowances : 0.0) +
        monthlyAdditions;
    final double decrementalSalary = attendanceDeficit + totalPenalties + monthlyDeductions;
    final double netEarnings = (incrementalSalary - decrementalSalary).clamp(
      0.0,
      double.infinity,
    );

    return PayrollReport(
      employee: emp,
      basicSalary: basicSalary,
      salaryCalcByDay: salaryCalcByDay,
      workingHours: workingHours,
      daysWorked: daysWorked,
      overtimeHours: overtimeHours,
      overtimeValue: overtimeValue,
      attendanceDeficitHours: attendanceDeficitHours,
      attendanceDeficit: attendanceDeficit,
      monthlyPenalties: totalPenalties,
      foodAllowance: foodAllowance,
      transportationAllowance: transportationAllowance,
      otherAllowance: otherAllowance,
      monthlyAdditions: monthlyAdditions,
      monthlyDeductions: monthlyDeductions,
      adjustments: empAdjustments,
      incrementalSalary: incrementalSalary,
      decrementalSalary: decrementalSalary,
      netEarnings: netEarnings,
      currency: currency,
    );
  }

  Future<void> addPayrollAdjustment(PayrollAdjustment adjustment) async {
    final existingIdx = _payrollAdjustments.indexWhere((a) => a.id == adjustment.id);
    if (existingIdx != -1) {
      _payrollAdjustments[existingIdx] = adjustment;
    } else {
      _payrollAdjustments.add(adjustment);
    }
    recalculateAllStats();
    notifyListeners();

    if (_firebaseService.isAvailable) {
      await _firebaseService.savePayrollAdjustment(adjustment);
    }
  }

  Future<void> deletePayrollAdjustment(String id) async {
    _payrollAdjustments.removeWhere((a) => a.id == id);
    recalculateAllStats();
    notifyListeners();

    if (_firebaseService.isAvailable) {
      await _firebaseService.deletePayrollAdjustment(id);
    }
  }

  List<PayrollAdjustment> getAdjustmentsForEmployee(String empId, DateTime targetMonth) {
    final targetMonthStr = DateFormat('yyyy-MM').format(targetMonth);
    return _payrollAdjustments.where((adj) {
      final matchesEmp = adj.employeeId.trim().toLowerCase() == empId.trim().toLowerCase();
      final matchesMonth = adj.month == targetMonthStr ||
          (adj.date.length >= 7 && adj.date.substring(0, 7) == targetMonthStr);
      return matchesEmp && matchesMonth;
    }).toList();
  }

  void recalculateAllStats() {
    final emp = currentEmployee;
    if (emp == null) return;
    final report = generatePayrollReport(emp, selectedMonth);
    _weeklyHours = report.workingHours;
    _daysWorked = report.daysWorked;
    _overtimeHours = report.overtimeHours;
    _overtimeValue = report.overtimeValue;
    _attendanceDeficitHours = report.attendanceDeficitHours;
    _attendanceDeficit = report.attendanceDeficit;
    _monthlyPenalties = report.monthlyPenalties;
    _salaryCalcByDay = report.salaryCalcByDay;
    _foodAllowance = report.foodAllowance;
    _transportationAllowance = report.transportationAllowance;
    _otherAllowance = report.otherAllowance;
    _incrementalSalary = report.incrementalSalary;
    _decrementalSalary = report.decrementalSalary;
    _monthlyEarnings = report.netEarnings;
    final config = getActiveSalaryConfig(emp, selectedMonth);
    _hourlyRate = config.workingHours > 0
        ? (config.basicSalary / config.workingHours)
        : 0.0;
  }

  void _initializeMockData() {}
  void _initializeHRMockData() {}
  void _initializeMockChats() {}
  void _initializeMockRequests() {}
  List<CompanyEmployee> getChatContacts(CompanyEmployee currentUser) {
    List<CompanyEmployee> contacts = [];
    final Set<String> contactIds = {};

    final userRole = currentUser.role.trim().toLowerCase();
    if (userRole == 'hr' || userRole == 'admin' || userRole == 'super_admin' || userRole == 'superadmin') {
      contacts = _employees.where((e) => e.id != currentUser.id).toList();
      for (var c in contacts) {
        contactIds.add(c.id);
      }
    } else if (userRole == 'supervisor') {
      final supervisedStructures = _structures
          .where((s) => s.supervisorId == currentUser.id)
          .map((s) => s.id)
          .toList();

      for (var structId in supervisedStructures) {
        final emps = _employees.where(
          (e) => e.id != currentUser.id && e.structureId == structId,
        );
        for (var e in emps) {
          if (contactIds.add(e.id)) {
            contacts.add(e);
          }
        }
      }

      if (currentUser.structureId != null &&
          currentUser.structureId!.isNotEmpty) {
        final emps = _employees.where(
          (e) =>
              e.id != currentUser.id &&
              e.structureId == currentUser.structureId &&
              e.role == 'employee',
        );
        for (var e in emps) {
          if (contactIds.add(e.id)) {
            contacts.add(e);
          }
        }
      }

      // Include HR managers & admins so supervisors can communicate with them
      final hrEmps = _employees.where(
        (e) => (e.role == 'hr' || e.role == 'admin') && e.id != currentUser.id,
      );
      for (var hr in hrEmps) {
        if (contactIds.add(hr.id)) {
          contacts.add(hr);
        }
      }
    } else {
      // Regular employee: supervisors
      final sups = getSupervisorsFor(currentUser.id);
      for (var sup in sups) {
        if (contactIds.add(sup.id)) {
          contacts.add(sup);
        }
      }

      // Plus HR managers and Admins
      final hrEmps = _employees.where(
        (e) => (e.role == 'hr' || e.role == 'admin') && e.id != currentUser.id,
      );
      for (var hr in hrEmps) {
        if (contactIds.add(hr.id)) {
          contacts.add(hr);
        }
      }
    }

    // Always include any employee with existing messages in the conversation history
    for (var otherId in _chatMessagesMap.keys) {
      if (_chatMessagesMap[otherId]?.isNotEmpty ?? false) {
        if (contactIds.add(otherId)) {
          try {
            final emp = _employees.firstWhere((e) => e.id == otherId);
            contacts.add(emp);
          } catch (_) {}
        }
      }
    }

    return contacts;
  }

  void ensureChatLoaded(dynamic contactId) {
    if (!_firebaseService.isAvailable) return;
    final cId = contactId.toString();
    final currentUser = currentEmployee;
    if (currentUser == null) return;
    if (_chatSubscriptionsMap.containsKey(cId)) return;

    _chatSubscriptionsMap[cId] = _firebaseService
        .streamChatMessages(currentUser.id, cId)
        .listen(
          (messages) {
            final previousMessages = _chatMessagesMap[cId] ?? [];
            _chatMessagesMap[cId] = messages;

            // Check for new incoming messages for local and web notifications
            if (previousMessages.isNotEmpty &&
                messages.length > previousMessages.length) {
              final newMsg = messages.last;
              if (newMsg.senderId != currentUser.id) {
                String contactName = 'Colleague';
                try {
                  final contactEmp = _employees.firstWhere((e) => e.id == cId);
                  contactName = contactEmp.name;
                } catch (_) {}
                _showLocalChatNotification(
                  contactName,
                  newMsg.text,
                  senderId: cId,
                );
              }
            }

            notifyListeners();
          },
          onError: (e) {
            debugPrint('Error streaming chat messages with $cId: $e');
          },
        );
  }

  Future<void> loadChatsForCurrentUser() async {
    final currentUser = currentEmployee;
    if (currentUser == null) return;

    final contacts = getChatContacts(currentUser);
    for (var contact in contacts) {
      ensureChatLoaded(contact.id);
    }
  }

  Future<List<AttendanceRecord>> getEmployeeRecords(String empId) async {
    final cleanId = empId.trim();
    if (cleanId.isEmpty) return [];

    // 1. If requesting current user and in-memory records are present
    if (cleanId.toLowerCase() == _employeeId.toLowerCase() && _records.isNotEmpty) {
      return _records;
    }

    // 2. Direct Firestore query
    if (_firebaseService.isAvailable) {
      final fetched = await _firebaseService.getUserRecords(cleanId);
      if (fetched.isNotEmpty) {
        return fetched;
      }

      // Check if cleanId matches an employee's name or email or alternative id
      final match = _employees.firstWhere(
        (e) => e.id.toLowerCase() == cleanId.toLowerCase() ||
               e.email.toLowerCase() == cleanId.toLowerCase() ||
               e.name.toLowerCase() == cleanId.toLowerCase(),
        orElse: () => CompanyEmployee(id: '', name: '', email: '', position: ''),
      );
      if (match.id.isNotEmpty && match.id.toLowerCase() != cleanId.toLowerCase()) {
        final altFetched = await _firebaseService.getUserRecords(match.id);
        if (altFetched.isNotEmpty) {
          return altFetched;
        }
      }
    }

    // 3. Check in-memory company records
    final fromAll = _allCompanyRecords
        .where((r) => r.employeeId != null &&
            r.employeeId!.trim().toLowerCase() == cleanId.toLowerCase())
        .toList();
    if (fromAll.isNotEmpty) {
      return fromAll;
    }

    // 4. Fallback if cleanId matches current employee
    if (cleanId.toLowerCase() == _employeeId.toLowerCase()) {
      return _records;
    }
    return [];
  }

  int get pendingApprovalsCount {
    if (currentEmployee?.role == 'hr' ||
        currentEmployee?.role == 'admin' ||
        canEditCompanyInfo) {
      return _allCompanyRequests
          .where(
            (r) =>
                (r.status == 'Pending' || r.status == 'Pending HR') &&
                r.employeeId != _employeeId,
          )
          .length;
    }
    if (currentEmployee?.role == 'supervisor') {
      final subordinateIds = _structures
          .where((s) => s.supervisorId == _employeeId)
          .expand(
            (s) =>
                _employees.where((e) => e.structureId == s.id).map((e) => e.id),
          )
          .toSet();
      return _allCompanyRequests
          .where(
            (r) =>
                (r.status == 'Pending' || r.status == 'Pending Supervisor') &&
                subordinateIds.contains(r.employeeId),
          )
          .length;
    }
    return 0;
  }

  Future<List<Request>> getEmployeeRequests(String empId) async {
    final cleanId = empId.trim();
    if (cleanId.isEmpty) return [];

    if (_firebaseService.isAvailable) {
      final fetched = await _firebaseService.getUserRequests(cleanId);
      if (fetched.isNotEmpty) {
        _allRequestsMap[cleanId] = fetched;
        return fetched;
      }

      final match = _employees.firstWhere(
        (e) => e.id.toLowerCase() == cleanId.toLowerCase() ||
               e.email.toLowerCase() == cleanId.toLowerCase(),
        orElse: () => CompanyEmployee(id: '', name: '', email: '', position: ''),
      );
      if (match.id.isNotEmpty && match.id.toLowerCase() != cleanId.toLowerCase()) {
        final altFetched = await _firebaseService.getUserRequests(match.id);
        if (altFetched.isNotEmpty) {
          _allRequestsMap[cleanId] = altFetched;
          return altFetched;
        }
      }
    }
    final fromAll = _allCompanyRequests
        .where((r) => r.employeeId != null &&
            r.employeeId!.trim().toLowerCase() == cleanId.toLowerCase())
        .toList();
    if (fromAll.isNotEmpty) {
      _allRequestsMap[cleanId] = fromAll;
      return fromAll;
    }
    return _allRequestsMap[cleanId] ?? [];
  }

  List<Request> getRequestsForEmployee(String empId) =>
      _allRequestsMap[empId] ?? [];

  // Profile image management
  Future<void> updateProfileImage(dynamic file) async {
    String? base64OrUrl;
    if (file is String?) {
      base64OrUrl = file;
    }

    _avatarPath = base64OrUrl;

    // 1. Update in-memory employee list and current employee
    final empIndex = _employees.indexWhere((e) => e.id == _employeeId);
    if (empIndex != -1) {
      final updatedEmp = _employees[empIndex].copyWith(
        avatarUrl: base64OrUrl,
        overrideAvatarUrl: true,
      );
      _employees[empIndex] = updatedEmp;

      // 2. Persist to Firestore
      if (_firebaseService.isAvailable) {
        await _firebaseService.saveEmployee(updatedEmp);
      }
    }

    // 3. Persist to SharedPreferences so it survives restarts/offline
    try {
      final prefs = await SharedPreferences.getInstance();
      if (base64OrUrl != null && base64OrUrl.isNotEmpty) {
        await prefs.setString('user_avatar_$_employeeId', base64OrUrl);
      } else {
        await prefs.remove('user_avatar_$_employeeId');
      }
    } catch (e) {
      debugPrint('Error saving user avatar to prefs: $e');
    }

    notifyListeners();
  }

  Future<void> switchProfile(String userId) async {
    final emp = _employees.firstWhere(
      (e) => e.id == userId,
      orElse: () => _employees.first,
    );
    _employeeId = emp.id;
    _userName = emp.name;
    _userTitle = emp.position;
    _email = emp.email;
    _department = emp.structureId ?? '';
    _position = emp.position;
    _avatarPath = emp.avatarUrl;

    _records.clear();
    _isClockedIn = false;
    _activeRecord = null;

    for (var sub in _chatSubscriptionsMap.values) {
      sub.cancel();
    }
    _chatSubscriptionsMap.clear();
    _chatMessagesMap.clear();

    await _saveAuthSession(
      true,
      _employeeId,
      name: _userName,
      email: _email,
      position: _position,
    );

    // Restart listeners
    await _setupFirestoreListeners();
    recalculateAllStats();
    notifyListeners();
  }

  Future<void> updatePassword(dynamic oldOrNew, [dynamic newPass]) async {
    final newPassword = (newPass != null ? newPass.toString() : oldOrNew.toString()).trim();
    final emp = currentEmployee;
    if (emp != null && newPassword.isNotEmpty) {
      final updated = emp.copyWith(password: newPassword);
      await updateEmployee(updated);
    }
  }

  // Group resolution with accurate date ranges
  String? getGroupIdForDate(dynamic emp, DateTime date) {
    if (emp is! CompanyEmployee) return null;
    final target = DateTime(date.year, date.month, date.day);

    if (emp.groupHistory.isNotEmpty) {
      final validEntries = emp.groupHistory
          .where((e) => e.groupId.isNotEmpty && e.startDate.isNotEmpty)
          .toList();

      // 1. Check specific bounded periods (has both start and end date)
      for (var entry in validEntries) {
        if (entry.endDate.isNotEmpty) {
          final start = _parseFlexibleDateOnly(entry.startDate);
          final end = _parseFlexibleDateOnly(entry.endDate);
          if (start != null && end != null) {
            if ((target.isAtSameMomentAs(start) || target.isAfter(start)) &&
                (target.isAtSameMomentAs(end) || target.isBefore(end))) {
              return entry.groupId;
            }
          }
        }
      }

      // 2. Check ongoing periods (endDate is empty), sorted newest start date first
      final ongoing = validEntries.where((e) => e.endDate.isEmpty).toList()
        ..sort((a, b) {
          final da = _parseFlexibleDateOnly(a.startDate) ?? DateTime(1900);
          final db = _parseFlexibleDateOnly(b.startDate) ?? DateTime(1900);
          return db.compareTo(da);
        });

      for (var entry in ongoing) {
        final start = _parseFlexibleDateOnly(entry.startDate);
        if (start != null) {
          if (target.isAtSameMomentAs(start) || target.isAfter(start)) {
            return entry.groupId;
          }
        }
      }

      // 3. Fallback: check all valid entries where start <= target
      for (var entry in validEntries) {
        final start = _parseFlexibleDateOnly(entry.startDate);
        final end = _parseFlexibleDateOnly(entry.endDate);
        if (start != null) {
          if (target.isAtSameMomentAs(start) || target.isAfter(start)) {
            if (end == null ||
                target.isAtSameMomentAs(end) ||
                target.isBefore(end)) {
              return entry.groupId;
            }
          }
        }
      }

      // 4. If target is BEFORE all entries in groupHistory:
      // Return the group of the earliest recorded period (employee was in that shift before the change)
      final sortedAsc = List<GroupHistoryEntry>.from(validEntries)
        ..sort((a, b) {
          final da = _parseFlexibleDateOnly(a.startDate) ?? DateTime(2100);
          final db = _parseFlexibleDateOnly(b.startDate) ?? DateTime(2100);
          return da.compareTo(db);
        });
      if (sortedAsc.isNotEmpty) {
        final earliestStart = _parseFlexibleDateOnly(sortedAsc.first.startDate);
        if (earliestStart != null && target.isBefore(earliestStart)) {
          return sortedAsc.first.groupId;
        }
      }
    }

    return emp.groupId;
  }

  /// Calculates the hours deducted for an approved leave request
  double calculateRequestLeaveHours(Request req, CompanyEmployee emp) {
    if (req.type != 'Annual Leave') return 0.0;

    final durStr = req.duration.trim().toLowerCase();

    // 1. Direct hours check: e.g. "4 hours", "8 hrs", "8h"
    final hourMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(?:hour|hr|h\b)').firstMatch(durStr);
    if (hourMatch != null) {
      final h = double.tryParse(hourMatch.group(1)!);
      if (h != null && h > 0) return h;
    }

    // 2. Day count check: e.g. "1 Day", "2 Days", "3 days"
    double days = 1.0;
    final dayMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(?:day)').firstMatch(durStr);
    if (dayMatch != null) {
      days = double.tryParse(dayMatch.group(1)!) ?? 1.0;
    } else if (RegExp(r'^\d+(\.\d+)?$').hasMatch(durStr)) {
      days = double.tryParse(durStr) ?? 1.0;
    } else if (durStr.contains('half')) {
      days = 0.5;
    } else if (req.date.contains(' - ')) {
      final parts = req.date.split(' - ');
      try {
        DateTime? d1;
        DateTime? d2;
        try {
          d1 = DateFormat('yyyy-MM-dd').parse(parts[0].trim());
        } catch (_) {
          try {
            d1 = DateFormat('MMMM d, yyyy').parse(parts[0].trim());
          } catch (_) {}
        }
        try {
          d2 = DateFormat('yyyy-MM-dd').parse(parts[1].trim());
        } catch (_) {
          try {
            d2 = DateFormat('MMMM d, yyyy').parse(parts[1].trim());
          } catch (_) {}
        }
        if (d1 != null && d2 != null) {
          final diff = d2.difference(d1).inDays + 1;
          if (diff > 0) days = diff.toDouble();
        }
      } catch (_) {}
    }

    DateTime reqDate = DateTime.now();
    try {
      final cleanDateStr = req.date.split(' - ').first.trim();
      reqDate = DateFormat('yyyy-MM-dd').parse(cleanDateStr);
    } catch (_) {
      try {
        final cleanDateStr = req.date.split(' - ').first.trim();
        reqDate = DateFormat('MMMM d, yyyy').parse(cleanDateStr);
      } catch (_) {}
    }

    final groupId = getGroupIdForDate(emp, reqDate);
    final group = _groups.where((g) => g.id == groupId).firstOrNull;
    final shift = _shifts.where((s) => s.id == group?.shiftId).firstOrNull;

    double hoursPerDay = 8.0;
    if (shift != null) {
      final shiftMins = shift.getShiftDurationMinutesForDate(reqDate);
      if (shiftMins > 0) {
        hoursPerDay = shiftMins / 60.0;
      }
    } else if (emp.workingHours > 0) {
      hoursPerDay = (emp.workingHours / 20.0).clamp(4.0, 12.0);
    }

    return days * hoursPerDay;
  }

  /// Adjusts employee's annual leave balance when a request is approved or un-approved
  Future<void> _adjustAnnualLeaveBalance({
    required Request request,
    required String empId,
    required bool isApproval, // true to deduct, false to refund
  }) async {
    if (request.type != 'Annual Leave') return;

    final empIndex = _employees.indexWhere((e) => e.id == empId);
    if (empIndex == -1) return;

    final emp = _employees[empIndex];
    final hours = calculateRequestLeaveHours(request, emp);
    if (hours <= 0) return;

    double newBalance = emp.annualLeaveBalance;
    if (isApproval) {
      newBalance = (newBalance - hours).clamp(0.0, 9999.0);
    } else {
      newBalance = (newBalance + hours).clamp(0.0, 9999.0);
    }

    // Only update if balance actually changed
    if ((newBalance - emp.annualLeaveBalance).abs() > 0.001) {
      final updatedEmp = emp.copyWith(annualLeaveBalance: newBalance);
      _employees[empIndex] = updatedEmp;
      notifyListeners();
      if (_firebaseService.isAvailable) {
        try {
          await _firebaseService.saveEmployee(updatedEmp);
        } catch (e) {
          debugPrint('Error updating annual leave balance in Firebase: $e');
        }
      }
    }
  }

  Future<void> submitRequest(
    dynamic type,
    dynamic date,
    dynamic duration, {
    dynamic targetShiftId,
    String? employeeId,
    String? note,
  }) async {
    final empId = employeeId ?? _employeeId;

    // Auto-approve if the employee is the top of the structure and manager of it
    String status = 'Pending Supervisor';
    bool isTopManager = false;
    try {
      isTopManager = _structures.any(
        (s) =>
            s.supervisorId == empId &&
            (s.parentId == null || s.parentId!.isEmpty),
      );
      if (isTopManager) {
        status = 'Approved';
      }
    } catch (_) {}

    if (!isTopManager) {
      // Find employee to check their structure supervisor
      final emp = _employees.where((e) => e.id == empId).firstOrNull ?? currentEmployee;
      String? structureSupervisorId;
      if (emp?.structureId != null && emp!.structureId!.isNotEmpty) {
        final struct = _structures.where((s) => s.id == emp.structureId).firstOrNull;
        structureSupervisorId = struct?.supervisorId;
      }

      // Check if structure has an active supervisor who is not the submitter
      final hasSupervisor = structureSupervisorId != null &&
          structureSupervisorId.isNotEmpty &&
          structureSupervisorId != empId &&
          _employees.any((e) => e.id == structureSupervisorId) &&
          emp?.role != 'hr' &&
          emp?.role != 'admin';

      // Check if company has an HR Manager
      final hasHRManager = _employees.any(
        (e) => (e.role == 'hr' || e.role == 'admin') && e.id != empId,
      );

      if (hasSupervisor) {
        // Starts with Supervisor
        status = 'Pending Supervisor';
      } else if (hasHRManager) {
        // Structure does not have a supervisor -> pass supervisor review, go to HR Manager
        status = 'Pending HR';
      } else {
        // Neither supervisor nor HR Manager -> pass both directly to Approved!
        status = 'Approved';
      }
    }

    final newReq = Request(
      id: 'req_${DateTime.now().millisecondsSinceEpoch}',
      type: type.toString(),
      date: date.toString(),
      duration: duration.toString(),
      status: status,
      targetShiftId: targetShiftId?.toString(),
      employeeId: empId,
      note: note,
      createdAt: DateTime.now().toIso8601String(),
      actionBy: (isTopManager || status == 'Approved') ? empId : null,
      actionDate: (isTopManager || status == 'Approved') ? DateTime.now().toIso8601String() : null,
    );
    if (_allRequestsMap[empId] == null) {
      _allRequestsMap[empId] = [];
    }
    _allRequestsMap[empId]!.insert(0, newReq);
    _allCompanyRequests.removeWhere((r) => r.id == newReq.id);
    _allCompanyRequests.insert(0, newReq);
    notifyListeners();

    if (_firebaseService.isAvailable) {
      await _firebaseService.saveRequest(empId, newReq);
    }

    if (status == 'Approved') {
      await _adjustAnnualLeaveBalance(request: newReq, empId: empId, isApproval: true);
    }
  }

  Future<void> deleteRequest(dynamic a, [dynamic b]) async {
    String empId = b != null ? a.toString() : _employeeId;
    final rId = (b ?? a).toString();
    if (empId == _employeeId) {
      final found = _allCompanyRequests.where((r) => r.id == rId).firstOrNull;
      if (found != null && found.employeeId != null) {
        empId = found.employeeId!;
      }
    }
    final targetReq = _allCompanyRequests.where((r) => r.id == rId).firstOrNull ??
        _allRequestsMap[empId]?.where((r) => r.id == rId).firstOrNull;

    _allRequestsMap[empId]?.removeWhere((r) => r.id == rId);
    _allCompanyRequests.removeWhere((r) => r.id == rId);
    notifyListeners();

    if (_firebaseService.isAvailable) {
      await _firebaseService.deleteRequest(empId, rId);
    }

    if (targetReq != null && targetReq.status == 'Approved') {
      await _adjustAnnualLeaveBalance(request: targetReq, empId: empId, isApproval: false);
    }
  }

  Future<void> updateRequestStatus(dynamic a, dynamic b, [dynamic c]) async {
    String empId = _employeeId;
    String reqId = '';
    String targetStatus = '';
    if (c != null) {
      empId = a.toString();
      reqId = b.toString();
      targetStatus = c.toString();
    } else {
      reqId = a.toString();
      targetStatus = b.toString();
    }

    if (empId == _employeeId) {
      final found = _allCompanyRequests.where((r) => r.id == reqId).firstOrNull;
      if (found != null && found.employeeId != null) {
        empId = found.employeeId!;
      }
    }

    final isHR = currentEmployee?.role == 'hr' ||
        currentEmployee?.role == 'admin' ||
        canEditCompanyInfo;
    final isSupervisor = currentEmployee?.role == 'supervisor';

    final existing = _allCompanyRequests.where((r) => r.id == reqId).firstOrNull ??
        _allRequestsMap[empId]?.where((r) => r.id == reqId).firstOrNull;
    final oldStatus = existing?.status;

    String finalStatus = targetStatus;
    String? supBy = existing?.supervisorActionBy;
    String? supDate = existing?.supervisorActionDate;
    String? supStatus = existing?.supervisorStatus;
    String? hrBy = existing?.hrActionBy;
    String? hrDate = existing?.hrActionDate;
    String? hrStatus = existing?.hrStatus;
    String? actBy = existing?.actionBy;
    String? actDate = existing?.actionDate;

    final nowIso = DateTime.now().toIso8601String();

    if (targetStatus == 'Rejected') {
      finalStatus = 'Rejected';
      if (isHR) {
        hrBy = _employeeId;
        hrDate = nowIso;
        hrStatus = 'Rejected';
      } else {
        supBy = _employeeId;
        supDate = nowIso;
        supStatus = 'Rejected';
      }
      actBy = _employeeId;
      actDate = nowIso;
    } else if (targetStatus == 'Approved') {
      // Check if the organization has an HR Manager
      final hasHRManager = _employees.any(
        (e) => (e.role == 'hr' || e.role == 'admin') && e.id != empId,
      );

      // If supervisor approves a request in 'Pending Supervisor' (or 'Pending')
      if (isSupervisor && !isHR && (existing?.status == 'Pending Supervisor' || existing?.status == 'Pending')) {
        if (hasHRManager) {
          finalStatus = 'Pending HR';
          supBy = _employeeId;
          supDate = nowIso;
          supStatus = 'Approved';
        } else {
          // If no HR Manager, just pass HR and approve directly!
          finalStatus = 'Approved';
          supBy = _employeeId;
          supDate = nowIso;
          supStatus = 'Approved';
          actBy = _employeeId;
          actDate = nowIso;
        }
      } else {
        // HR approves or final approval
        finalStatus = 'Approved';
        hrBy = _employeeId;
        hrDate = nowIso;
        hrStatus = 'Approved';
        actBy = _employeeId;
        actDate = nowIso;
      }
    } else if (targetStatus == 'Pending HR') {
      finalStatus = 'Pending HR';
      supBy = _employeeId;
      supDate = nowIso;
      supStatus = 'Approved';
    }

    Request? updatedReq;
    final reqs = _allRequestsMap[empId];
    if (reqs != null) {
      final idx = reqs.indexWhere((r) => r.id == reqId);
      if (idx != -1) {
        final old = reqs[idx];
        updatedReq = old.copyWith(
          status: finalStatus,
          employeeId: empId,
          actionBy: actBy,
          actionDate: actDate,
          supervisorActionBy: supBy,
          supervisorActionDate: supDate,
          supervisorStatus: supStatus,
          hrActionBy: hrBy,
          hrActionDate: hrDate,
          hrStatus: hrStatus,
        );
        reqs[idx] = updatedReq;
      }
    }

    final cIdx = _allCompanyRequests.indexWhere((r) => r.id == reqId);
    if (cIdx != -1) {
      final old = _allCompanyRequests[cIdx];
      updatedReq = old.copyWith(
        status: finalStatus,
        employeeId: empId,
        actionBy: actBy,
        actionDate: actDate,
        supervisorActionBy: supBy,
        supervisorActionDate: supDate,
        supervisorStatus: supStatus,
        hrActionBy: hrBy,
        hrActionDate: hrDate,
        hrStatus: hrStatus,
      );
      _allCompanyRequests[cIdx] = updatedReq;
    }

    notifyListeners();

    final reqForBalance = updatedReq ?? existing;
    if (reqForBalance != null) {
      if (finalStatus == 'Approved' && oldStatus != 'Approved') {
        await _adjustAnnualLeaveBalance(request: reqForBalance, empId: empId, isApproval: true);
      } else if (oldStatus == 'Approved' && finalStatus != 'Approved') {
        await _adjustAnnualLeaveBalance(request: reqForBalance, empId: empId, isApproval: false);
      }
    }

    if (updatedReq != null && _firebaseService.isAvailable) {
      await _firebaseService.saveRequest(empId, updatedReq);

      // Automated messages to the employee who registered the request:
      if (empId != _employeeId) {
        if (finalStatus == 'Approved') {
          // When request gets final approval
          final approvedByLabel = hrBy != null ? 'HR Management' : 'your Supervisor';
          String messageText =
              'Your request for ${updatedReq.type} on ${updatedReq.date} has been approved by $approvedByLabel.';
          if (updatedReq.type == 'Annual Leave') {
            final emp = _employees.where((e) => e.id == empId).firstOrNull;
            if (emp != null) {
              messageText += ' Remaining annual leave balance: ${emp.annualLeaveBalance.toStringAsFixed(1)} hours.';
            }
          }
          await sendChatMessage(empId, messageText);
        } else if (finalStatus == 'Pending HR') {
          // When Supervisor approves and it moves to HR Manager
          final messageText =
              'Your request for ${updatedReq.type} on ${updatedReq.date} has been approved by your Supervisor and forwarded to HR Manager for review.';
          await sendChatMessage(empId, messageText);
        } else if (finalStatus == 'Rejected') {
          final rejecter = isHR ? 'HR Management' : 'your Supervisor';
          final messageText =
              'Your request for ${updatedReq.type} on ${updatedReq.date} has been rejected by $rejecter.';
          await sendChatMessage(empId, messageText);
        }
      }
    }
  }

  // Clock & Attendance stubs
  Future<String?> verifyLocation() async {
    final emp = currentEmployee;
    if (emp == null) return 'No employee found.';

    List<Map<String, dynamic>> allowedZones = [];

    // Check structure
    if (emp.structureId != null) {
      try {
        final struct = _structures.firstWhere((s) => s.id == emp.structureId);
        if (struct.latitude != null &&
            struct.longitude != null &&
            struct.radius != null) {
          allowedZones.add({
            'lat': struct.latitude!,
            'lng': struct.longitude!,
            'radius': struct.radius!,
            'name': struct.name,
          });
        }
      } catch (_) {}
    }

    // Check group locations
    final String? groupId = getGroupIdForDate(emp, DateTime.now());
    if (groupId != null) {
      for (var loc in _locations) {
        if (loc.groupIds.contains(groupId)) {
          allowedZones.add({
            'lat': loc.latitude,
            'lng': loc.longitude,
            'radius': loc.radius,
            'name': loc.name,
          });
        }
      }
    }

    if (allowedZones.isEmpty) {
      return null; // If no zones are configured, skip location verification.
    }

    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return 'Location services are disabled. Please enable them.';
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return 'Location permissions are denied';
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return 'Location permissions are permanently denied, we cannot request permissions.';
    }

    Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (e) {
      return 'Failed to get current location: $e';
    }

    for (var zone in allowedZones) {
      double distanceInMeters = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        zone['lat'],
        zone['lng'],
      );
      if (distanceInMeters <= zone['radius']) {
        return null; // Inside an allowed zone
      }
    }

    return 'You are out of the allowed work zones. Please move closer to clock in/out.';
  }

  Future<String?> clockIn([dynamic a, dynamic b]) async {
    _isClockedIn = true;
    _activeRecord = AttendanceRecord(
      checkIn: DateTime.now(),
      employeeId: _employeeId,
    );
    // Add to local records list at the beginning (sorted newest first)
    _records.removeWhere(
      (r) =>
          r.checkIn.year == _activeRecord!.checkIn.year &&
          r.checkIn.month == _activeRecord!.checkIn.month &&
          r.checkIn.day == _activeRecord!.checkIn.day &&
          r.checkIn.hour == _activeRecord!.checkIn.hour &&
          r.checkIn.minute == _activeRecord!.checkIn.minute,
    );
    _records.insert(0, _activeRecord!);

    if (_firebaseService.isAvailable) {
      try {
        await _firebaseService.saveRecord(_employeeId, _activeRecord!);
      } catch (e) {
        debugPrint('Error saving clock in record to Firebase: $e');
      }
    }
    recalculateAllStats();
    notifyListeners();
    return null;
  }

  Future<String?> clockOut([dynamic a, dynamic b]) async {
    final now = DateTime.now();

    // If _activeRecord is null, locate the latest open record
    if (_activeRecord == null) {
      final openIdx = _records.indexWhere((r) => r.checkOut == null);
      if (openIdx != -1) {
        _activeRecord = _records[openIdx];
      }
    }

    if (_activeRecord != null) {
      _activeRecord = _activeRecord!.copyWith(
        checkOut: now,
        employeeId: _employeeId,
      );
      // Update it in the records list
      final idx = _records.indexWhere(
        (r) =>
            r.checkIn.year == _activeRecord!.checkIn.year &&
            r.checkIn.month == _activeRecord!.checkIn.month &&
            r.checkIn.day == _activeRecord!.checkIn.day &&
            r.checkIn.hour == _activeRecord!.checkIn.hour &&
            r.checkIn.minute == _activeRecord!.checkIn.minute,
      );
      if (idx != -1) {
        _records[idx] = _activeRecord!;
      } else {
        _records.insert(0, _activeRecord!);
      }
      if (_firebaseService.isAvailable) {
        try {
          await _firebaseService.saveRecord(_employeeId, _activeRecord!);
        } catch (e) {
          debugPrint('Error saving clock out record to Firebase: $e');
        }
      }
    } else {
      // Create a completed session for today
      _activeRecord = AttendanceRecord(
        checkIn: now.subtract(const Duration(hours: 1)),
        checkOut: now,
        employeeId: _employeeId,
      );
      _records.insert(0, _activeRecord!);
      if (_firebaseService.isAvailable) {
        try {
          await _firebaseService.saveRecord(_employeeId, _activeRecord!);
        } catch (e) {
          debugPrint('Error saving fallback clock out to Firebase: $e');
        }
      }
    }
    _isClockedIn = false;
    _activeRecord = null;
    recalculateAllStats();
    notifyListeners();
    return null;
  }

  /// Upsert an AttendanceRecord directly into local state for immediate reactivity
  void upsertRecordLocally(AttendanceRecord record) {
    final cleanEmpId = record.employeeId?.trim().toLowerCase();

    // 1. Update in _allCompanyRecords
    final idxAll = _allCompanyRecords.indexWhere((r) =>
        r.employeeId?.trim().toLowerCase() == cleanEmpId &&
        r.checkIn.year == record.checkIn.year &&
        r.checkIn.month == record.checkIn.month &&
        r.checkIn.day == record.checkIn.day &&
        r.checkIn.hour == record.checkIn.hour &&
        r.checkIn.minute == record.checkIn.minute);
    if (idxAll != -1) {
      _allCompanyRecords[idxAll] = record;
    } else {
      _allCompanyRecords.insert(0, record);
    }

    // 2. If for currently logged-in user, also update _records
    if (cleanEmpId != null && cleanEmpId == _employeeId.trim().toLowerCase()) {
      final idx = _records.indexWhere((r) =>
          r.checkIn.year == record.checkIn.year &&
          r.checkIn.month == record.checkIn.month &&
          r.checkIn.day == record.checkIn.day &&
          r.checkIn.hour == record.checkIn.hour &&
          r.checkIn.minute == record.checkIn.minute);
      if (idx != -1) {
        _records[idx] = record;
      } else {
        _records.insert(0, record);
      }
    }

    recalculateAllStats();
    notifyListeners();
  }

  /// Delete a punch session from local state and remote Firebase
  Future<void> deletePunchSession({
    required String employeeId,
    required AttendanceRecord record,
    String? reason,
  }) async {
    final cleanEmpId = employeeId.trim().toLowerCase();

    // 1. Remove from _allCompanyRecords
    _allCompanyRecords.removeWhere((r) =>
        (r.employeeId?.trim().toLowerCase() == cleanEmpId) &&
        r.checkIn.year == record.checkIn.year &&
        r.checkIn.month == record.checkIn.month &&
        r.checkIn.day == record.checkIn.day &&
        r.checkIn.hour == record.checkIn.hour &&
        r.checkIn.minute == record.checkIn.minute);

    // 2. Remove from _records if currently logged-in user
    if (cleanEmpId == _employeeId.trim().toLowerCase()) {
      _records.removeWhere((r) =>
          r.checkIn.year == record.checkIn.year &&
          r.checkIn.month == record.checkIn.month &&
          r.checkIn.day == record.checkIn.day &&
          r.checkIn.hour == record.checkIn.hour &&
          r.checkIn.minute == record.checkIn.minute);
    }

    recalculateAllStats();
    notifyListeners();

    // 3. Delete from Firebase
    if (_firebaseService.isAvailable) {
      await _firebaseService.deleteRecord(employeeId, record);
    }
  }

  // HR Management
  List<CompanyEmployee> getEmployeesInStructure(dynamic structId) {
    return _employees.where((e) => e.structureId == structId).toList();
  }

  Future<void> deleteStructure(dynamic id) async =>
      await _firebaseService.deleteStructure(id);
  Future<void> updateStructure(dynamic struct) async =>
      await _firebaseService.saveStructure(struct);
  Future<void> addStructure(dynamic struct) async =>
      await _firebaseService.saveStructure(struct);

  Future<void> deleteShift(dynamic id) async =>
      await _firebaseService.deleteShift(id);
  Future<void> updateShift(dynamic shift) async =>
      await _firebaseService.saveShift(shift);
  Future<void> addShift(dynamic shift) async =>
      await _firebaseService.saveShift(shift);

  Future<void> deleteGroup(dynamic id) async =>
      await _firebaseService.deleteGroup(id);
  Future<void> updateGroup(dynamic group) async =>
      await _firebaseService.saveGroup(group);
  Future<void> addGroup(dynamic group) async =>
      await _firebaseService.saveGroup(group);

  Future<void> deleteEmployee(dynamic id) async {
    final strId = id.toString();
    _employees.removeWhere((e) => e.id == strId);
    notifyListeners();
    await _firebaseService.deleteEmployee(strId);
  }

  /// Generates the next sequential numeric user ID ('1', '2', '3', ...).
  String getNextEmployeeId() {
    int maxId = 0;
    for (final emp in _employees) {
      final cleanId = emp.id.trim();
      // 1. Direct integer parse
      final directNum = int.tryParse(cleanId);
      if (directNum != null) {
        // Exclude massive timestamp values (e.g. > 1,000,000)
        if (directNum > maxId && directNum < 1000000) {
          maxId = directNum;
        }
        continue;
      }

      // 2. Prefixed integer parse like emp_1, emp_2, USR_3
      final matches = RegExp(r'\d+').allMatches(cleanId);
      for (final m in matches) {
        final val = int.tryParse(m.group(0)!);
        if (val != null && val > maxId && val < 1000000) {
          maxId = val;
        }
      }
    }
    return (maxId + 1).toString();
  }

  Future<void> updateEmployee(dynamic emp, {String? oldId}) async {
    if (emp is CompanyEmployee) {
      final targetOldId = (oldId != null && oldId.trim().isNotEmpty) ? oldId.trim() : emp.id;
      final isIdChanged = targetOldId != emp.id;

      if (isIdChanged) {
        // Remove old entry
        _employees.removeWhere((e) => e.id == targetOldId);
        final newIndex = _employees.indexWhere((e) => e.id == emp.id);
        if (newIndex != -1) {
          _employees[newIndex] = emp;
        } else {
          _employees.add(emp);
        }

        // Update current employeeId and avatar if this was the logged-in user
        if (_employeeId == targetOldId) {
          _employeeId = emp.id;
          _avatarPath = emp.avatarUrl;
        }

        // Migrate local requests map
        final oldReqs = _allRequestsMap.remove(targetOldId);
        if (oldReqs != null) {
          _allRequestsMap[emp.id] = oldReqs.map((r) => r.copyWith(employeeId: emp.id)).toList();
        }

        // Migrate local records if active
        final updatedList = _records.map((r) {
          if (r.employeeId == targetOldId) {
            return r.copyWith(employeeId: emp.id);
          }
          return r;
        }).toList();
        _records.clear();
        _records.addAll(updatedList);

        notifyListeners();

        // Migrate remote Firebase data
        await _firebaseService.migrateEmployeeId(targetOldId, emp.id);
        await _firebaseService.deleteEmployee(targetOldId);
        await _firebaseService.saveEmployee(emp);
      } else {
        final index = _employees.indexWhere((e) => e.id == emp.id);
        if (index != -1) {
          _employees[index] = emp;
        } else {
          _employees.add(emp);
        }
        if (emp.id == _employeeId) {
          _avatarPath = emp.avatarUrl;
        }
        notifyListeners();
        await _firebaseService.saveEmployee(emp);
      }
    }
  }

  Future<void> addEmployee(dynamic emp) async {
    if (emp is CompanyEmployee) {
      var toAdd = emp;
      // If no ID or auto-generated epoch timestamp ID, assign sequential simple number
      if (toAdd.id.trim().isEmpty ||
          (toAdd.id.startsWith('emp_') && toAdd.id.length > 10) ||
          (toAdd.id.startsWith('USR_') && toAdd.id.length > 10)) {
        toAdd = toAdd.copyWith(id: getNextEmployeeId());
      }

      final index = _employees.indexWhere((e) => e.id == toAdd.id);
      if (index != -1) {
        _employees[index] = toAdd;
      } else {
        _employees.add(toAdd);
      }
      notifyListeners();
      await _firebaseService.saveEmployee(toAdd);
    }
  }

  /// Re-sequences all employee IDs to simple numbers 1, 2, 3... in sequence.
  Future<void> resequenceEmployeeIds() async {
    // Sort employees: keep order of existing numeric IDs or startDate
    final sorted = List<CompanyEmployee>.from(_employees);
    sorted.sort((a, b) {
      final numA = int.tryParse(a.id) ?? int.tryParse(a.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 999999;
      final numB = int.tryParse(b.id) ?? int.tryParse(b.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 999999;
      if (numA != numB) return numA.compareTo(numB);
      return a.startDate.compareTo(b.startDate);
    });

    int sequence = 1;
    for (final emp in sorted) {
      // Don't modify super admin account if present
      if (emp.id == 'admin_super_account') continue;

      final newId = sequence.toString();
      sequence++;

      if (emp.id != newId) {
        final oldId = emp.id;
        final updatedEmp = emp.copyWith(id: newId);
        await updateEmployee(updatedEmp, oldId: oldId);
      }
    }
  }

  Future<void> restoreSuperAdminUser() async {
    final superAdmin = CompanyEmployee(
      id: 'admin_super_account',
      name: 'Super Admin',
      email: 'admin@company.com',
      position: 'Super Administrator',
      role: 'admin',
      password: 'admin123',
      startDate: DateTime.now().toIso8601String().split('T')[0],
      positionStartDate: DateTime.now().toIso8601String().split('T')[0],
      groupStartDate: DateTime.now().toIso8601String().split('T')[0],
      positionHistory: [],
      groupHistory: [],
      salaryHistory: [],
    );
    await addEmployee(superAdmin);
  }

  Future<void> deleteHoliday(dynamic id) async =>
      await _firebaseService.deleteHoliday(id);
  Future<void> updateHoliday(dynamic holiday) async =>
      await _firebaseService.saveHoliday(holiday);
  Future<void> addHoliday(dynamic holiday) async =>
      await _firebaseService.saveHoliday(holiday);

  Future<void> deleteLocation(dynamic id) async =>
      await _firebaseService.deleteLocation(id);
  Future<void> updateLocation(dynamic loc) async =>
      await _firebaseService.saveLocation(loc);
  Future<void> addLocation(dynamic loc) async =>
      await _firebaseService.saveLocation(loc);

  final FaceRecognitionService _faceService = FaceRecognitionService();

  /// Check if the provided face embedding matches any other employee
  CompanyEmployee? findDuplicateFaceEmployee(
    List<double> embedding, {
    String? excludeEmployeeId,
    double threshold = 1.05,
  }) {
    final cleanExclude = excludeEmployeeId?.toString().trim();
    for (final emp in _employees) {
      if (cleanExclude != null && cleanExclude.isNotEmpty && emp.id == cleanExclude) {
        continue;
      }
      if (emp.faceEmbedding == null || emp.faceEmbedding!.isEmpty) {
        continue;
      }
      final dist = _faceService.calculateEuclideanDistance(emp.faceEmbedding!, embedding);
      if (dist < threshold) {
        return emp;
      }
    }
    return null;
  }

  Future<void> updateEmployeeFaceEmbedding(
    dynamic empId,
    List<double>? embedding,
  ) async {
    if (!isHRManager) {
      throw Exception('PERMISSION_DENIED: Only HR Managers can register or delete Face ID.');
    }
    final strId = empId.toString().trim();
    if (embedding != null && embedding.isNotEmpty) {
      final duplicate = findDuplicateFaceEmployee(embedding, excludeEmployeeId: strId);
      if (duplicate != null) {
        throw Exception('DUPLICATE_FACE:${duplicate.name}');
      }
    }

    final index = _employees.indexWhere((e) => e.id == strId);
    if (index != -1) {
      final updated = _employees[index].copyWith(
        faceEmbedding: embedding,
        overrideFaceEmbedding: true,
      );
      await updateEmployee(updated);
    }
  }
  dynamic getHolidayForEmployee(dynamic emp, dynamic date) => null;
  dynamic getApprovedLeaveForDate(dynamic date, {dynamic employeeId}) => null;

  // Chat implementation
  List<CompanyEmployee> getSupervisorsFor(dynamic empId) {
    try {
      final emp = _employees.firstWhere((e) => e.id == empId);
      if (emp.structureId == null) return [];

      final struct = _structures.firstWhere((s) => s.id == emp.structureId);
      if (struct.supervisorId == null) return [];

      return _employees.where((e) => e.id == struct.supervisorId).toList();
    } catch (_) {
      return [];
    }
  }

  List<ChatMessage> getMessagesWith(dynamic otherId) {
    final cId = otherId.toString();
    ensureChatLoaded(cId);
    return _chatMessagesMap[cId] ?? [];
  }

  Future<void> markMessagesAsRead(dynamic otherId) async {
    final cId = otherId.toString().trim().toLowerCase();
    final myId = _employeeId.trim().toLowerCase();
    if (cId.isEmpty || myId.isEmpty) return;

    // Find the relevant message list
    String? matchedKey;
    List<ChatMessage>? messages = _chatMessagesMap[otherId.toString()];
    if (messages != null) {
      matchedKey = otherId.toString();
    } else {
      for (var entry in _chatMessagesMap.entries) {
        if (entry.key.trim().toLowerCase() == cId) {
          messages = entry.value;
          matchedKey = entry.key;
          break;
        }
      }
    }

    if (messages == null || matchedKey == null) return;

    final unreadMessages = messages
        .where((m) => m.receiverId.trim().toLowerCase() == myId && !m.isRead)
        .toList();
    if (unreadMessages.isEmpty) return;

    // Update in-memory first to avoid infinite callback loop
    for (int i = 0; i < messages.length; i++) {
      if (messages[i].receiverId.trim().toLowerCase() == myId && !messages[i].isRead) {
        messages[i] = messages[i].copyWith(isRead: true);
      }
    }
    notifyListeners();

    if (_firebaseService.isAvailable) {
      for (var m in unreadMessages) {
        await _firebaseService.saveChatMessage(m.copyWith(isRead: true));
      }
    }
  }

  Future<void> markAllChatMessagesAsRead() async {
    final myId = _employeeId.trim().toLowerCase();
    if (myId.isEmpty) return;

    final List<ChatMessage> toUpdateInFirestore = [];
    for (var list in _chatMessagesMap.values) {
      for (int i = 0; i < list.length; i++) {
        if (list[i].receiverId.trim().toLowerCase() == myId && !list[i].isRead) {
          final updated = list[i].copyWith(isRead: true);
          list[i] = updated;
          toUpdateInFirestore.add(updated);
        }
      }
    }

    if (toUpdateInFirestore.isNotEmpty) {
      notifyListeners();
      if (_firebaseService.isAvailable) {
        for (var m in toUpdateInFirestore) {
          await _firebaseService.saveChatMessage(m);
        }
      }
    }
  }

  Request? getRequestById(dynamic reqId, [dynamic b]) => null;

  Future<void> sendChatMessage(
    dynamic receiverId, [
    dynamic text,
    dynamic c,
  ]) async {
    final msgStr = text?.toString() ?? '';
    if (msgStr.isEmpty) return;

    final rId = receiverId.toString();
    ensureChatLoaded(rId);

    final newMsg = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      senderId: _employeeId,
      receiverId: rId,
      text: msgStr,
      timestamp: DateTime.now(),
    );

    if (_chatMessagesMap[rId] == null) {
      _chatMessagesMap[rId] = [];
    }
    if (!_chatMessagesMap[rId]!.any((m) => m.id == newMsg.id)) {
      _chatMessagesMap[rId]!.add(newMsg);
      notifyListeners();
    }

    if (_firebaseService.isAvailable) {
      await _firebaseService.saveChatMessage(newMsg);

      // Trigger push notification to receiver's device
      try {
        CompanyEmployee? receiverEmp;
        try {
          receiverEmp = _employees.firstWhere(
            (e) => e.id.trim().toLowerCase() == rId.trim().toLowerCase(),
          );
        } catch (_) {}

        if (receiverEmp != null && receiverEmp.fcmToken != null && receiverEmp.fcmToken!.isNotEmpty) {
          final senderName = _userName.isNotEmpty ? _userName : 'Colleague';
          FcmPushService.sendNotification(
            targetFcmToken: receiverEmp.fcmToken!,
            title: 'Message from $senderName',
            body: msgStr,
            data: {
              'type': 'chat_message',
              'senderId': _employeeId,
              'senderName': senderName,
              'receiverId': rId,
            },
          );
        }
      } catch (e) {
        debugPrint('Error triggering direct FCM push for chat: $e');
      }
    }
  }
}

class PayrollReport {
  final CompanyEmployee employee;
  final double basicSalary;
  final double salaryCalcByDay;
  final double workingHours;
  final int daysWorked;
  final double incrementalSalary;
  final double decrementalSalary;
  final double overtimeHours;
  final double overtimeValue;
  final double attendanceDeficitHours;
  final double attendanceDeficit;
  final double monthlyPenalties;
  final double foodAllowance;
  final double transportationAllowance;
  final double otherAllowance;
  final double monthlyAdditions;
  final double monthlyDeductions;
  final List<PayrollAdjustment> adjustments;
  final double netEarnings;
  final String currency;

  PayrollReport({
    required this.employee,
    required this.basicSalary,
    this.salaryCalcByDay = 0.0,
    required this.workingHours,
    required this.daysWorked,
    required this.incrementalSalary,
    required this.decrementalSalary,
    this.overtimeHours = 0.0,
    required this.overtimeValue,
    this.attendanceDeficitHours = 0.0,
    required this.attendanceDeficit,
    required this.monthlyPenalties,
    required this.foodAllowance,
    required this.transportationAllowance,
    required this.otherAllowance,
    this.monthlyAdditions = 0.0,
    this.monthlyDeductions = 0.0,
    this.adjustments = const [],
    required this.netEarnings,
    required this.currency,
  });
}
