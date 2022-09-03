import 'package:shelf/shelf.dart';

import 'dart:io';

import '../Helpers/authentication.dart';
import '../Helpers/config.dart';
import '../Helpers/http_body_to_map.dart';
import '../Helpers/instance_caching.dart';
import '../Helpers/mojang_versions_getter.dart';

Future<Response> listMCVersionsCached(Request req) async {
  final versionsFile =
      File("${config['RootMinecraftDirectory']}internal/versions.json");

  if (!await versionsFile.exists()) {
    await refreshMojangMCVersionsList();
  }

  final vContents = await versionsFile.readAsString();
  return Response.ok(vContents, headers: {"Content-Type": "application/json"});
}

Future<Response> cacheMCVersion(Request req, String version) async {
  if (isCached(version)) {
    return Response.ok("Version is already cached.");
  }

  final action = await createCache(version);
  if (action) {
    return Response.ok("Successfully cached version specified.");
  }
  return Response.internalServerError(
      body: "Failed to cache. Check version specified.");
}

Future<Response> removeCachedMCVersion(Request req, String version) async {
  if (!isCached(version)) {
    return Response.ok("Version is not cached.");
  }

  final check = await removeCache(version);
  if (check) {
    return Response.ok("Removed cache of version $version");
  }
  return Response.internalServerError(
      body: "Failed to remove cache. It may be locked.");
}

Future<Response> forceRefreshVersionsList(Request req) async {
  await refreshMojangMCVersionsList();
  return Response.ok("Refreshed version list.");
}
