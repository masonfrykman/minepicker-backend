import 'dart:convert';
import 'dart:io';

// Base layer of the cake to ensure the MPBackend server software never exits.
// Also monitors stdout & stderr for any important info.

void main(List<String> args) async {
  if (args.isEmpty) {
    exit(1);
  }

  secondLayerFunc(args);
}

void secondLayerFunc(List<String> args) async {
  final secondLayer = await Process.start(args.first, [pid.toString()]);
  secondLayer.exitCode.then((value) => () {
        if (value != 0) {
          stderr.write("Second layer exited with $value.");
        }
        secondLayerFunc(args);
      });

  secondLayer.stdout.transform(Utf8Decoder()).listen((String output) {
    print(output);
  });
  secondLayer.stderr.transform(Utf8Decoder()).listen((String err) {
    print("ERROR!!!!: $err");
  });
}
