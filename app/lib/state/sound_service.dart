import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:sim_core/sim_core.dart';

import 'game_controller.dart';

/// Short sound effects for game events (doc 07 §6). Silent when sound is off.
/// Uses audioplayers: the standard library has no audio playback, and flame_audio
/// (listed in doc 08) would pull in the whole Flame engine just to wrap it.
class SoundService {
  final GameController c;
  final Map<String, AudioPlayer> _players = {};
  final Map<String, DateTime> _last = {};
  StreamSubscription<SimEvent>? _sub;

  SoundService(this.c) {
    _sub = c.events.listen(_onEvent);
  }

  void dispose() {
    _sub?.cancel();
    for (final p in _players.values) {
      p.dispose();
    }
  }

  void _onEvent(SimEvent e) {
    switch (e.type) {
      case 'groupPaid':
      case 'deliverySent':
        play('coin', gapMs: 350);
      case 'groupWalkedOut':
        play('walkout', gapMs: 500);
      case 'incidentRaised':
        play('incident');
      case 'equipmentBroke':
        play('breakdown');
      case 'stageReached':
      case 'objectiveDone':
        play('stageup');
      case 'serviceStarted':
        play('bell', gapMs: 2000);
    }
  }

  Future<void> play(String name, {int gapMs = 120}) async {
    if (!c.settings.sound) return;
    final now = DateTime.now();
    final last = _last[name];
    if (last != null && now.difference(last).inMilliseconds < gapMs) return;
    _last[name] = now;
    try {
      final p = _players.putIfAbsent(
          name, () => AudioPlayer()..setReleaseMode(ReleaseMode.stop));
      await p.stop();
      await p.play(AssetSource('sfx/$name.wav'), volume: 0.6);
    } catch (_) {
      // Audio is a nicety: never let it break the game.
    }
  }
}
