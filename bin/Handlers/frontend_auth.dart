import 'package:shelf/shelf.dart';

import '../Helpers/authentication.dart';
import '../Helpers/http_body_to_map.dart';

Future<Response> newUserHandler(Request request) async {
  final body = httpBodyToMap(await request.readAsString());

  // Check the NEW credentials are included.
  if (!body.containsKey("username") || !body.containsKey("password")) {
    return Response.badRequest(
        body: "Requires username AND password fields in request.");
  }

  // Do the creation.
  final create = createUser(body["username"]!, body["password"]!);
  if (create) {
    return Response.ok("Created user account '${body['username']}'.");
  }
  return Response.internalServerError(body: "Unknown error occured.");
}

Future<Response> checkUserCredsHandler(Request request) async {
  final body = httpBodyToMap(await request.readAsString());
  if (!body.containsKey("username") || !body.containsKey("password")) {
    return Response.badRequest(
        body: "Requires username AND password fields in request.");
  }

  final check = authenticateUser(body["username"]!, body["password"]!);
  if (check) {
    return Response.ok("Login OK.");
  }
  return Response.forbidden("Bad login.");
}

Future<Response> deleteUserHandler(Request request) async {
  final body = httpBodyToMap(await request.readAsString());

  // Check the NEW credentials are included.
  if (!body.containsKey("username")) {
    return Response.badRequest(
        body: "Requires username field in request payload.");
  }

  final check = deleteUser(body["username"]!);
  if (check) {
    return Response.ok("Deleted user '${body['username']}'.");
  }
  return Response.internalServerError(
      body: "Unknown error occured deleting user. Perhaps it doesn't exist?");
}

Future<Response> changePasswordHandler(Request req) async {
  final body = httpBodyToMap(await req.readAsString());
  if (!body.containsKey("username") ||
      !body.containsKey("new-password") ||
      !body.containsKey("old-password")) {
    return Response.forbidden(
        "Requires username, old password, and new password in request payload.");
  }

  final action = changePassword(
      body["username"]!, body["old-password"]!, body["new-password"]!);
  if (!action) {
    return Response.forbidden(
        "Failed to change password, old-password probably incorrect.");
  }
  return Response.ok("Password changed.");
}
