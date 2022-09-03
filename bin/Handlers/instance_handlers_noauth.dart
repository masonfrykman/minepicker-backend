import 'dart:convert';

import 'package:shelf/shelf.dart';

import '../Classes/instances.dart';

Response listInstances(Request req) {
  final stitcher = [];
  for (dynamic world in InstanceManager.shared.getWorldsList()) {
    stitcher.add({"name": world.name, "uuid": world.uuid});
  }

  final publish = JsonEncoder().convert(stitcher);
  return Response.ok(publish, headers: {"Content-Type": "application/json"});
}

Response instanceUUIDName(Request req, String uuid) {
  final search = InstanceManager.shared.getWorldByUUID(uuid);
  if (search == null) {
    return Response.notFound("World with uuid '$uuid' was not found.");
  }
  return Response.ok(search.name);
}

Response allUnauthFieldsUUID(Request req, String uuid) {
  // Exposes all fields of an instance that doesn't require authentication.
  final search = InstanceManager.shared.getWorldByUUID(uuid);
  if (search == null) {
    return Response.notFound("World with uuid '$uuid' was not found.");
  }

  final stitcher = {};
  stitcher["name"] = search.name;
  stitcher["version"] = search.serverVersion;

  if (search.backupFrequency != null) {
    if (search.backupFrequency! > 0) {
      stitcher["backup-enabled"] = true;
      stitcher["backup-freq-days"] = search.backupFrequency;
    } else {
      stitcher["backup-enabled"] = false;
    }
  } else {
    stitcher["backup-enabled"] = false;
  }

  final publish = JsonEncoder().convert(stitcher);
  return Response.ok(publish, headers: {"Content-Type": "application/json"});
}
