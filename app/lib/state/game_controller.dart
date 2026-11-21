import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sim_core/sim_core.dart';

import 'save_service.dart';
import 'settings.dart';

enum Speed { paused, normal, fast, auto }

/// Owns the Sim, the service clock and autosave (doc 08 §6.1). No game rules live here.
class GameController extends ChangeNotifier with WidgetsBindingObserver {
  final Content content;
  final SaveService saves;
  Settings settings;
  Sim? sim;
  int revision = 0;
  Speed speed = Speed.paused;
  bool cardOpen = false;
  String? toast;
  final _events = StreamController<SimEvent>.broadcast();
  Stream<SimEvent> get events => _events.stream;

  Timer? _timer;
  double _acc = 0;
  int _lastMs = 0;
  int _ticksSinceSave = 0;
  final Stopwatch _clock = Stopwatch()..start();

  GameController(
      {required this.content, required this.saves, required this.settings}) {
    WidgetsBinding.instance.addObserver(this);
  }

  GameState? get state => sim?.state;
  bool get hasGame => sim != null;

  // ------------------------------------------------------------ lifecycle

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      setSpeed(Speed.paused);
      autosave();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _events.close();
    super.dispose();
  }

  void _changed() {
    revision++;
    notifyListeners();
  }

  // ------------------------------------------------------------ games

  void newGame(
      {required int seed,
      required String difficulty,
      String themeId = 'italian'}) {
    sim = Sim.newGame(
        content: content, seed: seed, difficulty: difficulty, themeId: themeId);
    speed = Speed.paused;
    _changed();
  }

  Future<bool> load(String slot) async {
    final data = await saves.read(slot);
    if (data == null) return false;
    try {
      sim = Sim.fromSave(content, data);
    } catch (_) {
      return false;
    }
    speed = Speed.paused;
    _changed();
    return true;
  }

  /// Returns false if the save could not be written (storage full or unavailable).
  Future<bool> saveTo(String slot) async {
    final s = sim;
    if (s == null) return false;
    try {
      await saves.write(slot, s.toSave());
      return true;
    } catch (_) {
      toast =
          'The game could not be saved. Check that the phone has free storage.';
      return false;
    }
  }

  Future<void> autosave() async {
    if (sim == null || sim!.state.phase == 'market') return;
    await saveTo('autosave');
  }

  void quitToTitle() {
    autosave();
    _timer?.cancel();
    sim = null;
    speed = Speed.paused;
    _changed();
  }

  Future<void> saveSettings() async {
    try {
      await saves.write('settings', settings.toJson());
    } catch (_) {
      // Settings still apply for this session.
    }
    notifyListeners();
  }

  // ------------------------------------------------------------ commands

  CommandResult send(Command c) {
    final s = sim;
    if (s == null) return CommandResult.fail(SimError.wrongPhase);
    final before = s.state.phase;
    final r = s.apply(c);
    _publish(r.events);
    if (!r.ok && r.message != null) toast = r.message;
    if (s.state.phase != before) {
      autosave();
      if (s.state.phase == 'service') setSpeed(Speed.normal);
      if (s.state.phase != 'service') _stopClock();
    }
    if (r.ok &&
        settings.haptics &&
        (c is OwnerQueueTask || c is OwnerRush || c is OwnerTreat)) {
      HapticFeedback.lightImpact();
    }
    _changed();
    return r;
  }

  String? takeToast() {
    final t = toast;
    toast = null;
    return t;
  }

  void _publish(List<SimEvent> events) {
    for (final e in events) {
      _events.add(e);
    }
  }

  // ------------------------------------------------------------ service clock

  void setSpeed(Speed sp) {
    speed = sp;
    if (sp == Speed.paused) {
      _stopClock();
    } else {
      _startClock();
    }
    notifyListeners();
  }

  void _startClock() {
    _timer ??=
        Timer.periodic(const Duration(milliseconds: 33), (_) => _onFrame());
    _lastMs = _clock.elapsedMilliseconds;
  }

  void _stopClock() {
    _timer?.cancel();
    _timer = null;
  }

  bool get quietSpell {
    final ss = sim?.service;
    if (ss == null) return false;
    final waiting = ss.groups.any((g) => g.waiting && g.state != 'waitTable') ||
        ss.groups.any((g) => g.state == 'waitTable') ||
        ss.tasks.any((t) => !t.started && t.type != 'clear');
    return !waiting;
  }

  double get _ticksPerSecond {
    final base = content.balance.d('TICKS_PER_SECOND_1X');
    var m = switch (speed) {
      Speed.paused => 0.0,
      Speed.normal => 1.0,
      Speed.fast => 2.0,
      Speed.auto => 4.0,
    };
    if (settings.quietFastForward && quietSpell && speed != Speed.paused) m = 4;
    return base * m;
  }

  /// How fast the restaurant scene should animate: 0 while paused or a card is
  /// open, 1 at normal speed, up to 4 when fast-forwarding.
  double get playRate {
    final s = sim;
    if (s == null || s.state.phase != 'service' || cardOpen) return 0;
    return _ticksPerSecond / content.balance.d('TICKS_PER_SECOND_1X');
  }

  void _onFrame() {
    final s = sim;
    if (s == null || s.state.phase != 'service' || cardOpen) {
      _lastMs = _clock.elapsedMilliseconds;
      if (s?.state.phase != 'service') _stopClock();
      return;
    }
    final now = _clock.elapsedMilliseconds;
    final dt = (now - _lastMs) / 1000.0;
    _lastMs = now;
    _acc += dt * _ticksPerSecond;
    var n = 0;
    var changed = false;
    while (_acc >= 1 && n < 8) {
      _acc -= 1;
      n++;
      final ev = s.tick();
      changed = true;
      _publish(ev);
      _ticksSinceSave++;
      if (ev.any((e) => e.type == 'incidentRaised')) {
        _acc = 0;
        break; // the shell opens the card and pauses
      }
      if (s.state.phase != 'service') {
        autosave();
        _stopClock();
        break;
      }
    }
    if (_acc > 8) _acc = 0;
    if (_ticksSinceSave >= 60) {
      _ticksSinceSave = 0;
      autosave();
    }
    if (changed) _changed();
  }
}
