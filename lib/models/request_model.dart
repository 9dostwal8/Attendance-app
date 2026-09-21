import 'package:flutter/material.dart';

class Request {
  final String id;
  final String type;
  final String date;
  final String duration;
  final String status; // 'Approved', 'Pending', 'Rejected'
  final String? targetShiftId;
  final String? employeeId;
  final String? note;
  final String? createdAt;
  final String? actionBy;
  final String? actionDate;

  Request({
    required this.id,
    required this.type,
    required this.date,
    required this.duration,
    required this.status,
    this.targetShiftId,
    this.employeeId,
    this.note,
    this.createdAt,
    this.actionBy,
    this.actionDate,
  });

  Color get statusColor {
    switch (status) {
      case 'Approved':
        return const Color(0xFF2EBD96);
      case 'Rejected':
        return const Color(0xFFEF4444);
      case 'Pending':
      default:
        return const Color(0xFF2E65FF);
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'date': date,
      'duration': duration,
      'status': status,
      'targetShiftId': targetShiftId,
      'employeeId': employeeId,
      'note': note,
      'createdAt': createdAt,
      'actionBy': actionBy,
      'actionDate': actionDate,
    };
  }

  factory Request.fromMap(Map<String, dynamic> map, String docId) {
    return Request(
      id: map['id'] ?? docId,
      type: map['type'] ?? '',
      date: map['date'] ?? '',
      duration: map['duration'] ?? '',
      status: map['status'] ?? 'Pending',
      targetShiftId: map['targetShiftId'],
      employeeId: map['employeeId'],
      note: map['note'],
      createdAt: map['createdAt'],
      actionBy: map['actionBy'],
      actionDate: map['actionDate'],
    );
  }

  Request copyWith({
    String? id,
    String? type,
    String? date,
    String? duration,
    String? status,
    String? targetShiftId,
    String? employeeId,
    String? note,
    String? createdAt,
    String? actionBy,
    String? actionDate,
    bool overrideTargetShiftId = false,
  }) {
    return Request(
      id: id ?? this.id,
      type: type ?? this.type,
      date: date ?? this.date,
      duration: duration ?? this.duration,
      status: status ?? this.status,
      targetShiftId: overrideTargetShiftId
          ? targetShiftId
          : (targetShiftId ?? this.targetShiftId),
      employeeId: employeeId ?? this.employeeId,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      actionBy: actionBy ?? this.actionBy,
      actionDate: actionDate ?? this.actionDate,
    );
  }
}
