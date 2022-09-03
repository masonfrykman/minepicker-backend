/*import 'dart:convert';
import 'dart:io';

import '../Helpers/authentication.dart';
import 'worldprocessmgr.dart';

class AuthenticatedSocket {
  Socket socket;
  bool authenticated = false;
  WorldProcessManager parent;

  AuthenticatedSocket(this.socket, this.parent) {
    socket.write("WANTSAUTH");
    socket.flush();
    socket.listen((event) {
      _processMessage(Utf8Decoder().convert(event));
    });
    socket.done.then((value) => {parent.stdoutSocketHasFinished(this)});
  }

  void _processMessage(String message) {
    var msplit = message.trim().split(";");
    print(message);
    if (msplit.first == "AUTH") {
      if (msplit.length != 3) {
        socket.add(
            Utf8Encoder().convert("Auth command requires 2 extra arguments."));
        socket.flush();
        return;
      }
      _tryAuth(msplit[1], msplit[2]);
      return;
    }
  }

  void _tryAuth(String username, String password) {
    var auth = authenticateUser(username.trim(), password.trim());
    if (!auth) {
      return;
    }
    authenticated = true;
    print("auth success!");
  }

  void sendIfAuthenticated(String message) {
    if (!authenticated) {
      return;
    }
    socket.add(Utf8Encoder().convert(message));
  }

  void disconnect() async {
    await socket.close();
    parent.stdoutSocketHasFinished(this);
  }
}
*/