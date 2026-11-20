import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Files in the app documents folder. Writes go to a temp file, then rename (atomic).
class SaveStore {
  Future<Directory> _dir() async => getApplicationDocumentsDirectory();

  Future<void> write(String name, String text) async {
    final dir = await _dir();
    final tmp = File('${dir.path}/$name.tmp');
    await tmp.writeAsString(text, flush: true);
    await tmp.rename('${dir.path}/$name');
  }

  Future<String?> read(String name) async {
    try {
      final f = File('${(await _dir()).path}/$name');
      if (!await f.exists()) return null;
      return await f.readAsString();
    } catch (_) {
      return null;
    }
  }

  Future<void> delete(String name) async {
    final f = File('${(await _dir()).path}/$name');
    if (await f.exists()) await f.delete();
  }
}
