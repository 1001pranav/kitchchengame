import 'dart:math' as math;

import 'commands.dart';
import 'content.dart';
import 'model.dart';
import 'rng.dart';

part 'systems/gen.dart';
part 'systems/demand.dart';
part 'systems/service.dart';
part 'systems/inventory.dart';
part 'systems/staff.dart';
part 'systems/day.dart';
part 'systems/finance.dart';
part 'systems/incidents.dart';
part 'systems/handlers.dart';
part 'systems/explain.dart';
part 'systems/queries.dart';

/// Something the UI may animate or log. The sim never reads it back.
class SimEvent {
  final String type;
  final Map<String, Object?> args;
  const SimEvent(this.type, [this.args = const {}]);
  @override
  String toString() => 'SimEvent($type, $args)';
}

enum SimError {
  notEnoughCash,
  wrongPhase,
  unknownId,
  belowMinimumOrder,
  limitReached,
  locked,
  invalidValue,
  refused,
}

class CommandResult {
  final bool ok;
  final SimError? error;
  final String? message;
  final List<SimEvent> events;
  final Object? value;
  const CommandResult(this.ok,
      {this.error, this.message, this.events = const [], this.value});
  factory CommandResult.fail(SimError e, [String? message]) =>
      CommandResult(false, error: e, message: message);
}

/// One line of a "Why?" breakdown.
class Factor {
  final String label;
  final double
      value; // multiplier, points or coins depending on [Explanation.kind]
  final String display;
  const Factor(this.label, this.value, this.display);
}

class Explanation {
  final String title;
  final String valueText;
  final String kind; // multiply | add | coins
  final List<Factor> factors;
  final String? howToImprove;
  const Explanation(this.title, this.valueText, this.kind, this.factors,
      {this.howToImprove});
}

class Forecast {
  final int groups;
  final String label;
  final Map<String, double> factors;
  const Forecast(this.groups, this.label, this.factors);
}

/// The only API the app uses (doc 08 §3).
class Sim {
  final Content content;
  final GameState state;
  SimRng _rng;
  final List<SimEvent> _events = [];

  Balance get b => content.balance;
  SimRng get rng => _rng;

  Sim._(this.content, this.state, this._rng);

  factory Sim.newGame({
    required Content content,
    required int seed,
    required String difficulty,
    String themeId = 'italian',
  }) {
    final rng = SimRng(seed);
    final st = GameState(
        seed: seed,
        rngState: rng.state,
        difficulty: difficulty,
        themeId: themeId);
    st.cash = content.balance.i('START_CAPITAL');
    final sim = Sim._(content, st, rng);
    sim._generateOffers();
    sim._syncRng();
    return sim;
  }

  factory Sim.fromSave(Content content, Map<String, dynamic> save) {
    final migrated = migrateSave(save);
    final st =
        GameState.fromJson((migrated['state'] as Map).cast<String, dynamic>());
    return Sim._(content, st, SimRng.fromState(st.rngState));
  }

  static const currentSaveVersion = 1;

  /// Applies save migrations in order (doc 08 §6.4).
  static Map<String, dynamic> migrateSave(Map<String, dynamic> save) {
    final v = (save['saveVersion'] as num?)?.toInt() ?? 1;
    if (v > currentSaveVersion) {
      throw StateError('This save was made by a newer version of the game.');
    }
    return save;
  }

  Map<String, dynamic> toSave() {
    _syncRng();
    return {'saveVersion': currentSaveVersion, 'state': state.toJson()};
  }

  void _syncRng() => state.rngState = _rng.state;

  // ------------------------------------------------------------ helpers

  Location get loc => state.loc;
  CuisineTheme get theme => content.themes[state.themeId]!;
  double diff(String key) => b.byDifficulty(key, state.difficulty);
  void emit(String type, [Map<String, Object?> args = const {}]) =>
      _events.add(SimEvent(type, args));
  List<SimEvent> _drain() {
    _syncRng();
    final out = List<SimEvent>.of(_events);
    _events.clear();
    return out;
  }

  void _note(String kind, String text, [int value = 0]) =>
      state.today.add(kind, text, value);
  void _timeline(String text) {
    state.timeline.add(TimelineEntry(state.dayIndex, text));
    if (state.timeline.length > 60) state.timeline.removeAt(0);
  }

  /// Every coin movement goes through here so the day's P&L stays complete.
  void spend(int amount, String bucket) {
    state.cash -= amount;
    final t = state.today;
    switch (bucket) {
      case 'ingredients':
        t.ingredientSpend += amount;
      case 'wages':
        t.wages += amount;
      case 'rent':
        t.rent += amount;
      case 'utilities':
        t.utilities += amount;
      case 'upkeep':
        t.upkeep += amount;
      case 'marketing':
        t.marketing += amount;
      case 'interest':
        t.interest += amount;
      case 'financing':
        break; // loan principal, inherited debt: not operating cost
      default:
        t.other += amount;
    }
    emit('cashChanged', {'delta': -amount});
  }

  void earn(int amount, String bucket) {
    state.cash += amount;
    if (bucket == 'revenue') {
      state.today.revenue += amount;
    } else if (bucket == 'other') {
      state.today.other -= amount;
    }
    emit('cashChanged', {'delta': amount});
  }

  String money(num v) {
    final n = v.round();
    final s = n.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return '${n < 0 ? '−' : ''}$buf';
  }

  String dateLabel([int? day]) {
    final d = day ?? state.dayIndex;
    return 'Day ${d + 1} · ${weekdays[d % 7]}';
  }

  // ------------------------------------------------------------ public API

  CommandResult apply(Command c) {
    final r = _handle(c);
    final ev = _drain();
    return CommandResult(r.ok,
        error: r.error, message: r.message, events: ev, value: r.value);
  }

  /// Advance one service tick. Only valid during service.
  List<SimEvent> tick() {
    if (state.phase != 'service') return const [];
    _serviceTick();
    return _drain();
  }

  List<SimEvent> beginDay() {
    _beginDay();
    return _drain();
  }

  Forecast forecast() => _forecast();

  Explanation explain(String target, {int? id}) => _explain(target, id: id);
}
