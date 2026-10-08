//! Daily statistics. Days are calendar days in the family's timezone;
//! "daytime" is 06:00-18:00 local (same split the Nara app uses).

use chrono::{Duration, NaiveDate, TimeZone};
use chrono_tz::Tz;
use serde::Serialize;

use crate::model::{Details, FeedMethod};

pub const DAY_START_HOUR: u32 = 6;
pub const NIGHT_START_HOUR: u32 = 18;

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
    pub bottle_count: u32,
    pub bottle_ml: f64,
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
    pub breast_seconds_per_day: f64,
    pub bottle_ml_per_day: f64,
    pub sleep_seconds_per_day: f64,
    pub day_sleep_seconds_per_day: f64,
    pub night_sleep_seconds_per_day: f64,
    pub naps_per_day: f64,
    pub diapers_per_day: f64,
    pub wet_per_day: f64,
    pub dirty_per_day: f64,
    pub pumped_ml_per_day: f64,
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
}

fn local_ms(tz: Tz, date: NaiveDate, hour: u32) -> i64 {
    let naive = date.and_hms_opt(hour, 0, 0).expect("valid hour");
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

pub fn compute(events: &[TrendEvent], tz: Tz, from: NaiveDate, days: u32, now: i64) -> Trends {
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
        let day0 = local_ms(tz, date, DAY_START_HOUR);
        let day1 = local_ms(tz, date, NIGHT_START_HOUR);
        let mut day = DayStats {
            date,
            complete: d1 <= now,
            feed: FeedStats::default(),
            sleep: SleepStats::default(),
            diaper: DiaperStats::default(),
            pump: PumpStats::default(),
        };
        for ev in events {
            let starts_today = ev.start >= d0 && ev.start < d1;
            let daytime = ev.start >= day0 && ev.start < day1;
            match &ev.details {
                Details::Feed(f) if starts_today => {
                    day.feed.count += 1;
                    let breast = f.left_seconds.unwrap_or(0) as i64 + f.right_seconds.unwrap_or(0) as i64;
                    if matches!(f.method, FeedMethod::Breast | FeedMethod::Combo) {
                        day.feed.breast_count += 1;
                        day.feed.breast_seconds += breast;
                        bf_total += breast;
                        bf_n += 1;
                    }
                    if matches!(f.method, FeedMethod::Bottle | FeedMethod::Combo) {
                        day.feed.bottle_count += 1;
                        let ml = f.amount_ml.unwrap_or(0.0);
                        day.feed.bottle_ml += ml;
                        if ml > 0.0 {
                            bottle_total += ml;
                            bottle_n += 1;
                        }
                    }
                    if f.method == FeedMethod::Solids {
                        day.feed.solids_count += 1;
                    }
                }
                Details::Sleep(_) => {
                    let end = ev.end.unwrap_or(ev.start).min(now.max(ev.start));
                    let total = overlap(ev.start, end, d0, d1);
                    let dayt = overlap(ev.start, end, day0, day1);
                    day.sleep.total_seconds += total / 1000;
                    day.sleep.day_seconds += dayt / 1000;
                    day.sleep.night_seconds += (total - dayt) / 1000;
                    if starts_today {
                        let dur = (end - ev.start) / 1000;
                        day.sleep.longest_seconds = day.sleep.longest_seconds.max(dur);
                        if daytime {
                            day.sleep.nap_count += 1;
                            nap_total += dur;
                            nap_n += 1;
                        }
                    }
                }
                Details::Diaper(d) if starts_today => {
                    day.diaper.count += 1;
                    if d.wet {
                        day.diaper.wet += 1;
                    }
                    if d.dirty {
                        day.diaper.dirty += 1;
                    }
                    if daytime {
                        day.diaper.day_count += 1;
                    } else {
                        day.diaper.night_count += 1;
                    }
                }
                Details::Pump(p) if starts_today => {
                    day.pump.count += 1;
                    day.pump.total_ml += p.left_ml.unwrap_or(0.0) + p.right_ml.unwrap_or(0.0);
                    day.pump.total_seconds += ev.end.map(|e| (e - ev.start) / 1000).unwrap_or(0);
                }
                _ => {}
            }
        }
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
        breast_seconds_per_day: avg(&|d| d.feed.breast_seconds as f64),
        bottle_ml_per_day: avg(&|d| d.feed.bottle_ml),
        sleep_seconds_per_day: avg(&|d| d.sleep.total_seconds as f64),
        day_sleep_seconds_per_day: avg(&|d| d.sleep.day_seconds as f64),
        night_sleep_seconds_per_day: avg(&|d| d.sleep.night_seconds as f64),
        naps_per_day: avg(&|d| d.sleep.nap_count as f64),
        diapers_per_day: avg(&|d| d.diaper.count as f64),
        wet_per_day: avg(&|d| d.diaper.wet as f64),
        dirty_per_day: avg(&|d| d.diaper.dirty as f64),
        pumped_ml_per_day: avg(&|d| d.pump.total_ml),
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
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::model::{Diaper, Feed, Sleep};

    fn ms(tz: Tz, s: &str) -> i64 {
        crate::util::parse_time(s, tz).unwrap()
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
        let t = compute(&events, tz, from, 2, now);
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
}
