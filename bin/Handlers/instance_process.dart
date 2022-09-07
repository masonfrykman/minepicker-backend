import 'dart:convert';

import 'package:shelf/shelf.dart';

import '../Classes/instances.dart';
import '../Classes/world.dart';
import '../Classes/worldprocessmgr.dart';
import '../Helpers/http_body_to_map.dart';

Future<Response> startJavaGameHandler(Request req, String uuid) async {
  final world = InstanceManager.shared.getWorldByUUID(uuid);
  if (world == null) {
    return Response.notFound("Failed to find world with uuid '$uuid'.");
  }

  if (world.processManager.status != WorldProcessStatus.stopped) {
    return Response.ok("The server is already starting or has started.");
  }

  final body = httpBodyToMap(await req.readAsString());
  final wantsStatic = body["try-static"] == "true" ? true : false;
  final wantsAdvert = body["try-advert"] == "true" ? true : false;
  await world.processManager
      .start(wantsAdvert: wantsAdvert, wantsStatic: wantsStatic);
  return Response.ok("World is starting.");
}

Future<Response> sendCommandToGameHandler(Request req, String uuid) async {
  final world = InstanceManager.shared.getWorldByUUID(uuid);
  if (world == null) {
    return Response.notFound("Failed to find world with uuid '$uuid'.");
  }

  if (world.processManager.status == WorldProcessStatus.stopped) {
    return Response.notFound("World is not running. Start it to use this URI.");
  }

  if (req.headers["x-command"] == null) {
    return Response.badRequest(body: "Expected x-command header.");
  }
  await world.processManager.sendCommand(req.headers["x-command"]!);
  return Response.ok("Sending command.");
}

Future<Response> stopRunningInstanceHandler(Request req, String uuid) async {
  final world = InstanceManager.shared.getWorldByUUID(uuid);
  if (world == null) {
    return Response.notFound("Failed to find world with uuid '$uuid'.");
  }

  if (world.processManager.status == WorldProcessStatus.stopped) {
    return Response.notFound("World is not running. Start it to use this URI.");
  }

  await world.processManager.stop();
  return Response.ok("World is stopping.");
}

Response instanceStatusHandler(Request req, String uuid) {
  final world = InstanceManager.shared.getWorldByUUID(uuid);
  if (world == null) {
    return Response.notFound("Failed to find world with uuid '$uuid'.");
  }

  if (world.processManager.status == WorldProcessStatus.stopped) {
    return Response.ok("Stopped");
  } else if (world.processManager.status == WorldProcessStatus.starting) {
    return Response.ok("Starting");
  } else if (world.processManager.status == WorldProcessStatus.running) {
    return Response.ok("Running");
  }
  return Response.internalServerError(
      body:
          "Unknown status -- Maybe this will help: ${world.processManager.status}");
}

Response playersInGame(Request req, String uuid) {
  final world = InstanceManager.shared.getWorldByUUID(uuid);
  if (world == null) {
    return Response.notFound("Failed to find world with uuid '$uuid'.");
  }

  if (world.processManager.status != WorldProcessStatus.running) {
    return Response.ok("World is not running.");
  }

  return Response.ok(JsonEncoder().convert(world.processManager.players),
      headers: {"Content-Type": "application/json"});
}

Future<Response> killServerProcess(Request req, String uuid) async {
  final world = InstanceManager.shared.getWorldByUUID(uuid);
  if (world == null) {
    return Response.notFound("Failed to find world with uuid '$uuid'.");
  }

  await world.processManager.forceKill();
  return Response.ok("Server process killed.");
}

Response getPort(Request req, String uuid) {
  final world = InstanceManager.shared.getWorldByUUID(uuid);
  if (world == null) {
    return Response.notFound("Failed to find world with uuid '$uuid'.");
  }

  if (world.processManager.status == WorldProcessStatus.stopped) {
    return Response.notFound("Instance is not running.");
  }
  return Response.ok("${world.processManager.runningAt}");
}

Response resetState(Request req, String uuid) {
  final world = InstanceManager.shared.getWorldByUUID(uuid);
  if (world == null) {
    return Response.notFound("Failed to find world with uuid '$uuid'.");
  }

  world.processManager.quickReset();
  return Response.ok("Reset state of the world's process manager.");
}

Response resetAllStates(Request req) {
  final wlist = InstanceManager.shared.getWorldsList();
  for (World world in wlist) {
    world.processManager.quickReset();
  }

  return Response.ok("Reset all world states");
}
