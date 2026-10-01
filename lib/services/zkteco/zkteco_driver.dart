import 'zkteco_models.dart';

abstract class ZkDeviceDriver {
  Future<ZkDeviceInfo> testConnection({
    required String ip,
    int port = 4370,
    int password = 0,
    int timeoutSeconds = 10,
  });

  Future<List<ZkDeviceUser>> getUsers({
    required String ip,
    int port = 4370,
    int password = 0,
    int timeoutSeconds = 10,
  });

  Future<List<ZkRawPunch>> getAttendanceLogs({
    required String ip,
    int port = 4370,
    int password = 0,
    DateTime? fromDate,
    DateTime? toDate,
    int timeoutSeconds = 15,
  });
}
