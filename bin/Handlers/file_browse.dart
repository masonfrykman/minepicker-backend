import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';

import '../Helpers/config.dart';
import '../Helpers/file_explorer.dart';

Future<Response> fmAccessGet(Request req, String uuid, String path) async {
  print(path);

  // Check against explicitly disallowed downloads.
  if (path.split("/").last == "server.properties") {
    return Response.forbidden(
        "Accessing server.properties in any context is explicitly forbidden.");
  }

  final typeQuery = await pathIsFile(path, uuid);
  if (typeQuery == null) {
    return Response.notFound("$path could not be found on the server.");
  }

  if (typeQuery) {
    final fpath = path.replaceAll("..", "");
    final requestedFile =
        File("${config['RootMinecraftDirectory']}instances/$uuid/$fpath");
    final contents = await requestedFile.readAsBytes();
    return Response.ok(contents, headers: {"X-FileType": "file"});
  } else {
    if (req.headers["x-dl"] != "true") {
      final fpath = path.replaceAll("..", "");
      final lister = await listDirectory(fpath, uuid);
      if (lister == null) {
        print("ugh");
        return Response.notFound("$path could not be found on the server.");
      }

      return Response.ok(JsonEncoder().convert(lister),
          headers: {"X-FileType": "directory"});
    } else {
      final fpath = path.replaceAll("..", "");
      final requestedPath =
          "${config['RootMinecraftDirectory']}instances/$uuid/$fpath";

      var tarringCmd =
          await Process.run("tar", ["--to-stdout", "-zcv", requestedPath]);

      if (tarringCmd.exitCode == 0) {
        return Response.ok(tarringCmd.stdout, headers: {
          "Content-Type": "application/tar+gzip",
          "X-FileType": "file"
        });
      }
      return Response.internalServerError(
          body: "Failed to tarball the directory contents.");
    }
  }
}

Future<Response> fmAccessPut(Request req, String uuid, String path) async {
  if (path.split("/").last == "server.properties") {
    return Response.forbidden(
        "Accessing server.properties in any context is explicitly forbidden.");
  }

  final instanceDir = instanceDirectoryOf(uuid);
  if (instanceDir == null) {
    return Response.notFound("$path could not be found on the server.");
  }

  if (await FileSystemEntity.type("$instanceDir/$path") !=
      FileSystemEntityType.notFound) {
    if (req.headers["x-overwrite"] != "true") {
      return Response(409, body: "$path already exists.");
    }
  }

  var fileToWrite = File("$instanceDir/$path");
  fileToWrite.create(recursive: true);
  var ftwOpen = fileToWrite.openWrite();
  var body = req.read();
  await body.forEach((element) => ftwOpen.add(element));
  await ftwOpen.flush();
  await ftwOpen.close();

  return Response.ok("Successfully wrote to $path");
}

Future<Response> fmAccessDelete(Request req, String uuid, String path) async {
  if (path.split("/").last.trim() == "server.properties") {
    return Response.forbidden(
        "Accessing server.properties in any context is explicitly forbidden.");
  } else if (path.split("/").last.trim() == "eula.txt") {
    return Response.forbidden(
        "Deleting the EULA is forbidden. Discontinue and/or remove this software if you disagree with the Minecraft EULA.");
  }

  if (path.trim().replaceAll("/", "") == "" || path.isEmpty) {
    return Response.forbidden("No deleting the whole thing!");
  }

  final instanceDir = instanceDirectoryOf(uuid);
  if (instanceDir == null) {
    return Response.notFound("$path could not be found on the server.");
  }

  if (await FileSystemEntity.type("$instanceDir/$path") ==
      FileSystemEntityType.notFound) {
    return Response.notFound("$path could not be found on the server.");
  }

  await File("$instanceDir/$path").delete(recursive: true);
  return Response.ok("Successfully deleted $path.");
}

Future<Response> fmAccessHead(Request req, String uuid, String path) async {
  print(path);

  final pc = await pathIsFile(path, uuid);
  if (pc == null) {
    return Response.notFound(null);
  }

  if (pc) {
    return Response.ok(null, headers: {"X-FileType": "file"});
  } else if (!pc) {
    return Response.ok(null, headers: {"X-FileType": "directory"});
  }
  return Response.notFound(null);
}
