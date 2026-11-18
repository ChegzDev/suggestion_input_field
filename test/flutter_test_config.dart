import 'dart:async';

import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';

/// Enables leak tracking; individual tests opt in with
/// `experimentalLeakTesting: LeakTesting.settings.withTrackedAll()`.
FutureOr<void> testExecutable(FutureOr<void> Function() testMain) async {
  LeakTesting.enable();
  LeakTesting.settings = LeakTesting.settings.withIgnoredAll();
  await testMain();
}
