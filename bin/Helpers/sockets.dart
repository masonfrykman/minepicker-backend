import 'config.dart';

import 'dart:io';
import 'dart:math';

bool informationalSocketsAreAvaliable() =>
    (config["MaxSocketsPort"] != null && config["MinSocketsPort"] != null);

bool portOpen(int port) {
  final ptp =
      Process.runSync("nc", ["-z", config["BindAddress"]!, port.toString()]);
  if (ptp.exitCode == 0) {
    return true;
  }
  return false;
}

int? getFirstOpenPort(int max, int min) {
  int safetyValve;
  for (safetyValve = min; safetyValve <= max; safetyValve++) {
    if (portOpen(safetyValve)) {
      return safetyValve;
    }
  }
  return null; // No ports are open in the range.
}

int? getRandomInRange(int max, int min) {
  final random = Random();
  final mx = random.nextInt((max - min) + 1);
  return max - mx;
}

Future<ServerSocket?> getOpenSocket() async {
  if (!informationalSocketsAreAvaliable()) {
    return null;
  }

  final port = getFirstOpenPort(int.parse(config["MaxSocketsPort"]!),
      int.parse(config["MinSocketsPort"]!));

  if (port == null) {
    return null; // No open ports.
  }

  return await ServerSocket.bind(config["BindAddress"], port);
}
