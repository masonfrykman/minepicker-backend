import 'dart:async';

import 'mojang_versions_getter.dart';

void registerLongTermTimers() {
  // Insert more timers later if/when needed.

  Timer.periodic(Duration(days: 3), (timer) async {
    await refreshMojangMCVersionsList();
  });
}
