import 'dart:io';

import '../Helpers/config.dart';

import 'dart:async';
import 'dart:convert';

class MulticastAdvertManager {
  static MulticastAdvertManager shared = MulticastAdvertManager();

  List<Map<String, String>> _shouldAdvertise = [];

  bool running = false;

  Timer? _loop;
  RawDatagramSocket? _sock;

  void start() async {
    if (_loop != null) {
      _loop!.cancel();
    }

    _sock ??= await RawDatagramSocket.bind(config["BindAddress"]!, 36521,
        reusePort: true);
    _sock!.broadcastEnabled = true;

    _loop = Timer.periodic(Duration(seconds: 2), (timer) async {
      for (Map<String, String> advertDetail in _shouldAdvertise) {
        _sock!.send(
            Utf8Encoder().convert(
                "[MOTD]${advertDetail['name']}[/MOTD][AD]${advertDetail['port']}[/AD]"),
            InternetAddress("255.255.255.255"),
            4445); // Port MUST be 4445 here.
      }
    });

    running = true;
  }

  void stop() {
    if (_loop != null) {
      _loop!.cancel();
      _loop = null;
    }
    running = false;
  }

  void add(String name, int port) {
    if (name.isEmpty || port <= 0) {
      return;
    }

    for (Map<String, String> adv in _shouldAdvertise) {
      if (adv["port"] == port.toString()) {
        return;
      }
    }
    _shouldAdvertise.add({"name": name, "port": port.toString()});
  }

  void remove(int port) {
    List<Map<String, String>> stitch = [];

    for (Map<String, String> adv in _shouldAdvertise) {
      if (adv["port"] == port.toString()) {
        continue;
      }
      stitch.add(adv);
    }

    _shouldAdvertise = stitch;
  }
}
