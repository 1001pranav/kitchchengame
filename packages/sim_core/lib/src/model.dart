// State classes (doc 03 §2). Mutable inside sim_core; the app treats them as read-only.
// Every class round-trips through toJson / fromJson exactly.

double _d(dynamic v) => (v as num).toDouble();
int _i(dynamic v) => (v as num).toInt();
int? _ni(dynamic v) => v == null ? null : (v as num).toInt();
List<T> _l<T>(dynamic v, T Function(Map<String, dynamic>) f) =>
    ((v as List?) ?? const [])
        .map((e) => f((e as Map).cast<String, dynamic>()))
        .toList();
List<int> _li(dynamic v) => ((v as List?) ?? const []).map(_i).toList();
List<String> _ls(dynamic v) =>
    ((v as List?) ?? const []).cast<String>().toList();
Map<String, int> _mi(dynamic v) =>
    ((v as Map?) ?? const {}).map((k, x) => MapEntry(k as String, _i(x)));
Map<String, double> _md(dynamic v) =>
    ((v as Map?) ?? const {}).map((k, x) => MapEntry(k as String, _d(x)));
Map<String, String> _ms(dynamic v) =>
    ((v as Map?) ?? const {}).map((k, x) => MapEntry(k as String, x as String));

const roles = [
  'headChef',
  'lineCook',
  'prepCook',
  'dishwasher',
  'server',
  'cashier',
  'cleaner',
];
const floorRoles = ['server', 'cashier', 'dishwasher', 'cleaner'];
const segments = ['office', 'family', 'student', 'tourist'];
const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const seasons = ['spring', 'summer', 'autumn', 'winter'];

class MoodMod {
  String key;
  double score;
  int untilDay;
  MoodMod(this.key, this.score, this.untilDay);
  Map<String, dynamic> toJson() =>
      {'key': key, 'score': score, 'untilDay': untilDay};
  MoodMod.fromJson(Map<String, dynamic> j)
      : key = j['key'] as String,
        score = _d(j['score']),
        untilDay = _i(j['untilDay']);
}

class Staff {
  int id;
  String name;
  String role;
  double skill, reliability, loyalty, honesty, morale, fatigue;
  int wage;
  List<String> traits;
  int dayOff;
  int preferredDayOff;
  bool preferredKnown;
  int hiredDay;
  int daysWorked;
  String status; // active | notice
  int noticeLeft;
  int absentUntil; // absent while dayIndex < absentUntil
  int trainingUntil;
  List<MoodMod> moodMods;
  int lastGrowthDay;
  List<int> recentRush; // 1/0 for the last 7 worked days
  List<int> recentTips; // tips per worked day, last 7
  int consecutiveDays;
  int workDayOffDay; // dayIndex they agreed to work on their day off (-1 none)
  int lastWorkDayOffWeek;
  int workedDayOffWeek;
  int deniedUntil; // denied a raise/leave recently
  bool trainedByOwner;
  int warnings;
  // Today (set at prep).
  bool workingToday;
  bool absentToday;
  int lateTick;
  bool rushToday;
  int tipsToday;
  int askingWage; // applicants only

  Staff({
    required this.id,
    required this.name,
    required this.role,
    required this.skill,
    required this.reliability,
    required this.loyalty,
    required this.honesty,
    required this.morale,
    required this.fatigue,
    required this.wage,
    required this.traits,
    required this.dayOff,
    required this.preferredDayOff,
    this.preferredKnown = false,
    this.hiredDay = 0,
    this.daysWorked = 0,
    this.status = 'active',
    this.noticeLeft = 0,
    this.absentUntil = -1,
    this.trainingUntil = -1,
    List<MoodMod>? moodMods,
    this.lastGrowthDay = -999,
    List<int>? recentRush,
    List<int>? recentTips,
    this.consecutiveDays = 0,
    this.workDayOffDay = -1,
    this.lastWorkDayOffWeek = -99,
    this.workedDayOffWeek = -99,
    this.deniedUntil = -1,
    this.trainedByOwner = false,
    this.warnings = 0,
    this.workingToday = false,
    this.absentToday = false,
    this.lateTick = 0,
    this.rushToday = false,
    this.tipsToday = 0,
    this.askingWage = 0,
  })  : moodMods = moodMods ?? [],
        recentRush = recentRush ?? [],
        recentTips = recentTips ?? [];

  bool hasTrait(String t) => traits.contains(t);
  bool get skillKnown => daysWorked >= 7;
  bool get reliabilityKnown => daysWorked >= 7;
  bool get honestyKnown => daysWorked >= 14;
  bool get isCook => role == 'headChef' || role == 'lineCook';
  bool get isKitchen =>
      role == 'headChef' ||
      role == 'lineCook' ||
      role == 'prepCook' ||
      role == 'dishwasher';

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'role': role,
        'skill': skill,
        'reliability': reliability,
        'loyalty': loyalty,
        'honesty': honesty,
        'morale': morale,
        'fatigue': fatigue,
        'wage': wage,
        'traits': traits,
        'dayOff': dayOff,
        'preferredDayOff': preferredDayOff,
        'preferredKnown': preferredKnown,
        'hiredDay': hiredDay,
        'daysWorked': daysWorked,
        'status': status,
        'noticeLeft': noticeLeft,
        'absentUntil': absentUntil,
        'trainingUntil': trainingUntil,
        'moodMods': moodMods.map((m) => m.toJson()).toList(),
        'lastGrowthDay': lastGrowthDay,
        'recentRush': recentRush,
        'recentTips': recentTips,
        'consecutiveDays': consecutiveDays,
        'workDayOffDay': workDayOffDay,
        'lastWorkDayOffWeek': lastWorkDayOffWeek,
        'workedDayOffWeek': workedDayOffWeek,
        'deniedUntil': deniedUntil,
        'trainedByOwner': trainedByOwner,
        'warnings': warnings,
        'workingToday': workingToday,
        'absentToday': absentToday,
        'lateTick': lateTick,
        'rushToday': rushToday,
        'tipsToday': tipsToday,
        'askingWage': askingWage,
      };

  factory Staff.fromJson(Map<String, dynamic> j) => Staff(
        id: _i(j['id']),
        name: j['name'] as String,
        role: j['role'] as String,
        skill: _d(j['skill']),
        reliability: _d(j['reliability']),
        loyalty: _d(j['loyalty']),
        honesty: _d(j['honesty']),
        morale: _d(j['morale']),
        fatigue: _d(j['fatigue']),
        wage: _i(j['wage']),
        traits: _ls(j['traits']),
        dayOff: _i(j['dayOff']),
        preferredDayOff: _i(j['preferredDayOff']),
        preferredKnown: j['preferredKnown'] as bool,
        hiredDay: _i(j['hiredDay']),
        daysWorked: _i(j['daysWorked']),
        status: j['status'] as String,
        noticeLeft: _i(j['noticeLeft']),
        absentUntil: _i(j['absentUntil']),
        trainingUntil: _i(j['trainingUntil']),
        moodMods: _l(j['moodMods'], MoodMod.fromJson),
        lastGrowthDay: _i(j['lastGrowthDay']),
        recentRush: _li(j['recentRush']),
        recentTips: _li(j['recentTips']),
        consecutiveDays: _i(j['consecutiveDays']),
        workDayOffDay: _i(j['workDayOffDay']),
        lastWorkDayOffWeek: _i(j['lastWorkDayOffWeek']),
        workedDayOffWeek: _i(j['workedDayOffWeek']),
        deniedUntil: _i(j['deniedUntil']),
        trainedByOwner: j['trainedByOwner'] as bool,
        warnings: _i(j['warnings']),
        workingToday: j['workingToday'] as bool,
        absentToday: j['absentToday'] as bool,
        lateTick: _i(j['lateTick']),
        rushToday: j['rushToday'] as bool,
        tipsToday: _i(j['tipsToday']),
        askingWage: _i(j['askingWage']),
      );
}

class Equipment {
  int id;
  String type;
  double condition;
  bool broken;
  int ageDays;
  int unavailableUntil; // not usable while dayIndex < this (repair / delivery / servicing)
  int lastMaintDay;
  int fragileUntil; // a cheap repair may fail again before this day
  Equipment({
    required this.id,
    required this.type,
    required this.condition,
    this.broken = false,
    this.ageDays = 0,
    this.unavailableUntil = -1,
    this.lastMaintDay = -99,
    this.fragileUntil = -1,
  });
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'condition': condition,
        'broken': broken,
        'ageDays': ageDays,
        'unavailableUntil': unavailableUntil,
        'lastMaintDay': lastMaintDay,
        'fragileUntil': fragileUntil,
      };
  factory Equipment.fromJson(Map<String, dynamic> j) => Equipment(
        id: _i(j['id']),
        type: j['type'] as String,
        condition: _d(j['condition']),
        broken: j['broken'] as bool,
        ageDays: _i(j['ageDays']),
        unavailableUntil: _i(j['unavailableUntil']),
        lastMaintDay: _i(j['lastMaintDay']),
        fragileUntil: _i(j['fragileUntil']),
      );
}

class Batch {
  String ingredientId;
  int qty;
  int quality;
  int daysLeft;
  Batch(this.ingredientId, this.qty, this.quality, this.daysLeft);
  Map<String, dynamic> toJson() => {
        'ingredientId': ingredientId,
        'qty': qty,
        'quality': quality,
        'daysLeft': daysLeft
      };
  Batch.fromJson(Map<String, dynamic> j)
      : ingredientId = j['ingredientId'] as String,
        qty = _i(j['qty']),
        quality = _i(j['quality']),
        daysLeft = _i(j['daysLeft']);
}

class StockOrder {
  int id;
  String supplierId;
  Map<String, int> lines;
  int dueDay;
  int total;
  int placedDay;
  bool late;
  StockOrder({
    required this.id,
    required this.supplierId,
    required this.lines,
    required this.dueDay,
    required this.total,
    required this.placedDay,
    this.late = false,
  });
  Map<String, dynamic> toJson() => {
        'id': id,
        'supplierId': supplierId,
        'lines': lines,
        'dueDay': dueDay,
        'total': total,
        'placedDay': placedDay,
        'late': late,
      };
  factory StockOrder.fromJson(Map<String, dynamic> j) => StockOrder(
        id: _i(j['id']),
        supplierId: j['supplierId'] as String,
        lines: _mi(j['lines']),
        dueDay: _i(j['dueDay']),
        total: _i(j['total']),
        placedDay: _i(j['placedDay']),
        late: j['late'] as bool,
      );
}

class Payable {
  int id;
  String? supplierId;
  int amount;
  int dueDay;
  String label;
  bool inherited;
  Payable(this.id, this.supplierId, this.amount, this.dueDay, this.label,
      this.inherited);
  Map<String, dynamic> toJson() => {
        'id': id,
        'supplierId': supplierId,
        'amount': amount,
        'dueDay': dueDay,
        'label': label,
        'inherited': inherited,
      };
  Payable.fromJson(Map<String, dynamic> j)
      : id = _i(j['id']),
        supplierId = j['supplierId'] as String?,
        amount = _i(j['amount']),
        dueDay = _i(j['dueDay']),
        label = j['label'] as String,
        inherited = j['inherited'] as bool;
}

class Loan {
  int id;
  String lender; // bank | private | start
  int principal0;
  int outstanding;
  double weeklyRate;
  int termWeeks;
  bool secured;
  int startDay;
  int missedInRow;
  Loan({
    required this.id,
    required this.lender,
    required this.principal0,
    required this.outstanding,
    required this.weeklyRate,
    required this.termWeeks,
    required this.secured,
    required this.startDay,
    this.missedInRow = 0,
  });
  int get interestDue => (outstanding * weeklyRate).round();
  int get instalment {
    if (outstanding <= 0) return 0;
    final p = (principal0 / termWeeks + outstanding * weeklyRate).round();
    final cap = outstanding + interestDue;
    return p > cap ? cap : p;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'lender': lender,
        'principal0': principal0,
        'outstanding': outstanding,
        'weeklyRate': weeklyRate,
        'termWeeks': termWeeks,
        'secured': secured,
        'startDay': startDay,
        'missedInRow': missedInRow,
      };
  factory Loan.fromJson(Map<String, dynamic> j) => Loan(
        id: _i(j['id']),
        lender: j['lender'] as String,
        principal0: _i(j['principal0']),
        outstanding: _i(j['outstanding']),
        weeklyRate: _d(j['weeklyRate']),
        termWeeks: _i(j['termWeeks']),
        secured: j['secured'] as bool,
        startDay: _i(j['startDay']),
        missedInRow: _i(j['missedInRow']),
      );
}

class Campaign {
  int id;
  String type;
  int startDay;
  int endDay; // last day of boost (inclusive)
  int cost;
  double boost; // after outcome
  double mult;
  String outcome;
  String reason;
  double buzzLeft;
  double extraGroups;
  double extraProfit;
  int discountGiven;
  bool revealed;
  bool settled;
  Campaign({
    required this.id,
    required this.type,
    required this.startDay,
    required this.endDay,
    required this.cost,
    required this.boost,
    required this.mult,
    required this.outcome,
    required this.reason,
    this.buzzLeft = 0,
    this.extraGroups = 0,
    this.extraProfit = 0,
    this.discountGiven = 0,
    this.revealed = false,
    this.settled = false,
  });
  int get spend => cost + discountGiven;
  double? get returnOnSpend => spend == 0 ? null : extraProfit / spend;
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'startDay': startDay,
        'endDay': endDay,
        'cost': cost,
        'boost': boost,
        'mult': mult,
        'outcome': outcome,
        'reason': reason,
        'buzzLeft': buzzLeft,
        'extraGroups': extraGroups,
        'extraProfit': extraProfit,
        'discountGiven': discountGiven,
        'revealed': revealed,
        'settled': settled,
      };
  factory Campaign.fromJson(Map<String, dynamic> j) => Campaign(
        id: _i(j['id']),
        type: j['type'] as String,
        startDay: _i(j['startDay']),
        endDay: _i(j['endDay']),
        cost: _i(j['cost']),
        boost: _d(j['boost']),
        mult: _d(j['mult']),
        outcome: j['outcome'] as String,
        reason: j['reason'] as String,
        buzzLeft: _d(j['buzzLeft']),
        extraGroups: _d(j['extraGroups']),
        extraProfit: _d(j['extraProfit']),
        discountGiven: _i(j['discountGiven']),
        revealed: j['revealed'] as bool,
        settled: j['settled'] as bool,
      );
}

class MenuItem {
  String dishId;
  int price;
  bool enabled;
  int offSinceDay;
  int soldToday;
  int soldYesterday;
  int unavailableToday;
  MenuItem({
    required this.dishId,
    required this.price,
    required this.enabled,
    this.offSinceDay = -999,
    this.soldToday = 0,
    this.soldYesterday = 0,
    this.unavailableToday = 0,
  });
  Map<String, dynamic> toJson() => {
        'dishId': dishId,
        'price': price,
        'enabled': enabled,
        'offSinceDay': offSinceDay,
        'soldToday': soldToday,
        'soldYesterday': soldYesterday,
        'unavailableToday': unavailableToday,
      };
  factory MenuItem.fromJson(Map<String, dynamic> j) => MenuItem(
        dishId: j['dishId'] as String,
        price: _i(j['price']),
        enabled: j['enabled'] as bool,
        offSinceDay: _i(j['offSinceDay']),
        soldToday: _i(j['soldToday']),
        soldYesterday: _i(j['soldYesterday']),
        unavailableToday: _i(j['unavailableToday']),
      );
}

class Mod {
  String key;
  double mult;
  int untilDay; // active while dayIndex <= untilDay
  Mod(this.key, this.mult, this.untilDay);
  Map<String, dynamic> toJson() =>
      {'key': key, 'mult': mult, 'untilDay': untilDay};
  Mod.fromJson(Map<String, dynamic> j)
      : key = j['key'] as String,
        mult = _d(j['mult']),
        untilDay = _i(j['untilDay']);
}

class ParLevel {
  int par;
  String supplierId;
  ParLevel(this.par, this.supplierId);
  Map<String, dynamic> toJson() => {'par': par, 'supplierId': supplierId};
  ParLevel.fromJson(Map<String, dynamic> j)
      : par = _i(j['par']),
        supplierId = j['supplierId'] as String;
}

class HiddenProblem {
  String kind;
  bool revealed;
  int dueDay;
  int amount;
  bool done;
  HiddenProblem(this.kind,
      {this.revealed = false,
      this.dueDay = 0,
      this.amount = 0,
      this.done = false});
  Map<String, dynamic> toJson() => {
        'kind': kind,
        'revealed': revealed,
        'dueDay': dueDay,
        'amount': amount,
        'done': done
      };
  HiddenProblem.fromJson(Map<String, dynamic> j)
      : kind = j['kind'] as String,
        revealed = j['revealed'] as bool,
        dueDay = _i(j['dueDay']),
        amount = _i(j['amount']),
        done = j['done'] as bool;
}

// ---------------------------------------------------------------- service

class Group {
  int id;
  int size;
  String segment;
  String state; // waitTable waitOrder waitFood eating waitBill left walkedOut
  int arriveTick;
  int counter;
  int totalWait;
  int totalLimit;
  int? tableId;
  List<int> ticketIds;
  int eatUntil;
  int unavailable;
  bool treated;
  bool rushed;
  bool broughtBill;
  double satAdj;
  int payment;
  bool ill;
  bool critic;
  bool foodDelivered;
  double stars;
  bool seatTaskOpen;
  Group({
    required this.id,
    required this.size,
    required this.segment,
    required this.arriveTick,
    this.state = 'waitTable',
    this.counter = 0,
    this.totalWait = 0,
    this.totalLimit = 0,
    this.tableId,
    List<int>? ticketIds,
    this.eatUntil = 0,
    this.unavailable = 0,
    this.treated = false,
    this.rushed = false,
    this.broughtBill = false,
    this.satAdj = 0,
    this.payment = 0,
    this.ill = false,
    this.critic = false,
    this.foodDelivered = false,
    this.stars = 0,
    this.seatTaskOpen = false,
  }) : ticketIds = ticketIds ?? [];
  bool get waiting =>
      state == 'waitTable' ||
      state == 'waitOrder' ||
      state == 'waitFood' ||
      state == 'waitBill';
  bool get gone => state == 'left' || state == 'walkedOut';
  Map<String, dynamic> toJson() => {
        'id': id,
        'size': size,
        'segment': segment,
        'state': state,
        'arriveTick': arriveTick,
        'counter': counter,
        'totalWait': totalWait,
        'totalLimit': totalLimit,
        'tableId': tableId,
        'ticketIds': ticketIds,
        'eatUntil': eatUntil,
        'unavailable': unavailable,
        'treated': treated,
        'rushed': rushed,
        'broughtBill': broughtBill,
        'satAdj': satAdj,
        'payment': payment,
        'ill': ill,
        'critic': critic,
        'foodDelivered': foodDelivered,
        'stars': stars,
        'seatTaskOpen': seatTaskOpen,
      };
  factory Group.fromJson(Map<String, dynamic> j) => Group(
        id: _i(j['id']),
        size: _i(j['size']),
        segment: j['segment'] as String,
        arriveTick: _i(j['arriveTick']),
        state: j['state'] as String,
        counter: _i(j['counter']),
        totalWait: _i(j['totalWait']),
        totalLimit: _i(j['totalLimit']),
        tableId: _ni(j['tableId']),
        ticketIds: _li(j['ticketIds']),
        eatUntil: _i(j['eatUntil']),
        unavailable: _i(j['unavailable']),
        treated: j['treated'] as bool,
        rushed: j['rushed'] as bool,
        broughtBill: j['broughtBill'] as bool,
        satAdj: _d(j['satAdj']),
        payment: _i(j['payment']),
        ill: j['ill'] as bool,
        critic: j['critic'] as bool,
        foodDelivered: j['foodDelivered'] as bool,
        stars: _d(j['stars']),
        seatTaskOpen: j['seatTaskOpen'] as bool,
      );
}

class TableRt {
  int id;
  int seats;
  String state; // free occupied dirty
  int? groupId;
  bool reserved; // a seat task is heading here
  TableRt(this.id, this.seats,
      {this.state = 'free', this.groupId, this.reserved = false});
  Map<String, dynamic> toJson() => {
        'id': id,
        'seats': seats,
        'state': state,
        'groupId': groupId,
        'reserved': reserved
      };
  TableRt.fromJson(Map<String, dynamic> j)
      : id = _i(j['id']),
        seats = _i(j['seats']),
        state = j['state'] as String,
        groupId = _ni(j['groupId']),
        reserved = j['reserved'] as bool;
}

class Ticket {
  int id;
  int groupId;
  String dishId;
  String state; // wait cook ready cancel
  double quality;
  int priority; // lower first; rushed tickets jump the queue
  Ticket(this.id, this.groupId, this.dishId,
      {this.state = 'wait', this.quality = 0, this.priority = 0});
  Map<String, dynamic> toJson() => {
        'id': id,
        'groupId': groupId,
        'dishId': dishId,
        'state': state,
        'quality': quality,
        'priority': priority,
      };
  Ticket.fromJson(Map<String, dynamic> j)
      : id = _i(j['id']),
        groupId = _i(j['groupId']),
        dishId = j['dishId'] as String,
        state = j['state'] as String,
        quality = _d(j['quality']),
        priority = _i(j['priority']);
}

class Task {
  int id;
  String type; // seat takeOrder cook deliver bill clear apologise
  int? groupId;
  int? tableId;
  int? ticketId;
  int created;
  String? assignee; // staff id as string, or 'owner'
  int startTick;
  int endTick;
  bool reserved; // reserved for the owner by tap
  Task({
    required this.id,
    required this.type,
    this.groupId,
    this.tableId,
    this.ticketId,
    required this.created,
    this.assignee,
    this.startTick = -1,
    this.endTick = -1,
    this.reserved = false,
  });
  bool get started => assignee != null;
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'groupId': groupId,
        'tableId': tableId,
        'ticketId': ticketId,
        'created': created,
        'assignee': assignee,
        'startTick': startTick,
        'endTick': endTick,
        'reserved': reserved,
      };
  factory Task.fromJson(Map<String, dynamic> j) => Task(
        id: _i(j['id']),
        type: j['type'] as String,
        groupId: _ni(j['groupId']),
        tableId: _ni(j['tableId']),
        ticketId: _ni(j['ticketId']),
        created: _i(j['created']),
        assignee: j['assignee'] as String?,
        startTick: _i(j['startTick']),
        endTick: _i(j['endTick']),
        reserved: j['reserved'] as bool,
      );
}

class Arrival {
  int tick, size;
  String segment;
  bool critic;
  Arrival(this.tick, this.size, this.segment, {this.critic = false});
  Map<String, dynamic> toJson() =>
      {'tick': tick, 'size': size, 'segment': segment, 'critic': critic};
  Arrival.fromJson(Map<String, dynamic> j)
      : tick = _i(j['tick']),
        size = _i(j['size']),
        segment = j['segment'] as String,
        critic = j['critic'] as bool;
}

class ServiceState {
  int tick;
  List<Arrival> arrivals;
  List<Group> groups;
  List<TableRt> tables;
  List<Task> tasks;
  List<Ticket> tickets;
  double dirtyDishes;
  int favours;
  int favourClock;
  String? ownerArea;
  List<int> ownerQueue;
  int ownerIdleTicks;
  int ownerBusyUntil; // owner tied up (mediating, apologising) until this tick
  Map<String, String> moves; // staffId → role tonight
  Set<String> eightySix; // dishes auto-86'd today
  int target;
  int lost;
  int forecast;
  double patienceMult;
  int patienceUntil;
  Map<String, int> stationOffUntil; // station → tick
  int noSeatUntil;
  double billMult;
  int billMultUntil;
  Map<String, double> roleSlow; // role → duration multiplier tonight
  int lastIncidentTick;
  int breakdownTick;
  int breakdownEqId;
  Set<String> rushRoles;
  bool done;
  int nextId;
  int platesFullTicks;
  int seatingStartTick;
  ServiceState({
    this.tick = 0,
    List<Arrival>? arrivals,
    List<Group>? groups,
    List<TableRt>? tables,
    List<Task>? tasks,
    List<Ticket>? tickets,
    this.dirtyDishes = 0,
    this.favours = 3,
    this.favourClock = 0,
    this.ownerArea,
    List<int>? ownerQueue,
    this.ownerIdleTicks = 0,
    this.ownerBusyUntil = -1,
    Map<String, String>? moves,
    Set<String>? eightySix,
    this.target = 1,
    this.lost = 0,
    this.forecast = 0,
    this.patienceMult = 1,
    this.patienceUntil = -1,
    Map<String, int>? stationOffUntil,
    this.noSeatUntil = -1,
    this.billMult = 1,
    this.billMultUntil = -1,
    Map<String, double>? roleSlow,
    this.lastIncidentTick = 0,
    this.breakdownTick = -1,
    this.breakdownEqId = -1,
    Set<String>? rushRoles,
    this.done = false,
    this.nextId = 1,
    this.platesFullTicks = 0,
    this.seatingStartTick = 0,
  })  : arrivals = arrivals ?? [],
        groups = groups ?? [],
        tables = tables ?? [],
        tasks = tasks ?? [],
        tickets = tickets ?? [],
        ownerQueue = ownerQueue ?? [],
        moves = moves ?? {},
        eightySix = eightySix ?? {},
        stationOffUntil = stationOffUntil ?? {},
        roleSlow = roleSlow ?? {},
        rushRoles = rushRoles ?? {};

  Group? group(int? id) {
    if (id == null) return null;
    for (final g in groups) {
      if (g.id == id) return g;
    }
    return null;
  }

  TableRt? table(int? id) {
    if (id == null) return null;
    for (final t in tables) {
      if (t.id == id) return t;
    }
    return null;
  }

  Ticket? ticket(int? id) {
    if (id == null) return null;
    for (final t in tickets) {
      if (t.id == id) return t;
    }
    return null;
  }

  Task? task(int? id) {
    if (id == null) return null;
    for (final t in tasks) {
      if (t.id == id) return t;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'tick': tick,
        'arrivals': arrivals.map((e) => e.toJson()).toList(),
        'groups': groups.map((e) => e.toJson()).toList(),
        'tables': tables.map((e) => e.toJson()).toList(),
        'tasks': tasks.map((e) => e.toJson()).toList(),
        'tickets': tickets.map((e) => e.toJson()).toList(),
        'dirtyDishes': dirtyDishes,
        'favours': favours,
        'favourClock': favourClock,
        'ownerArea': ownerArea,
        'ownerQueue': ownerQueue,
        'ownerIdleTicks': ownerIdleTicks,
        'ownerBusyUntil': ownerBusyUntil,
        'moves': moves,
        'eightySix': eightySix.toList()..sort(),
        'target': target,
        'lost': lost,
        'forecast': forecast,
        'patienceMult': patienceMult,
        'patienceUntil': patienceUntil,
        'stationOffUntil': stationOffUntil,
        'noSeatUntil': noSeatUntil,
        'billMult': billMult,
        'billMultUntil': billMultUntil,
        'roleSlow': roleSlow,
        'lastIncidentTick': lastIncidentTick,
        'breakdownTick': breakdownTick,
        'breakdownEqId': breakdownEqId,
        'rushRoles': rushRoles.toList()..sort(),
        'done': done,
        'nextId': nextId,
        'platesFullTicks': platesFullTicks,
        'seatingStartTick': seatingStartTick,
      };

  factory ServiceState.fromJson(Map<String, dynamic> j) => ServiceState(
        tick: _i(j['tick']),
        arrivals: _l(j['arrivals'], Arrival.fromJson),
        groups: _l(j['groups'], Group.fromJson),
        tables: _l(j['tables'], TableRt.fromJson),
        tasks: _l(j['tasks'], Task.fromJson),
        tickets: _l(j['tickets'], Ticket.fromJson),
        dirtyDishes: _d(j['dirtyDishes']),
        favours: _i(j['favours']),
        favourClock: _i(j['favourClock']),
        ownerArea: j['ownerArea'] as String?,
        ownerQueue: _li(j['ownerQueue']),
        ownerIdleTicks: _i(j['ownerIdleTicks']),
        ownerBusyUntil: _i(j['ownerBusyUntil']),
        moves: _ms(j['moves']),
        eightySix: _ls(j['eightySix']).toSet(),
        target: _i(j['target']),
        lost: _i(j['lost']),
        forecast: _i(j['forecast']),
        patienceMult: _d(j['patienceMult']),
        patienceUntil: _i(j['patienceUntil']),
        stationOffUntil: _mi(j['stationOffUntil']),
        noSeatUntil: _i(j['noSeatUntil']),
        billMult: _d(j['billMult']),
        billMultUntil: _i(j['billMultUntil']),
        roleSlow: _md(j['roleSlow']),
        lastIncidentTick: _i(j['lastIncidentTick']),
        breakdownTick: _i(j['breakdownTick']),
        breakdownEqId: _i(j['breakdownEqId']),
        rushRoles: _ls(j['rushRoles']).toSet(),
        done: j['done'] as bool,
        nextId: _i(j['nextId']),
        platesFullTicks: _i(j['platesFullTicks']),
        seatingStartTick: _i(j['seatingStartTick']),
      );
}

// ---------------------------------------------------------------- reports

class DayEvent {
  String kind; // a stable key used for cause ranking
  String text;
  int value; // coins or count used to rank causes
  DayEvent(this.kind, this.text, this.value);
  Map<String, dynamic> toJson() => {'kind': kind, 'text': text, 'value': value};
  DayEvent.fromJson(Map<String, dynamic> j)
      : kind = j['kind'] as String,
        text = j['text'] as String,
        value = _i(j['value']);
}

class DayStats {
  int dayIndex;
  int revenue;
  int tips;
  int ingredientSpend;
  int wages;
  int rent;
  int utilities;
  int upkeep; // maintenance + repairs + equipment purchases
  int marketing;
  int other; // incidents, fines, licences
  int interest;
  int groupsArrived;
  int groupsSeated;
  int groupsServed;
  int walkTable;
  int walkOrder;
  int walkFood;
  int walkBill;
  double starsSum;
  double starsN;
  int wasteCost;
  int unavailable;
  int ownerTasks;
  int forecast;
  int target;
  int lost;
  double foodQualitySum;
  int foodTickets;
  int ingredientsUsedCost;
  bool closed;
  bool ownerRested;
  List<DayEvent> events;
  DayStats({
    required this.dayIndex,
    this.revenue = 0,
    this.tips = 0,
    this.ingredientSpend = 0,
    this.wages = 0,
    this.rent = 0,
    this.utilities = 0,
    this.upkeep = 0,
    this.marketing = 0,
    this.other = 0,
    this.interest = 0,
    this.groupsArrived = 0,
    this.groupsSeated = 0,
    this.groupsServed = 0,
    this.walkTable = 0,
    this.walkOrder = 0,
    this.walkFood = 0,
    this.walkBill = 0,
    this.starsSum = 0,
    this.starsN = 0,
    this.wasteCost = 0,
    this.unavailable = 0,
    this.ownerTasks = 0,
    this.forecast = 0,
    this.target = 0,
    this.lost = 0,
    this.foodQualitySum = 0,
    this.foodTickets = 0,
    this.ingredientsUsedCost = 0,
    this.closed = false,
    this.ownerRested = false,
    List<DayEvent>? events,
  }) : events = events ?? [];

  int get walkouts => walkTable + walkOrder + walkFood + walkBill;
  int get costs =>
      ingredientSpend + wages + rent + utilities + upkeep + marketing + other;
  int get profit => revenue - costs;
  double get avgStars => starsN == 0 ? 0 : starsSum / starsN;

  void add(String kind, String text, [int value = 0]) =>
      events.add(DayEvent(kind, text, value));

  Map<String, dynamic> toJson() => {
        'dayIndex': dayIndex,
        'revenue': revenue,
        'tips': tips,
        'ingredientSpend': ingredientSpend,
        'wages': wages,
        'rent': rent,
        'utilities': utilities,
        'upkeep': upkeep,
        'marketing': marketing,
        'other': other,
        'interest': interest,
        'groupsArrived': groupsArrived,
        'groupsSeated': groupsSeated,
        'groupsServed': groupsServed,
        'walkTable': walkTable,
        'walkOrder': walkOrder,
        'walkFood': walkFood,
        'walkBill': walkBill,
        'starsSum': starsSum,
        'starsN': starsN,
        'wasteCost': wasteCost,
        'unavailable': unavailable,
        'ownerTasks': ownerTasks,
        'forecast': forecast,
        'target': target,
        'lost': lost,
        'foodQualitySum': foodQualitySum,
        'foodTickets': foodTickets,
        'ingredientsUsedCost': ingredientsUsedCost,
        'closed': closed,
        'ownerRested': ownerRested,
        'events': events.map((e) => e.toJson()).toList(),
      };
  factory DayStats.fromJson(Map<String, dynamic> j) => DayStats(
        dayIndex: _i(j['dayIndex']),
        revenue: _i(j['revenue']),
        tips: _i(j['tips']),
        ingredientSpend: _i(j['ingredientSpend']),
        wages: _i(j['wages']),
        rent: _i(j['rent']),
        utilities: _i(j['utilities']),
        upkeep: _i(j['upkeep']),
        marketing: _i(j['marketing']),
        other: _i(j['other']),
        interest: _i(j['interest']),
        groupsArrived: _i(j['groupsArrived']),
        groupsSeated: _i(j['groupsSeated']),
        groupsServed: _i(j['groupsServed']),
        walkTable: _i(j['walkTable']),
        walkOrder: _i(j['walkOrder']),
        walkFood: _i(j['walkFood']),
        walkBill: _i(j['walkBill']),
        starsSum: _d(j['starsSum']),
        starsN: _d(j['starsN']),
        wasteCost: _i(j['wasteCost']),
        unavailable: _i(j['unavailable']),
        ownerTasks: _i(j['ownerTasks']),
        forecast: _i(j['forecast']),
        target: _i(j['target']),
        lost: _i(j['lost']),
        foodQualitySum: _d(j['foodQualitySum']),
        foodTickets: _i(j['foodTickets']),
        ingredientsUsedCost: _i(j['ingredientsUsedCost']),
        closed: j['closed'] as bool,
        ownerRested: j['ownerRested'] as bool,
        events: _l(j['events'], DayEvent.fromJson),
      );
}

class WeekRecord {
  int week;
  int revenue;
  int costs;
  int operatingProfit;
  int interest;
  int wasteCost;
  int groupsServed;
  int walkouts;
  double avgStars;
  int ingredientSpend;
  int wages;
  int rent;
  int marketing;
  int upkeep;
  int other;
  int utilities;
  WeekRecord({
    required this.week,
    this.revenue = 0,
    this.costs = 0,
    this.operatingProfit = 0,
    this.interest = 0,
    this.wasteCost = 0,
    this.groupsServed = 0,
    this.walkouts = 0,
    this.avgStars = 0,
    this.ingredientSpend = 0,
    this.wages = 0,
    this.rent = 0,
    this.marketing = 0,
    this.upkeep = 0,
    this.other = 0,
    this.utilities = 0,
  });
  int get netProfit => operatingProfit - interest;
  Map<String, dynamic> toJson() => {
        'week': week,
        'revenue': revenue,
        'costs': costs,
        'operatingProfit': operatingProfit,
        'interest': interest,
        'wasteCost': wasteCost,
        'groupsServed': groupsServed,
        'walkouts': walkouts,
        'avgStars': avgStars,
        'ingredientSpend': ingredientSpend,
        'wages': wages,
        'rent': rent,
        'marketing': marketing,
        'upkeep': upkeep,
        'other': other,
        'utilities': utilities,
      };
  factory WeekRecord.fromJson(Map<String, dynamic> j) => WeekRecord(
        week: _i(j['week']),
        revenue: _i(j['revenue']),
        costs: _i(j['costs']),
        operatingProfit: _i(j['operatingProfit']),
        interest: _i(j['interest']),
        wasteCost: _i(j['wasteCost']),
        groupsServed: _i(j['groupsServed']),
        walkouts: _i(j['walkouts']),
        avgStars: _d(j['avgStars']),
        ingredientSpend: _i(j['ingredientSpend']),
        wages: _i(j['wages']),
        rent: _i(j['rent']),
        marketing: _i(j['marketing']),
        upkeep: _i(j['upkeep']),
        other: _i(j['other']),
        utilities: _i(j['utilities']),
      );
}

class IncidentInstance {
  int id;
  String incidentId;
  int? subjectId; // staff or equipment id
  String? subjectKey; // supplier id / ingredient id / dish id
  String subjectName;
  int createdDay;
  int countdown; // service ticks left before the default applies (-1 none)
  bool resolved;
  String? chosen;
  String result;
  Map<String, int> vars;
  IncidentInstance({
    required this.id,
    required this.incidentId,
    this.subjectId,
    this.subjectKey,
    this.subjectName = '',
    required this.createdDay,
    this.countdown = -1,
    this.resolved = false,
    this.chosen,
    this.result = '',
    Map<String, int>? vars,
  }) : vars = vars ?? {};
  Map<String, dynamic> toJson() => {
        'id': id,
        'incidentId': incidentId,
        'subjectId': subjectId,
        'subjectKey': subjectKey,
        'subjectName': subjectName,
        'createdDay': createdDay,
        'countdown': countdown,
        'resolved': resolved,
        'chosen': chosen,
        'result': result,
        'vars': vars,
      };
  factory IncidentInstance.fromJson(Map<String, dynamic> j) => IncidentInstance(
        id: _i(j['id']),
        incidentId: j['incidentId'] as String,
        subjectId: _ni(j['subjectId']),
        subjectKey: j['subjectKey'] as String?,
        subjectName: j['subjectName'] as String,
        createdDay: _i(j['createdDay']),
        countdown: _i(j['countdown']),
        resolved: j['resolved'] as bool,
        chosen: j['chosen'] as String?,
        result: j['result'] as String,
        vars: _mi(j['vars']),
      );
}

class Scheduled {
  String incidentId;
  int day;
  int? subjectId;
  String? subjectKey;
  Scheduled(this.incidentId, this.day, {this.subjectId, this.subjectKey});
  Map<String, dynamic> toJson() => {
        'incidentId': incidentId,
        'day': day,
        'subjectId': subjectId,
        'subjectKey': subjectKey
      };
  Scheduled.fromJson(Map<String, dynamic> j)
      : incidentId = j['incidentId'] as String,
        day = _i(j['day']),
        subjectId = _ni(j['subjectId']),
        subjectKey = j['subjectKey'] as String?;
}

// ---------------------------------------------------------------- location

class Location {
  int id;
  String name;
  String tierId;
  String classId;
  int rentWeekly;
  List<int> tableSeats;
  double reputation;
  double hygiene;
  double buzz;
  double freshness;
  double competition;
  double awareness;
  Map<String, MenuItem> menu;
  List<Staff> staff;
  List<Equipment> equipment;
  List<Batch> stock;
  List<StockOrder> orders;
  Map<String, double> priceIndex;
  Map<String, int> supplierRel;
  Map<String, int> supplierBlockedUntil;
  Map<String, int> supplierCashOnlyUntil;
  Map<String, double> supplierDeal; // supplierId → priceMult reduction
  List<Payable> payables;
  Map<String, ParLevel> parLevels;
  List<Campaign> campaigns;
  List<Mod> demandMods;
  Map<String, int> categorySpikeUntil;
  String? shortageIngredient;
  int shortageUntil;
  int closedUntil; // no service while dayIndex < closedUntil
  int inspectionDay;
  int lastReworkDay;
  int lastRotateDay;
  int lastMaintWeek;
  double utilitiesAccrued;
  int leaseLockUntil;
  int lossWeeks;
  List<HiddenProblem> hidden;
  ServiceState? service;
  Location({
    required this.id,
    required this.name,
    required this.tierId,
    required this.classId,
    required this.rentWeekly,
    required this.tableSeats,
    required this.reputation,
    required this.hygiene,
    required this.buzz,
    required this.freshness,
    this.competition = 0,
    this.awareness = 1,
    Map<String, MenuItem>? menu,
    List<Staff>? staff,
    List<Equipment>? equipment,
    List<Batch>? stock,
    List<StockOrder>? orders,
    Map<String, double>? priceIndex,
    Map<String, int>? supplierRel,
    Map<String, int>? supplierBlockedUntil,
    Map<String, int>? supplierCashOnlyUntil,
    Map<String, double>? supplierDeal,
    List<Payable>? payables,
    Map<String, ParLevel>? parLevels,
    List<Campaign>? campaigns,
    List<Mod>? demandMods,
    Map<String, int>? categorySpikeUntil,
    this.shortageIngredient,
    this.shortageUntil = -1,
    this.closedUntil = -1,
    this.inspectionDay = -1,
    this.lastReworkDay = -999,
    this.lastRotateDay = -999,
    this.lastMaintWeek = -1,
    this.utilitiesAccrued = 0,
    this.leaseLockUntil = -1,
    this.lossWeeks = 0,
    List<HiddenProblem>? hidden,
    this.service,
  })  : menu = menu ?? {},
        staff = staff ?? [],
        equipment = equipment ?? [],
        stock = stock ?? [],
        orders = orders ?? [],
        priceIndex = priceIndex ?? {},
        supplierRel = supplierRel ?? {},
        supplierBlockedUntil = supplierBlockedUntil ?? {},
        supplierCashOnlyUntil = supplierCashOnlyUntil ?? {},
        supplierDeal = supplierDeal ?? {},
        payables = payables ?? [],
        parLevels = parLevels ?? {},
        campaigns = campaigns ?? [],
        demandMods = demandMods ?? [],
        categorySpikeUntil = categorySpikeUntil ?? {},
        hidden = hidden ?? [];

  Staff? staffById(int? id) {
    if (id == null) return null;
    for (final s in staff) {
      if (s.id == id) return s;
    }
    return null;
  }

  Equipment? equipmentById(int? id) {
    if (id == null) return null;
    for (final e in equipment) {
      if (e.id == id) return e;
    }
    return null;
  }

  int stockOf(String ingredientId) {
    var n = 0;
    for (final b in stock) {
      if (b.ingredientId == ingredientId) n += b.qty;
    }
    return n;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'tierId': tierId,
        'classId': classId,
        'rentWeekly': rentWeekly,
        'tableSeats': tableSeats,
        'reputation': reputation,
        'hygiene': hygiene,
        'buzz': buzz,
        'freshness': freshness,
        'competition': competition,
        'awareness': awareness,
        'menu': menu.map((k, v) => MapEntry(k, v.toJson())),
        'staff': staff.map((e) => e.toJson()).toList(),
        'equipment': equipment.map((e) => e.toJson()).toList(),
        'stock': stock.map((e) => e.toJson()).toList(),
        'orders': orders.map((e) => e.toJson()).toList(),
        'priceIndex': priceIndex,
        'supplierRel': supplierRel,
        'supplierBlockedUntil': supplierBlockedUntil,
        'supplierCashOnlyUntil': supplierCashOnlyUntil,
        'supplierDeal': supplierDeal,
        'payables': payables.map((e) => e.toJson()).toList(),
        'parLevels': parLevels.map((k, v) => MapEntry(k, v.toJson())),
        'campaigns': campaigns.map((e) => e.toJson()).toList(),
        'demandMods': demandMods.map((e) => e.toJson()).toList(),
        'categorySpikeUntil': categorySpikeUntil,
        'shortageIngredient': shortageIngredient,
        'shortageUntil': shortageUntil,
        'closedUntil': closedUntil,
        'inspectionDay': inspectionDay,
        'lastReworkDay': lastReworkDay,
        'lastRotateDay': lastRotateDay,
        'lastMaintWeek': lastMaintWeek,
        'utilitiesAccrued': utilitiesAccrued,
        'leaseLockUntil': leaseLockUntil,
        'lossWeeks': lossWeeks,
        'hidden': hidden.map((e) => e.toJson()).toList(),
        'service': service?.toJson(),
      };

  factory Location.fromJson(Map<String, dynamic> j) => Location(
        id: _i(j['id']),
        name: j['name'] as String,
        tierId: j['tierId'] as String,
        classId: j['classId'] as String,
        rentWeekly: _i(j['rentWeekly']),
        tableSeats: _li(j['tableSeats']),
        reputation: _d(j['reputation']),
        hygiene: _d(j['hygiene']),
        buzz: _d(j['buzz']),
        freshness: _d(j['freshness']),
        competition: _d(j['competition']),
        awareness: _d(j['awareness']),
        menu: ((j['menu'] as Map?) ?? const {}).map((k, v) => MapEntry(
            k as String,
            MenuItem.fromJson((v as Map).cast<String, dynamic>()))),
        staff: _l(j['staff'], Staff.fromJson),
        equipment: _l(j['equipment'], Equipment.fromJson),
        stock: _l(j['stock'], Batch.fromJson),
        orders: _l(j['orders'], StockOrder.fromJson),
        priceIndex: _md(j['priceIndex']),
        supplierRel: _mi(j['supplierRel']),
        supplierBlockedUntil: _mi(j['supplierBlockedUntil']),
        supplierCashOnlyUntil: _mi(j['supplierCashOnlyUntil']),
        supplierDeal: _md(j['supplierDeal']),
        payables: _l(j['payables'], Payable.fromJson),
        parLevels: ((j['parLevels'] as Map?) ?? const {}).map((k, v) =>
            MapEntry(k as String,
                ParLevel.fromJson((v as Map).cast<String, dynamic>()))),
        campaigns: _l(j['campaigns'], Campaign.fromJson),
        demandMods: _l(j['demandMods'], Mod.fromJson),
        categorySpikeUntil: _mi(j['categorySpikeUntil']),
        shortageIngredient: j['shortageIngredient'] as String?,
        shortageUntil: _i(j['shortageUntil']),
        closedUntil: _i(j['closedUntil']),
        inspectionDay: _i(j['inspectionDay']),
        lastReworkDay: _i(j['lastReworkDay']),
        lastRotateDay: _i(j['lastRotateDay']),
        lastMaintWeek: _i(j['lastMaintWeek']),
        utilitiesAccrued: _d(j['utilitiesAccrued']),
        leaseLockUntil: _i(j['leaseLockUntil']),
        lossWeeks: _i(j['lossWeeks']),
        hidden: _l(j['hidden'], HiddenProblem.fromJson),
        service: j['service'] == null
            ? null
            : ServiceState.fromJson(
                (j['service'] as Map).cast<String, dynamic>()),
      );
}

class Offer {
  String tierId;
  int price;
  int loan;
  bool inspected;
  Location location;
  Offer(this.tierId, this.price, this.loan, this.location,
      {this.inspected = false});
  Map<String, dynamic> toJson() => {
        'tierId': tierId,
        'price': price,
        'loan': loan,
        'inspected': inspected,
        'location': location.toJson()
      };
  Offer.fromJson(Map<String, dynamic> j)
      : tierId = j['tierId'] as String,
        price = _i(j['price']),
        loan = _i(j['loan']),
        inspected = j['inspected'] as bool,
        location =
            Location.fromJson((j['location'] as Map).cast<String, dynamic>());
}

class Owner {
  double energy;
  int zeroEnergyDays;
  bool restingToday;
  int forcedRestDay;
  String? startArea;
  int restDaysThisWeek;
  Owner({
    this.energy = 100,
    this.zeroEnergyDays = 0,
    this.restingToday = false,
    this.forcedRestDay = -1,
    this.startArea = 'door',
    this.restDaysThisWeek = 0,
  });
  Map<String, dynamic> toJson() => {
        'energy': energy,
        'zeroEnergyDays': zeroEnergyDays,
        'restingToday': restingToday,
        'forcedRestDay': forcedRestDay,
        'startArea': startArea,
        'restDaysThisWeek': restDaysThisWeek,
      };
  factory Owner.fromJson(Map<String, dynamic> j) => Owner(
        energy: _d(j['energy']),
        zeroEnergyDays: _i(j['zeroEnergyDays']),
        restingToday: j['restingToday'] as bool,
        forcedRestDay: _i(j['forcedRestDay']),
        startArea: j['startArea'] as String?,
        restDaysThisWeek: _i(j['restDaysThisWeek']),
      );
}

class TimelineEntry {
  int day;
  String text;
  TimelineEntry(this.day, this.text);
  Map<String, dynamic> toJson() => {'day': day, 'text': text};
  TimelineEntry.fromJson(Map<String, dynamic> j)
      : day = _i(j['day']),
        text = j['text'] as String;
}

class GameState {
  int saveVersion;
  int seed;
  int rngState;
  String difficulty;
  String themeId;
  String phase; // market prep service close gameOver
  int dayIndex;
  int cash;
  double creditScore;
  int negativeDays;
  int missedInRow;
  int lastMissDay;
  int bankBlockedUntil;
  int? counterOffer;
  int counterOfferTerm;
  bool investorTaken;
  double investorShare;
  int stage;
  Set<String> objectivesDone;
  int profitableWeeksInRow;
  List<Offer> offers;
  List<Location> locations;
  Owner owner;
  List<Loan> loans;
  List<IncidentInstance> incidents; // open (unresolved) and today's resolved
  Map<String, int> cooldowns;
  List<Scheduled> scheduled;
  Map<String, int> flags; // key → expiry day (inclusive), or 1<<30 forever
  List<Staff> applicants;
  DayStats today;
  List<DayStats> days; // history, capped
  List<WeekRecord> weeks;
  List<int> cashHistory;
  int monthProfit;
  int monthRevenue;
  int wagesOwed;
  int monthUtilities;
  String? gameOverReason;
  List<TimelineEntry> timeline;
  int nextId;
  bool autoRunTipShown;
  List<String> pendingNotices; // shown at next prep
  GameState({
    this.saveVersion = 1,
    required this.seed,
    required this.rngState,
    required this.difficulty,
    required this.themeId,
    this.phase = 'market',
    this.dayIndex = 0,
    this.cash = 0,
    this.creditScore = 60,
    this.negativeDays = 0,
    this.missedInRow = 0,
    this.lastMissDay = -999,
    this.bankBlockedUntil = -1,
    this.counterOffer,
    this.counterOfferTerm = 52,
    this.investorTaken = false,
    this.investorShare = 0,
    this.stage = 1,
    Set<String>? objectivesDone,
    this.profitableWeeksInRow = 0,
    List<Offer>? offers,
    List<Location>? locations,
    Owner? owner,
    List<Loan>? loans,
    List<IncidentInstance>? incidents,
    Map<String, int>? cooldowns,
    List<Scheduled>? scheduled,
    Map<String, int>? flags,
    List<Staff>? applicants,
    DayStats? today,
    List<DayStats>? days,
    List<WeekRecord>? weeks,
    List<int>? cashHistory,
    this.monthProfit = 0,
    this.monthRevenue = 0,
    this.wagesOwed = 0,
    this.monthUtilities = 0,
    this.gameOverReason,
    List<TimelineEntry>? timeline,
    this.nextId = 1,
    this.autoRunTipShown = false,
    List<String>? pendingNotices,
  })  : objectivesDone = objectivesDone ?? {},
        offers = offers ?? [],
        locations = locations ?? [],
        owner = owner ?? Owner(),
        loans = loans ?? [],
        incidents = incidents ?? [],
        cooldowns = cooldowns ?? {},
        scheduled = scheduled ?? [],
        flags = flags ?? {},
        applicants = applicants ?? [],
        today = today ?? DayStats(dayIndex: 0),
        days = days ?? [],
        weeks = weeks ?? [],
        cashHistory = cashHistory ?? [],
        timeline = timeline ?? [],
        pendingNotices = pendingNotices ?? [];

  Location get loc => locations.first;
  bool get hasLocation => locations.isNotEmpty;
  int get weekday => dayIndex % 7;
  int get weekIndex => dayIndex ~/ 7;
  int get dayOfMonth => dayIndex % 28 + 1; // 1..28
  int get month => (dayIndex ~/ 28) % 12 + 1; // 1..12
  int get year => dayIndex ~/ 336 + 1;
  String get season => seasons[(month - 1) ~/ 3];
  bool flag(String k) => (flags[k] ?? -1) >= dayIndex;
  int allocId() => nextId++;
  int get totalOutstanding => loans.fold(0, (a, l) => a + l.outstanding);
  List<IncidentInstance> get openIncidents =>
      incidents.where((i) => !i.resolved).toList();

  Map<String, dynamic> toJson() => {
        'saveVersion': saveVersion,
        'seed': seed,
        'rngState': rngState,
        'difficulty': difficulty,
        'themeId': themeId,
        'phase': phase,
        'dayIndex': dayIndex,
        'cash': cash,
        'creditScore': creditScore,
        'negativeDays': negativeDays,
        'missedInRow': missedInRow,
        'lastMissDay': lastMissDay,
        'bankBlockedUntil': bankBlockedUntil,
        'counterOffer': counterOffer,
        'counterOfferTerm': counterOfferTerm,
        'investorTaken': investorTaken,
        'investorShare': investorShare,
        'stage': stage,
        'objectivesDone': objectivesDone.toList()..sort(),
        'profitableWeeksInRow': profitableWeeksInRow,
        'offers': offers.map((e) => e.toJson()).toList(),
        'locations': locations.map((e) => e.toJson()).toList(),
        'owner': owner.toJson(),
        'loans': loans.map((e) => e.toJson()).toList(),
        'incidents': incidents.map((e) => e.toJson()).toList(),
        'cooldowns': cooldowns,
        'scheduled': scheduled.map((e) => e.toJson()).toList(),
        'flags': flags,
        'applicants': applicants.map((e) => e.toJson()).toList(),
        'today': today.toJson(),
        'days': days.map((e) => e.toJson()).toList(),
        'weeks': weeks.map((e) => e.toJson()).toList(),
        'cashHistory': cashHistory,
        'monthProfit': monthProfit,
        'monthRevenue': monthRevenue,
        'wagesOwed': wagesOwed,
        'monthUtilities': monthUtilities,
        'gameOverReason': gameOverReason,
        'timeline': timeline.map((e) => e.toJson()).toList(),
        'nextId': nextId,
        'autoRunTipShown': autoRunTipShown,
        'pendingNotices': pendingNotices,
      };

  factory GameState.fromJson(Map<String, dynamic> j) => GameState(
        saveVersion: _i(j['saveVersion']),
        seed: _i(j['seed']),
        rngState: _i(j['rngState']),
        difficulty: j['difficulty'] as String,
        themeId: j['themeId'] as String,
        phase: j['phase'] as String,
        dayIndex: _i(j['dayIndex']),
        cash: _i(j['cash']),
        creditScore: _d(j['creditScore']),
        negativeDays: _i(j['negativeDays']),
        missedInRow: _i(j['missedInRow']),
        lastMissDay: _i(j['lastMissDay']),
        bankBlockedUntil: _i(j['bankBlockedUntil']),
        counterOffer: _ni(j['counterOffer']),
        counterOfferTerm: _i(j['counterOfferTerm']),
        investorTaken: j['investorTaken'] as bool,
        investorShare: _d(j['investorShare']),
        stage: _i(j['stage']),
        objectivesDone: _ls(j['objectivesDone']).toSet(),
        profitableWeeksInRow: _i(j['profitableWeeksInRow']),
        offers: _l(j['offers'], Offer.fromJson),
        locations: _l(j['locations'], Location.fromJson),
        owner: Owner.fromJson((j['owner'] as Map).cast<String, dynamic>()),
        loans: _l(j['loans'], Loan.fromJson),
        incidents: _l(j['incidents'], IncidentInstance.fromJson),
        cooldowns: _mi(j['cooldowns']),
        scheduled: _l(j['scheduled'], Scheduled.fromJson),
        flags: _mi(j['flags']),
        applicants: _l(j['applicants'], Staff.fromJson),
        today: DayStats.fromJson((j['today'] as Map).cast<String, dynamic>()),
        days: _l(j['days'], DayStats.fromJson),
        weeks: _l(j['weeks'], WeekRecord.fromJson),
        cashHistory: _li(j['cashHistory']),
        monthProfit: _i(j['monthProfit']),
        monthRevenue: _i(j['monthRevenue']),
        wagesOwed: _i(j['wagesOwed']),
        monthUtilities: _i(j['monthUtilities']),
        gameOverReason: j['gameOverReason'] as String?,
        timeline: _l(j['timeline'], TimelineEntry.fromJson),
        nextId: _i(j['nextId']),
        autoRunTipShown: j['autoRunTipShown'] as bool,
        pendingNotices: _ls(j['pendingNotices']),
      );
}
