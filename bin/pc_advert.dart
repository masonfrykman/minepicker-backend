import 'dart:async';
import 'dart:convert';
import 'dart:io';

void main(List<String> args) async {
  List<Map<String, String>> toAdvert = [
    {"name": "Foobar", "port": "25565"},
    {"name": "Foo", "port": "25561"},
    {"name": "Bar", "port": "26187"}
  ];

  // Switch the anyIPv4 to the IP address of the Server Address of the running server instance if needed.
  // The MC client assumes the IP that's being advertised from is the address of the running instance

  final sock = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 23399,
      reusePort: true);
  sock.broadcastEnabled = true;
  Timer.periodic(Duration(seconds: 2), (timer) async {
    for (Map<String, String> advertDetail in toAdvert) {
      sock.send(
          Utf8Encoder().convert(
              "[MOTD]${advertDetail['name']}[/MOTD][AD]${advertDetail['port']}[/AD]"),
          InternetAddress("255.255.255.255"),
          4445); // Port MUST be 4445 here.
    }
  });
}
