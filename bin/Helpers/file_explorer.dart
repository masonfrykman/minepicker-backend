import 'dart:io';

import 'config.dart';

String? instanceDirectoryOf(String uuid) {
  if (uuid.trim().isEmpty) {
    return null;
  }
  var infer = "${config['RootMinecraftDirectory']}instances/$uuid";
  if (Directory(infer).existsSync()) {
    return infer;
  }
  return null;
}

Future<List<Map<String, String>>?> listDirectory(
    String path, String fromUUID) async {
  var instanceDir = instanceDirectoryOf(fromUUID);
  if (instanceDir == null) {
    return null;
  }

  var pcheck = path.replaceAll("..", ""); // Prevent listing things from before.

  var listStream = Directory("$instanceDir/$pcheck").list(followLinks: false);
  var tl = await listStream.toList();
  List<Map<String, String>> list = [];

  for (FileSystemEntity entity in tl) {
    if (!entity.path.startsWith(".")) {
      if (await FileSystemEntity.isFile(entity.path)) {
        list.add({"name": entity.path.split("/").last, "type": "file"});
      } else if (await FileSystemEntity.isDirectory(entity.path)) {
        list.add({"name": entity.path.split("/").last, "type": "directory"});
      }
    }
  }

  return list;
}

Future<bool?> pathIsFile(String path, String fromUUID) async {
  // True: file
  // False: directory
  // null: does not exist / is not file or dir (ex. link).

  var instanceDir = instanceDirectoryOf(fromUUID);
  if (instanceDir == null) {
    return null;
  }

  final pc =
      await FileSystemEntity.type("$instanceDir/$path", followLinks: false);
  if (pc == FileSystemEntityType.notFound) {
    return null;
  } else if (pc == FileSystemEntityType.file) {
    return true;
  } else if (pc == FileSystemEntityType.directory) {
    return false;
  }
  return null;
}
