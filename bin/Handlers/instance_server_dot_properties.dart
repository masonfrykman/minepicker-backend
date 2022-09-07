import 'dart:convert';

import 'package:shelf/shelf.dart';

import '../Classes/instances.dart';
import '../Classes/worldprocessmgr.dart';
import '../Helpers/http_body_to_map.dart';

Future<Response> refreshServerProperties(Request req, String uuid) async {
  final world = InstanceManager.shared.getWorldByUUID(uuid);
  if (world == null) {
    return Response.notFound("Failed to find world with uuid '$uuid'.");
  }

  if (world.processManager.status != WorldProcessStatus.stopped) {
    return Response(503,
        body:
            "This command cannot be run while the target instance isn't stopped.");
  }

  await world.createServerProperties();
  return Response.ok("Successfully refreshed properties.");
}

Future<Response> addServerPropertiesMixin(Request req, String uuid) async {
  final world = InstanceManager.shared.getWorldByUUID(uuid);
  if (world == null) {
    return Response.notFound("Failed to find world with uuid '$uuid'.");
  }

  if (world.processManager.status != WorldProcessStatus.stopped) {
    return Response(503,
        body:
            "This command cannot be run while the target instance isn't stopped.");
  }

  final body = await req.readAsString();
  final paramsMap = httpBodyToMap(body);
  if (!paramsMap.containsKey("key") || !paramsMap.containsKey("value")) {
    return Response.badRequest(body: "Request must contain key & value keys.");
  }

  world.addMixin(paramsMap["key"]!, paramsMap["value"]!);
  return Response.ok(
      "Added '${paramsMap["key"]}' with value ${paramsMap["value"]} to mixins. Value wont take effectt until server properties are refreshed.");
}

Future<Response> removeServerPropertiesMixin(Request req, String uuid) async {
  final world = InstanceManager.shared.getWorldByUUID(uuid);
  if (world == null) {
    return Response.notFound("Failed to find world with uuid '$uuid'.");
  }

  if (world.processManager.status != WorldProcessStatus.stopped) {
    return Response(503,
        body:
            "This command cannot be run while the target instance isn't stopped.");
  }

  final body = await req.readAsString();
  final paramsMap = httpBodyToMap(body);
  if (!paramsMap.containsKey("key")) {
    return Response.badRequest(
        body: "Request must contain server.properties key to remove.");
  }

  world.removeMixin(paramsMap["key"]!);
  return Response.ok("Removed key '${paramsMap["key"]}' from mixins.");
}

Future<Response> listAllServerProperties(Request req, String uuid) async {
  final world = InstanceManager.shared.getWorldByUUID(uuid);
  if (world == null) {
    return Response.notFound("Failed to find world with uuid '$uuid'.");
  }

  if (world.serverPropertiesFileMixins == null) {
    return Response.ok("[]", headers: {"content-type": "application/json"});
  }

  List<String> sdp = [];
  world.serverPropertiesFileMixins!.forEach((key, value) {
    sdp.add("$key=$value");
  });

  return Response.ok(JsonEncoder().convert(sdp),
      headers: {"content-type": "application/json"});
}
