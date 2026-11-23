import 'dart:math' as math;

import 'package:sim_core/sim_core.dart';

import 'scene/shopfront.dart';

/// Opening night gets one clear, positive goal: serve this many parties.
///
/// The share of the forecast is set per tier from measured first nights with
/// no help from the owner (tool/first_night.dart, 60 seeds): a Good place
/// serves about 95% of its forecast, a Bad one about 67%, the Worst about 62%.
/// Each goal sits a little above that, so the owner's help is what makes it.
class OpeningGoal {
  final int parties;
  const OpeningGoal(this.parties);

  /// Only on the very first day of the game.
  static OpeningGoal? of(Sim sim, {int? forecast, int? dayIndex}) {
    final st = sim.state;
    if ((dayIndex ?? st.dayIndex) != 0) return null;
    final fc = forecast ?? sim.forecast().groups;
    if (fc <= 0) return null;
    const share = [0.65, 0.7, 0.95, 0.95, 0.95];
    final q = tierQuality(st.viewLoc.tierId);
    return OpeningGoal(math.max(3, (fc * share[q]).round()));
  }

  bool met(int served) => served >= parties;
}
