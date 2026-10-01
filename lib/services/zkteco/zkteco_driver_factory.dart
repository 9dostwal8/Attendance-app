import 'zkteco_driver.dart';
import 'zkteco_driver_io.dart' if (dart.library.html) 'zkteco_driver_web.dart';

ZkDeviceDriver createZkDriver() => getZkDeviceDriver();
