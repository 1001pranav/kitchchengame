import 'dart:io';

import 'package:sim_core/sim_core.dart';

/// Loads content from the package's data folder (tools and tests only; the app uses assets).
Content loadContent([String dir = 'data']) {
  final files = <String, String>{};
  for (final f in contentFiles) {
    files[f] = File('$dir/$f').readAsStringSync();
  }
  return ContentLoader.load(files);
}
