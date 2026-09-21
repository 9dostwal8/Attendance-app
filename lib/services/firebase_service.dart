import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/hr_models.dart';
import '../models/attendance_record.dart';
import '../models/request_model.dart';
import '../models/chat_message.dart';

class FirebaseService {
  // Check if Firebase is initialized
  bool get isAvailable {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  // --- OrgStructure CRUD ---
  Future<List<OrgStructure>> getStructures() async {
    if (!isAvailable) return [];
    try {
      final snapshot = await _firestore.collection('structures').get();
      final list = <OrgStructure>[];
      for (var doc in snapshot.docs) {
        try {
          list.add(OrgStructure.fromMap(doc.data(), doc.id));
        } catch (e) {
          debugPrint('Error parsing OrgStructure ${doc.id}: $e');
        }
      }
      return list;
    } catch (e) {
      debugPrint('Error getting structures: $e');
      return [];
    }
  }

  Stream<List<OrgStructure>> streamStructures() {
    if (!isAvailable) return Stream.value([]);
    return _firestore.collection('structures').snapshots().map((snapshot) {
      final list = <OrgStructure>[];
      for (var doc in snapshot.docs) {
        try {
          list.add(OrgStructure.fromMap(doc.data(), doc.id));
        } catch (e) {
          debugPrint('Error parsing OrgStructure ${doc.id}: $e');
        }
      }
      return list;
    });
  }

  Future<void> saveStructure(OrgStructure structure) async {
    if (!isAvailable) return;
    try {
      await _firestore
          .collection('structures')
          .doc(structure.id)
          .set(structure.toMap());
    } catch (e) {
      debugPrint('Error saving structure: $e');
    }
  }

  Future<void> deleteStructure(String id) async {
    if (!isAvailable) return;
    try {
      await _firestore.collection('structures').doc(id).delete();
    } catch (e) {
      debugPrint('Error deleting structure: $e');
    }
  }

  // --- WorkShift CRUD ---
  Future<List<WorkShift>> getShifts() async {
    if (!isAvailable) return [];
    try {
      final snapshot = await _firestore.collection('shifts').get();
      final list = <WorkShift>[];
      for (var doc in snapshot.docs) {
        try {
          list.add(WorkShift.fromMap(doc.data(), doc.id));
        } catch (e) {
          debugPrint('Error parsing WorkShift ${doc.id}: $e');
        }
      }
      return list;
    } catch (e) {
      debugPrint('Error getting shifts: $e');
      return [];
    }
  }

  Stream<List<WorkShift>> streamShifts() {
    if (!isAvailable) return Stream.value([]);
    return _firestore.collection('shifts').snapshots().map((snapshot) {
      final list = <WorkShift>[];
      for (var doc in snapshot.docs) {
        try {
          list.add(WorkShift.fromMap(doc.data(), doc.id));
        } catch (e) {
          debugPrint('Error parsing WorkShift ${doc.id}: $e');
        }
      }
      return list;
    });
  }

  Future<void> saveShift(WorkShift shift) async {
    if (!isAvailable) return;
    try {
      await _firestore.collection('shifts').doc(shift.id).set(shift.toMap());
    } catch (e) {
      debugPrint('Error saving shift: $e');
    }
  }

  Future<void> deleteShift(String id) async {
    if (!isAvailable) return;
    try {
      await _firestore.collection('shifts').doc(id).delete();
    } catch (e) {
      debugPrint('Error deleting shift: $e');
    }
  }

  // --- EmployeeGroup CRUD ---
  Future<List<EmployeeGroup>> getGroups() async {
    if (!isAvailable) return [];
    try {
      final snapshot = await _firestore.collection('groups').get();
      final list = <EmployeeGroup>[];
      for (var doc in snapshot.docs) {
        try {
          list.add(EmployeeGroup.fromMap(doc.data(), doc.id));
        } catch (e) {
          debugPrint('Error parsing EmployeeGroup ${doc.id}: $e');
        }
      }
      return list;
    } catch (e) {
      debugPrint('Error getting groups: $e');
      return [];
    }
  }

  Stream<List<EmployeeGroup>> streamGroups() {
    if (!isAvailable) return Stream.value([]);
    return _firestore.collection('groups').snapshots().map((snapshot) {
      final list = <EmployeeGroup>[];
      for (var doc in snapshot.docs) {
        try {
          list.add(EmployeeGroup.fromMap(doc.data(), doc.id));
        } catch (e) {
          debugPrint('Error parsing EmployeeGroup ${doc.id}: $e');
        }
      }
      return list;
    });
  }

  Future<void> saveGroup(EmployeeGroup group) async {
    if (!isAvailable) return;
    try {
      await _firestore.collection('groups').doc(group.id).set(group.toMap());
    } catch (e) {
      debugPrint('Error saving group: $e');
    }
  }

  Future<void> deleteGroup(String id) async {
    if (!isAvailable) return;
    try {
      await _firestore.collection('groups').doc(id).delete();
    } catch (e) {
      debugPrint('Error deleting group: $e');
    }
  }

  // --- WorkLocation CRUD ---
  Future<List<WorkLocation>> getLocations() async {
    if (!isAvailable) return [];
    try {
      final snapshot = await _firestore.collection('locations').get();
      final list = <WorkLocation>[];
      for (var doc in snapshot.docs) {
        try {
          list.add(WorkLocation.fromMap(doc.data(), doc.id));
        } catch (e) {
          debugPrint('Error parsing WorkLocation ${doc.id}: $e');
        }
      }
      return list;
    } catch (e) {
      debugPrint('Error getting locations: $e');
      return [];
    }
  }

  Stream<List<WorkLocation>> streamLocations() {
    if (!isAvailable) return Stream.value([]);
    return _firestore.collection('locations').snapshots().map((snapshot) {
      final list = <WorkLocation>[];
      for (var doc in snapshot.docs) {
        try {
          list.add(WorkLocation.fromMap(doc.data(), doc.id));
        } catch (e) {
          debugPrint('Error parsing WorkLocation ${doc.id}: $e');
        }
      }
      return list;
    });
  }

  Future<void> saveLocation(WorkLocation location) async {
    if (!isAvailable) return;
    try {
      await _firestore.collection('locations').doc(location.id).set(location.toMap());
    } catch (e) {
      debugPrint('Error saving location: $e');
    }
  }

  Future<void> deleteLocation(String id) async {
    if (!isAvailable) return;
    try {
      await _firestore.collection('locations').doc(id).delete();
    } catch (e) {
      debugPrint('Error deleting location: $e');
    }
  }

  // --- Holiday CRUD ---
  Future<List<Holiday>> getHolidays() async {
    if (!isAvailable) return [];
    try {
      final snapshot = await _firestore.collection('holidays').get();
      final list = <Holiday>[];
      for (var doc in snapshot.docs) {
        try {
          list.add(Holiday.fromMap(doc.data(), doc.id));
        } catch (e) {
          debugPrint('Error parsing Holiday ${doc.id}: $e');
        }
      }
      return list;
    } catch (e) {
      debugPrint('Error getting holidays: $e');
      return [];
    }
  }

  Stream<List<Holiday>> streamHolidays() {
    if (!isAvailable) return Stream.value([]);
    return _firestore.collection('holidays').snapshots().map((snapshot) {
      final list = <Holiday>[];
      for (var doc in snapshot.docs) {
        try {
          list.add(Holiday.fromMap(doc.data(), doc.id));
        } catch (e) {
          debugPrint('Error parsing Holiday ${doc.id}: $e');
        }
      }
      return list;
    });
  }

  Future<void> saveHoliday(Holiday holiday) async {
    if (!isAvailable) return;
    try {
      await _firestore.collection('holidays').doc(holiday.id).set(holiday.toMap());
    } catch (e) {
      debugPrint('Error saving holiday: $e');
    }
  }

  Future<void> deleteHoliday(String id) async {
    if (!isAvailable) return;
    try {
      await _firestore.collection('holidays').doc(id).delete();
    } catch (e) {
      debugPrint('Error deleting holiday: $e');
    }
  }

  // --- CompanyEmployee CRUD ---
  Future<List<CompanyEmployee>> getEmployees() async {
    if (!isAvailable) return [];
    try {
      final snapshot = await _firestore.collection('employees').get();
      final list = <CompanyEmployee>[];
      for (var doc in snapshot.docs) {
        try {
          list.add(CompanyEmployee.fromMap(doc.data(), doc.id));
        } catch (e) {
          debugPrint('Error parsing CompanyEmployee ${doc.id}: $e');
        }
      }
      return list;
    } catch (e) {
      debugPrint('Error getting employees: $e');
      return [];
    }
  }

  Stream<List<CompanyEmployee>> streamEmployees() {
    if (!isAvailable) return Stream.value([]);
    return _firestore.collection('employees').snapshots().map((snapshot) {
      final list = <CompanyEmployee>[];
      for (var doc in snapshot.docs) {
        try {
          list.add(CompanyEmployee.fromMap(doc.data(), doc.id));
        } catch (e) {
          debugPrint('Error parsing CompanyEmployee ${doc.id}: $e');
        }
      }
      return list;
    });
  }

  Future<void> saveEmployee(CompanyEmployee employee) async {
    if (!isAvailable) return;
    try {
      await _firestore
          .collection('employees')
          .doc(employee.id)
          .set(employee.toMap());
    } catch (e) {
      debugPrint('Error saving employee: $e');
    }
  }

  Future<void> deleteEmployee(String id) async {
    if (!isAvailable) return;
    try {
      await _firestore.collection('employees').doc(id).delete();
    } catch (e) {
      debugPrint('Error deleting employee: $e');
    }
  }

  // --- AttendanceRecord CRUD ---
  Future<List<AttendanceRecord>> getUserRecords(String employeeId) async {
    if (!isAvailable) return [];
    try {
      final trimmedId = employeeId.trim();
      QuerySnapshot<Map<String, dynamic>> snapshot;
      try {
        snapshot = await _firestore
            .collection('attendance_records')
            .doc(trimmedId)
            .collection('user_records')
            .get();
      } catch (e) {
        debugPrint('Error getting user_records for $trimmedId: $e');
        return [];
      }

      // If direct doc lookup is empty, try case-insensitive doc match in attendance_records
      if (snapshot.docs.isEmpty) {
        try {
          final parentSnap = await _firestore.collection('attendance_records').get();
          for (var pDoc in parentSnap.docs) {
            if (pDoc.id.toLowerCase() == trimmedId.toLowerCase()) {
              snapshot = await pDoc.reference.collection('user_records').get();
              if (snapshot.docs.isNotEmpty) break;
            }
          }
        } catch (_) {}
      }

      final list = <AttendanceRecord>[];
      for (var doc in snapshot.docs) {
        try {
          list.add(AttendanceRecord.fromMap(doc.data(), trimmedId));
        } catch (e) {
          debugPrint('Error parsing AttendanceRecord ${doc.id}: $e');
        }
      }
      list.sort((a, b) => b.checkIn.compareTo(a.checkIn));
      return list;
    } catch (e) {
      debugPrint('Error getting user records: $e');
      return [];
    }
  }

  Stream<List<AttendanceRecord>> streamUserRecords(String employeeId) {
    if (!isAvailable) return Stream.value([]);
    final trimmedId = employeeId.trim();
    return _firestore
        .collection('attendance_records')
        .doc(trimmedId)
        .collection('user_records')
        .snapshots()
        .map((snapshot) {
      final list = <AttendanceRecord>[];
      for (var doc in snapshot.docs) {
        try {
          list.add(AttendanceRecord.fromMap(doc.data(), trimmedId));
        } catch (e) {
          debugPrint('Error parsing AttendanceRecord ${doc.id}: $e');
        }
      }
      list.sort((a, b) => b.checkIn.compareTo(a.checkIn));
      return list;
    }).handleError((e) {
      debugPrint('Error in streamUserRecords for $trimmedId: $e');
      return <AttendanceRecord>[];
    });
  }

  Stream<List<AttendanceRecord>> streamAllRecords() {
    if (!isAvailable) return Stream.value([]);
    try {
      return _firestore.collectionGroup('user_records').snapshots().map((snapshot) {
        final list = <AttendanceRecord>[];
        for (var doc in snapshot.docs) {
          try {
            final empId = doc.data()['employeeId']?.toString() ??
                doc.reference.parent.parent?.id;
            list.add(AttendanceRecord.fromMap(doc.data(), empId));
          } catch (e) {
            debugPrint('Error parsing collectionGroup AttendanceRecord ${doc.id}: $e');
          }
        }
        list.sort((a, b) => b.checkIn.compareTo(a.checkIn));
        return list;
      }).handleError((e) {
        debugPrint('collectionGroup user_records stream error (likely missing index): $e');
        return <AttendanceRecord>[];
      });
    } catch (e) {
      debugPrint('Error starting streamAllRecords: $e');
      return Stream.value([]);
    }
  }

  Future<void> saveRecord(String employeeId, AttendanceRecord record) async {
    if (!isAvailable) return;
    try {
      // Use CheckIn timestamp as document ID to uniquely identify day session
      final docId = record.checkIn.toIso8601String().replaceAll(':', '-');
      final data = record.toMap();
      data['employeeId'] = employeeId;
      await _firestore
          .collection('attendance_records')
          .doc(employeeId)
          .collection('user_records')
          .doc(docId)
          .set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving attendance record: $e');
      rethrow;
    }
  }

  Future<void> deleteRecord(String employeeId, AttendanceRecord record) async {
    if (!isAvailable) return;
    try {
      final docId = record.checkIn.toIso8601String().replaceAll(':', '-');
      await _firestore
          .collection('attendance_records')
          .doc(employeeId)
          .collection('user_records')
          .doc(docId)
          .delete();
    } catch (e) {
      debugPrint('Error deleting attendance record: $e');
    }
  }

  // --- Request CRUD ---
  Future<List<Request>> getUserRequests(String employeeId) async {
    if (!isAvailable) return [];
    try {
      final trimmedId = employeeId.trim();
      QuerySnapshot<Map<String, dynamic>> snapshot;
      try {
        snapshot = await _firestore
            .collection('requests')
            .doc(trimmedId)
            .collection('user_requests')
            .get();
      } catch (e) {
        debugPrint('Error getting user_requests for $trimmedId: $e');
        return [];
      }

      if (snapshot.docs.isEmpty) {
        try {
          final parentSnap = await _firestore.collection('requests').get();
          for (var pDoc in parentSnap.docs) {
            if (pDoc.id.toLowerCase() == trimmedId.toLowerCase()) {
              snapshot = await pDoc.reference.collection('user_requests').get();
              if (snapshot.docs.isNotEmpty) break;
            }
          }
        } catch (_) {}
      }

      return snapshot.docs.map((doc) {
        final data = doc.data();
        final req = Request.fromMap(data, doc.id);
        return req.copyWith(
          employeeId: req.employeeId ?? trimmedId,
          overrideTargetShiftId: false,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error getting user requests: $e');
      return [];
    }
  }

  Stream<List<Request>> streamUserRequests(String employeeId) {
    if (!isAvailable) return Stream.value([]);
    return _firestore
        .collection('requests')
        .doc(employeeId)
        .collection('user_requests')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final req = Request.fromMap(data, doc.id);
        return req.copyWith(
          employeeId: req.employeeId ?? employeeId,
          overrideTargetShiftId: false,
        );
      }).toList();
    });
  }

  Future<List<Request>> getAllRequests() async {
    if (!isAvailable) return [];
    try {
      final snapshot = await _firestore.collectionGroup('user_requests').get();
      final list = <Request>[];
      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          String? empId = data['employeeId'];
          if (empId == null || empId.isEmpty) {
            try {
              empId = doc.reference.parent.parent?.id;
            } catch (_) {}
          }
          final req = Request.fromMap(data, doc.id);
          list.add(req.copyWith(
            employeeId: empId ?? req.employeeId,
            overrideTargetShiftId: false,
          ));
        } catch (e) {
          debugPrint('Error parsing request doc ${doc.id}: $e');
        }
      }
      return list;
    } catch (e) {
      debugPrint('Error getting all requests: $e');
      return [];
    }
  }

  Stream<List<Request>> streamAllRequests() {
    if (!isAvailable) return Stream.value([]);
    return _firestore.collectionGroup('user_requests').snapshots().map((snapshot) {
      final list = <Request>[];
      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          String? empId = data['employeeId'];
          if (empId == null || empId.isEmpty) {
            try {
              empId = doc.reference.parent.parent?.id;
            } catch (_) {}
          }
          final req = Request.fromMap(data, doc.id);
          list.add(req.copyWith(
            employeeId: empId ?? req.employeeId,
            overrideTargetShiftId: false,
          ));
        } catch (e) {
          debugPrint('Error parsing request doc ${doc.id} in stream: $e');
        }
      }
      return list;
    });
  }

  Future<void> saveRequest(String employeeId, Request request) async {
    if (!isAvailable) return;
    try {
      await _firestore
          .collection('requests')
          .doc(employeeId)
          .collection('user_requests')
          .doc(request.id)
          .set(request.toMap());
    } catch (e) {
      debugPrint('Error saving request: $e');
    }
  }

  Future<void> deleteRequest(String employeeId, String requestId) async {
    if (!isAvailable) return;
    try {
      await _firestore
          .collection('requests')
          .doc(employeeId)
          .collection('user_requests')
          .doc(requestId)
          .delete();
    } catch (e) {
      debugPrint('Error deleting request: $e');
    }
  }

  // --- Database Initialization Seeding ---
  Future<void> seedDefaultMockData({
    required List<OrgStructure> structures,
    required List<WorkShift> shifts,
    required List<EmployeeGroup> groups,
    required List<CompanyEmployee> employees,
    required List<AttendanceRecord> userRecords,
    required String testUserId,
    required List<Request> userRequests,
    List<WorkLocation>? locations,
  }) async {
    if (!isAvailable) return;

    try {
      final snaps = await Future.wait([
        _firestore.collection('structures').limit(1).get(),
        _firestore.collection('shifts').limit(1).get(),
        _firestore.collection('groups').limit(1).get(),
        _firestore.collection('employees').limit(1).get(),
        _firestore.collection('attendance_records').doc(testUserId).collection('user_records').limit(1).get(),
        _firestore.collection('requests').doc(testUserId).collection('user_requests').limit(1).get(),
        _firestore.collection('locations').limit(1).get(),
      ]);

      final structSnap = snaps[0];
      final shiftSnap = snaps[1];
      final groupSnap = snaps[2];
      final empSnap = snaps[3];
      final recordSnap = snaps[4];
      final reqSnap = snaps[5];
      final locationSnap = snaps[6];

      // 1. Seed Structures
      if (structSnap.docs.isEmpty) {
        debugPrint('Seeding structures in Firestore...');
        for (var s in structures) {
          await saveStructure(s);
        }
      }

      // 2. Seed Shifts
      if (shiftSnap.docs.isEmpty) {
        debugPrint('Seeding shifts in Firestore...');
        for (var s in shifts) {
          await saveShift(s);
        }
      }

      // 3. Seed Groups
      if (groupSnap.docs.isEmpty) {
        debugPrint('Seeding groups in Firestore...');
        for (var g in groups) {
          await saveGroup(g);
        }
      }

      // 4. Seed Employees
      if (empSnap.docs.isEmpty) {
        debugPrint('Seeding employees in Firestore...');
        for (var e in employees) {
          await saveEmployee(e);
        }
      }

      // 5. Seed Attendance Records for testUserId
      if (recordSnap.docs.isEmpty) {
        debugPrint(
          'Seeding attendance records for $testUserId in Firestore...',
        );
        for (var r in userRecords) {
          await saveRecord(testUserId, r);
        }
      }

      // 6. Seed Requests for testUserId
      if (reqSnap.docs.isEmpty) {
        debugPrint('Seeding requests for $testUserId in Firestore...');
        for (var req in userRequests) {
          await saveRequest(testUserId, req);
        }
      }

      // 7. Seed Locations
      if (locationSnap.docs.isEmpty && locations != null) {
        debugPrint('Seeding locations in Firestore...');
        for (var l in locations) {
          await saveLocation(l);
        }
      }
    } catch (e) {
      debugPrint('Error during Firestore database seeding: $e');
    }
  }

  // --- Chat Message CRUD ---
  Future<List<ChatMessage>> getChatMessages(String userA, String userB) async {
    if (!isAvailable) return [];
    try {
      final roomId = userA.compareTo(userB) < 0
          ? '${userA}_$userB'
          : '${userB}_$userA';
      final snapshot = await _firestore
          .collection('chat_rooms')
          .doc(roomId)
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .get();
      final list = <ChatMessage>[];
      for (var doc in snapshot.docs) {
        try {
          list.add(ChatMessage.fromMap(doc.data(), doc.id));
        } catch (e) {
          debugPrint('Error parsing ChatMessage ${doc.id}: $e');
        }
      }
      list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return list;
    } catch (e) {
      debugPrint('Error getting chat messages: $e');
      return [];
    }
  }

  Stream<List<ChatMessage>> streamChatMessages(String userA, String userB) {
    if (!isAvailable) return Stream.value([]);
    final roomId = userA.compareTo(userB) < 0
        ? '${userA}_$userB'
        : '${userB}_$userA';
    return _firestore
        .collection('chat_rooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
          final list = <ChatMessage>[];
          for (var doc in snapshot.docs) {
            try {
              list.add(ChatMessage.fromMap(doc.data(), doc.id));
            } catch (e) {
              debugPrint('Error parsing ChatMessage in stream ${doc.id}: $e');
            }
          }
          list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          return list;
        });
  }

  Future<void> saveChatMessage(ChatMessage message) async {
    if (!isAvailable) return;
    try {
      final userA = message.senderId;
      final userB = message.receiverId;
      final roomId = userA.compareTo(userB) < 0
          ? '${userA}_$userB'
          : '${userB}_$userA';
      await _firestore
          .collection('chat_rooms')
          .doc(roomId)
          .collection('messages')
          .doc(message.id)
          .set(message.toMap());

      await _firestore.collection('chat_rooms').doc(roomId).set({
        'roomId': roomId,
        'userA': userA.compareTo(userB) < 0 ? userA : userB,
        'userB': userA.compareTo(userB) < 0 ? userB : userA,
        'participants': [userA, userB],
        'lastMessage': message.text,
        'lastTimestamp': message.timestamp.toUtc().toIso8601String(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving chat message: $e');
    }
  }

  // --- Company Profile ---
  Future<CompanyProfile?> getCompanyProfile() async {
    if (!isAvailable) return null;
    try {
      final doc = await _firestore.collection('settings').doc('company_profile').get();
      if (doc.exists && doc.data() != null) {
        return CompanyProfile.fromMap(doc.data()!);
      }
    } catch (e) {
      debugPrint('Error getting company profile: $e');
    }
    return null;
  }

  Stream<CompanyProfile?> streamCompanyProfile() {
    if (!isAvailable) return Stream.value(null);
    return _firestore.collection('settings').doc('company_profile').snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return CompanyProfile.fromMap(doc.data()!);
      }
      return null;
    });
  }

  Future<void> saveCompanyProfile(CompanyProfile profile) async {
    if (!isAvailable) return;
    try {
      await _firestore.collection('settings').doc('company_profile').set(profile.toMap());
    } catch (e) {
      debugPrint('Error saving company profile: $e');
    }
  }
}
