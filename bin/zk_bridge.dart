// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:flutter_zk/flutter_zk.dart';

void main() async {
  const port = 5055;
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  print('================================================================');
  print(' ZKTeco Local Attendance Bridge running on http://127.0.0.1:$port');
  print(' Ready to bridge web browser requests to your ZKTeco device.');
  print(' Press Ctrl+C to stop.');
  print('================================================================');

  await for (HttpRequest request in server) {
    // Add CORS headers for browser access
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    request.response.headers.add('Access-Control-Allow-Headers', 'Content-Type, Authorization');

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      continue;
    }

    final path = request.uri.path;
    final params = request.uri.queryParameters;
    final ip = (params['ip'] ?? '192.168.1.201').trim();
    final zkPort = int.tryParse(params['port'] ?? '4370') ?? 4370;
    final password = int.tryParse(params['password'] ?? '0') ?? 0;

    print('[${DateTime.now().toString().substring(11, 19)}] ${request.method} $path (Device: $ip:$zkPort)');

    request.response.headers.contentType = ContentType.json;

    try {
      if (path == '/test' || path == '/info') {
        final zk = ZK(ip, port: zkPort, password: password);
        try {
          await zk.connect().timeout(const Duration(seconds: 8));

          String deviceName = '';
          String serialNumber = '';
          String firmware = '';
          String platform = '';
          String mac = '';
          DateTime? devTime;

          try { deviceName = await zk.getDeviceName(); } catch (_) {}
          try { serialNumber = await zk.getSerialNumber(); } catch (_) {}
          try { firmware = await zk.getFirmwareVersion(); } catch (_) {}
          try { platform = await zk.getPlatform(); } catch (_) {}
          try { mac = await zk.getMacAddress(); } catch (_) {}
          try { devTime = await zk.getTime(); } catch (_) {}

          int userCount = 0;
          int logCount = 0;
          try {
            await zk.readSizes();
            userCount = zk.usersCount;
            logCount = zk.recordsCount;
          } catch (_) {}

          await zk.disconnect();

          final result = {
            'success': true,
            'isConnected': true,
            'ip': ip,
            'port': zkPort,
            'deviceName': deviceName.isNotEmpty ? deviceName : 'ZKTeco Device',
            'serialNumber': serialNumber,
            'firmwareVersion': firmware,
            'platform': platform,
            'macAddress': mac,
            'userCount': userCount,
            'logCount': logCount,
            'deviceTime': devTime?.toIso8601String(),
          };
          request.response.statusCode = HttpStatus.ok;
          request.response.write(jsonEncode(result));
        } catch (e) {
          try { await zk.disconnect(); } catch (_) {}
          request.response.statusCode = HttpStatus.ok;
          request.response.write(jsonEncode({
            'success': false,
            'isConnected': false,
            'ip': ip,
            'port': zkPort,
            'error': e.toString().replaceAll('Exception:', '').trim(),
          }));
        }
      } else if (path == '/users') {
        final zk = ZK(ip, port: zkPort, password: password);
        try {
          await zk.connect().timeout(const Duration(seconds: 10));
          final users = await zk.getUsers();
          await zk.disconnect();

          final list = users.map((u) => {
            'uid': u.uid,
            'userId': u.userId.isNotEmpty ? u.userId : u.uid.toString(),
            'name': u.name,
            'privilege': u.privilege,
            'card': u.card,
          }).toList();

          request.response.statusCode = HttpStatus.ok;
          request.response.write(jsonEncode({'success': true, 'users': list}));
        } catch (e) {
          try { await zk.disconnect(); } catch (_) {}
          request.response.statusCode = HttpStatus.ok;
          request.response.write(jsonEncode({'success': false, 'error': e.toString()}));
        }
      } else if (path == '/attendance' || path == '/logs') {
        final zk = ZK(ip, port: zkPort, password: password);
        try {
          await zk.connect().timeout(const Duration(seconds: 12));

          DateTime? fromDate;
          DateTime? toDate;
          if (params['from'] != null) {
            fromDate = DateTime.tryParse(params['from']!);
          }
          if (params['to'] != null) {
            toDate = DateTime.tryParse(params['to']!);
          }

          final logs = await zk.getAttendance(
            fromDate: fromDate,
            toDate: toDate,
            sort: 'asc',
          );
          await zk.disconnect();

          final list = logs.map((l) => {
            'userId': l.userId.trim(),
            'timestamp': l.timestamp.toIso8601String(),
            'status': l.status,
            'punch': l.punch,
          }).toList();

          request.response.statusCode = HttpStatus.ok;
          request.response.write(jsonEncode({'success': true, 'logs': list}));
        } catch (e) {
          try { await zk.disconnect(); } catch (_) {}
          request.response.statusCode = HttpStatus.ok;
          request.response.write(jsonEncode({'success': false, 'error': e.toString()}));
        }
      } else {
        request.response.statusCode = HttpStatus.notFound;
        request.response.write(jsonEncode({'error': 'Not found'}));
      }
    } catch (e) {
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write(jsonEncode({'error': e.toString()}));
    }

    await request.response.close();
  }
}
