import 'dart:convert';
import 'dart:io';

import 'config.dart';

import 'package:http/http.dart';

Future<void> refreshMojangMCVersionsList() async {
  final httpGetter = await get(Uri.parse(
      "http://launchermeta.mojang.com/mc/game/version_manifest_v2.json"));

  if (httpGetter.headers["content-type"] != "application/json") {
    return;
  }

  if (httpGetter.body.isEmpty) {
    throw VersionRefreshFailure("Response body is empty.");
  }

  final toJSON = JsonDecoder().convert(httpGetter.body);
  if (toJSON["versions"] == null) {
    throw VersionRefreshFailure(
        "Converted JSON from HTTP response does not contain 'versions'.");
  }

  final versionsList = toJSON["versions"]!;
  final List<Map<String, String>> extractedList = [];

  for (dynamic version in versionsList) {
    if (version["type"] != "release" ||
        version["id"] == null ||
        version["url"] == null) {
      continue;
    }
    extractedList.add(
        {"name": version["id"]! as String, "url": version["url"]! as String});
  }

  await Directory("${config["RootMinecraftDirectory"]}internal")
      .create(recursive: true); // Ensure internal exists.
  await File("${config["RootMinecraftDirectory"]}internal/versions.json")
      .writeAsString(JsonEncoder().convert(extractedList), flush: true);
}

Future<Map<String, dynamic>?> getVersionDictFromCache(String version) async {
  if (!await File("${config['RootMinecraftDirectory']}internal/versions.json")
      .exists()) {
    await refreshMojangMCVersionsList();
  }
  final versionsContent = JsonDecoder().convert(
      await File("${config['RootMinecraftDirectory']}internal/versions.json")
          .readAsString());

  for (dynamic versionDict in versionsContent) {
    if (versionDict["name"] == version) {
      return versionDict;
    }
  }
  return null;
}

class VersionRefreshFailure implements Exception {
  String reason;

  VersionRefreshFailure(this.reason);

  @override
  String toString() {
    return "Refresh failed: $reason";
  }
}
