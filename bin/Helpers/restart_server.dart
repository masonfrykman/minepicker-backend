import 'dart:io';

import 'package:shelf/shelf.dart';

bool _serverWillRestart = false;

Future<bool> restartServer() async {
  if (_serverWillRestart == true) {
    return true;
  }

  if (!await checkBackendServiceExistance()) {
    Future.delayed(Duration(seconds: 20), () async {
      print(Platform.script.path);
      if (Platform.isLinux) {
        final rp = await Process.start(
            "/sbin/mprestart", ["$pid", Platform.script.path],
            mode: ProcessStartMode.detached);
      } else if (Platform.isMacOS) {
        final rp = await Process.start(
            "/Applications/Utilities/mprestart", ["$pid", Platform.script.path],
            mode: ProcessStartMode.detached);
      }
      exit(0);
    });
  } else {
    Future.delayed(Duration(seconds: 20), () {
      Process.runSync("systemctl", ["restart", "mpbackend.service"]);
    });
  }
  _serverWillRestart = true;
  return true;
}

Future<bool> checkBackendServiceExistance() async {
  try {
    final query =
        await Process.run("systemctl", ["--all", "--type", "service"]);
    if (query.stdout.toString().contains("mpbackend.service") &&
        query.exitCode == 0) {
      return true;
    }
    return false;
  } catch (err) {
    return false;
  }
}

bool willServerRestart() {
  return _serverWillRestart;
}
