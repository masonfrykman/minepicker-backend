import 'dart:async';
import 'dart:io';

import '../Classes/instances.dart';
import '../Classes/world.dart';

void registerSignalListeners() {
  ProcessSignal.sigint.watch().listen((signal) => _genericExit());
  ProcessSignal.sigterm.watch().listen((signal) => _genericExit());
}

Future<void> _genericExit() async {
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
