import 'parse_config.dart';

import 'dart:io';

Map<String, String> config = {};

Future<void> reloadConfig() async {
  var nconfig = parseConfigFile("/etc/mpbackend.cfg");

  // Check for required values.
  if (nconfig["RootMinecraftDirectory"] == null) {
    throw ConfigRequiredMissingException("RootMinecraftDirectory");
  }

  // Make sure RMD ends with a slash.
  if (!nconfig["RootMinecraftDirectory"]!.endsWith("/")) {
    var cfg = nconfig["RootMinecraftDirectory"]!;
    nconfig["RootMinecraftDirectory"] = "$cfg/";
  }

  // Set manifest. No custom path will cause inference.
  if (nconfig["CustomManifestPath"] != null) {
    nconfig["manifest"] = nconfig["CustomManifestPath"]!;
  } else {
    // Manifest inference. once inferred, check the file exists.
    final infer = "${nconfig["RootMinecraftDirectory"]}manifest.json";
    if (!await File(infer).exists()) {
      throw ManifestInferenceFailed(infer);
    }
    nconfig["manifest"] = infer;
  }

  // Ensure a max & min memory value is avaliable.
  nconfig["DefaultMaximumMemoryMegabytes"] ??= "2048";
  nconfig["DefaultMinimumMemoryMegabytes"] ??= "204";

  nconfig["MaxMCPort"] ??= "26000";
  nconfig["MinMCPort"] ??= "25565";

  nconfig["MaxSocketsPort"] ??= "31000";
  nconfig["MinSocketsPort"] ??= "30000";

  nconfig["AllowRestartOverHTTP"] ??= "false";

  config = nconfig;
}

class ConfigRequiredMissingException implements Exception {
  // Thrown when a required configuration value is missing.

  String missingKey; // ex. RootMinecraftDirectory
  String description;

  @override
  String toString() {
    return "$description ($missingKey)";
  }

  ConfigRequiredMissingException(this.missingKey,
      {this.description =
          "A required key-value pair was missing while loading the configuration."});
}

class ManifestInferenceFailed implements Exception {
  String failedPath;
  String description;

  ManifestInferenceFailed(this.failedPath,
      {this.description =
          "Failed to infer the manifest path from the RootMinecraftDirectory key."});

  @override
  String toString() {
    return "$description ($failedPath)";
  }
}
