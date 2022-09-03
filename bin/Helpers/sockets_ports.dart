/*import 'dart:math';

import '../Classes/instances.dart';
import 'config.dart';

int? getRandomSocketsPort() {
  int? max = int.tryParse(config["MaxSocketsPort"]!);
  int? min = int.tryParse(config["MinSocketsPort"]!);
  if (max == null || min == null) {
    return null;
  }

  var range = max - min;
  while (true) {
    var port = Random().nextInt(range + 1) + min;
    if (InstanceManager.shared.portTest(port)) {
      return port;
    }
  }
}
*/