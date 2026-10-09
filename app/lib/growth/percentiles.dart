import 'dart:math' as math;

import 'who_lms.dart';

/// WHO Child Growth Standards (birth to 24 months) via the LMS method: for an age and sex the
/// WHO gives L (skew), M (median) and S (spread); a value's z-score is ((x/M)^L − 1) / (L·S).
enum GrowthIndicator { weight, length, head }

/// The percentile curves drawn on growth charts, with their z-scores.
const percentileCurves = <(int, double)>[
  (2, -2.0537),
  (5, -1.6449),
  (10, -1.2816),
  (25, -0.6745),
  (50, 0),
  (75, 0.6745),
  (90, 1.2816),
  (95, 1.6449),
  (98, 2.0537),
];

/// Last age covered by the tables.
const whoMaxDays = 730.5;

class WhoStandard {
  WhoStandard(this.indicator, this.sex) : _rows = whoLms[indicator.name]![sex]!;

  final GrowthIndicator indicator;

  /// `female` or `male`.
  final String sex;
  final List<(double, double, double, double)> _rows;

  /// L, M, S at [days] (linear between the WHO's weekly / monthly values); null past 24 months.
  (double, double, double)? lms(double days) {
    if (days < 0 || days > whoMaxDays) return null;
    for (var i = 1; i < _rows.length; i++) {
      final (d1, l1, m1, s1) = _rows[i];
      if (days <= d1) {
        final (d0, l0, m0, s0) = _rows[i - 1];
        final t = d1 == d0 ? 0.0 : (days - d0) / (d1 - d0);
        return (l0 + (l1 - l0) * t, m0 + (m1 - m0) * t, s0 + (s1 - s0) * t);
      }
    }
    final (_, l, m, s) = _rows.last;
    return (l, m, s);
  }

  /// The value at [z] (e.g. the 50th percentile curve is z = 0).
  double? valueAt(double days, double z) {
    final p = lms(days);
    if (p == null) return null;
    final (l, m, s) = p;
    if (l.abs() < 1e-6) return m * math.exp(s * z);
    final base = 1 + l * s * z;
    return base <= 0 ? null : m * math.pow(base, 1 / l);
  }

  double? zScore(double days, double value) {
    final p = lms(days);
    if (p == null || value <= 0) return null;
    final (l, m, s) = p;
    if (l.abs() < 1e-6) return math.log(value / m) / s;
    return (math.pow(value / m, l) - 1) / (l * s);
  }

  /// Percentile (0–100) of [value] at [days] of age.
  double? percentile(double days, double value) {
    final z = zScore(days, value);
    return z == null ? null : 100 * normalCdf(z);
  }
}

/// Standard normal CDF (Abramowitz & Stegun 7.1.26, error < 1.5e-7).
double normalCdf(double z) {
  final x = z.abs() / math.sqrt2;
  final t = 1 / (1 + 0.3275911 * x);
  final erf = 1 - (((((1.061405429 * t - 1.453152027) * t) + 1.421413741) * t - 0.284496736) * t + 0.254829592) * t * math.exp(-x * x);
  return z >= 0 ? (1 + erf) / 2 : (1 - erf) / 2;
}

/// "13th", "<1st", ">99th".
String percentileLabel(double p) {
  if (p < 1) return '<1st';
  if (p > 99) return '>99th';
  final n = p.round();
  final suffix = (n % 100 >= 11 && n % 100 <= 13)
      ? 'th'
      : switch (n % 10) {
          1 => 'st',
          2 => 'nd',
          3 => 'rd',
          _ => 'th',
        };
  return '$n$suffix';
}
