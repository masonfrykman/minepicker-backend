import 'dart:async';
import 'dart:io';

import '../Classes/instances.dart';
import '../Classes/world.dart';
import 'sockets/server_status_socket.dart';

int taps = 0;

void registerSignalListeners() {
  ProcessSignal.sigint.watch().listen((signal) => _genericExit());
  ProcessSignal.sigterm.watch().listen((signal) => _genericExit());
}

Future<void> _genericExit() async {
  taps++;
  if (taps == 3) {
    exit(0);
  }
  if (taps > 1) {
    print("Already exiting. Hit ^C a ${3 - taps} more time(s) for force quit.");
    return;
  }

  if (taps == 1) {
    updateStatusWithEventCode(StatusEventCode.shutdown);
  }

  print("\nGracefully exiting...");

  print("Stopping worlds (This will take 12 seconds)");
  for (World world in InstanceManager.shared.getWorldsList()) {
    await world.processManager.stop();
  }
  Future.delayed(Duration(seconds: 12), () async {
    await InstanceManager.shared.dumpWorldsToManifest();
    exit(0);
  });
}
