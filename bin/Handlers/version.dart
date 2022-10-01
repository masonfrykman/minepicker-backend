import 'package:shelf/shelf.dart';

const versionName = "1.1.0";
const versionDate = "In Development";
const versionCompatibility = "1.0.2 - 1.1.0";

Response version(Request req) {
  return Response.ok(versionName);
}

Response vDate(Request req) {
  return Response.ok(versionDate);
}

Response madeFor(Request req) {
  return Response.ok("Compatible with $versionCompatibility");
}
