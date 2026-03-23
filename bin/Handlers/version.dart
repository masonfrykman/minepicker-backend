import 'package:shelf/shelf.dart';

const versionName = "1.1.0";
const versionDate = "February 20, 2023";
const versionCompatibility = "1.2.0";

Response version(Request req) {
  return Response.ok(versionName);
}

Response vDate(Request req) {
  return Response.ok(versionDate);
}

Response madeFor(Request req) {
  return Response.ok("For client $versionCompatibility");
}
