import 'dart:io';

import '../../Classes/socket_serv_mgr.dart';
import 'sockets.dart';

SocketServerManager? serverStatusSocket;

enum StatusEventCode {
  shutdown,
  instanceNew,
  instanceStart,
  instanceStop,
  instanceStarting
}

void updateStatusWithEventCode(StatusEventCode code, {String? instanceUUID}) {
  if (serverStatusSocket == null) {
    return;
  }
  switch (code) {
    case StatusEventCode.shutdown:
      serverStatusSocket!.push("shutting-down");
      break;
    case StatusEventCode.instanceNew:
      if (instanceUUID == null) {
        break;
      }
      serverStatusSocket!.push("new-instance;$instanceUUID");
      break;
    case StatusEventCode.instanceStart:
      if (instanceUUID == null) {
        break;
      }
      serverStatusSocket!.push("instance-start;$instanceUUID");
      break;
    case StatusEventCode.instanceStop:
      if (instanceUUID == null) {
        break;
      }
      serverStatusSocket!.push("instance-stop;$instanceUUID");
      break;
    case StatusEventCode.instanceStarting:
      if (instanceUUID == null) {
        break;
      }
      serverStatusSocket!.push("instance-starting;$instanceUUID");
  }
}
