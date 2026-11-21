import 'dart:convert';

/// Typed accessors over balance.json. A missing key is an error naming the key.
class Balance {
  final Map<String, dynamic> raw;
  Balance(this.raw);

  dynamic _get(String k) {
    if (!raw.containsKey(k)) {
      throw ContentError('balance.json', k, 'missing key');
    }
    return raw[k];
  }

  double d(String k) => (_get(k) as num).toDouble();
  int i(String k) => (_get(k) as num).toInt();
  List<double> list(String k) =>
      (_get(k) as List).map((e) => (e as num).toDouble()).toList();
  Map<String, double> dmap(String k) => (_get(k) as Map)
      .map((key, v) => MapEntry(key as String, (v as num).toDouble()));
  Map<String, dynamic> map(String k) =>
      (_get(k) as Map).cast<String, dynamic>();

  /// Value from a difficulty table such as {"easy": .., "normal": .., "hard": ..}.
  double byDifficulty(String k, String difficulty) => dmap(k)[difficulty]!;
}

class ContentError implements Exception {
  final String file;
  final String id;
  final String message;
  ContentError(this.file, this.id, this.message);
  @override
  String toString() => 'ContentError($file, $id): $message';
}

double _d(dynamic v) => (v as num).toDouble();
int _i(dynamic v) => (v as num).toInt();

class Ingredient {
  final String id, name, category, storage;
  final int shelfLifeDays;
  final double baseCost;
  Ingredient.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        name = j['name'] as String,
        category = j['category'] as String,
        storage = j['storage'] as String,
        shelfLifeDays = _i(j['shelfLifeDays']),
        baseCost = _d(j['baseCost']);
}

class RecipeLine {
  final String ingredientId;
  final int qty;
  RecipeLine(this.ingredientId, this.qty);
}

class Dish {
  final String id, name, theme, course, station;
  final int prepTicks, skillReq;
  final double popularity;
  final List<RecipeLine> recipe;
  int basePrice = 0; // derived at load
  Dish.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        name = j['name'] as String,
        theme = j['theme'] as String,
        course = j['course'] as String,
        station = j['station'] as String,
        prepTicks = _i(j['prepTicks']),
        skillReq = _i(j['skillReq']),
        popularity = j['popularity'] == null ? 1.0 : _d(j['popularity']),
        recipe = (j['recipe'] as List)
            .map((r) => RecipeLine(r['ingredientId'] as String, _i(r['qty'])))
            .toList();

  /// Optional courses (starter, side, dessert/drink) are grouped as in doc 02 §6.5.
  String get courseGroup =>
      (course == 'dessert' || course == 'drink') ? 'sweet' : course;
}

class EquipmentType {
  final String type, name, kind;
  final String? station, storage;
  final int slots, capacity, price;
  final double wearPerDay;
  EquipmentType.fromJson(Map<String, dynamic> j)
      : type = j['type'] as String,
        name = j['name'] as String,
        kind = j['kind'] as String,
        station = j['station'] as String?,
        storage = j['storage'] as String?,
        slots = j['slots'] == null ? 0 : _i(j['slots']),
        capacity = j['capacity'] == null ? 0 : _i(j['capacity']),
        price = _i(j['price']),
        wearPerDay = _d(j['wearPerDay']);
}

class Supplier {
  final String id, name;
  final List<String> categories;
  final double priceMult, reliability;
  final int quality, minOrder, leadDays, creditDays;
  Supplier.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        name = j['name'] as String,
        categories = (j['categories'] as List).cast<String>(),
        priceMult = _d(j['priceMult']),
        reliability = _d(j['reliability']),
        quality = _i(j['quality']),
        minOrder = _i(j['minOrder']),
        leadDays = _i(j['leadDays']),
        creditDays = _i(j['creditDays']);
}

class Trait {
  final String id, name, description;
  final List<String>? roles;
  final Map<String, double> modifiers;
  Trait.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        name = j['name'] as String,
        description = j['description'] as String,
        roles = (j['roles'] as List?)?.cast<String>(),
        modifiers =
            (j['modifiers'] as Map).map((k, v) => MapEntry(k as String, _d(v)));
}

class Festival {
  final String id, name;
  final int month, day, durationDays;
  final double demandMult;
  Festival.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        name = j['name'] as String,
        month = _i(j['month']),
        day = _i(j['day']),
        durationDays = _i(j['durationDays']),
        demandMult = _d(j['demandMult']);
}

class CuisineTheme {
  final String id, name, accent, mainStation;
  final List<String> stations;
  final Map<String, List<MapEntry<String, int>>> startingEquipment;
  final List<String> restaurantNames, firstNames, lastNames;
  final List<Festival> festivals;
  final List<String>? startingMenu;
  bool get isMixed => id == 'mixed';
  CuisineTheme.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        name = j['name'] as String,
        accent = j['accent'] as String,
        mainStation = j['mainStation'] as String,
        stations = (j['stations'] as List).cast<String>(),
        startingEquipment = (j['startingEquipment'] as Map).map((k, v) =>
            MapEntry(
                k as String,
                (v as List)
                    .map((e) => MapEntry(e['type'] as String, _i(e['count'])))
                    .toList())),
        restaurantNames =
            ((j['namePools'] as Map)['restaurant'] as List).cast<String>(),
        firstNames =
            ((j['namePools'] as Map)['staffFirst'] as List).cast<String>(),
        lastNames =
            ((j['namePools'] as Map)['staffLast'] as List).cast<String>(),
        festivals = (j['festivals'] as List)
            .map((f) => Festival.fromJson(f as Map<String, dynamic>))
            .toList(),
        startingMenu = (j['startingMenu'] as List?)?.cast<String>();
}

class LocationClass {
  final String id, name;
  final int baseFootfall, weeklyRent;
  final Map<String, double> segmentMix;
  LocationClass.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        name = j['name'] as String,
        baseFootfall = _i(j['baseFootfall']),
        weeklyRent = _i(j['weeklyRent']),
        segmentMix = (j['segmentMix'] as Map)
            .map((k, v) => MapEntry(k as String, _d(v)));
}

class Tier {
  final String id, name, locationClass, stationSet;
  final int price, loan, morale, tables;
  final List<String> staffRoles;
  final List<int> skillRange,
      equipmentCondition,
      equipmentAgeYears,
      hiddenProblems;
  final double reputation, wageMult, stockDays;
  final int? rentOverride;
  final bool hasAc, hasGenerator, extraFridge, oneBroken, badApple;
  Tier.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        name = j['name'] as String,
        locationClass = j['locationClass'] as String,
        stationSet = j['stationSet'] as String,
        price = _i(j['price']),
        loan = _i(j['loan']),
        morale = _i(j['morale']),
        tables = _i(j['tables']),
        staffRoles = (j['staffRoles'] as List).cast<String>(),
        skillRange = (j['skillRange'] as List).map(_i).toList(),
        equipmentCondition = (j['equipmentCondition'] as List).map(_i).toList(),
        equipmentAgeYears = (j['equipmentAgeYears'] as List).map(_i).toList(),
        hiddenProblems = (j['hiddenProblems'] as List).map(_i).toList(),
        reputation = _d(j['reputation']),
        wageMult = _d(j['wageMult']),
        stockDays = _d(j['stockDays']),
        rentOverride = j['rentOverride'] == null ? null : _i(j['rentOverride']),
        hasAc = j['hasAc'] as bool,
        hasGenerator = j['hasGenerator'] as bool,
        extraFridge = j['extraFridge'] as bool,
        oneBroken = (j['oneBroken'] as bool?) ?? false,
        badApple = (j['badApple'] as bool?) ?? false;
}

class IncidentOption {
  final String id, label;
  final Map<String, dynamic>? requires;
  final List<Map<String, dynamic>> effects;
  final String? hint;
  IncidentOption.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        label = j['label'] as String,
        hint = j['hint'] as String?,
        requires = (j['requires'] as Map?)?.cast<String, dynamic>(),
        effects = ((j['effects'] as List?) ?? const [])
            .map((e) => (e as Map).cast<String, dynamic>())
            .toList();
}

class IncidentDef {
  final String id, title, text, timing, category;
  final Map<String, dynamic> trigger;
  final double weight;
  final int cooldownDays;
  final bool forced;
  final List<String> tags;
  final String subject;
  final Map<String, dynamic>? subjectFilter;
  final List<IncidentOption> options;
  final String defaultOption;
  IncidentDef.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        title = j['title'] as String,
        text = j['text'] as String,
        timing = j['timing'] as String,
        category = (j['category'] as String?) ?? 'staff',
        trigger = ((j['trigger'] as Map?) ?? const {}).cast<String, dynamic>(),
        weight = j['weight'] == null ? 0 : _d(j['weight']),
        cooldownDays = j['cooldownDays'] == null ? 0 : _i(j['cooldownDays']),
        forced = (j['forced'] as bool?) ?? false,
        tags = ((j['tags'] as List?) ?? const []).cast<String>(),
        subject = (j['subject'] as String?) ?? 'none',
        subjectFilter = (j['subjectFilter'] as Map?)?.cast<String, dynamic>(),
        options = (j['options'] as List)
            .map((o) =>
                IncidentOption.fromJson((o as Map).cast<String, dynamic>()))
            .toList(),
        defaultOption = j['defaultOption'] as String;

  IncidentOption option(String id) => options.firstWhere((o) => o.id == id);
}

class Objective {
  final String id, text, rewardText;
  final int stage;
  final List<Map<String, dynamic>> reward;
  Objective.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        text = j['text'] as String,
        rewardText = j['rewardText'] as String,
        stage = _i(j['stage']),
        reward = ((j['reward'] as List?) ?? const [])
            .map((e) => (e as Map).cast<String, dynamic>())
            .toList();
}

class Term {
  final String id, name, meaning, why;
  Term(this.id, this.name, this.meaning, this.why);
}

/// All static content. Built by [ContentLoader].
class Content {
  final Balance balance;
  final Map<String, Ingredient> ingredients;
  final Map<String, Dish> dishes;
  final Map<String, EquipmentType> equipment;
  final Map<String, Supplier> suppliers;
  final Map<String, Trait> traits;
  final Map<String, CuisineTheme> themes;
  final Map<String, LocationClass> locationClasses;
  final List<Tier> tiers;
  final Map<String, IncidentDef> incidents;
  final List<Objective> objectives;
  final Map<String, Term> terms;

  Content({
    required this.balance,
    required this.ingredients,
    required this.dishes,
    required this.equipment,
    required this.suppliers,
    required this.traits,
    required this.themes,
    required this.locationClasses,
    required this.tiers,
    required this.incidents,
    required this.objectives,
    required this.terms,
  });

  Tier tier(String id) => tiers.firstWhere((t) => t.id == id);

  /// Mixed draws from every pack (doc 01 §4.2).
  List<Dish> dishesFor(String themeId) => themeId == 'mixed'
      ? dishes.values.toList()
      : dishes.values.where((d) => d.theme == themeId).toList();
}

/// File names the loader expects, relative to the data folder.
const contentFiles = [
  'balance.json',
  'ingredients.json',
  'dishes.json',
  'equipment.json',
  'suppliers.json',
  'traits.json',
  'themes.json',
  'locations.json',
  'tiers.json',
  'incidents.json',
  'objectives.json',
  'terms_en.json',
];

class ContentLoader {
  /// [files] maps file name → JSON text.
  static Content load(Map<String, String> files) {
    dynamic read(String f) {
      final t = files[f];
      if (t == null) throw ContentError(f, '-', 'file missing');
      return jsonDecode(t);
    }

    List<Map<String, dynamic>> list(String f) => (read(f) as List)
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();

    final balance =
        Balance((read('balance.json') as Map).cast<String, dynamic>());
    final ingredients = {
      for (final j in list('ingredients.json'))
        j['id'] as String: Ingredient.fromJson(j)
    };
    final dishes = {
      for (final j in list('dishes.json')) j['id'] as String: Dish.fromJson(j)
    };
    final targets = balance.dmap('FOOD_COST_TARGET');
    for (final d in dishes.values) {
      var cost = 0.0;
      for (final r in d.recipe) {
        final ing = ingredients[r.ingredientId];
        if (ing == null) {
          throw ContentError(
              'dishes.json', d.id, 'unknown ingredient ${r.ingredientId}');
        }
        cost += r.qty * ing.baseCost;
      }
      final t = targets[d.course];
      if (t == null) {
        throw ContentError('dishes.json', d.id, 'unknown course ${d.course}');
      }
      d.basePrice = (cost / t).round();
    }
    final termsRaw = (read('terms_en.json') as Map).cast<String, dynamic>();
    final terms = <String, Term>{};
    termsRaw.forEach((k, v) {
      final m = (v as Map).cast<String, dynamic>();
      terms[k] = Term(
          k, m['name'] as String, m['meaning'] as String, m['why'] as String);
    });
    final content = Content(
      balance: balance,
      ingredients: ingredients,
      dishes: dishes,
      equipment: {
        for (final j in list('equipment.json'))
          j['type'] as String: EquipmentType.fromJson(j)
      },
      suppliers: {
        for (final j in list('suppliers.json'))
          j['id'] as String: Supplier.fromJson(j)
      },
      traits: {
        for (final j in list('traits.json'))
          j['id'] as String: Trait.fromJson(j)
      },
      themes: {
        for (final j in list('themes.json'))
          j['id'] as String: CuisineTheme.fromJson(j)
      },
      locationClasses: {
        for (final j in list('locations.json'))
          j['id'] as String: LocationClass.fromJson(j)
      },
      tiers: list('tiers.json').map(Tier.fromJson).toList(),
      incidents: {
        for (final j in list('incidents.json'))
          j['id'] as String: IncidentDef.fromJson(j)
      },
      objectives: list('objectives.json').map(Objective.fromJson).toList(),
      terms: terms,
    );
    return content;
  }
}
