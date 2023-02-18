import 'dart:io';

import '../../Classes/socket_serv_mgr.dart';
import 'sockets.dart';

SocketServerManager? serverStatusSocket;

enum StatusEventCode { shutdown }

void updateStatusWithEventCode(StatusEventCode code) {
  switch (code) {
    case StatusEventCode.shutdown:
      if (serverStatusSocket != null) {
        serverStatusSocket!.push("shutting-down");
      }
      break;
  }
}
