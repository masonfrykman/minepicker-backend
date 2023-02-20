import 'dart:convert';
import 'dart:io';
import 'dart:async';

import '../Helpers/sockets/server_status_socket.dart';
import 'advert_mgr.dart';
import 'instances.dart';
import 'world.dart';
import '../Helpers/config.dart';

class WorldProcessManager {
  WorldProcessStatus status = WorldProcessStatus.stopped;
  Process? process;
  World parent;

  int? runningAt;
  ServerSocket? procSocket;
  // List<AuthenticatedSocket>? connectedStdoutSockets;

  List<String> players = [];

  Timer? awaitStop;

  WorldProcessManager(this.parent);

  Future<void> start(
      {bool wantsStatic = false, bool wantsAdvert = false}) async {
    status = WorldProcessStatus.starting;
    updateStatusWithEventCode(StatusEventCode.instanceStarting,
        instanceUUID: parent.uuid);
    if (process != null) {
      process!.kill(ProcessSignal.sigkill);
    }

    var port = await parent.createServerProperties(wantsStatic: wantsStatic);
    var register = InstanceManager.shared.registerIfPortAvaliable(port, parent);
    if (!register) {
      throw "Failed to register port used by the Minecraft server software.";
    }

    runningAt = port;

    Directory.current = Directory(parent.instanceDirectory!);
    process = await Process.start(
        "/usr/bin/java",
        [
          "-Xmx${parent.maximumMemory ?? config["DefaultMaximumMemoryMegabytes"]}M",
          "-Xms${parent.minimumMemory ?? config["DefaultMinimumMemoryMegabytes"]}M",
          "-Duser.dir=${parent.instanceDirectory}",
          "-jar",
          "${parent.instanceDirectory}/server.jar",
          "nogui"
        ],
        runInShell: true);

    process!.stdout.listen(
      (List<int> event) {
        final transform = Utf8Decoder().convert(event);
        _processProcessOutput(transform);
      },
      onDone: () async {
        print("STDOUT for ${parent.uuid} is closing!");
        status = WorldProcessStatus.stopped;
        updateStatusWithEventCode(StatusEventCode.instanceStop,
            instanceUUID: parent.uuid);
      },
    );
    process!.stderr.listen(
      (List<int> event) {
        print("stderr event");
        final transform = Utf8Decoder().convert(event);
        print(transform);
      },
      onDone: () {
        print("STDERR for ${parent.uuid} is closing!");
      },
    );
    awaitStop = Timer.periodic(Duration(seconds: 10), (timer) {
      if (status != WorldProcessStatus.stopped) {
        return;
      }

      players.clear();

      timer.cancel();
    });

    if (wantsAdvert) {
      advertise();
    }
  }

  Future<void> stop() async {
    if (process == null) {
      return;
    }
    await sendCommand("stop"); // Try to stop the world this way.
    MulticastAdvertManager.shared.remove(runningAt!);
    delayedCleanup();
  }

  Future<void> forceKill() async {
    if (process == null) {
      return;
    }
    process!.kill(ProcessSignal.sigkill);
    if (runningAt != null) {
      MulticastAdvertManager.shared.remove(runningAt!);
    }
    delayedCleanup();
  }

  void delayedCleanup() {
    Future.delayed(Duration(seconds: 15), () {
      print("WPM for ${parent.uuid}: Cleaning up.");
      if (process != null) {
        process!.kill();
      }
      if (runningAt != null) {
        MulticastAdvertManager.shared.remove(runningAt!);
      }
      process = null;
      status = WorldProcessStatus.stopped;
      updateStatusWithEventCode(StatusEventCode.instanceStop,
          instanceUUID: parent.uuid);
    });
  }

  Future<void> sendCommand(String command) async {
    if (process == null) {
      return;
    }
    process!.stdin.writeln(command);
    await process!.stdin.flush();
  }

  void advertise() async {
    print("WPM for ${parent.uuid}: Trying lan advertisement by request.");
    if (process == null || runningAt == null) {
      print("WPM for ${parent.uuid}: Cancelling advertisement.");
      return;
    }
    MulticastAdvertManager.shared.add(parent.name, runningAt!);
  }

  void _processProcessOutput(String ln) {
    print("PROCESSING THREAD: $ln");
    if (ln.contains("<") && ln.contains(">")) {
      return;
    }

    if (ln.contains("Done") && ln.contains("For help")) {
      // Server finish
      status = WorldProcessStatus.running;
      updateStatusWithEventCode(StatusEventCode.instanceStart,
          instanceUUID: parent.uuid);
      print("WPM for ${parent.uuid}: Detected server start finish");
    } else if (ln.contains("Encountered an unexpected exception")) {
      status = WorldProcessStatus.stopped;
      updateStatusWithEventCode(StatusEventCode.instanceStop,
          instanceUUID: parent.uuid);
      if (process != null) {
        process!.kill(ProcessSignal.sigkill);
        process = null;
      }
    } else if (ln.contains("Stopping the server")) {
      // Server stopping
      status = WorldProcessStatus.stopped;
      updateStatusWithEventCode(StatusEventCode.instanceStop,
          instanceUUID: parent.uuid);
      print("WPM for ${parent.uuid}: Detected stopping server.");
      delayedCleanup();
    } else if (ln.contains("joined the game")) {
      playerJoinedGame(ln);
    } else if (ln.contains("left the game")) {
      playerLeftGame(ln);
    }
  }

  void playerJoinedGame(String outputLine) {
    final search = outputLine.split(":").last.trim().split(" ").first;
    players.add(search.trim());
  }

  void playerLeftGame(String outputLine) {
    final search = outputLine.split(":").last.trim().split(" ").first;
    players.remove(search.trim());
  }

  void quickReset() {
    if (process != null) {
      process!.kill(ProcessSignal.sigkill);
      process = null;
    }
    if (runningAt != null) {
      MulticastAdvertManager.shared.remove(runningAt!);
    }
    status = WorldProcessStatus.stopped;
    updateStatusWithEventCode(StatusEventCode.instanceStop,
        instanceUUID: parent.uuid);
    runningAt = null;
    if (procSocket != null) {
      procSocket!.close().then((value) {
        procSocket = null;
      });
    }
    players.clear();
    if (awaitStop != null) {
      awaitStop!.cancel();
      awaitStop = null;
    }
  }
}

enum WorldProcessStatus { running, stopped, starting }
