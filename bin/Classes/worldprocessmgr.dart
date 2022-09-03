import 'dart:convert';
import 'dart:io';
import 'dart:async';

import '../Helpers/embedded_lan_advertise.dart';
import '../Helpers/sockets_ports.dart';
import 'advert_mgr.dart';
import 'instances.dart';
import 'world.dart';
import 'stdout_socket_sub.dart';
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

    // TODO: await makeStdoutSocket();

    if (wantsAdvert) {
      advertise();
    }
  }

  /*
  Future<void> makeStdoutSocket() async {
    var getPort = getRandomSocketsPort();
    if (getPort == null) {
      return;
    }

    procSocket = await ServerSocket.bind(
        InternetAddress(config["BindAddress"]!), getPort);
    connectedStdoutSockets = [];
    procSocket!.listen((Socket newSocket) {
      print("NEW SOCKET!");
      if (connectedStdoutSockets == null) {
        return;
      }
      connectedStdoutSockets!.add(AuthenticatedSocket(newSocket, this));
    });

    print(procSocket!.address);
  }

  String? get stdoutSocketIPPortPair {
    if (procSocket == null) {
      return null;
    }
    return "${procSocket!.address.address}:${procSocket!.port}";
  }

  void stdoutSocketHasFinished(AuthenticatedSocket socket) {
    if (connectedStdoutSockets != null) {
      for (AuthenticatedSocket sock in connectedStdoutSockets!) {
        if (sock == socket) {
          connectedStdoutSockets!.remove(sock);
        }
      }
    }
  }
  */
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
    /*
    if (connectedStdoutSockets != null) {
      for (AuthenticatedSocket sock in connectedStdoutSockets!) {
        sock.sendIfAuthenticated(ln);
      }
    }
*/
    if (ln.contains("<") && ln.contains(">")) {
      return;
    }

    if (ln.contains("Done") && ln.contains("For help")) {
      // Server finish
      status = WorldProcessStatus.running;
      print("WPM for ${parent.uuid}: Detected server start finish");
    } else if (ln.contains("Encountered an unexpected exception")) {
      status = WorldProcessStatus.stopped;
      if (process != null) {
        process!.kill(ProcessSignal.sigkill);
        process = null;
      }
    } else if (ln.contains("Stopping the server")) {
      // Server stopping
      status = WorldProcessStatus.stopped;
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
