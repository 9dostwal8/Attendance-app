// Model definitions for ZKTeco integration

class ZkDeviceInfo {
  final bool isConnected;
  final String deviceName;
  final String serialNumber;
  final String firmwareVersion;
  final String platform;
  final String macAddress;
  final String ip;
  final int port;
  final int userCount;
  final int logCount;
  final DateTime? deviceTime;
  final String? errorMessage;

  const ZkDeviceInfo({
    this.isConnected = false,
    this.deviceName = '',
    this.serialNumber = '',
    this.firmwareVersion = '',
    this.platform = '',
    this.macAddress = '',
    this.ip = '',
    this.port = 4370,
    this.userCount = 0,
    this.logCount = 0,
    this.deviceTime,
    this.errorMessage,
  });

  ZkDeviceInfo copyWith({
    bool? isConnected,
    String? deviceName,
    String? serialNumber,
    String? firmwareVersion,
    String? platform,
    String? macAddress,
    String? ip,
    int? port,
    int? userCount,
    int? logCount,
    DateTime? deviceTime,
    String? errorMessage,
  }) {
    return ZkDeviceInfo(
      isConnected: isConnected ?? this.isConnected,
      deviceName: deviceName ?? this.deviceName,
      serialNumber: serialNumber ?? this.serialNumber,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      platform: platform ?? this.platform,
      macAddress: macAddress ?? this.macAddress,
      ip: ip ?? this.ip,
      port: port ?? this.port,
      userCount: userCount ?? this.userCount,
      logCount: logCount ?? this.logCount,
      deviceTime: deviceTime ?? this.deviceTime,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class ZkRawPunch {
  final String userId;
  final DateTime timestamp;
  final int status; // 0: Check-In, 1: Check-Out, etc.
  final int punchType; // 0: Finger, 1: Password, 2: Card

  const ZkRawPunch({
    required this.userId,
    required this.timestamp,
    this.status = 0,
    this.punchType = 0,
  });

  @override
  String toString() => 'Punch(user: $userId, time: $timestamp, status: $status)';
}

class ZkDeviceUser {
  final int uid;
  final String userId;
  final String name;
  final int privilege;
  final int card;

  const ZkDeviceUser({
    required this.uid,
    required this.userId,
    required this.name,
    this.privilege = 0,
    this.card = 0,
  });
}

class ZkSyncSummary {
  final bool success;
  final int totalPunchesFetched;
  final int newRecordsCreated;
  final int recordsUpdated;
  final DateTime syncTime;
  final String message;
  final List<String> details;

  const ZkSyncSummary({
    required this.success,
    this.totalPunchesFetched = 0,
    this.newRecordsCreated = 0,
    this.recordsUpdated = 0,
    required this.syncTime,
    required this.message,
    this.details = const [],
  });
}
