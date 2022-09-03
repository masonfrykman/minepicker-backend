import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';

//import 'Classes/instances.dart';
import 'Classes/advert_mgr.dart';
import 'Handlers/backend_mgmt.dart';
import 'Handlers/features.dart';
import 'Handlers/frontend_auth.dart';
import 'Handlers/instance_backend.dart';
import 'Handlers/instance_create_delete.dart';
import 'Handlers/instance_handlers_auth.dart';
import 'Handlers/instance_handlers_noauth.dart';
import 'Handlers/instance_process.dart';
import 'Handlers/instance_server_dot_properties.dart';
import 'Handlers/version.dart';
import 'Helpers/authentication.dart';
import 'Helpers/config.dart';
import 'Helpers/restart_server.dart';

// Configure routes.
final _router = Router(notFoundHandler: notFoundHandler)
  ..get('/', _rootHandler)
  ..get('/version', version)
  ..get('/version/date', vDate)
  ..get('/version/compatibility', madeFor)
  //..post('/backend/restart', tryServerRestart)
  ..get('/backend/feature/<feature>', queryFeatureAvailability)
  // INSTANCE MGMT
  ..get('/instance/list', listInstances)
  ..post('/instance/manifest/save', dumpManifestHandler)
  ..post('/instance/resetAllStates', resetAllStates)
  ..get('/instance/<uuid>/name', instanceUUIDName) // Just returns name
  ..get('/instance/<uuid>/all/public', allUnauthFieldsUUID) // All public params
  ..get('/instance/<uuid>/all/authenticated',
      allFieldsByUUID) // Public + private params
  ..delete('/instance/<uuid>/trash', trashInstance) // Trash an instance
  ..post('/instance/<uuid>/restore', restoreInstanceHandler) // Restore < trash
  ..put('/instance/new', createInstance) // Submit instance data for creation
  ..patch(
      '/instance/<uuid>/update', patchUpdateInstance) // Update instance data
  ..post('/instance/<uuid>/resetState', resetState)
  // INSTANCE MGMT -- GAME
  ..post('/instance/<uuid>/game/start', startJavaGameHandler)
  ..post('/instance/<uuid>/game/sendCmd', sendCommandToGameHandler)
  ..post('/instance/<uuid>/game/stop', stopRunningInstanceHandler)
  ..post('/instance/<uuid>/game/kill', killServerProcess)
  ..get('/instance/<uuid>/game/status', instanceStatusHandler)
  ..get('/instance/<uuid>/game/players', playersInGame)
  ..get('/instance/<uuid>/game/port', getPort)
  // TODO: ..get('/instance/<uuid>/socket/stdout', getStdoutSocketAddressOfUUID)
  ..get('/instance/<uuid>/sdp/list', listAllServerProperties)
  ..post('/instance/<uuid>/sdp/refresh', refreshServerProperties)
  ..put('/instance/<uuid>/sdp/addMixin', addServerPropertiesMixin)
  ..delete("/instance/<uuid>/sdp/removeMixin", removeServerPropertiesMixin)
  // INSTANCE BACKEND MGMT
  ..get('/versionctrl/list',
      listMCVersionsCached) // Gets all release versions of MC.
  ..post('/versionctrl/refresh', forceRefreshVersionsList) // Refreshes list
  ..post('/versionctrl/<version>/cache',
      cacheMCVersion) // Caches a version for quick duplication
  ..delete('/versionctrl/<version>/remove',
      removeCachedMCVersion) // Removes cache of a version.
  // ACCOUNT MGMT
  ..post("/account/new", newUserHandler) // Create new account
  ..post('/account/check', checkUserCredsHandler) // Check credentials
  ..post('/account/changePassword', changePasswordHandler)
  ..delete("/account/delete", deleteUserHandler); // Delete user

Response _rootHandler(Request req) {
  return Response.ok('Millie Bobby Brown is on her way.\n');
}

Response notFoundHandler(Request req) {
  return Response.notFound("Requested URI not found.");
}

void main(List<String> args) async {
  // EULA
  print(
      "Use of this software implies agreement to the Minecraft EULA (https://www.minecraft.net/en-us/eula)");
  print("DISCONTINUE USE OF THIS SOFTWARE IF YOU DO NOT AGREE WITH THE EULA.");

  // Handle config stuff.
  await reloadConfig();

  if (config.isEmpty) {
    stderr.write("FATAL ERROR: Failed to load config.");
    await stderr.flush();
    return;
  }

  // Don't handle this in reloadConfig, these values are only needed once.
  if (config["BindAddress"] == null) {
    throw ConfigRequiredMissingException("BindAddress",
        description: "The BindAddress key is required to start the server.");
  }
  if (config["BindPort"] == null) {
    throw ConfigRequiredMissingException("BindPort",
        description: "The BindPort key is required to start the server.");
  }

  createAccountsDB(); // Make sure the accounts table is avaliable.
  //await refreshMojangMCVersionsList(); // Refresh mojang versions.
  safelyPrintNewCredentialsIfTableEmpty();

  final authMW = createMiddleware(
    requestHandler: (Request request) {
      if (request.url.path == "account/new" ||
          request.url.path == "account/changePassword" ||
          request.url.path == "account/check" ||
          request.url.path.startsWith("version")) {
        // Allow SOME account stuff w/o this.
        return null;
      }

      if (!request.headers.containsKey("x-username") ||
          !request.headers.containsKey("x-password")) {
        return Response(401);
      }

      final doAuth = authenticateUser(
          request.headers["x-username"]!, request.headers["x-password"]!);

      if (!doAuth) {
        return Response.forbidden("Incorrect Credentials.");
      }
    },
  );

  final serverDownMW = createMiddleware(requestHandler: (Request request) {
    if (willServerRestart()) {
      return Response(503, body: "Server is restarting.");
    }
  });

  print(getAccountsDBFilePath());

  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(serverDownMW)
      .addMiddleware(authMW)
      .addHandler(_router);

  print(await checkBackendServiceExistance());

  MulticastAdvertManager.shared.start();

  final ip = InternetAddress(config["BindAddress"]!);
  var port = int.parse(config["BindPort"]!);
  final server = await serve(handler, ip, port);
  print(
      'Server listening at address ${server.address.address} on port ${server.port}');
}
