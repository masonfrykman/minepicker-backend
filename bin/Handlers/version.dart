import 'package:shelf/shelf.dart';

const versionName = "ESPRESSO with MOCHA SWIRL";
const versionDate = "In Development";
const versionCompatibility = "SIMBA patch 3 - NALA patch 1";

Response version(Request req) {
  return Response.ok(versionName);
}

Response vDate(Request req) {
  return Response.ok(versionDate);
}

Response madeFor(Request req) {
  return Response.ok("Compatible with $versionCompatibility");
}
