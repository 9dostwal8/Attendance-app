/// A Dart library for connecting to and managing ZKTeco biometric devices.
///
/// This library provides a high-level API for interacting with ZKTeco devices
/// over a TCP/IP network. It supports operations such as fetching users,
/// attendance records, and device information, as well as controlling the device
/// (e.g., restarting, opening doors).
library;

export 'zk_base.dart';
export 'exceptions.dart';
export 'models/attendance.dart';
export 'models/user.dart';
export 'models/finger.dart';
