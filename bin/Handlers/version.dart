import 'package:shelf/shelf.dart';

Response version(Request req) {
  return Response.ok("ESPRESSO with HAZELNUT");
}

Response vDate(Request req) {
  return Response.ok("September 3, 2022");
}

Response madeFor(Request req) {
  return Response.ok("Compatible with SIMBA patch 3 - NALA patch 1");
}
