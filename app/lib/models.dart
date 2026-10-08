/// Plain models over the API's JSON. Times are parsed to local [DateTime]s.
library;

DateTime? parseTime(dynamic v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;

double? toDouble(dynamic v) => v is num ? v.toDouble() : null;
int? toInt(dynamic v) => v is num ? v.round() : null;

/// RFC 3339 with the device's offset, e.g. `2026-10-08T14:30:00-04:00`.
String formatTime(DateTime t) {
  final local = t.toLocal();
  final off = local.timeZoneOffset;
  String two(int n) => n.abs().toString().padLeft(2, '0');
  final sign = off.isNegative ? '-' : '+';
  return '${local.year.toString().padLeft(4, '0')}-${two(local.month)}-${two(local.day)}'
      'T${two(local.hour)}:${two(local.minute)}:${two(local.second)}'
      '$sign${two(off.inHours)}:${two(off.inMinutes.remainder(60))}';
}

class Me {
  Me(this.json);
  final Map<String, dynamic> json;
  String get id => json['id'];
  String get name => json['name'] ?? '';
  String get email => json['email'] ?? '';
  bool get imperial => json['units'] == 'imperial';
}

class Member {
  Member(this.json);
  final Map<String, dynamic> json;
  String get userId => json['user_id'];
  String get name => json['name'] ?? '';
  String get email => json['email'] ?? '';
  String get role => json['role'] ?? 'caregiver';
}

class Child {
  Child(this.json);
  final Map<String, dynamic> json;
  String get id => json['id'];
  String get familyId => json['family_id'];
  String get name => json['name'] ?? 'Baby';
  String? get sex => json['sex'];
  DateTime? get birthDate => json['birth_date'] is String ? DateTime.tryParse(json['birth_date']) : null;

  /// "3 months 2 weeks", "5 days", "1 year 2 months".
  String? get age {
    final b = birthDate;
    if (b == null) return null;
    final now = DateTime.now();
    final days = DateTime(now.year, now.month, now.day).difference(b).inDays;
    if (days < 0) return 'Due in ${-days} day${-days == 1 ? '' : 's'}';
    if (days < 14) return '$days day${days == 1 ? '' : 's'}';
    var months = (now.year - b.year) * 12 + now.month - b.month;
    if (now.day < b.day) months--;
    if (months < 1) return '${days ~/ 7} weeks';
    if (months < 24) {
      final anchor = DateTime(b.year, b.month + months, b.day);
      final weeks = DateTime(now.year, now.month, now.day).difference(anchor).inDays ~/ 7;
      final m = '$months month${months == 1 ? '' : 's'}';
      return weeks > 0 ? '$m $weeks week${weeks == 1 ? '' : 's'}' : m;
    }
    final y = months ~/ 12, m = months % 12;
    return '$y year${y == 1 ? '' : 's'}${m > 0 ? ' $m month${m == 1 ? '' : 's'}' : ''}';
  }
}

class Family {
  Family(this.json);
  final Map<String, dynamic> json;
  String get id => json['id'];
  String get name => json['name'] ?? '';
  String get timezone => json['timezone'] ?? 'UTC';
  String? get role => json['role'];
  bool get isOwner => role == 'owner';
  List<Member> get members => [for (final m in (json['members'] as List? ?? [])) Member(m)];
  List<Child> get children => [for (final c in (json['children'] as List? ?? [])) Child(c)];
}

/// One logged record. Type-specific fields are read straight from [json].
class Event {
  Event(this.json);
  final Map<String, dynamic> json;
  String get id => json['id'];
  String get childId => json['child_id'];
  String get type => json['type'];
  DateTime get start => parseTime(json['start']) ?? DateTime.now();
  DateTime? get end => parseTime(json['end']);
  int? get durationSeconds => toInt(json['duration_seconds']);
  String? get note => json['note'];
  String? get source => json['source'];
  dynamic operator [](String key) => json[key];

  /// Which breast the feed ended on (Nara shows this so you know where to start next).
  String? get endSide {
    final l = toInt(json['left_seconds']) ?? 0, r = toInt(json['right_seconds']) ?? 0;
    if (l > 0 && r > 0) {
      final s = json['start_side'];
      return s == 'left'
          ? 'right'
          : s == 'right'
          ? 'left'
          : null;
    }
    if (l > 0) return 'left';
    if (r > 0) return 'right';
    return null;
  }
}

/// A running or paused timer. Elapsed values tick locally from when the JSON was received.
class TimerModel {
  TimerModel(this.json) : _received = DateTime.now();
  final Map<String, dynamic> json;
  final DateTime _received;

  String get id => json['id'];
  String get childId => json['child_id'];
  String get kind => json['kind'];
  bool get running => json['running'] == true;
  String? get side => json['side'];
  DateTime get startedAt => parseTime(json['started_at']) ?? _received;

  int get _drift => running ? DateTime.now().difference(_received).inSeconds : 0;
  int get elapsed => (toInt(json['elapsed_seconds']) ?? 0) + _drift;
  int get left => (toInt(json['left_seconds']) ?? 0) + (side == 'left' || side == 'both' ? _drift : 0);
  int get right => (toInt(json['right_seconds']) ?? 0) + (side == 'right' || side == 'both' ? _drift : 0);
}
