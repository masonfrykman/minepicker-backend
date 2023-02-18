import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class SocketServerManager {
  ServerSocket serverSocket;

  List<StreamSubscription<Uint8List>> indivConsumerListeners = [];

  bool _greenLight = false; // Go ahead to push data to consumers.
  bool get greenLight => _greenLight;

  List<Socket> consumers = [];
  void Function(List<int>)?
      consumerInputProcessor; // Leave null to ignore input.
  StreamSubscription<Socket>? socketListener;

  SocketServerManager(this.serverSocket);

  // ###################
  // Serv Socket Control
  // ###################

  void start() {
    if (socketListener != null) {
      return; // Already running.
    }
    for (Socket consumer in consumers) {
      _attachConsumerListener(consumer);
    }
    socketListener = serverSocket.listen((Socket consumer) {
      consumers.add(consumer);
      _attachConsumerListener(consumer);
    });
    _greenLight = true;
  }

  void _attachConsumerListener(Socket consumer) {
    final cListener = consumer.listen(
      (event) {
        _recievedDataFromSocket(event);
      },
      onDone: () {
        consumers.remove(consumer);
      },
    );
    indivConsumerListeners.add(cListener);
  }

  void stop({bool preserveConnections = true}) async {
    // Might want to preserve connections so they can be rebinded to later.
    // However, if server socket is being closed INDEFINITELY it's useful to
    //    close the connections.
    // stop with preserveConnections is more like a pause.

    _greenLight = false;

    if (socketListener != null) {
      await socketListener!.cancel();
    }
    socketListener = null;

    for (StreamSubscription<Uint8List> subscription in indivConsumerListeners) {
      await subscription.cancel();
    }
    indivConsumerListeners.clear();

    if (!preserveConnections) {
      for (Socket connection in consumers) {
        await connection.flush(); // Don't want to lose any data.
        await connection.close();
      }
      consumers.clear();
    }
  }

  // ###############
  // Push TO SOCKETS
  // ###############

  void push(String message, {bool flush = true}) async =>
      pushRaw(utf8.encode(message), flush: flush);

  void pushRaw(List<int> data, {bool flush = true}) async {
    if (!_greenLight) {
      return;
    }
    for (Socket socket in consumers) {
      socket.add(data);
      if (flush) {
        await socket.flush();
      }
    }
  }

  void _recievedDataFromSocket(List<int> data) {
    // Doesn't punt the data to the processor in listener bc it might be defined
    //    after the listener is binded to the socket.
    if (consumerInputProcessor != null) {
      consumerInputProcessor!(data);
    }
  }
}
