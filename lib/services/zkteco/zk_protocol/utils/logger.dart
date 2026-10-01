// Pure Dart logger without package:flutter
const bool kDebugMode = !bool.fromEnvironment('dart.vm.product');

void debugLog(
  String message, {
  String? name,
  Object? error,
  StackTrace? stackTrace,
}) {
  if (kDebugMode) {
    // ignore: avoid_print
    print(message);
    if (error != null) {
      // ignore: avoid_print
      print('Error: $error');
    }
    if (stackTrace != null) {
      // ignore: avoid_print
      print('StackTrace: $stackTrace');
    }
  }
}

