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

class AttendanceProvider with ChangeNotifier {
  // User Profile Data
  String _userName = 'Jane Smith';
  String _userTitle = 'HR Manager';
  String _employeeId = 'emp_2'; // Aligned to emp_2 (HR Manager) to match Firestore seed
  String _email = 'jane.smith@company.com';
  String _department = 'Human Resources';
  String _position = 'HR Manager';
  String? _avatarPath;

  final FirebaseService _firebaseService = FirebaseService();
  final Map<String, List<Request>> _allRequestsMap = {};
  String _currentLanguage = 'en';
  bool _isLoading = false;
  bool _isLoggedIn = false;
  final List<StreamSubscription> _subscriptions = [];

  bool get isLoggedIn => _isLoggedIn;

  void _syncCurrentEmployeeInfo() {
    if (_employees.isNotEmpty) {
      CompanyEmployee? match;
      try {
        match = _employees.firstWhere((e) => e.id == _employeeId);
      } catch (_) {
        match = _employees.first;
        _employeeId = match.id;
      }
      _userName = match.name;
      _userTitle = match.position;
      _position = match.position;
      _email = match.email;
      _department = match.position;
    }
  }

  Future<void> _saveAuthSession(bool loggedIn, String empId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', loggedIn);
      if (loggedIn) {
        await prefs.setString('loggedInEmployeeId', empId);
      } else {
        await prefs.remove('loggedInEmployeeId');
      }
    } catch (e) {
      debugPrint('Error saving auth session: $e');
    }
  }

  Future<void> _loadAuthSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedInSaved = prefs.getBool('isLoggedIn') ?? false;
      final savedEmployeeId = prefs.getString('loggedInEmployeeId');

      if (isLoggedInSaved) {
        _isLoggedIn = true;
        if (savedEmployeeId != null && savedEmployeeId.isNotEmpty) {
          _employeeId = savedEmployeeId;
          _syncCurrentEmployeeInfo();
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading auth session: $e');
    }
  }

  Future<bool> login({required String identifier, required String password}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final input = identifier.trim().toLowerCase();
      final matchIndex = _employees.indexWhere(
        (e) =>
            e.email.toLowerCase() == input ||
            e.id.toLowerCase() == input ||
            e.name.toLowerCase() == input,
      );

      if (matchIndex != -1) {
        final match = _employees[matchIndex];
        _employeeId = match.id;
        _userName = match.name;
        _userTitle = match.position;
        _position = match.position;
        _email = match.email;
        _isLoggedIn = true;
        _isLoading = false;
        await _saveAuthSession(true, _employeeId);
        notifyListeners();
        return true;
      }

      // If no exact match or in offline mode, allow demo login
      if (_employees.isNotEmpty) {
        final defaultEmp = _employees.first;
        await loginAsEmployee(defaultEmp);
        _isLoading = false;
        return true;
      } else {
        _isLoggedIn = true;
        _isLoading = false;
        await _saveAuthSession(true, _employeeId);
        notifyListeners();
        return true;
      }
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
    _isLoggedIn = true;
    await _saveAuthSession(true, _employeeId);
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
    for (var messages in _chatMessagesMap.values) {
      if (messages.any((m) => m.receiverId == _employeeId && !m.isRead)) {
        count++;
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
    for (var messages in _chatMessagesMap.values) {
      if (messages.any((m) => m.receiverId == _employeeId && !m.isRead)) {
        return true;
      }
    }
    return false;
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
  CompanyProfile? _companyProfile;

  // Getters
  String get userName => _userName;
  String get userTitle => _userTitle;
  String get employeeId => _employeeId;
  String get email => _email;
  String get department => _department;
  String get position => _position;
  String? get avatarPath => _avatarPath;

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
      final emps = _employees.where((e) => e.id != supervisor.id && e.structureId == structId);
      for (var e in emps) {
        if (subordinateIds.add(e.id)) {
          subordinates.add(e);
        }
      }
    }
    
    // Co-workers in same structure if supervisor is just regular employee (wait, only supervisors)
    if (supervisor.structureId != null && supervisor.structureId!.isNotEmpty) {
      final emps = _employees.where((e) => e.id != supervisor.id && e.structureId == supervisor.structureId && e.role == 'employee');
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

  bool get isDarkMode => (currentEmployee?.themePreference ?? 'dark') == 'dark';

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

  void setLanguage(String langCode) {
    _currentLanguage = langCode;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    final emp = currentEmployee;
    if (emp == null) return;
    
    final newPreference = isDarkMode ? 'light' : 'dark';
    final updatedEmp = emp.copyWith(themePreference: newPreference);
    
    final index = _employees.indexWhere((e) => e.id == emp.id);
    if (index != -1) {
      _employees[index] = updatedEmp;
    }
    
    await _firebaseService.saveEmployee(updatedEmp);
    notifyListeners();
  }

  AttendanceProvider() {
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

    // Seed empty Firestore tables with timeout
    try {
      await _firebaseService
          .seedDefaultMockData(
            structures: _structures,
            shifts: _shifts,
            groups: _groups,
            employees: _employees,
            userRecords: _records,
            testUserId: _employeeId,
            userRequests: defaultRequests,
            locations: _locations,
          )
          .timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('Seeding Firestore database timed out or failed: $e');
    }

    // 2. Query Firestore and update state
    try {
      await _setupFirestoreListeners();
    } catch (e) {
      debugPrint('Error loading data from Firestore: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _setupFirestoreListeners() async {
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();

    try {
      _subscriptions.add(_firebaseService.streamCompanyProfile().listen((data) {
        _companyProfile = data;
        notifyListeners();
      }));

      _subscriptions.add(_firebaseService.streamStructures().listen((data) {
        _structures.clear();
        _structures.addAll(data);
        loadChatsForCurrentUser();
        notifyListeners();
      }));

      _subscriptions.add(_firebaseService.streamShifts().listen((data) {
        _shifts.clear();
        _shifts.addAll(data);
        notifyListeners();
      }));

      _subscriptions.add(_firebaseService.streamGroups().listen((data) {
        _groups.clear();
        _groups.addAll(data);
        notifyListeners();
      }));

      _subscriptions.add(_firebaseService.streamEmployees().listen((data) {
        _employees.clear();
        _employees.addAll(data);
        _syncCurrentEmployeeInfo();
        _avatarPath = currentEmployee?.avatarUrl;
        loadChatsForCurrentUser();
        notifyListeners();
      }));

      _subscriptions.add(_firebaseService.streamHolidays().listen((data) {
        _holidays.clear();
        _holidays.addAll(data);
        notifyListeners();
      }));

      _subscriptions.add(_firebaseService.streamLocations().listen((data) {
        _locations.clear();
        _locations.addAll(data);
        notifyListeners();
      }));

      _subscriptions.add(_firebaseService.streamUserRecords(_employeeId).listen((data) {
        _records.clear();
        _records.addAll(data);
        _restoreActiveRecordFromRecords();
        recalculateAllStats();
        notifyListeners();
      }));

      _subscriptions.add(_firebaseService.streamUserRequests(_employeeId).listen((data) {
        _allRequestsMap[_employeeId] = data;
        notifyListeners();
      }));

      _subscriptions.add(_firebaseService.streamAllRecords().listen((data) {
        _allCompanyRecords.clear();
        _allCompanyRecords.addAll(data);
        notifyListeners();
      }));

      try {
        final initialRequests = await _firebaseService.getAllRequests();
        if (initialRequests.isNotEmpty) {
          _allCompanyRequests.clear();
          _allCompanyRequests.addAll(initialRequests);
          for (var req in initialRequests) {
            if (req.employeeId != null) {
              _allRequestsMap[req.employeeId!] ??= [];
              final existingIdx =
                  _allRequestsMap[req.employeeId!]!.indexWhere((r) => r.id == req.id);
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

      _subscriptions.add(_firebaseService.streamAllRequests().listen((data) {
        _allCompanyRequests.clear();
        _allCompanyRequests.addAll(data);
        for (var req in data) {
          if (req.employeeId != null) {
            _allRequestsMap[req.employeeId!] ??= [];
            final existingIdx =
                _allRequestsMap[req.employeeId!]!.indexWhere((r) => r.id == req.id);
            if (existingIdx != -1) {
              _allRequestsMap[req.employeeId!]![existingIdx] = req;
            } else {
              _allRequestsMap[req.employeeId!]!.add(req);
            }
          }
        }
        notifyListeners();
      }));

      await loadChatsForCurrentUser();
      if (!kIsWeb) {
        await _setupPushNotifications();
      }
    } catch (e) {
      debugPrint('Error setting up Firestore listeners: $e');
      rethrow;
    }
  }

  final FlutterLocalNotificationsPlugin _localNotificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> _setupPushNotifications() async {
    if (kIsWeb) return;
    try {
      final messaging = FirebaseMessaging.instance;
      
      // Request permission
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      
      // Initialize local notifications for foreground
      const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings();
      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );
      await _localNotificationsPlugin.initialize(
        settings: initializationSettings,
      );
      
      // Get token
      String? token = await messaging.getToken();
      if (token != null && currentEmployee != null && currentEmployee!.fcmToken != token) {
        final updatedEmp = currentEmployee!.copyWith(fcmToken: token, overrideFcmToken: true);
        await updateEmployee(updatedEmp);
      }
      
      // Listen to token refresh
      messaging.onTokenRefresh.listen((newToken) async {
        if (currentEmployee != null && currentEmployee!.fcmToken != newToken) {
          final updatedEmp = currentEmployee!.copyWith(fcmToken: newToken, overrideFcmToken: true);
          await updateEmployee(updatedEmp);
        }
      });
      
      // Setup foreground notification display
      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        debugPrint('Got a message whilst in the foreground!');
        debugPrint('Message data: ${message.data}');
        
        if (message.notification != null) {
          debugPrint('Message also contained a notification: ${message.notification}');
          
          const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
            'chat_channel_id',
            'Chat Messages',
            importance: Importance.max,
            priority: Priority.high,
          );
          const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);
          
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
            final contact =
                _employees.where((e) => e.id == senderId).firstOrNull;
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
      const NotificationDetails platformDetails =
          NotificationDetails(android: androidDetails);

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
            r.checkIn.year == now.year &&
            r.checkIn.month == now.month &&
            r.checkIn.day == now.day,
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
      DateTime? end = entry.endDate != null ? DateTime.parse(entry.endDate!) : null;

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
      basicSalary: emp.basicSalary > 0 ? emp.basicSalary : 3240.0,
      workingHours: emp.workingHours > 0 ? emp.workingHours : 160.0,
      currency: emp.salaryCurrency,
      startDate: '',
      foodAllowance: emp.foodAllowance,
      transportationAllowance: emp.transportationAllowance,
      otherAllowance: emp.otherAllowance,
    );
  }
  PayrollReport generatePayrollReport(CompanyEmployee emp, DateTime targetMonth, {List<AttendanceRecord>? customRecords}) {
    final config = getActiveSalaryConfig(emp, targetMonth);
    final basicSalary = config.basicSalary;
    final configWorkingHours = config.workingHours > 0 ? config.workingHours : 160.0;
    final hourlyRate = configWorkingHours > 0 ? (basicSalary / configWorkingHours) : 0.0;
    final currency = config.currency;

    final foodAllowance = config.foodAllowance;
    final transportationAllowance = config.transportationAllowance;
    final otherAllowance = config.otherAllowance;
    final totalAllowances = foodAllowance + transportationAllowance + otherAllowance;

    // We will look up the group & shift per-day inside the loop.


    // Records for this employee
    final employeeRecords = customRecords ?? ((emp.id == _employeeId)
        ? _records
        : <AttendanceRecord>[]);
    final employeeRequests = _allRequestsMap[emp.id] ?? [];

    final daysInMonth = DateUtils.getDaysInMonth(targetMonth.year, targetMonth.month);
    
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
      final shift = _shifts.firstWhere(
        (s) => s.id == group.shiftId,
        orElse: () => WorkShift(
          id: '',
          name: 'Default Shift',
          startTime: '09:00',
          endTime: '17:00',
        ),
      );

      final isWorkingDay = shift.isWorkingDay(date);

      // Get records on this day
      final dayRecords = employeeRecords.where((r) =>
        r.checkIn.year == date.year &&
        r.checkIn.month == date.month &&
        r.checkIn.day == date.day
      ).toList();

      final hasRecord = dayRecords.isNotEmpty;

      // Approved requests on this day
      final dateStr = DateFormat('MMMM d, yyyy').format(date);
      final dayApprovedRequests = employeeRequests.where((req) =>
        req.status == 'Approved' &&
        (req.date == dateStr || req.date.contains(DateFormat('MMMM d').format(date)))
      ).toList();

      final hasLeave = dayApprovedRequests.any((r) =>
        r.type == 'Annual Leave' || r.type == 'Sick Leave' || r.type == 'Hourly Leave'
      );
      final hasApprovedOt = dayApprovedRequests.any((r) => r.type == 'Overtime Approval');

      final holiday = _holidays.firstWhere(
        (h) {
          final isForGroup = h.groupIds.isEmpty || (emp.groupId != null && h.groupIds.contains(emp.groupId));
          if (!isForGroup) return false;
          try {
            final from = DateTime.parse(h.fromDate).subtract(const Duration(days: 1));
            final to = DateTime.parse(h.toDate).add(const Duration(days: 1));
            return date.isAfter(from) && date.isBefore(to);
          } catch (_) {
            return false;
          }
        },
        orElse: () => Holiday(id: '', name: '', fromDate: '2099-01-01', toDate: '2099-01-01'),
      );
      final isHoliday = holiday.id.isNotEmpty;

      if (hasRecord) {
        daysWorked++;
        int dayDuty = 0;
        int dayExtra = 0;

        final startTimeStr = shift.getStartTimeForDate(date);
        final endTimeStr = shift.getEndTimeForDate(date);
        final sParts = startTimeStr.split(':');
        final eParts = endTimeStr.split(':');
        final shiftStartMins = sParts.length >= 2 ? int.parse(sParts[0]) * 60 + int.parse(sParts[1]) : 540;
        final shiftEndMins = eParts.length >= 2 ? int.parse(eParts[0]) * 60 + int.parse(eParts[1]) : 1020;

        for (var rec in dayRecords) {
          final rawIn = rec.checkIn;
          final rawOut = rec.checkOut ?? rawIn;
          final cIn = DateTime(rawIn.year, rawIn.month, rawIn.day, rawIn.hour, rawIn.minute);
          final cOut = DateTime(rawOut.year, rawOut.month, rawOut.day, rawOut.hour, rawOut.minute);

          final shiftStart = DateTime(date.year, date.month, date.day, shiftStartMins ~/ 60, shiftStartMins % 60);
          var shiftEnd = DateTime(date.year, date.month, date.day, shiftEndMins ~/ 60, shiftEndMins % 60);
          if (shiftEnd.isBefore(shiftStart)) {
            shiftEnd = shiftEnd.add(const Duration(days: 1));
          }

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
        }

        totalDutyMinutes += dayDuty;

        // Delay & Early Exit
        int dayDelay = 0;
        int dayEarlyExit = 0;
        int unexcusedRestMinutes = 0;
        if (isWorkingDay && !hasLeave && !isHoliday) {
          final sorted = List<AttendanceRecord>.from(dayRecords)..sort((a, b) => a.checkIn.compareTo(b.checkIn));
          final firstRec = sorted.first;
          final checkInMins = firstRec.checkIn.hour * 60 + firstRec.checkIn.minute;
          final delay = checkInMins - shiftStartMins;
          if (delay > shift.forgivenessOfDelay) {
            dayDelay = delay;
          }

          final lastRec = sorted.last;
          if (lastRec.checkOut != null) {
            final checkOutMins = lastRec.checkOut!.hour * 60 + lastRec.checkOut!.minute;
            final earlyExit = shiftEndMins - checkOutMins;
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

          if (sorted.length > 1) {
            for (int i = 0; i < sorted.length - 1; i++) {
              final currentOut = sorted[i].checkOut;
              final nextIn = sorted[i+1].checkIn;
              if (currentOut != null && nextIn.isAfter(currentOut)) {
                final gapDuration = nextIn.difference(currentOut).inMinutes;
                
                if (bStart != null && bEnd != null) {
                  final intersectStart = currentOut.isAfter(bStart) ? currentOut : bStart;
                  final intersectEnd = nextIn.isBefore(bEnd) ? nextIn : bEnd;
                  
                  int excusedInGap = 0;
                  if (intersectEnd.isAfter(intersectStart)) {
                    excusedInGap = intersectEnd.difference(intersectStart).inMinutes;
                  }
                  
                  if (totalExcusedRestMinutes + excusedInGap > allowedBreakDuration) {
                    excusedInGap = allowedBreakDuration - totalExcusedRestMinutes;
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
          if (dayDelay >= group.delayTier1Min && dayDelay <= group.delayTier1Max) {
            delayPenalty = group.delayTier1Penalty;
          } else if (dayDelay >= group.delayTier2Min && dayDelay <= group.delayTier2Max) {
            delayPenalty = group.delayTier2Penalty;
          } else if (dayDelay >= group.delayTier3Min) {
            delayPenalty = group.delayTier3Penalty;
          }
        }

        double earlyExitPenalty = 0.0;
        if (dayEarlyExit > 0 && group.earlyExitPenaltiesEnabled) {
          if (dayEarlyExit >= group.earlyExitTier1Min && dayEarlyExit <= group.earlyExitTier1Max) {
            earlyExitPenalty = group.earlyExitTier1Penalty;
          } else if (dayEarlyExit >= group.earlyExitTier2Min && dayEarlyExit <= group.earlyExitTier2Max) {
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
              totalOvertimeMinutes += (baseOt * group.weekendOvertimeRatio).toInt();
            } else {
              totalOvertimeMinutes += baseOt;
            }
          }
        }

        // Deficit on active day
        int dayDeficit = dayDelay + dayEarlyExit + unexcusedRestMinutes;
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

    final double incrementalSalary = salaryCalcByDay + overtimeValue + (daysWorked > 0 ? totalAllowances : 0.0);
    final double decrementalSalary = attendanceDeficit + totalPenalties;
    final double netEarnings = (incrementalSalary - decrementalSalary).clamp(0.0, double.infinity);

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
      incrementalSalary: incrementalSalary,
      decrementalSalary: decrementalSalary,
      netEarnings: netEarnings,
      currency: currency,
    );
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
    _hourlyRate = config.workingHours > 0 ? (config.basicSalary / config.workingHours) : 0.0;
  }
  void _initializeMockData() {}
  void _initializeHRMockData() {}
  void _initializeMockChats() {}
  void _initializeMockRequests() {}
  List<CompanyEmployee> getChatContacts(CompanyEmployee currentUser) {
    List<CompanyEmployee> contacts = [];
    final Set<String> contactIds = {};

    if (currentUser.role == 'hr') {
      contacts = _employees.where((e) => e.id != currentUser.id).toList();
      for (var c in contacts) {
        contactIds.add(c.id);
      }
    } else if (currentUser.role == 'supervisor') {
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

      // Include HR managers so supervisors can communicate with HR
      final hrEmps = _employees.where(
        (e) => e.role == 'hr' && e.id != currentUser.id,
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

      // Plus HR managers
      final hrEmps = _employees.where(
        (e) => e.role == 'hr' && e.id != currentUser.id,
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
                _showLocalChatNotification(contactName, newMsg.text, senderId: cId);
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
    if (_firebaseService.isAvailable) {
      final fetched = await _firebaseService.getUserRecords(empId);
      if (fetched.isNotEmpty) {
        return fetched;
      }
    }
    final fromAll = _allCompanyRecords.where((r) => r.employeeId == empId).toList();
    if (fromAll.isNotEmpty) {
      return fromAll;
    }
    if (empId == _employeeId) {
      return _records;
    }
    return [];
  }

  int get pendingApprovalsCount {
    if (currentEmployee?.role == 'hr' ||
        currentEmployee?.role == 'admin' ||
        canEditCompanyInfo) {
      return _allCompanyRequests
          .where((r) => r.status == 'Pending' && r.employeeId != _employeeId)
          .length;
    }
    if (currentEmployee?.role == 'supervisor') {
      final subordinateIds = _structures
          .where((s) => s.supervisorId == _employeeId)
          .expand((s) => _employees.where((e) => e.structureId == s.id).map((e) => e.id))
          .toSet();
      return _allCompanyRequests
          .where((r) => r.status == 'Pending' && subordinateIds.contains(r.employeeId))
          .length;
    }
    return 0;
  }

  Future<List<Request>> getEmployeeRequests(String empId) async {
    if (_firebaseService.isAvailable) {
      final fetched = await _firebaseService.getUserRequests(empId);
      if (fetched.isNotEmpty) {
        _allRequestsMap[empId] = fetched;
        return fetched;
      }
    }
    final fromAll = _allCompanyRequests.where((r) => r.employeeId == empId).toList();
    if (fromAll.isNotEmpty) {
      _allRequestsMap[empId] = fromAll;
      return fromAll;
    }
    return _allRequestsMap[empId] ?? [];
  }

  List<Request> getRequestsForEmployee(String empId) => _allRequestsMap[empId] ?? [];

  // Profile screen stubs
  Future<void> updateProfileImage(dynamic file) async {}
  Future<void> switchProfile(String userId) async {
    final emp = _employees.firstWhere((e) => e.id == userId, orElse: () => _employees.first);
    _employeeId = emp.id;
    _userName = emp.name;
    _userTitle = emp.position;
    _email = emp.email;
    _department = emp.structureId ?? '';
    _position = emp.position;
    
    _records.clear();
    _isClockedIn = false;
    _activeRecord = null;

    for (var sub in _chatSubscriptionsMap.values) {
      sub.cancel();
    }
    _chatSubscriptionsMap.clear();
    _chatMessagesMap.clear();

    // Restart listeners
    await _setupFirestoreListeners();
    recalculateAllStats();
    notifyListeners();
  }
  Future<void> updatePassword(dynamic oldOrNew, [dynamic newPass]) async {}

  // Requests screen stubs
  String? getGroupIdForDate(dynamic emp, DateTime date) {
    if (emp is CompanyEmployee) {
      if (emp.groupHistory.isNotEmpty) {
        for (var entry in emp.groupHistory) {
          DateTime start = DateTime.parse(entry.startDate);
          DateTime? end = entry.endDate.isNotEmpty ? DateTime.parse(entry.endDate) : null;
          
          if (date.isAtSameMomentAs(start) || date.isAfter(start)) {
            if (end == null || date.isBefore(end) || date.isAtSameMomentAs(end)) {
              return entry.groupId;
            }
          }
        }
      }
      return emp.groupId;
    }
    return null;
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
    String status = 'Pending';
    try {
      final isTopManager = _structures.any((s) => 
        s.supervisorId == empId && 
        (s.parentId == null || s.parentId!.isEmpty)
      );
      if (isTopManager) {
        status = 'Approved';
      }
    } catch (_) {}

    final newReq = Request(
      id: 'req_${DateTime.now().millisecondsSinceEpoch}',
      type: type.toString(),
      date: date.toString(),
      duration: duration.toString(),
      status: status,
      targetShiftId: targetShiftId?.toString(),
      employeeId: empId,
      note: note,
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
    _allRequestsMap[empId]?.removeWhere((r) => r.id == rId);
    _allCompanyRequests.removeWhere((r) => r.id == rId);
    notifyListeners();

    if (_firebaseService.isAvailable) {
      await _firebaseService.deleteRequest(empId, rId);
    }
  }

  Future<void> updateRequestStatus(dynamic a, dynamic b, [dynamic c]) async {
    String empId = _employeeId;
    String reqId = '';
    String status = '';
    if (c != null) {
      empId = a.toString();
      reqId = b.toString();
      status = c.toString();
    } else {
      reqId = a.toString();
      status = b.toString();
    }

    if (empId == _employeeId) {
      final found = _allCompanyRequests.where((r) => r.id == reqId).firstOrNull;
      if (found != null && found.employeeId != null) {
        empId = found.employeeId!;
      }
    }

    Request? updatedReq;
    final reqs = _allRequestsMap[empId];
    if (reqs != null) {
      final idx = reqs.indexWhere((r) => r.id == reqId);
      if (idx != -1) {
        final old = reqs[idx];
        updatedReq = old.copyWith(status: status, employeeId: empId);
        reqs[idx] = updatedReq;
      }
    }

    final cIdx = _allCompanyRequests.indexWhere((r) => r.id == reqId);
    if (cIdx != -1) {
      final old = _allCompanyRequests[cIdx];
      updatedReq = old.copyWith(status: status, employeeId: empId);
      _allCompanyRequests[cIdx] = updatedReq;
    }

    notifyListeners();

    if (updatedReq != null && _firebaseService.isAvailable) {
      await _firebaseService.saveRequest(empId, updatedReq);
      
      if (empId != _employeeId && status != 'Pending') {
        final messageText = 'Your request for ${updatedReq.type} has been $status.';
        await sendChatMessage(empId, messageText);
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
        if (struct.latitude != null && struct.longitude != null && struct.radius != null) {
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
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
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
    _records.removeWhere((r) =>
        r.checkIn.year == _activeRecord!.checkIn.year &&
        r.checkIn.month == _activeRecord!.checkIn.month &&
        r.checkIn.day == _activeRecord!.checkIn.day &&
        r.checkIn.hour == _activeRecord!.checkIn.hour &&
        r.checkIn.minute == _activeRecord!.checkIn.minute);
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
      final idx = _records.indexWhere((r) =>
          r.checkIn.year == _activeRecord!.checkIn.year &&
          r.checkIn.month == _activeRecord!.checkIn.month &&
          r.checkIn.day == _activeRecord!.checkIn.day &&
          r.checkIn.hour == _activeRecord!.checkIn.hour &&
          r.checkIn.minute == _activeRecord!.checkIn.minute);
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

  // HR Management
  List<CompanyEmployee> getEmployeesInStructure(dynamic structId) {
    return _employees.where((e) => e.structureId == structId).toList();
  }
  Future<void> deleteStructure(dynamic id) async => await _firebaseService.deleteStructure(id);
  Future<void> updateStructure(dynamic struct) async => await _firebaseService.saveStructure(struct);
  Future<void> addStructure(dynamic struct) async => await _firebaseService.saveStructure(struct);

  Future<void> deleteShift(dynamic id) async => await _firebaseService.deleteShift(id);
  Future<void> updateShift(dynamic shift) async => await _firebaseService.saveShift(shift);
  Future<void> addShift(dynamic shift) async => await _firebaseService.saveShift(shift);

  Future<void> deleteGroup(dynamic id) async => await _firebaseService.deleteGroup(id);
  Future<void> updateGroup(dynamic group) async => await _firebaseService.saveGroup(group);
  Future<void> addGroup(dynamic group) async => await _firebaseService.saveGroup(group);

  Future<void> deleteEmployee(dynamic id) async {
    final strId = id.toString();
    _employees.removeWhere((e) => e.id == strId);
    notifyListeners();
    await _firebaseService.deleteEmployee(strId);
  }

  Future<void> updateEmployee(dynamic emp) async {
    if (emp is CompanyEmployee) {
      final index = _employees.indexWhere((e) => e.id == emp.id);
      if (index != -1) {
        _employees[index] = emp;
      } else {
        _employees.add(emp);
      }
      notifyListeners();
      await _firebaseService.saveEmployee(emp);
    }
  }

  Future<void> addEmployee(dynamic emp) async {
    if (emp is CompanyEmployee) {
      final index = _employees.indexWhere((e) => e.id == emp.id);
      if (index != -1) {
        _employees[index] = emp;
      } else {
        _employees.add(emp);
      }
      notifyListeners();
      await _firebaseService.saveEmployee(emp);
    }
  }

  Future<void> deleteHoliday(dynamic id) async => await _firebaseService.deleteHoliday(id);
  Future<void> updateHoliday(dynamic holiday) async => await _firebaseService.saveHoliday(holiday);
  Future<void> addHoliday(dynamic holiday) async => await _firebaseService.saveHoliday(holiday);

  Future<void> deleteLocation(dynamic id) async => await _firebaseService.deleteLocation(id);
  Future<void> updateLocation(dynamic loc) async => await _firebaseService.saveLocation(loc);
  Future<void> addLocation(dynamic loc) async => await _firebaseService.saveLocation(loc);

  Future<void> updateEmployeeFaceEmbedding(dynamic empId, dynamic embedding) async {}
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
    final cId = otherId.toString();
    final messages = _chatMessagesMap[cId];
    if (messages == null) return;

    final unreadMessages = messages
        .where((m) => m.receiverId == _employeeId && !m.isRead)
        .toList();
    if (unreadMessages.isEmpty) return;

    // Update in-memory first to avoid infinite callback loop
    for (int i = 0; i < messages.length; i++) {
      if (messages[i].receiverId == _employeeId && !messages[i].isRead) {
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

  Request? getRequestById(dynamic reqId, [dynamic b]) => null;

  Future<void> sendChatMessage(dynamic receiverId, [dynamic text, dynamic c]) async {
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
    required this.netEarnings,
    required this.currency,
  });
}
