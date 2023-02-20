import 'dart:convert';
import 'dart:math';

import '../Helpers/config.dart';
import '../Helpers/sockets/sockets.dart';
import 'world.dart';

import 'dart:io';

class InstanceManager {
  final List<World> _worlds = [];
  final List<World> _trash =
      []; // "Deleted" worlds not yet written to manifest.

  static InstanceManager shared = InstanceManager.fromJSONFile(
      config["manifest"]!); // should be used to manage the main worlds.

  // Min & max port number.
  int _portMax = int.tryParse(config["MaxMCPort"]!) ?? 25600;
  int _portMin = int.tryParse(config["MinMCPort"]!) ?? 25565;

  int? staticPort = int.tryParse(config["StaticPort"] ?? "");

  Map<int, World> usingPort = {};

  void setPortMax(int max) {
    if (max < _portMax) {
      // Stop any servers using ports above the new max port.
      var i = max;
      while (i <= _portMax) {
        if (usingPort[i] != null) {
          usingPort[i]!.processManager.stop();
        }
        i--;
      }
    }
    _portMax = max;
  }

  void setPortMin(int min) {
    _portMin = min;
    if (min > _portMin) {
      var i = min;
      while (i >= _portMin) {
        if (usingPort[i] != null) {
          usingPort[i]!.processManager.stop();
        }
      }
      i++;
    }
  }

  int getRandomPortInRange({bool wantsStatic = false}) {
    if (wantsStatic && staticPort != null) {
      return staticPort!;
    }
    final random = Random();
    final mx = random.nextInt((_portMax - _portMin) + 1);
    return _portMax - mx;
  }

  bool registerIfPortAvaliable(int port, World world) {
    if (portTest(port)) {
      usingPort.addAll({port: world});
      return true;
    }
    return false;
  }

  bool portTest(int port) {
    return portOpen(port);
  }

  void deregister(World world) {
    usingPort.forEach((key, value) {
      if (value == world) {
        usingPort.remove(key);
        return;
      }
    });
  }

  // Existing worlds
  World? getWorldByUUID(String uuid) {
    for (World world in _worlds) {
      if (world.uuid == uuid) {
        return world;
      }
    }
    return null;
  }

  List<World> getWorldsByNames(String name) {
    List<World> wcollection = [];
    for (World world in _worlds) {
      if (world.name == name) {
        wcollection.add(world);
      }
    }
    return wcollection;
  }

  List<World> getWorldsList() {
    return _worlds;
  }

  List<String> getWorldUUIDs() {
    var uuids = <String>[];
    for (World world in _worlds) {
      uuids.add(world.uuid);
    }
    return uuids;
  }

  bool safelyPushWorld(World world) {
    print("sp - slurps");
    if (getWorldByUUID(world.uuid) != null) {
      print("1");
      return false;
    }
    print('2');
    _worlds.add(world);
    return true;
  }

  // Trashing worlds
  // The trash should only get cleared when it's dumped to the manifest.

  bool trashWorldByUUID(String uuid) {
    // true if success.
    for (World world in _worlds) {
      if (world.uuid == uuid) {
        _trash.add(world);
        _worlds.remove(world);
        return true;
      }
    }
    return false;
  }

  List<String> getTrashedWorldsUUIDs() {
    List<String> uuids = [];
    for (World world in _trash) {
      uuids.add(world.uuid);
    }
    return uuids;
  }

  bool checkUUIDInTrash(String uuid) {
    for (World world in _trash) {
      if (world.uuid == uuid) {
        return true;
      }
    }
    return false;
  }

  bool restoreWorldByUUID(String uuid) {
    for (World world in _trash) {
      if (world.uuid == uuid) {
        _worlds.add(world);
        _trash.remove(world);
        return true;
      }
    }
    return false;
  }

  Future<void> _deleteWorldsInTrash() async {
    for (World world in _trash) {
      await Directory(world.instanceDirectory ?? world.inferInstanceDirectory())
          .delete(recursive: true);
    }

    _trash.clear();
  }

  // Manifest Management

  Future<void> dumpWorldsToManifest({bool patch = true}) async {
    // patch false: overwrites any worlds not in this manager in the manifest
    // patch true: preserves worlds not referenced in _worlds or _trash.

    if (patch) {
      if (config["manifest"] == null) {
        throw ConfigRequiredMissingException("manifest",
            description:
                "Failed to find a program-generated key 'manifest'. This is required to save new worlds.");
      }
      // *****************************
      // * STEP 1: Get the manifest. *
      // *****************************

      List<dynamic> manifest =
          JsonDecoder().convert(await File(config["manifest"]!).readAsString());
      // If it ain't a list, I dont want it.

      // *****************************************************
      // * STEP 2: Scan for worlds in mem & not in manifest. *
      // *****************************************************
      var missing = _isolatedStep2(manifest);

      // STEP 2.1: Construct maps for new worlds in memory.
      var newWorlds = _isolatedStep2point1(missing);

      // ************************************************************
      // * STEP 3: Go through manifest & patch the existing worlds. *
      // ************************************************************
      manifest = _isolatedStep3(manifest, newWorlds);

      // STEP 4: Final verification, search for duplicate UUIDs, trashed worlds
      // Remove trashed worlds, they will be deleted.
      manifest = _isolatedStep4(manifest);

      // STEP 5: Save to disk
      await _isolatedStep5(manifest);
    } else {
      final List<Map<String, dynamic>> manifest = [];
      for (World world in _worlds) {
        if (world.uuid.trim().isEmpty) {
          // TODO: uuid inference blah blah blah.
          continue;
        }

        Map<String, dynamic> nwCraft = {};
        nwCraft["name"] = world.name;
        nwCraft["uuid"] = world.uuid;
        nwCraft["version"] = world.serverVersion;
        nwCraft["backup-freq-days"] = world.backupFrequency;
        nwCraft["absolute-path"] = world.instanceDirectory;

        nwCraft["server-opts"]["memory-max-mb"] = world.maximumMemory;
        nwCraft["server-opts"]["memory-min-mb"] = world.minimumMemory;
        nwCraft["server-opts"]["executable"] = world.executable;

        nwCraft["server-properties-mixins"] = world.serverPropertiesFileMixins;

        manifest.add(nwCraft);
      }

      if (config["manifest"] == null) {
        throw WorldDumpException("Failed to obtain 'manifest' key in config.");
      }
      final manifestFile = File(config["manifest"]!);
      final convertedJSON = JsonEncoder.withIndent("\t").convert(manifest);
      await manifestFile.writeAsString(convertedJSON, flush: true);
    }
    await _deleteWorldsInTrash();
  }

  List<World> _isolatedStep2(List<dynamic> manifest) {
    List<World> missing = <World>[].followedBy(_worlds).toList();
    for (dynamic world in manifest) {
      if (world["uuid"] == null) {
        // TODO: Do some sherlock work to try to resolve the issue.
      }
      if (!(world["uuid"] is String)) {
        // Invalid UUID value.
        continue;
      }

      var worldFromUUID = getWorldByUUID(world["uuid"]!);
      if (worldFromUUID == null) {
        continue;
      } else {
        missing.remove(worldFromUUID);
      }
    }

    return missing;
  }

  List<Map<String, dynamic>> _isolatedStep2point1(List<World> missing) {
    List<Map<String, dynamic>> newWorlds = []; // Save for later

    for (var wmissing in missing) {
      Map<String, dynamic> jsonified = <String, dynamic>{};

      // Required values
      jsonified["name"] = wmissing.name;
      jsonified["uuid"] = wmissing.uuid;
      jsonified["version"] = wmissing.serverVersion;

      // Optional values
      if (wmissing.backupFrequency != null) {
        jsonified["backup-freq-days"] = wmissing.backupFrequency!;
      }
      if (wmissing.instanceDirectory != null) {
        jsonified["absolute-path"] = wmissing.instanceDirectory!;
      }

      if (wmissing.maximumMemory != null ||
          wmissing.minimumMemory != null ||
          wmissing.executable != null) {
        jsonified["server-opts"] = {};
      }
      // Nested server-opts dictionary.
      if (wmissing.maximumMemory != null) {
        jsonified["server-opts"]["memory-max-mb"] = wmissing.maximumMemory!;
      }
      if (wmissing.minimumMemory != null) {
        jsonified["server-opts"]["memory-min-mb"] = wmissing.minimumMemory!;
      }
      if (wmissing.executable != null) {
        jsonified["server-opts"]["executable"] = wmissing.executable!;
      }

      if (wmissing.serverPropertiesFileMixins != null) {
        jsonified["server-properties-mixins"] =
            wmissing.serverPropertiesFileMixins!;
      }

      newWorlds.add(jsonified);
    }

    return newWorlds;
  }

  List<dynamic> _isolatedStep3(
      List<dynamic> manifest, List<Map<String, dynamic>> newWorlds) {
    for (dynamic eworld in manifest) {
      if (eworld["uuid"] == null) {
        // TODO: Try to use context clues to recover UUID
        continue;
      }
      if (!(eworld["uuid"] is String)) {
        // UUID bad.
        continue;
      }
      var memworld = getWorldByUUID(eworld["uuid"]!);
      if (memworld == null) {
        // This means it's in manifest yet not loaded.
        continue;
      }

      // Required values
      if (memworld.name.trim().isNotEmpty) {
        eworld["name"] = memworld.name.trim();
      }
      if (memworld.serverVersion.trim().isNotEmpty) {
        eworld["version"] = memworld.serverVersion.trim();
      }

      // Optional values, allows null.
      eworld["backup-freq-days"] = memworld.backupFrequency;
      eworld["absolute-path"] = memworld.instanceDirectory;
      eworld["server-opts"] = {};
      eworld["server-opts"]["memory-max-mb"] = memworld.maximumMemory;
      eworld["server-opts"]["memory-min-mb"] = memworld.minimumMemory;
      eworld["server-opts"]["executable"] = memworld.executable;
      eworld["server-properties-mixins"] = memworld.serverPropertiesFileMixins;
    }

    manifest.addAll(newWorlds);

    return manifest;
  }

  List<dynamic> _isolatedStep4(List<dynamic> manifest) {
    List<dynamic> superCoolManifest = [];
    for (dynamic pworld in manifest) {
      if (!checkUUIDInTrash(pworld["uuid"])) {
        superCoolManifest.add(pworld);
      }
    }

    return superCoolManifest;
  }

  Future<void> _isolatedStep5(List<dynamic> manifest) async {
    if (config["manifest"] == null) {
      throw WorldDumpException("Failed to obtain 'manifest' key in config.");
    }
    final manifestFile = File(config["manifest"]!);
    final convertedJSON = JsonEncoder.withIndent("\t").convert(manifest);
    await manifestFile.writeAsString(convertedJSON, flush: true);
  }

  // Inits
  InstanceManager(); // For a clean slate.

  InstanceManager.fromJSONFile(String path) {
    // Useful for manifest (global)
    final mfFile = File(path);
    if (!mfFile.existsSync()) {
      throw "Specified path '$path' does not exist.";
    }
    final mfContents = mfFile.readAsStringSync();
    final manifest = JsonDecoder().convert(mfContents);
    for (Map<String, dynamic> worldJSON in manifest) {
      _worlds.add(World.fromJSON(JsonEncoder().convert(worldJSON)));
    }
  }
}

class WorldDumpException implements Exception {
  String description;

  WorldDumpException(this.description);

  @override
  String toString() {
    return description;
  }
}
