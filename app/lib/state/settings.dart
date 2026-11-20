/// Player settings, stored apart from saves (doc 08 §6.4).
class Settings {
  bool sound;
  bool haptics;
  bool reducedMotion;
  bool quietFastForward;
  double textScale;
  bool tutorial;
  Set<String> seenTerms;
  Settings({
    this.sound = true,
    this.haptics = true,
    this.reducedMotion = false,
    this.quietFastForward = true,
    this.textScale = 1.0,
    this.tutorial = true,
    Set<String>? seenTerms,
  }) : seenTerms = seenTerms ?? {};

  Map<String, dynamic> toJson() => {
        'sound': sound,
        'haptics': haptics,
        'reducedMotion': reducedMotion,
        'quietFastForward': quietFastForward,
        'textScale': textScale,
        'tutorial': tutorial,
        'seenTerms': seenTerms.toList(),
      };

  factory Settings.fromJson(Map<String, dynamic> j) => Settings(
        sound: j['sound'] as bool? ?? true,
        haptics: j['haptics'] as bool? ?? true,
        reducedMotion: j['reducedMotion'] as bool? ?? false,
        quietFastForward: j['quietFastForward'] as bool? ?? true,
        textScale: (j['textScale'] as num?)?.toDouble() ?? 1.0,
        tutorial: j['tutorial'] as bool? ?? true,
        seenTerms: ((j['seenTerms'] as List?) ?? const []).cast<String>().toSet(),
      );
}
