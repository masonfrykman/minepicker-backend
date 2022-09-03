import 'package:shelf/shelf.dart';

import '../Helpers/config.dart';

Response queryFeatureAvailability(Request req, String feature) {
  switch (feature) {
    case "softwarerestart":
      if (config["AllowRestartOverHTTP"] != "true") {
        return Response.ok("false");
      }
      return Response.ok("true");
    case "advertiseserver":
      if (config["AdvertiseServerOverLAN"] != "true") {
        return Response.ok("false");
      }
      return Response.ok("true");
  }
  return Response.notFound("Unknown feature '$feature'.");
}
