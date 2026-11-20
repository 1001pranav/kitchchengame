import 'dart:convert';

import 'save_store_stub.dart' if (dart.library.io) 'save_store_io.dart';

/// Save slots: autosave + 3 manual slots + settings (doc 08 §6.4).
class SaveService {
  final SaveStore _store = SaveStore();

  static const slots = ['autosave', 'save_1', 'save_2', 'save_3'];

  Future<void> write(String slot, Map<String, dynamic> data) =>
      _store.write('$slot.json', jsonEncode(data));

  Future<Map<String, dynamic>?> read(String slot) async {
    final text = await _store.read('$slot.json');
    if (text == null) return null;
    try {
      return (jsonDecode(text) as Map).cast<String, dynamic>();
    } catch (_) {
      return null;
    }
  }

  Future<void> delete(String slot) => _store.delete('$slot.json');
}
