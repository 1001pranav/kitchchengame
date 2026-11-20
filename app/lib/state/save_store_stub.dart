/// In-memory saves for platforms without a file system (the web build used for previews).
class SaveStore {
  static final Map<String, String> _mem = {};
  Future<void> write(String name, String text) async => _mem[name] = text;
  Future<String?> read(String name) async => _mem[name];
  Future<void> delete(String name) async => _mem.remove(name);
}
