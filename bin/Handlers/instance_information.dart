import 'package:shelf/shelf.dart';

import 'dart:convert';

import '../Classes/instances.dart';
import '../Helpers/authentication.dart';
import '../Helpers/http_body_to_map.dart';

Response allFieldsByUUID(Request req, String uuid) {
  final search = InstanceManager.shared.getWorldByUUID(uuid);
  if (search == null) {
    return Response.notFound("World with uuid '$uuid' was not found.");
  }

  final publish = JsonEncoder().convert(search);
  return Response.ok(publish, headers: {"Content-Type": "application/json"});
}

Future<Response> patchUpdateInstance(Request req, String uuid) async {
  // Convert body string -> Map
  final body = await req.readAsString();
  final paramsMap = httpBodyToMap(body);
  if (!paramsMap.containsKey("field")) {
    return Response.badRequest(
        body: "Request to this URI must contain the field key in the body.");
  }

  // Check UUID exists.
  final world = InstanceManager.shared.getWorldByUUID(uuid);
  if (world == null) {
    return Response.notFound("World with UUID '$uuid' does not exist.");
  }

  if (paramsMap["field"] == "name") {
    if (!paramsMap.containsKey("new-value")) {
      return Response.badRequest(
          body: "Field 'name' expects additional payload 'new-value'.");
    }
    world.name = paramsMap["new-value"]!.trim();
    return Response.ok('Successfully updated world name.');
  } /*else if (paramsMap["field"] == "version") {
    // TODO: Maybe in another universe.
    if (!paramsMap.containsKey("new-value")) {
      return Response.badRequest(
          body: "Field 'version' expects additional payload 'new-value'.");
    }
    world.serverVersion = paramsMap["new-value"]!.trim();
    return Response.ok('Successfully updated version.');
  }*/
  else if (paramsMap["field"] == "backup-freq-days") {
    if (paramsMap.containsKey("disable")) {
      if (paramsMap["disable"] == "true") {
        // Allow disabling.
        world.backupFrequency = null;
        return Response.ok("Successfully disabled backup on world.");
      }
    }
    if (!paramsMap.containsKey("new-value")) {
      return Response.badRequest(
          body:
              "Field 'backup-freq-days' expects additional payload 'new-value'.");
    }
    final nfi = int.tryParse(paramsMap["new-value"]!.trim());
    if (nfi == null) {
      return Response.badRequest(body: "new-value payload must be an integer.");
    }
    world.backupFrequency = nfi;
    return Response.ok('Successfully updated version.');
  } else if (paramsMap["field"] == "memory") {
    String? extractedMax;
    String? extractedMin;
    if (paramsMap.containsKey("new-max")) {
      extractedMax = paramsMap["new-max"]!;
    }
    if (paramsMap.containsKey("new-min")) {
      extractedMin = paramsMap["new-min"]!;
    }

    // Check for null
    if (extractedMax == null && extractedMin == null) {
      return Response.badRequest(
          body:
              "Field 'memory' expects addition payload(s) 'new-max' and/or 'new-min'.");
    } else if (extractedMax != null && extractedMin != null) {
      // Changing both.
      int? convMax = int.tryParse(extractedMax) ?? world.maximumMemory;
      int? convMin = int.tryParse(extractedMin) ?? world.minimumMemory;

      if (convMax == null || convMin == null) {
        return Response.badRequest(body: "Values provided must be integer.");
      }

      if (convMax < convMin) {
        return Response.badRequest(
            body:
                "Maximum value must be larger than minimum value ($convMax < $convMin).");
      }

      world.maximumMemory = convMax;
      world.minimumMemory = convMin;

      return Response.ok(
          "Successfully updated memory values to $convMax and $convMin");
    } else if (extractedMax != null && extractedMin == null) {
      // Just changing max value.
      int? convMax = int.tryParse(extractedMax) ?? world.maximumMemory;
      int? convMin = world.minimumMemory;

      if (convMax == null) {
        return Response.badRequest(body: "Values provided must be integer.");
      }
      if (convMin == null) {
        world.maximumMemory = convMax;
      } else {
        if (convMax < convMin) {
          return Response.badRequest(
              body: "Maximum value must be larger than minimum value.");
        }
        world.maximumMemory = convMax;
      }

      return Response.ok("Maximum value updated to $convMax");
    } else if (extractedMax == null && extractedMin != null) {
      // Just changing max value.
      int? convMax = world.maximumMemory;
      int? convMin = int.tryParse(extractedMin) ?? world.minimumMemory;

      if (convMin == null) {
        return Response.badRequest(body: "Values provided must be integer.");
      }
      if (convMax == null) {
        world.minimumMemory = convMin;
      } else {
        if (convMax < convMin) {
          return Response.badRequest(
              body: "Maximum value must be larger than minimum value.");
        }
        world.minimumMemory = convMin;
      }

      return Response.ok("Minimum value updated to $convMin");
    }
    return Response.internalServerError(body: "Unknown error occurred.");
  }
  return Response.badRequest(
      body: "Unrecognized payload field '${paramsMap['field']}'.");
}

Future<Response> dumpManifestHandler(Request req) async {
  if (req.headers["x-username"] == null || req.headers["x-password"] == null) {
    return Response(401,
        body: "Failed to authenticate: not enough credentials provided.");
  }

  final auth =
      authenticateUser(req.headers["x-username"]!, req.headers["x-password"]!);
  if (!auth) {
    return Response.forbidden("Failed to authenticate: incorrect credentials.");
  }

  await InstanceManager.shared.dumpWorldsToManifest();
  return Response.ok("Successfully saved manifest to disk.");
}

// Formerly in instance_handlers_noauth.dart

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
