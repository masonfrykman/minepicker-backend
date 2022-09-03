import 'package:shelf/shelf.dart';

import '../Helpers/config.dart';
import '../Helpers/restart_server.dart';

Future<Response> tryServerRestart(Request req) async {
  if (config["AllowRestartOverHTTP"] != "true") {
    return Response(418,
        body:
            "Stop trying to restart a teapot. Try restarting the coffee pot instead.");
  }

  var willRestart = await restartServer();
  if (!willRestart) {
    return Response.internalServerError(
        body:
            "Failed to start the restart timer. Either mpbackend.service could not be found or this feature is not supported.");
  }
  return Response.ok("Server will restart in 20 seconds.");
}
