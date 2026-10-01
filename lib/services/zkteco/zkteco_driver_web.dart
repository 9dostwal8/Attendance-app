import 'dart:convert';
import 'package:http/http.dart' as http;

import 'zkteco_driver.dart';
import 'zkteco_models.dart';

class ZkDeviceDriverWeb implements ZkDeviceDriver {
  static const String _bridgeBaseUrl = 'http://127.0.0.1:5055';

  @override
  Future<ZkDeviceInfo> testConnection({
    required String ip,
    int port = 4370,
    int password = 0,
    int timeoutSeconds = 10,
  }) async {
    final uri = Uri.parse('$_bridgeBaseUrl/test?ip=$ip&port=$port&password=$password');

    try {
      final response = await http.get(uri).timeout(
        Duration(seconds: timeoutSeconds),
        onTimeout: () => throw Exception('Bridge request timed out to $_bridgeBaseUrl'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final isConnected = data['isConnected'] as bool? ?? false;

        if (isConnected) {
          DateTime? devTime;
          if (data['deviceTime'] != null) {
            devTime = DateTime.tryParse(data['deviceTime'].toString());
          }

          return ZkDeviceInfo(
            isConnected: true,
            ip: ip,
            port: port,
            deviceName: data['deviceName'] as String? ?? 'ZKTeco Device',
            serialNumber: data['serialNumber'] as String? ?? '',
            firmwareVersion: data['firmwareVersion'] as String? ?? '',
            platform: data['platform'] as String? ?? '',
            macAddress: data['macAddress'] as String? ?? '',
            userCount: data['userCount'] as int? ?? 0,
            logCount: data['logCount'] as int? ?? 0,
            deviceTime: devTime,
          );
        } else {
          return ZkDeviceInfo(
            isConnected: false,
            ip: ip,
            port: port,
            errorMessage: data['error'] as String? ?? 'Device unreachable at $ip:$port',
          );
        }
      } else {
        return ZkDeviceInfo(
          isConnected: false,
          ip: ip,
          port: port,
          errorMessage: 'Bridge responded with status ${response.statusCode}',
        );
      }
    } catch (e) {
      return ZkDeviceInfo(
        isConnected: false,
        ip: ip,
        port: port,
        errorMessage:
            'ZKTeco Local Bridge not running on this computer. Please double-click "start_zk_bridge.bat" to connect Chrome to your device, or run the app on Windows Desktop.',
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
    final uri = Uri.parse('$_bridgeBaseUrl/users?ip=$ip&port=$port&password=$password');
    try {
      final response = await http.get(uri).timeout(Duration(seconds: timeoutSeconds));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          final list = (data['users'] as List? ?? []).cast<Map<String, dynamic>>();
          return list.map((u) {
            return ZkDeviceUser(
              uid: u['uid'] as int? ?? 0,
              userId: (u['userId'] ?? '').toString(),
              name: (u['name'] ?? '').toString(),
              privilege: u['privilege'] as int? ?? 0,
              card: u['card'] as int? ?? 0,
            );
          }).toList();
        }
      }
    } catch (_) {}
    return [];
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
    var url = '$_bridgeBaseUrl/attendance?ip=$ip&port=$port&password=$password';
    if (fromDate != null) {
      url += '&from=${fromDate.toIso8601String()}';
    }
    if (toDate != null) {
      url += '&to=${toDate.toIso8601String()}';
    }

    final uri = Uri.parse(url);
    try {
      final response = await http.get(uri).timeout(Duration(seconds: timeoutSeconds));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          final list = (data['logs'] as List? ?? []).cast<Map<String, dynamic>>();
          return list.map((l) {
            return ZkRawPunch(
              userId: (l['userId'] ?? '').toString().trim(),
              timestamp: DateTime.parse(l['timestamp'].toString()),
              status: l['status'] as int? ?? 0,
              punchType: l['punch'] as int? ?? 0,
            );
          }).toList();
        }
      }
    } catch (_) {}
    return [];
  }
}

ZkDeviceDriver getZkDeviceDriver() => ZkDeviceDriverWeb();
