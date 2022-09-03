import 'dart:convert';

import 'package:shelf/shelf.dart';

import '../Classes/instances.dart';
import '../Classes/world.dart';
import '../Helpers/authentication.dart';
import '../Helpers/http_body_to_map.dart';
import '../Helpers/instance_caching.dart';

// Trash worlds

Response trashInstance(Request req, String uuid) {
  final trashAction = InstanceManager.shared.trashWorldByUUID(uuid);
  if (trashAction) {
    return Response.ok("Trashed world with uuid '$uuid'.");
  }
  return Response.internalServerError(
      body: "An error occured, likely world with uuid '$uuid' doesn't exist.");
}

Response trashedInstancesHandler(Request req) {
  return Response.ok(
      JsonEncoder().convert(InstanceManager.shared.getTrashedWorldsUUIDs()),
      headers: {"Content-Type": "application/json"});
}

Response restoreInstanceHandler(Request req, String uuid) {
  final chuuid = InstanceManager.shared.checkUUIDInTrash(uuid);
  if (!chuuid) {
    return Response.notFound("UUID not in trash.");
  }

  final action = InstanceManager.shared.restoreWorldByUUID(uuid);
  if (action) {
    return Response.ok("Successfully restored world.");
  }
  return Response.internalServerError(body: "Unknown error occured.");
}

// Create instance
Future<Response> createInstance(Request req) async {
  // Get world parameters
  final body = await req.readAsString();
  final worldparams = httpBodyToMap(body);

  if (!worldparams.containsKey("version") || !worldparams.containsKey("name")) {
    return Response.badRequest(
        body: "Resource requires version and name payload fields.");
  }

  // Create cache if not avaliable.
  final checkValidVersion = await canBeCached(worldparams["version"]!);
  if (!checkValidVersion) {
    return Response.badRequest(
        body:
            "Cannot create instance with version '${worldparams["version"]!}'. Refresh the cache and try again.");
  }

  final checkIfVersionIsCached = isCached(worldparams["version"]!);
  if (!checkIfVersionIsCached) {
    final doCache = await createCache(worldparams["version"]!);
    if (!doCache) {
      return Response.internalServerError(body: "Failed to create cache.");
    }
  }

  // Make World object
  var worldObject =
      World.full(worldparams["name"]!, worldparams["version"]!, null);

  if (worldparams.containsKey("backup-frequency")) {
    worldObject.backupFrequency =
        int.tryParse(worldparams["backup-frequency"]!);
  }
  if (worldparams.containsKey("max-memory")) {
    worldObject.maximumMemory = int.tryParse(worldparams["max-memory"]!);
  }
  if (worldparams.containsKey("min-memory")) {
    worldObject.minimumMemory = int.tryParse(worldparams["min-memory"]!);
  }
  if (!worldObject.verifyMemoryValues()) {
    return Response.badRequest(
        body:
            "Maximum memory value cannot be less than or equal to minimum memory value.");
  }

  worldObject.inferInstanceDirectory(onlyReplaceIfNull: false);

  try {
    await worldObject.createInstance();
  } catch (err) {
    return Response.internalServerError(
        body: "An error occured creating the instance on disk.");
  }

  InstanceManager.shared.safelyPushWorld(worldObject);
  await InstanceManager.shared.dumpWorldsToManifest();

  return Response.ok(JsonEncoder().convert(worldObject),
      headers: {"Content-Type": "application/json"});
}
