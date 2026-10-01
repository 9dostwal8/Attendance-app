import 'dart:async';
import 'package:flutter/foundation.dart';
import 'zk_protocol/flutter_zk.dart';
import 'zkteco_driver.dart';
import 'zkteco_models.dart';

class ZkDeviceDriverImpl implements ZkDeviceDriver {
  @override
  Future<ZkDeviceInfo> testConnection({
    required String ip,
    int port = 4370,
    int password = 0,
    int timeoutSeconds = 10,
  }) async {
    final zk = ZK(ip, port: port, password: password);
    try {
      await zk.connect().timeout(
        Duration(seconds: timeoutSeconds),
        onTimeout: () => throw TimeoutException('Connection timed out to $ip:$port'),
      );

      String deviceName = '';
      String serialNumber = '';
      String firmware = '';
      String platform = '';
      String mac = '';
      DateTime? devTime;

      try {
        deviceName = await zk.getDeviceName();
      } catch (_) {}

      try {
        serialNumber = await zk.getSerialNumber();
      } catch (_) {}

      try {
        firmware = await zk.getFirmwareVersion();
      } catch (_) {}

      try {
        platform = await zk.getPlatform();
      } catch (_) {}

      try {
        mac = await zk.getMacAddress();
      } catch (_) {}

      try {
        devTime = await zk.getTime();
      } catch (_) {}

      int userCount = 0;
      int logCount = 0;
      try {
        await zk.readSizes();
        userCount = zk.usersCount;
        logCount = zk.recordsCount;
      } catch (_) {}

      await zk.disconnect();

      return ZkDeviceInfo(
        isConnected: true,
        ip: ip,
        port: port,
        deviceName: deviceName.isNotEmpty ? deviceName : 'ZKTeco Device',
        serialNumber: serialNumber,
        firmwareVersion: firmware,
        platform: platform,
        macAddress: mac,
        deviceTime: devTime,
        userCount: userCount,
        logCount: logCount,
      );
    } catch (e) {
      try {
        await zk.disconnect();
      } catch (_) {}
      debugPrint('ZKTeco connection failed: $e');
      return ZkDeviceInfo(
        isConnected: false,
        ip: ip,
        port: port,
        errorMessage: e.toString().replaceAll('Exception:', '').trim(),
      );
    }
  }

  @override
  Future<List<ZkDeviceUser>> getUsers({
    required String ip,
    int port = 4370,
    int password = 0,
    int timeoutSeconds = 10,
  }) async {
    final zk = ZK(ip, port: port, password: password);
    try {
      await zk.connect().timeout(
        Duration(seconds: timeoutSeconds),
        onTimeout: () => throw TimeoutException('Connection timed out'),
      );
      final users = await zk.getUsers();
      await zk.disconnect();

      return users.map((u) {
        return ZkDeviceUser(
          uid: u.uid,
          userId: u.userId.isNotEmpty ? u.userId : u.uid.toString(),
          name: u.name,
          privilege: u.privilege,
          card: u.card,
        );
      }).toList();
    } catch (e) {
      try {
        await zk.disconnect();
      } catch (_) {}
      debugPrint('Failed to get users from ZKTeco: $e');
      rethrow;
    }
  }

  @override
  Future<List<ZkRawPunch>> getAttendanceLogs({
    required String ip,
    int port = 4370,
    int password = 0,
    DateTime? fromDate,
    DateTime? toDate,
    int timeoutSeconds = 15,
  }) async {
    final zk = ZK(ip, port: port, password: password);
    try {
      await zk.connect().timeout(
        Duration(seconds: timeoutSeconds),
        onTimeout: () => throw TimeoutException('Connection timed out'),
      );

      final logs = await zk.getAttendance(
        fromDate: fromDate,
        toDate: toDate,
        sort: 'asc',
      );

      await zk.disconnect();

      return logs.map((att) {
        return ZkRawPunch(
          userId: att.userId.trim(),
          timestamp: att.timestamp,
          status: att.status,
          punchType: att.punch,
        );
      }).toList();
    } catch (e) {
      try {
        await zk.disconnect();
      } catch (_) {}
      debugPrint('Failed to get attendance logs from ZKTeco: $e');
      rethrow;
    }
  }
}

ZkDeviceDriver getZkDeviceDriver() => ZkDeviceDriverImpl();
