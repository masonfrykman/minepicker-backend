import 'dart:io';

Map<String, String> parseConfigFile(String path) {
  var config = File(path);

  var configLines = config.readAsLinesSync();

  if (configLines.isEmpty) {
    // The server can't start without configs.
    stderr.write("Configs (from $path) was empty.");
    exit(255);
  }

  Map<String, String> result = {};
  configLines.forEach((element) {
    if (element.startsWith("#")) {
      return; // Don't include comments.
    }
    String? key;
    String? value;
    var sp = element.trim().split(" ");
    for (var word in sp) {
      if (key == null) {
        key = word;
      } else {
        if (value == null) {
          value = word;
        } else {
          value += " $word";
        }
      }
    }

    if (value == null || key == null) {
      return;
    }
    result.addAll({key: value});
  });

  return result;
}
