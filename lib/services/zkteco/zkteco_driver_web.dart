import 'zkteco_driver.dart';
import 'zkteco_models.dart';

class ZkDeviceDriverWeb implements ZkDeviceDriver {
  @override
  Future<ZkDeviceInfo> testConnection({
    required String ip,
    int port = 4370,
    int password = 0,
    int timeoutSeconds = 10,
  }) async {
    return ZkDeviceInfo(
      isConnected: false,
      ip: ip,
      port: port,
      errorMessage:
          'Direct TCP socket connection to ZKTeco hardware is supported on the Windows Desktop app. Web browsers restrict raw socket connections.',
    );
  }

  @override
  Future<List<ZkDeviceUser>> getUsers({
    required String ip,
    int port = 4370,
    int password = 0,
    int timeoutSeconds = 10,
  }) async {
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
    return [];
  }
}

ZkDeviceDriver getZkDeviceDriver() => ZkDeviceDriverWeb();
