import 'dart:convert';
import 'dart:io';

import 'package:uuid/uuid.dart';
import 'package:io/io.dart';

import '../Helpers/config.dart';
import '../Helpers/instance_caching.dart';
import 'instances.dart';
import 'worldprocessmgr.dart';

class World {
  late String name;
  late String uuid; // Should ALWAYS be assigned by server.
  late String serverVersion;
  int? backupFrequency; // backup-freq-days in JSON.
  String? instanceDirectory; // absolute-path in JSON. No opt in create.

  // Inside server-opts dictionary
  int? maximumMemory;
  int? minimumMemory;
  String? executable; // Based off instanceDirectory. No opt in create.

  Map<String, dynamic>? serverPropertiesFileMixins;

  late WorldProcessManager processManager;

  // (Object) instance functions
  bool verifyMemoryValues() {
    var max =
        maximumMemory ?? int.parse(config["DefaultMaximumMemoryMegabytes"]!);
    var min =
        minimumMemory ?? int.parse(config["DefaultMinimumMemoryMegabytes"]!);

    if (max <= min) {
      return false;
    }
    return true;
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'version': serverVersion,
        'uuid': uuid,
        'backup-freq-days': backupFrequency,
        'absolute-path': instanceDirectory,
        'memory-max-mb': maximumMemory,
        'memory-min-mb': minimumMemory,
        'executable': executable,
        'server-properties-mixins': serverPropertiesFileMixins
      };

  String inferInstanceDirectory(
      {bool replaceVariable = true, bool onlyReplaceIfNull = true}) {
    final inference = "${config['RootMinecraftDirectory']}instances/$uuid";
    if (replaceVariable) {
      if (onlyReplaceIfNull) {
        instanceDirectory ??= inference;
      } else {
        instanceDirectory = inference;
      }
    }
    return inference;
  }

  Future<void> createInstance() async {
    instanceDirectory ??= inferInstanceDirectory(replaceVariable: false);

    await Directory(instanceDirectory!).create(recursive: true);

    // Verify cache exists & can exist.
    if (!isCached(serverVersion)) {
      if (!await canBeCached(serverVersion)) {
        throw InstanceCreationFailure(
            "Invalid server version $serverVersion. Refresh the cache and try again.",
            instanceDirectory);
      }
      final createc = await createCache(serverVersion);
      if (!createc) {
        throw InstanceCreationFailure(
            "Could not create cache of version $serverVersion.",
            instanceDirectory);
      }
    }

    final cacheDir = getCacheDirectory(serverVersion);
    if (cacheDir == null) {
      throw InstanceCreationFailure(
          "Failed to get cache directory after checking for it succeeded. Maybe look into that?",
          instanceDirectory);
    }

    // Copy cache directory to instance directory.
    await copyPath(cacheDir, instanceDirectory!);

    // Create server.properties
    await createServerProperties();
  }

  Future<int> createServerProperties({bool wantsStatic = false}) async {
    final Map<String, dynamic> serverProperties = {};

    if (serverPropertiesFileMixins != null) {
      serverProperties.addAll(serverPropertiesFileMixins!);
    }

    int port = -1;
    while (true) {
      var generatePortNumber =
          InstanceManager.shared.getRandomPortInRange(wantsStatic: wantsStatic);
      if (!InstanceManager.shared.portTest(generatePortNumber)) {
        wantsStatic = false;
        continue;
      }
      port = generatePortNumber;
      break;
    }

    serverProperties.addAll({
      'enable-query': 'true',
      'broadcast-console-to-ops': 'false',
      'broadcast-rcon-to-ops': 'false',
      'enable-rcon': 'false',
      'server-ip': config["BindAddress"]!,
      'server-port': port,
      'query.port': port
    });

    final servDotPropFile =
        File("$instanceDirectory/server.properties").openWrite();

    serverProperties.forEach((key, value) {
      servDotPropFile.writeln("$key=$value");
    });

    servDotPropFile.flush().then((value) => {servDotPropFile.close()});

    return port;
  }

  void addMixin(String key, String value) {
    if (serverPropertiesFileMixins == null) {
      serverPropertiesFileMixins = {key: value};
      return;
    }
    serverPropertiesFileMixins!.addAll({key: value});
  }

  void removeMixin(String key) {
    if (serverPropertiesFileMixins == null) {
      return;
    }
    serverPropertiesFileMixins!.remove(key);
  }

  // Initializers
  World(this.name) {
    uuid = Uuid().v4();
    processManager = WorldProcessManager(this);
  }

  World.full(this.name, this.serverVersion, this.instanceDirectory,
      {this.executable,
      this.maximumMemory,
      this.minimumMemory,
      this.backupFrequency}) {
    uuid = Uuid().v4();
    processManager = WorldProcessManager(this);
  }

  World.fromJSON(String jsonString) {
    // Will not generate anything.
    final json = JsonDecoder().convert(jsonString);

    // Fail if required values don't exist.
    if (json["name"] == null ||
        json["uuid"] == null ||
        json["version"] == null) {
      throw Exception("Required value name, uuid, and/or version was null.");
    }

    name = json["name"];
    uuid = json["uuid"];
    if (json["absolute-path"] != null) {
      instanceDirectory = json["absolute-path"];
    }
    serverVersion = json["version"];

    // Backup days
    if (json["backup-freq-days"] != null) {
      if (json["backup-freq-days"] is int) {
        backupFrequency = json["backup-freq-days"];
      } else if (json["backup-freq-days"] is String) {
        backupFrequency = int.tryParse(json["backup-freq-days"]);
      }
      // Otherwise throw the value in the trash where it belongs.
    }
    if (json["server-opts"] != null) {
      if (json["server-opts"]["memory-max-mb"] != null) {
        if (json["server-opts"]["memory-max-mb"] is int) {
          maximumMemory = json["server-opts"]["memory-max-mb"];
        } else if (json["server-opts"]["memory-max-mb"] is String) {
          maximumMemory = int.tryParse(json["server-opts"]["memory-max-mb"]);
        }
      }

      if (json["server-opts"]["memory-min-mb"] != null) {
        if (json["server-opts"]["memory-min-mb"] is int) {
          minimumMemory = json["server-opts"]["memory-min-mb"];
        } else if (json["server-opts"]["memory-min-mb"] is String) {
          minimumMemory = int.tryParse(json["server-opts"]["memory-min-mb"]);
        }
      }

      if (json["server-opts"]["executable"] != null) {
        executable = json["server-opts"]["executable"];
      }
    }

    if (json["server-properties-mixins"] != null) {
      serverPropertiesFileMixins = json["server-properties-mixins"];
    }

    processManager = WorldProcessManager(this);
  }
}

class InstanceCreationFailure implements Exception {
  String description;
  String? instanceDirectory;

  InstanceCreationFailure(this.description, this.instanceDirectory) {
    cleanup();
  }

  void cleanup() {
    // TODO: Switch to passing in a running list of files to delete.
    if (instanceDirectory == null) {
      return;
    }
    final list = Directory(instanceDirectory!).listSync();
    for (FileSystemEntity entity in list) {
      if (FileSystemEntity.typeSync(entity.path) != FileSystemEntityType.file) {
        continue;
      }
      entity.deleteSync();
    }
  }
}
