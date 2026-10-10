//! Daily statistics. Days are calendar days in the family's timezone;
//! "daytime" is the family's day window, 06:00-18:00 local by default (same split the Nara app uses).

use chrono::{Duration, NaiveDate, TimeZone};
use chrono_tz::Tz;
use serde::Serialize;

use crate::model::{Details, FeedMethod, Milk};

/// When daytime starts and ends, in minutes after local midnight (`start < end`).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct DayWindow {
    pub start: u32,
    pub end: u32,
}

impl Default for DayWindow {
    fn default() -> Self {
        DayWindow { start: 6 * 60, end: 18 * 60 }
    }
}

impl DayWindow {
    /// Checks a window from the API.
    pub fn new(start: u32, end: u32) -> Option<Self> {
        (start < end && end <= 24 * 60).then_some(DayWindow { start, end })
    }

    fn on(self, tz: Tz, date: NaiveDate) -> (i64, i64) {
        (local_ms(tz, date, self.start), local_ms(tz, date, self.end))
    }
}

/// "06:30" ↔ 390.
pub fn hhmm(minutes: u32) -> String {
    format!("{:02}:{:02}", minutes / 60, minutes % 60)
}

pub fn parse_hhmm(s: &str) -> Option<u32> {
    let (h, m) = s.split_once(':')?;
    let (h, m): (u32, u32) = (h.parse().ok()?, m.parse().ok()?);
    (m < 60 && h * 60 + m <= 24 * 60).then_some(h * 60 + m)
}

pub struct TrendEvent {
    pub start: i64,
    pub end: Option<i64>,
    pub details: Details,
}

#[derive(Debug, Default, Clone, Serialize)]
pub struct FeedStats {
    pub count: u32,
    pub breast_count: u32,
    pub breast_seconds: i64,
    pub breast_left_seconds: i64,
    pub breast_right_seconds: i64,
    /// Breastfeeding in feeds that started during the daytime (night = total - day).
    pub day_breast_seconds: i64,
    pub day_breast_left_seconds: i64,
    pub day_breast_right_seconds: i64,
    pub bottle_count: u32,
    pub bottle_ml: f64,
    /// Bottle amount by milk (bottles without a milk type are only in `bottle_ml`).
    pub breast_milk_ml: f64,
    pub formula_ml: f64,
    pub mixed_ml: f64,
    pub solids_count: u32,
}

#[derive(Debug, Default, Clone, Serialize)]
pub struct SleepStats {
    /// Sleep inside this calendar day (sleep crossing midnight is split).
    pub total_seconds: i64,
    pub day_seconds: i64,
    pub night_seconds: i64,
    /// Sleeps that started during the daytime.
    pub nap_count: u32,
    pub longest_seconds: i64,
}

#[derive(Debug, Default, Clone, Serialize)]
pub struct DiaperStats {
    pub count: u32,
    pub wet: u32,
    pub dirty: u32,
    pub day_count: u32,
    pub night_count: u32,
    pub day_wet: u32,
    pub day_dirty: u32,
}

#[derive(Debug, Default, Clone, Serialize)]
pub struct PumpStats {
    pub count: u32,
    pub total_ml: f64,
    pub total_seconds: i64,
}

#[derive(Debug, Clone, Serialize)]
pub struct DayStats {
    pub date: NaiveDate,
    pub complete: bool,
    pub feed: FeedStats,
    pub sleep: SleepStats,
    pub diaper: DiaperStats,
    pub pump: PumpStats,
}

#[derive(Debug, Default, Clone, Serialize)]
pub struct Averages {
    /// Number of complete days the daily averages are based on.
    pub days: u32,
    pub feeds_per_day: f64,
    pub breast_feeds_per_day: f64,
    pub bottle_feeds_per_day: f64,
    pub solids_per_day: f64,
    pub breast_seconds_per_day: f64,
    pub breast_left_seconds_per_day: f64,
    pub breast_right_seconds_per_day: f64,
    pub day_breast_seconds_per_day: f64,
    pub day_breast_left_seconds_per_day: f64,
    pub day_breast_right_seconds_per_day: f64,
    pub night_breast_seconds_per_day: f64,
    pub night_breast_left_seconds_per_day: f64,
    pub night_breast_right_seconds_per_day: f64,
    pub bottle_ml_per_day: f64,
    pub breast_milk_ml_per_day: f64,
    pub formula_ml_per_day: f64,
    pub mixed_ml_per_day: f64,
    pub sleep_seconds_per_day: f64,
    pub day_sleep_seconds_per_day: f64,
    pub night_sleep_seconds_per_day: f64,
    pub naps_per_day: f64,
    /// Average of each day's longest sleep (by start day).
    pub longest_sleep_seconds: f64,
    pub diapers_per_day: f64,
    pub wet_per_day: f64,
    pub dirty_per_day: f64,
    pub day_diapers_per_day: f64,
    pub day_wet_per_day: f64,
    pub day_dirty_per_day: f64,
    pub night_diapers_per_day: f64,
    pub night_wet_per_day: f64,
    pub night_dirty_per_day: f64,
    pub pumps_per_day: f64,
    pub pumped_ml_per_day: f64,
    pub pump_seconds_per_day: f64,
    /// Average time from the start of one feed to the start of the next.
    pub feed_interval_seconds: Option<i64>,
    /// Average time awake between two sleeps.
    pub wake_window_seconds: Option<i64>,
    pub avg_breastfeed_seconds: Option<i64>,
    pub avg_bottle_ml: Option<f64>,
    pub avg_nap_seconds: Option<i64>,
}

#[derive(Debug, Clone, Serialize)]
pub struct Trends {
    pub timezone: String,
    pub from: NaiveDate,
    pub to: NaiveDate,
    pub days: Vec<DayStats>,
    pub averages: Averages,
    /// Averages over the same number of days just before `from` (null when nothing was logged then).
    pub previous: Option<Averages>,
}

/// Epoch ms of `minutes` after midnight on `date` (24:00 is the next midnight).
fn local_ms(tz: Tz, date: NaiveDate, minutes: u32) -> i64 {
    let naive = date.and_hms_opt(0, 0, 0).expect("midnight") + Duration::minutes(minutes as i64);
    tz.from_local_datetime(&naive)
        .earliest()
        // A DST gap at this exact hour: fall back to one hour later.
        .or_else(|| tz.from_local_datetime(&(naive + Duration::hours(1))).earliest())
        .map(|d| d.timestamp_millis())
        .expect("valid local time")
}

fn overlap(a0: i64, a1: i64, b0: i64, b1: i64) -> i64 {
    (a1.min(b1) - a0.max(b0)).max(0)
}

/// Range of epoch ms covering `days` days starting at `from` (local midnight to midnight).
pub fn range_ms(tz: Tz, from: NaiveDate, days: u32) -> (i64, i64) {
    (local_ms(tz, from, 0), local_ms(tz, from + Duration::days(days as i64), 0))
}

/// Totals behind the averages that a `DayStats` doesn't keep.
#[derive(Default)]
struct Extra {
    nap_seconds: i64,
    naps: u32,
    bottle_ml: f64,
    bottles: u32,
}

/// Stats for events starting in [w0, w1) (sleep: the part inside it). `daytimes` are the
/// 06–18 intervals overlapping the window, for the day/night split and naps.
fn window_stats(events: &[TrendEvent], date: NaiveDate, w0: i64, w1: i64, daytimes: &[(i64, i64)], now: i64) -> (DayStats, Extra) {
    let mut day = DayStats {
        date,
        complete: w1 <= now,
        feed: FeedStats::default(),
        sleep: SleepStats::default(),
        diaper: DiaperStats::default(),
        pump: PumpStats::default(),
    };
    let mut extra = Extra::default();
    for ev in events {
        let starts_in = ev.start >= w0 && ev.start < w1;
        let daytime = daytimes.iter().any(|&(a, b)| ev.start >= a && ev.start < b);
        match &ev.details {
            Details::Feed(f) if starts_in => {
                day.feed.count += 1;
                let (left, right) = (f.left_seconds.unwrap_or(0) as i64, f.right_seconds.unwrap_or(0) as i64);
                if matches!(f.method, FeedMethod::Breast | FeedMethod::Combo) {
                    day.feed.breast_count += 1;
                    day.feed.breast_seconds += left + right;
                    day.feed.breast_left_seconds += left;
                    day.feed.breast_right_seconds += right;
                    if daytime {
                        day.feed.day_breast_seconds += left + right;
                        day.feed.day_breast_left_seconds += left;
                        day.feed.day_breast_right_seconds += right;
                    }
                }
                if matches!(f.method, FeedMethod::Bottle | FeedMethod::Combo) {
                    day.feed.bottle_count += 1;
                    let ml = f.amount_ml.unwrap_or(0.0);
                    day.feed.bottle_ml += ml;
                    match f.milk {
                        Some(Milk::BreastMilk) => day.feed.breast_milk_ml += ml,
                        Some(Milk::Formula) => day.feed.formula_ml += ml,
                        Some(Milk::Mixed) => day.feed.mixed_ml += ml,
                        None => {}
                    }
                    if ml > 0.0 {
                        extra.bottle_ml += ml;
                        extra.bottles += 1;
                    }
                }
                if f.method == FeedMethod::Solids {
                    day.feed.solids_count += 1;
                }
            }
            Details::Sleep(_) => {
                let end = ev.end.unwrap_or(ev.start).min(now.max(ev.start));
                let total = overlap(ev.start, end, w0, w1);
                let dayt: i64 = daytimes.iter().map(|&(a, b)| overlap(ev.start, end, a.max(w0), b.min(w1))).sum();
                day.sleep.total_seconds += total / 1000;
                day.sleep.day_seconds += dayt / 1000;
                day.sleep.night_seconds += (total - dayt) / 1000;
                if starts_in {
                    let dur = (end - ev.start) / 1000;
                    day.sleep.longest_seconds = day.sleep.longest_seconds.max(dur);
                    if daytime {
                        day.sleep.nap_count += 1;
                        extra.nap_seconds += dur;
                        extra.naps += 1;
                    }
                }
            }
            Details::Diaper(d) if starts_in => {
                day.diaper.count += 1;
                if d.wet {
                    day.diaper.wet += 1;
                }
                if d.dirty {
                    day.diaper.dirty += 1;
                }
                if daytime {
                    day.diaper.day_count += 1;
                    day.diaper.day_wet += d.wet as u32;
                    day.diaper.day_dirty += d.dirty as u32;
                } else {
                    day.diaper.night_count += 1;
                }
            }
            Details::Pump(p) if starts_in => {
                day.pump.count += 1;
                day.pump.total_ml += p.left_ml.unwrap_or(0.0) + p.right_ml.unwrap_or(0.0);
                day.pump.total_seconds += ev.end.map(|e| (e - ev.start) / 1000).unwrap_or(0);
            }
            _ => {}
        }
    }
    (day, extra)
}

/// The 24 hours up to `now` (rolling, not the calendar day). `date` is today's local date.
pub fn last_24h(events: &[TrendEvent], tz: Tz, window: DayWindow, now: i64) -> DayStats {
    let w0 = now - 24 * 3600 * 1000;
    let today = tz.timestamp_millis_opt(now).single().map(|t| t.date_naive()).unwrap_or_default();
    let daytimes: Vec<(i64, i64)> = [today - Duration::days(1), today]
        .into_iter()
        .map(|d| window.on(tz, d))
        .collect();
    let (mut day, _) = window_stats(events, today, w0, now, &daytimes, now);
    day.complete = false;
    day
}

pub fn compute(events: &[TrendEvent], tz: Tz, window: DayWindow, from: NaiveDate, days: u32, now: i64) -> Trends {
    let mut out = Vec::with_capacity(days as usize);
    let mut nap_total = 0i64;
    let mut nap_n = 0u32;
    let mut bf_total = 0i64;
    let mut bf_n = 0u32;
    let mut bottle_total = 0.0;
    let mut bottle_n = 0u32;

    for i in 0..days {
        let date = from + Duration::days(i as i64);
        let d0 = local_ms(tz, date, 0);
        let d1 = local_ms(tz, date + Duration::days(1), 0);
        let daytime = [window.on(tz, date)];
        let (day, extra) = window_stats(events, date, d0, d1, &daytime, now);
        nap_total += extra.nap_seconds;
        nap_n += extra.naps;
        bf_total += day.feed.breast_seconds;
        bf_n += day.feed.breast_count;
        bottle_total += extra.bottle_ml;
        bottle_n += extra.bottles;
        out.push(day);
    }

    // Daily averages use complete days only (today would drag them down),
    // unless today is the only day requested.
    let complete: Vec<&DayStats> = out.iter().filter(|d| d.complete).collect();
    let basis: Vec<&DayStats> = if complete.is_empty() { out.iter().collect() } else { complete };
    let n = basis.len().max(1) as f64;
    let avg = |f: &dyn Fn(&DayStats) -> f64| (basis.iter().map(|d| f(d)).sum::<f64>() / n * 10.0).round() / 10.0;

    let (r0, r1) = range_ms(tz, from, days);
    let mut feed_starts: Vec<i64> = events
        .iter()
        .filter(|e| matches!(e.details, Details::Feed(_)) && e.start >= r0 && e.start < r1)
        .map(|e| e.start)
        .collect();
    feed_starts.sort_unstable();
    let gaps: Vec<i64> = feed_starts.windows(2).map(|w| w[1] - w[0]).filter(|g| *g > 0).collect();

    let mut sleeps: Vec<(i64, i64)> = events
        .iter()
        .filter(|e| matches!(e.details, Details::Sleep(_)) && e.start < r1 && e.end.unwrap_or(e.start) >= r0)
        .map(|e| (e.start, e.end.unwrap_or(e.start)))
        .collect();
    sleeps.sort_unstable();
    let wakes: Vec<i64> = sleeps.windows(2).map(|w| w[1].0 - w[0].1).filter(|g| *g > 0).collect();

    let mean_s = |v: &[i64]| if v.is_empty() { None } else { Some(v.iter().sum::<i64>() / v.len() as i64 / 1000) };

    let averages = Averages {
        days: basis.len() as u32,
        feeds_per_day: avg(&|d| d.feed.count as f64),
        breast_feeds_per_day: avg(&|d| d.feed.breast_count as f64),
        bottle_feeds_per_day: avg(&|d| d.feed.bottle_count as f64),
        solids_per_day: avg(&|d| d.feed.solids_count as f64),
        breast_seconds_per_day: avg(&|d| d.feed.breast_seconds as f64),
        breast_left_seconds_per_day: avg(&|d| d.feed.breast_left_seconds as f64),
        breast_right_seconds_per_day: avg(&|d| d.feed.breast_right_seconds as f64),
        day_breast_seconds_per_day: avg(&|d| d.feed.day_breast_seconds as f64),
        day_breast_left_seconds_per_day: avg(&|d| d.feed.day_breast_left_seconds as f64),
        day_breast_right_seconds_per_day: avg(&|d| d.feed.day_breast_right_seconds as f64),
        night_breast_seconds_per_day: avg(&|d| (d.feed.breast_seconds - d.feed.day_breast_seconds) as f64),
        night_breast_left_seconds_per_day: avg(&|d| (d.feed.breast_left_seconds - d.feed.day_breast_left_seconds) as f64),
        night_breast_right_seconds_per_day: avg(&|d| (d.feed.breast_right_seconds - d.feed.day_breast_right_seconds) as f64),
        bottle_ml_per_day: avg(&|d| d.feed.bottle_ml),
        breast_milk_ml_per_day: avg(&|d| d.feed.breast_milk_ml),
        formula_ml_per_day: avg(&|d| d.feed.formula_ml),
        mixed_ml_per_day: avg(&|d| d.feed.mixed_ml),
        sleep_seconds_per_day: avg(&|d| d.sleep.total_seconds as f64),
        day_sleep_seconds_per_day: avg(&|d| d.sleep.day_seconds as f64),
        night_sleep_seconds_per_day: avg(&|d| d.sleep.night_seconds as f64),
        naps_per_day: avg(&|d| d.sleep.nap_count as f64),
        longest_sleep_seconds: avg(&|d| d.sleep.longest_seconds as f64),
        diapers_per_day: avg(&|d| d.diaper.count as f64),
        wet_per_day: avg(&|d| d.diaper.wet as f64),
        dirty_per_day: avg(&|d| d.diaper.dirty as f64),
        day_diapers_per_day: avg(&|d| d.diaper.day_count as f64),
        day_wet_per_day: avg(&|d| d.diaper.day_wet as f64),
        day_dirty_per_day: avg(&|d| d.diaper.day_dirty as f64),
        night_diapers_per_day: avg(&|d| d.diaper.night_count as f64),
        night_wet_per_day: avg(&|d| (d.diaper.wet - d.diaper.day_wet) as f64),
        night_dirty_per_day: avg(&|d| (d.diaper.dirty - d.diaper.day_dirty) as f64),
        pumps_per_day: avg(&|d| d.pump.count as f64),
        pumped_ml_per_day: avg(&|d| d.pump.total_ml),
        pump_seconds_per_day: avg(&|d| d.pump.total_seconds as f64),
        feed_interval_seconds: mean_s(&gaps[..]),
        wake_window_seconds: mean_s(&wakes[..]),
        avg_breastfeed_seconds: if bf_n > 0 { Some(bf_total / bf_n as i64) } else { None },
        avg_bottle_ml: if bottle_n > 0 { Some((bottle_total / bottle_n as f64 * 10.0).round() / 10.0) } else { None },
        avg_nap_seconds: if nap_n > 0 { Some(nap_total / nap_n as i64) } else { None },
    };

    Trends {
        timezone: tz.to_string(),
        from,
        to: from + Duration::days(days as i64 - 1),
        days: out,
        averages,
        previous: None,
    }
}

/// `compute` for `days` days from `from`, plus the averages of the `days` days before it.
/// `events` must cover both periods.
pub fn compute_with_previous(events: &[TrendEvent], tz: Tz, window: DayWindow, from: NaiveDate, days: u32, now: i64) -> Trends {
    let mut t = compute(events, tz, window, from, days, now);
    let prev_from = from - Duration::days(days as i64);
    let (p0, p1) = range_ms(tz, prev_from, days);
    if events.iter().any(|e| e.start >= p0 && e.start < p1) {
        t.previous = Some(compute(events, tz, window, prev_from, days, now).averages);
    }
    t
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::model::{Diaper, Feed, Sleep};

    fn ms(tz: Tz, s: &str) -> i64 {
        crate::util::parse_time(s, tz).unwrap()
    }

    #[test]
    fn last_24_hours_cross_midnight() {
        let tz: Tz = "America/New_York".parse().unwrap();
        let events = vec![
            // Yesterday evening: inside the last 24 h, not "today".
            TrendEvent { start: ms(tz, "2026-10-01T20:00"), end: None, details: Details::Diaper(Diaper { wet: true, ..Default::default() }) },
            TrendEvent { start: ms(tz, "2026-10-01T22:00"), end: Some(ms(tz, "2026-10-02T04:00")), details: Details::Sleep(Sleep::default()) },
            // More than 24 h ago: out.
            TrendEvent { start: ms(tz, "2026-10-01T08:00"), end: None, details: Details::Diaper(Diaper { dirty: true, ..Default::default() }) },
            // This morning: a nap, and a sleep still in progress counts up to now.
            TrendEvent { start: ms(tz, "2026-10-02T07:00"), end: Some(ms(tz, "2026-10-02T08:00")), details: Details::Sleep(Sleep::default()) },
        ];
        let now = ms(tz, "2026-10-02T10:00");
        let d = last_24h(&events, tz, DayWindow::default(), now);
        assert_eq!((d.diaper.count, d.diaper.wet, d.diaper.dirty), (1, 1, 0));
        assert_eq!(d.sleep.total_seconds, 7 * 3600);
        assert_eq!(d.sleep.night_seconds, 6 * 3600);
        assert_eq!(d.sleep.day_seconds, 3600);
        assert_eq!(d.sleep.nap_count, 1);
        let today = compute(&events, tz, DayWindow::default(), NaiveDate::from_ymd_opt(2026, 10, 2).unwrap(), 1, now);
        assert_eq!(today.days[0].diaper.count, 0);
    }

    #[test]
    fn splits_sleep_across_midnight() {
        let tz: Tz = "America/New_York".parse().unwrap();
        let from = NaiveDate::from_ymd_opt(2026, 10, 1).unwrap();
        let events = vec![
            TrendEvent { start: ms(tz, "2026-10-01T22:00"), end: Some(ms(tz, "2026-10-02T04:00")), details: Details::Sleep(Sleep::default()) },
            TrendEvent { start: ms(tz, "2026-10-02T13:00"), end: Some(ms(tz, "2026-10-02T14:30")), details: Details::Sleep(Sleep::default()) },
            TrendEvent {
                start: ms(tz, "2026-10-02T08:00"),
                end: None,
                details: Details::Feed(Feed { method: FeedMethod::Bottle, left_seconds: None, right_seconds: None, start_side: None, amount_ml: Some(120.0), milk: None, formula_name: None, foods: None }),
            },
            TrendEvent { start: ms(tz, "2026-10-02T11:00"), end: None, details: Details::Feed(Feed { method: FeedMethod::Breast, left_seconds: Some(600), right_seconds: Some(300), start_side: None, amount_ml: None, milk: None, formula_name: None, foods: None }) },
            TrendEvent { start: ms(tz, "2026-10-02T23:00"), end: None, details: Details::Diaper(Diaper { wet: true, dirty: true, ..Default::default() }) },
        ];
        let now = ms(tz, "2026-10-05T00:00");
        let t = compute(&events, tz, DayWindow::default(), from, 2, now);
        assert_eq!(t.days[0].sleep.total_seconds, 2 * 3600);
        assert_eq!(t.days[0].sleep.night_seconds, 2 * 3600);
        assert_eq!(t.days[0].sleep.longest_seconds, 6 * 3600);
        assert_eq!(t.days[1].sleep.total_seconds, 4 * 3600 + 5400);
        assert_eq!(t.days[1].sleep.day_seconds, 5400);
        assert_eq!(t.days[1].sleep.nap_count, 1);
        assert_eq!(t.days[1].feed.count, 2);
        assert_eq!(t.days[1].feed.bottle_ml, 120.0);
        assert_eq!(t.days[1].feed.breast_seconds, 900);
        assert_eq!(t.days[1].diaper.night_count, 1);
        assert_eq!(t.averages.feed_interval_seconds, Some(3 * 3600));
        assert_eq!(t.averages.wake_window_seconds, Some(9 * 3600));
        assert_eq!(t.averages.days, 2);
    }

    #[test]
    fn sides_day_night_and_previous_period() {
        let tz: Tz = "America/New_York".parse().unwrap();
        let breast = |l, r| Details::Feed(Feed { method: FeedMethod::Breast, left_seconds: Some(l), right_seconds: Some(r), start_side: None, amount_ml: None, milk: None, formula_name: None, foods: None });
        let events = vec![
            // Previous period (Oct 1).
            TrendEvent { start: ms(tz, "2026-10-01T10:00"), end: None, details: breast(100, 100) },
            // Current period (Oct 2): one daytime and one nighttime feed, a bottle of formula.
            TrendEvent { start: ms(tz, "2026-10-02T10:00"), end: None, details: breast(600, 300) },
            TrendEvent { start: ms(tz, "2026-10-02T22:00"), end: None, details: breast(60, 120) },
            TrendEvent {
                start: ms(tz, "2026-10-02T12:00"),
                end: None,
                details: Details::Feed(Feed { method: FeedMethod::Bottle, left_seconds: None, right_seconds: None, start_side: None, amount_ml: Some(90.0), milk: Some(Milk::Formula), formula_name: None, foods: None }),
            },
            TrendEvent { start: ms(tz, "2026-10-02T20:00"), end: None, details: Details::Diaper(Diaper { wet: true, dirty: true, ..Default::default() }) },
        ];
        let now = ms(tz, "2026-10-05T00:00");
        let t = compute_with_previous(&events, tz, DayWindow::default(), NaiveDate::from_ymd_opt(2026, 10, 2).unwrap(), 1, now);
        let a = &t.averages;
        assert_eq!((a.breast_left_seconds_per_day, a.breast_right_seconds_per_day), (660.0, 420.0));
        assert_eq!((a.day_breast_left_seconds_per_day, a.day_breast_right_seconds_per_day), (600.0, 300.0));
        assert_eq!((a.night_breast_left_seconds_per_day, a.night_breast_right_seconds_per_day), (60.0, 120.0));
        assert_eq!((a.breast_feeds_per_day, a.bottle_feeds_per_day, a.formula_ml_per_day), (2.0, 1.0, 90.0));
        assert_eq!((a.night_diapers_per_day, a.night_wet_per_day, a.day_diapers_per_day), (1.0, 1.0, 0.0));
        let p = t.previous.as_ref().expect("previous period");
        assert_eq!((p.feeds_per_day, p.breast_seconds_per_day), (1.0, 200.0));
        // Nothing logged before Oct 1: no comparison.
        let first = compute_with_previous(&events, tz, DayWindow::default(), NaiveDate::from_ymd_opt(2026, 10, 1).unwrap(), 1, now);
        assert!(first.previous.is_none());
    }

    #[test]
    fn custom_day_window() {
        let tz: Tz = "America/New_York".parse().unwrap();
        let events = vec![
            // 07:00: night with an 08:00 start, sleep 07:00-09:00 is half night, half day.
            TrendEvent { start: ms(tz, "2026-10-02T07:00"), end: None, details: Details::Diaper(Diaper { wet: true, ..Default::default() }) },
            TrendEvent { start: ms(tz, "2026-10-02T07:00"), end: Some(ms(tz, "2026-10-02T09:00")), details: Details::Sleep(Sleep::default()) },
        ];
        let window = DayWindow::new(8 * 60, 20 * 60 + 30).unwrap();
        let t = compute(&events, tz, window, NaiveDate::from_ymd_opt(2026, 10, 2).unwrap(), 1, ms(tz, "2026-10-05T00:00"));
        assert_eq!((t.days[0].diaper.day_count, t.days[0].diaper.night_count), (0, 1));
        assert_eq!((t.days[0].sleep.day_seconds, t.days[0].sleep.night_seconds), (3600, 3600));
        assert_eq!(t.days[0].sleep.nap_count, 0);
        assert_eq!((parse_hhmm("20:30"), hhmm(510)), (Some(1230), "08:30".to_string()));
        assert!(DayWindow::new(600, 600).is_none());
    }
}
