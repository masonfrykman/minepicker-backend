import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart';

import 'config.dart';
import 'mojang_versions_getter.dart';

bool isCached(String version) {
  final vconv = version.replaceAll(".", "-");

  if (Directory(
          "${config['RootMinecraftDirectory']}internal/instance-cache/$vconv")
      .existsSync()) {
    return true;
  }
  return false;
}

Future<bool> createCache(String version) async {
  print("CREATE CACHE REQUEST: $version");
  if (isCached(version)) {
    return true;
  }

  final vconv = version.replaceAll(".", "-");
  final indirectoryPath =
      "${config['RootMinecraftDirectory']}internal/instance-cache/$vconv";
  await Directory(indirectoryPath).create(recursive: true);
  await File("$indirectoryPath/creation.lock").create();

  // Get server jar
  final cachedDict = await getVersionDictFromCache(version);
  if (cachedDict == null) {
    return false;
  }

  if (cachedDict["url"] == null) {
    return false;
  }

  final jsonWithJarLink = await get(Uri.parse(cachedDict["url"] as String));
  if (jsonWithJarLink.headers["content-type"] != "application/json" ||
      jsonWithJarLink.body.isEmpty) {
    return false;
  }

  final jwjlBodyJSON = JsonDecoder().convert(jsonWithJarLink.body);
  if (jwjlBodyJSON["downloads"] == null) {
    return false;
  }
  if (jwjlBodyJSON["downloads"]["server"] == null) {
    return false;
  }
  if (jwjlBodyJSON["downloads"]["server"]["url"] == null) {
    return false;
  }

  final jar = await get(Uri.parse(jwjlBodyJSON["downloads"]["server"]["url"]!));
  if (jar.statusCode != 200) {
    return false;
  }

  await File("$indirectoryPath/server.jar").writeAsBytes(jar.bodyBytes);

  // This is why that EULA notice is put up when the program is run.
  await File("$indirectoryPath/eula.txt").writeAsString("eula=true");

  await File("$indirectoryPath/creation.lock").delete();
  return true;
}

Future<bool> removeCache(String version) async {
  print("REMOVE CACHE REQUEST: $version");
  if (!isCached(version)) {
    return true;
  }

  final vconv = version.replaceAll(".", "-");
  final indirectoryPath =
      "${config['RootMinecraftDirectory']}internal/instance-cache/$vconv";

  await Directory(indirectoryPath).delete(recursive: true);
  return true;
}

Future<bool> canBeCached(String version) async {
  final cachedDict = await getVersionDictFromCache(version);
  if (cachedDict == null) {
    return false;
  }
  return true;
}

String? getCacheDirectory(String version) {
  final vconv = version.replaceAll(".", "-");

  if (Directory(
          "${config['RootMinecraftDirectory']}internal/instance-cache/$vconv")
      .existsSync()) {
    return "${config['RootMinecraftDirectory']}internal/instance-cache/$vconv";
  }
  return null;
}
