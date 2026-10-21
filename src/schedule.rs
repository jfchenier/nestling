//! Medicine schedules and reminders, both kept on the child (`children.medicines` /
//! `children.reminders`, JSON lists) so they travel with it everywhere a child does.
//!
//! - A medicine schedule says how often a medicine may be given (`every_hours`, and optionally
//!   `max_per_day` in any 24 hours). Its doses are the child's `health` / `medicine` entries with
//!   the same name (case and spaces ignored). The summary shows when the next dose is allowed.
//!   With `times` ("08:00", in the family's time zone) the doses are due at those times every day
//!   instead: a dose given from a little before a time until a little before the next one counts
//!   for it, so the reminder does not shift with the hour the dose was given.
//! - A routine ("bath") works the same way for `activity` entries of that kind: every few hours
//!   after the last one, or at set times.
//! - Set times can be limited to some days: every N days (counted from the day of the last
//!   entry) or some weekdays.
//! - A reminder ("no feed in 3 h") and a medicine's or routine's `remind` flag become phone
//!   notifications, only on a server set up for them (see `reminders.rs`).
//!
//! `app/lib/local/schedule.dart` is a port of this file: keep both in step.

use chrono::{Datelike, Duration, NaiveDate, NaiveTime, TimeZone, Timelike};
use chrono_tz::Tz;
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};

use crate::error::{bad, AppResult};

pub const REMINDER_TYPES: [&str; 4] = ["feed", "sleep", "diaper", "pump"];
const MAX_ITEMS: usize = 20;
pub const DAY_MS: i64 = 24 * 3600 * 1000;
const MAX_TIMES: usize = 12;
/// How early a dose may be given and still count for a set time (at most half the gap to the
/// time before).
const EARLY_MS: i64 = 2 * 3600 * 1000;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Medicine {
    pub name: String,
    /// Hours between doses (0.5 to 168).
    pub every_hours: f64,
    /// At most this many doses in any 24 hours.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub max_per_day: Option<u32>,
    /// The usual dose, to fill the form.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub dose: Option<f64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub dose_unit: Option<String>,
    /// Notify the family's phones when the next dose is due.
    #[serde(default)]
    pub remind: bool,
    /// Daily dose times ("HH:MM", family time zone, sorted). When set, doses are due at these
    /// times rather than `every_hours` after the last one (`max_per_day` is then not used).
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub times: Vec<String>,
    #[serde(flatten)]
    pub days: Days,
}

/// The days a set-times schedule is due on (none given: every day).
#[derive(Debug, Clone, Default, Serialize, Deserialize, PartialEq)]
pub struct Days {
    /// Every N days (2 to 30), counted from the day of the last entry.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub every_days: Option<u32>,
    /// On these weekdays only (1 = Monday … 7 = Sunday, sorted).
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub weekdays: Vec<u8>,
}

/// A routine activity ("bath") and how often it is done; its entries are the child's
/// `activity` entries of that kind (case, spaces and `_` ignored).
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Routine {
    /// The activity's kind, as its entries save it ("bath", "tummy_time" or any other name).
    pub name: String,
    /// Hours between two (0.5 to 720), when there are no `times`.
    pub every_hours: f64,
    /// Notify the family's phones when it is due.
    #[serde(default)]
    pub remind: bool,
    /// Set times ("HH:MM", family time zone, sorted), on the days `days` allows.
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub times: Vec<String>,
    #[serde(flatten)]
    pub days: Days,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Reminder {
    /// feed | sleep | diaper | pump. Sleep: time awake (since the last sleep ended).
    #[serde(rename = "type")]
    pub kind: String,
    /// Notify when there was none for this long.
    pub after_minutes: u32,
}

/// The name doses are matched on.
pub fn medicine_key(name: &str) -> String {
    name.split_whitespace().collect::<Vec<_>>().join(" ").to_lowercase()
}

/// The name a routine's entries are matched on ("Tummy time" and "tummy_time" are the same).
pub fn routine_key(name: &str) -> String {
    medicine_key(&name.replace('_', " "))
}

/// Cleans set times: "8:00" → "08:00", sorted, no repeats.
fn check_times(list: &[String]) -> AppResult<Vec<String>> {
    if list.len() > MAX_TIMES {
        return bad(format!("at most {MAX_TIMES} times a day"));
    }
    let mut times = Vec::new();
    for t in list {
        let Ok(t) = NaiveTime::parse_from_str(t.trim(), "%H:%M") else {
            return bad("times must be like \"08:00\"");
        };
        times.push(t.format("%H:%M").to_string());
    }
    times.sort();
    times.dedup();
    Ok(times)
}

/// Cleans the days of a schedule with `times`: every 1 day and all 7 weekdays are every day.
fn check_days(days: &mut Days, times: &[String]) -> AppResult<()> {
    if days.every_days == Some(1) {
        days.every_days = None;
    }
    if days.every_days.is_some_and(|n| !(2..=30).contains(&n)) {
        return bad("every_days must be between 1 and 30");
    }
    if days.weekdays.iter().any(|d| !(1..=7).contains(d)) {
        return bad("weekdays must be 1 (Monday) to 7 (Sunday)");
    }
    days.weekdays.sort();
    days.weekdays.dedup();
    if days.weekdays.len() == 7 {
        days.weekdays.clear();
    }
    if days.every_days.is_some() && !days.weekdays.is_empty() {
        return bad("give every_days or weekdays, not both");
    }
    if (days.every_days.is_some() || !days.weekdays.is_empty()) && times.is_empty() {
        return bad("every_days and weekdays need times");
    }
    Ok(())
}

pub fn check_medicines(list: &mut [Medicine]) -> AppResult<()> {
    if list.len() > MAX_ITEMS {
        return bad(format!("at most {MAX_ITEMS} medicines"));
    }
    let mut seen = Vec::new();
    for m in list.iter_mut() {
        m.name = m.name.split_whitespace().collect::<Vec<_>>().join(" ");
        if m.name.is_empty() || m.name.chars().count() > 80 {
            return bad("a medicine needs a name (up to 80 characters)");
        }
        let key = medicine_key(&m.name);
        if seen.contains(&key) {
            return bad(format!("{} is listed twice", m.name));
        }
        seen.push(key);
        if !m.every_hours.is_finite() || !(0.5..=168.0).contains(&m.every_hours) {
            return bad("every_hours must be between 0.5 and 168");
        }
        if m.max_per_day.is_some_and(|n| !(1..=24).contains(&n)) {
            return bad("max_per_day must be between 1 and 24");
        }
        if m.dose.is_some_and(|d| !(0.0..=10_000.0).contains(&d)) {
            return bad("dose must be a positive number");
        }
        m.dose_unit = m.dose_unit.as_ref().map(|u| u.trim().to_string()).filter(|u| !u.is_empty());
        m.times = check_times(&m.times)?;
        check_days(&mut m.days, &m.times)?;
    }
    Ok(())
}

pub fn check_routines(list: &mut [Routine]) -> AppResult<()> {
    if list.len() > MAX_ITEMS {
        return bad(format!("at most {MAX_ITEMS} routines"));
    }
    let mut seen = Vec::new();
    for r in list.iter_mut() {
        r.name = r.name.split_whitespace().collect::<Vec<_>>().join(" ");
        if r.name.is_empty() || r.name.chars().count() > 80 {
            return bad("a routine needs a name (up to 80 characters)");
        }
        let key = routine_key(&r.name);
        if seen.contains(&key) {
            return bad(format!("{} is listed twice", r.name));
        }
        seen.push(key);
        if !r.every_hours.is_finite() || !(0.5..=720.0).contains(&r.every_hours) {
            return bad("every_hours must be between 0.5 and 720");
        }
        r.times = check_times(&r.times)?;
        check_days(&mut r.days, &r.times)?;
    }
    Ok(())
}

pub fn check_reminders(list: &[Reminder]) -> AppResult<()> {
    for (i, r) in list.iter().enumerate() {
        if !REMINDER_TYPES.contains(&r.kind.as_str()) {
            return bad("a reminder's type must be feed, sleep, diaper or pump");
        }
        if list[..i].iter().any(|o| o.kind == r.kind) {
            return bad(format!("there is already a {} reminder", r.kind));
        }
        if !(15..=24 * 60).contains(&r.after_minutes) {
            return bad("after_minutes must be between 15 and 1440");
        }
    }
    Ok(())
}

/// Where a medicine stands: `doses` are its dose times (ms), newest first, at least those of the
/// last 24 hours.
#[derive(Debug, Clone, PartialEq)]
pub struct MedicineStatus {
    pub last_at: Option<i64>,
    /// When the next dose is allowed (none given yet: now).
    pub next_at: Option<i64>,
    pub doses_24h: u32,
    /// The 24-hour limit is what holds the next dose back.
    pub limited: bool,
    /// A dose can be given now (set times: the current time's dose is not given yet, even if
    /// `next_at` is a little later).
    pub due: bool,
}

/// Minutes after midnight of "HH:MM" times.
fn minutes(times: &[String]) -> Vec<i64> {
    let mut out: Vec<i64> = times
        .iter()
        .filter_map(|t| NaiveTime::parse_from_str(t, "%H:%M").ok())
        .map(|t| i64::from(t.hour() * 60 + t.minute()))
        .collect();
    out.sort();
    out.dedup();
    out
}

/// How early a dose counts for a set time: 2 h, or half the shortest gap between the times.
pub fn early_ms(mins: &[i64]) -> i64 {
    let gaps = mins.windows(2).map(|w| w[1] - w[0]).chain(mins.first().zip(mins.last()).map(|(f, l)| f + 1440 - l));
    gaps.map(|g| g * 30_000).fold(EARLY_MS, i64::min)
}

/// The set times (ms) from a week before `now` to a month after, in time zone `tz`, on the days
/// `days` allows (every N days: from N days after the day of `last` on).
fn slots(mins: &[i64], days: &Days, last: Option<i64>, now: i64, tz: Tz) -> Vec<i64> {
    let date = |ms: i64| tz.timestamp_millis_opt(ms).single().map(|t| t.date_naive());
    let today: NaiveDate = date(now).unwrap_or_default();
    let first = days.every_days.zip(last.and_then(date)).map(|(n, d)| d + Duration::days(i64::from(n)));
    let mut out = Vec::new();
    for d in -8..=32 {
        let day = today + Duration::days(d);
        if first.is_some_and(|f| day < f) {
            continue;
        }
        if !days.weekdays.is_empty() && !days.weekdays.contains(&(day.weekday().number_from_monday() as u8)) {
            continue;
        }
        for &m in mins {
            let local = day.and_time(NaiveTime::MIN) + Duration::minutes(m);
            // A time skipped by a clock change happens an hour later that day.
            let at = tz.from_local_datetime(&local).earliest().or_else(|| tz.from_local_datetime(&(local + Duration::hours(1))).earliest());
            if let Some(at) = at {
                out.push(at.timestamp_millis());
            }
        }
    }
    out.sort();
    out
}

/// Status of a medicine given at set times: the current time is the last one whose early window
/// has opened; its dose is given if one was logged since then.
fn fixed_status(mins: &[i64], days: &Days, doses: &[i64], now: i64, tz: Tz) -> MedicineStatus {
    let early = early_ms(mins);
    let last_at = doses.first().copied();
    let slots = slots(mins, days, last_at, now, tz);
    let recent = doses.iter().filter(|&&t| t > now - DAY_MS && t <= now).count() as u32;
    let Some(i) = slots.iter().rposition(|&s| s - early <= now) else {
        return MedicineStatus { last_at, next_at: slots.first().copied(), doses_24h: recent, limited: false, due: false };
    };
    let current = slots[i];
    if doses.iter().any(|&t| t >= current - early && t <= now) {
        let next = slots.get(i + 1).copied();
        MedicineStatus { last_at, next_at: next, doses_24h: recent, limited: false, due: false }
    } else {
        MedicineStatus { last_at, next_at: Some(current), doses_24h: recent, limited: false, due: true }
    }
}

pub fn medicine_status(m: &Medicine, doses: &[i64], now: i64, tz: Tz) -> MedicineStatus {
    schedule_status(m.every_hours, m.max_per_day, &m.times, &m.days, doses, now, tz)
}

/// Where a routine stands (`done` are its entries' times, newest first), like a medicine.
pub fn routine_status(r: &Routine, done: &[i64], now: i64, tz: Tz) -> MedicineStatus {
    schedule_status(r.every_hours, None, &r.times, &r.days, done, now, tz)
}

fn schedule_status(every_hours: f64, max_per_day: Option<u32>, times: &[String], days: &Days, doses: &[i64], now: i64, tz: Tz) -> MedicineStatus {
    if !times.is_empty() {
        return fixed_status(&minutes(times), days, doses, now, tz);
    }
    let Some(&last) = doses.first() else {
        return MedicineStatus { last_at: None, next_at: None, doses_24h: 0, limited: false, due: true };
    };
    let recent: Vec<i64> = doses.iter().copied().filter(|&t| t > now - DAY_MS && t <= now).collect();
    let mut next = last + (every_hours * 3_600_000.0).round() as i64;
    let mut limited = false;
    if let Some(max) = max_per_day {
        // Doses newest first: the max-th newest leaves the window 24 h after it was given.
        if let Some(&oldest) = recent.get(max as usize - 1) {
            if oldest + DAY_MS > next {
                next = oldest + DAY_MS;
                limited = true;
            }
        }
    }
    MedicineStatus { last_at: Some(last), next_at: Some(next), doses_24h: recent.len() as u32, limited, due: next <= now }
}

/// A medicine and its status, as the summary shows it (`fmt` formats times).
pub fn medicine_json(m: &Medicine, st: &MedicineStatus, fmt: impl Fn(i64) -> String) -> Value {
    let mut v = serde_json::to_value(m).unwrap_or_default();
    v["last_at"] = json!(st.last_at.map(&fmt));
    v["next_at"] = json!(st.next_at.map(&fmt));
    v["due"] = json!(st.due);
    v["doses_24h"] = json!(st.doses_24h);
    v["limited"] = json!(st.limited);
    v
}

/// A routine and its status, as the summary shows it.
pub fn routine_json(r: &Routine, st: &MedicineStatus, fmt: impl Fn(i64) -> String) -> Value {
    let mut v = serde_json::to_value(r).unwrap_or_default();
    v["last_at"] = json!(st.last_at.map(&fmt));
    v["next_at"] = json!(st.next_at.map(&fmt));
    v["due"] = json!(st.due);
    v
}

pub fn parse_routines(s: &str) -> Vec<Routine> {
    serde_json::from_str(s).unwrap_or_default()
}

pub fn parse_medicines(s: &str) -> Vec<Medicine> {
    serde_json::from_str(s).unwrap_or_default()
}

pub fn parse_reminders(s: &str) -> Vec<Reminder> {
    serde_json::from_str(s).unwrap_or_default()
}

#[cfg(test)]
mod tests {
    use super::*;

    const H: i64 = 3_600_000;
    const UTC: Tz = chrono_tz::UTC;

    fn med(every: f64, max: Option<u32>) -> Medicine {
        Medicine { name: "Tylenol".into(), every_hours: every, max_per_day: max, dose: None, dose_unit: None, remind: false, times: vec![], days: Days::default() }
    }

    fn daily(times: &[&str]) -> Medicine {
        Medicine { times: times.iter().map(|t| t.to_string()).collect(), ..med(24.0, None) }
    }

    #[test]
    fn next_dose() {
        let now = 100 * H;
        assert_eq!(medicine_status(&med(4.0, None), &[], now, UTC).next_at, None);
        let st = medicine_status(&med(4.0, None), &[now - H, now - 6 * H], now, UTC);
        assert_eq!((st.last_at, st.next_at, st.doses_24h, st.limited), (Some(now - H), Some(now + 3 * H), 2, false));
        // 4 doses in 24 h, every 4 h: the 4th newest (20 h ago) must leave the window first.
        let doses = [now - H, now - 6 * H, now - 12 * H, now - 20 * H, now - 30 * H];
        let st = medicine_status(&med(4.0, Some(4)), &doses, now, UTC);
        assert_eq!((st.next_at, st.doses_24h, st.limited), (Some(now + 4 * H), 4, true));
        let st = medicine_status(&med(4.0, Some(5)), &doses, now, UTC);
        assert_eq!((st.next_at, st.limited), (Some(now + 3 * H), false));
    }

    #[test]
    fn set_times() {
        // Day 100 (UTC), daily at 08:00.
        let day = 100 * DAY_MS;
        let at8 = day + 8 * H;
        let m = daily(&["08:00"]);
        // Nothing given: due from 08:00 (shown as "next at 08:00" from 06:00).
        let st = medicine_status(&m, &[], at8 + H, UTC);
        assert_eq!((st.next_at, st.due), (Some(at8), true));
        let st = medicine_status(&m, &[], at8 - H, UTC);
        assert_eq!((st.next_at, st.due), (Some(at8), true));
        let st = medicine_status(&m, &[], at8 - 3 * H, UTC);
        assert_eq!((st.next_at, st.due), (Some(at8 - DAY_MS), true));
        // Given at 07:00 or at 21:00: counts for today's 08:00; next is tomorrow's.
        for given in [at8 - H, at8 + 13 * H] {
            let st = medicine_status(&m, &[given], given + 1, UTC);
            assert_eq!((st.next_at, st.due, st.last_at), (Some(at8 + DAY_MS), false, Some(given)));
        }
        // Yesterday's dose doesn't count for today.
        let st = medicine_status(&m, &[at8 - DAY_MS + 3 * H], at8 + 1, UTC);
        assert_eq!((st.next_at, st.due), (Some(at8), true));
        // Twice a day: the window before a time is at most half the gap.
        let m = daily(&["20:00", "08:00", "09:00"]);
        assert_eq!(early_ms(&minutes(&m.times)), 30 * 60_000);
        let st = medicine_status(&m, &[at8 + 10 * 60_000], at8 + 31 * 60_000, UTC);
        assert_eq!((st.next_at, st.due), (Some(at8 + H), true));
        // A time zone: 08:00 in Toronto (UTC-4 in summer) is 12:00 UTC.
        let toronto: Tz = "America/Toronto".parse().unwrap();
        let summer = chrono::Utc.with_ymd_and_hms(2026, 7, 1, 13, 0, 0).unwrap().timestamp_millis();
        let st = medicine_status(&daily(&["08:00"]), &[], summer, toronto);
        assert_eq!(st.next_at, Some(summer - H));
    }

    fn routine(times: &[&str], days: Days) -> Routine {
        Routine { name: "bath".into(), every_hours: 48.0, remind: true, times: times.iter().map(|t| t.to_string()).collect(), days }
    }

    #[test]
    fn every_n_days() {
        // Day 100 (UTC) is a Saturday; a bath every 2 days at 19:00.
        let day = 100 * DAY_MS;
        let at19 = day + 19 * H;
        let r = routine(&["19:00"], Days { every_days: Some(2), weekdays: vec![] });
        // Never done: due every day.
        let st = routine_status(&r, &[], at19 + H, UTC);
        assert_eq!((st.next_at, st.due), (Some(at19), true));
        // Done today (even this morning): next is in 2 days.
        for done in [day + 8 * H, at19 - H, at19 + 2 * H] {
            let st = routine_status(&r, &[done], at19 + 3 * H, UTC);
            assert_eq!((st.next_at, st.due), (Some(at19 + 2 * DAY_MS), false), "{done}");
        }
        // Done yesterday: tomorrow; done 2 days ago: due tonight, and still due after if missed.
        let st = routine_status(&r, &[at19 - DAY_MS], at19 + H, UTC);
        assert_eq!((st.next_at, st.due), (Some(at19 + DAY_MS), false));
        let st = routine_status(&r, &[at19 - 2 * DAY_MS], at19 + H, UTC);
        assert_eq!((st.next_at, st.due), (Some(at19), true));
        let st = routine_status(&r, &[at19 - 3 * DAY_MS], at19 - 6 * H, UTC);
        assert_eq!((st.next_at, st.due), (Some(at19 - DAY_MS), true));
        // Every 2 days as an interval instead: 48 h after the last one.
        let r = Routine { times: vec![], days: Days::default(), ..r };
        let st = routine_status(&r, &[day + 8 * H], at19, UTC);
        assert_eq!((st.next_at, st.due), (Some(day + 8 * H + 2 * DAY_MS), false));
    }

    #[test]
    fn weekdays() {
        // Day 100 is a Saturday: Monday is day 102, Friday day 106.
        let day = 100 * DAY_MS;
        let mon = 102 * DAY_MS + 19 * H;
        let fri = 106 * DAY_MS + 19 * H;
        let r = routine(&["19:00"], Days { every_days: None, weekdays: vec![1, 5] });
        // Saturday, last done Friday: next Monday.
        let st = routine_status(&r, &[day - DAY_MS + 19 * H], day + 12 * H, UTC);
        assert_eq!((st.next_at, st.due), (Some(mon), false));
        // Monday evening, not done: due; done: next Friday.
        let st = routine_status(&r, &[day - DAY_MS + 19 * H], mon + H, UTC);
        assert_eq!((st.next_at, st.due), (Some(mon), true));
        let st = routine_status(&r, &[mon + 10 * 60_000], mon + H, UTC);
        assert_eq!((st.next_at, st.due), (Some(fri), false));
        // A bath on another day doesn't count for Monday's.
        let st = routine_status(&r, &[day + 19 * H], mon + H, UTC);
        assert_eq!((st.next_at, st.due), (Some(mon), true));
    }

    #[test]
    fn validation() {
        let mut list = vec![med(4.0, Some(4)), Medicine { name: "  tylenol ".into(), ..med(6.0, None) }];
        assert!(check_medicines(&mut list).is_err());
        let mut list = vec![Medicine { name: " Vitamin   D ".into(), dose_unit: Some(" ".into()), ..med(24.0, None) }];
        check_medicines(&mut list).unwrap();
        assert_eq!((list[0].name.as_str(), list[0].dose_unit.clone()), ("Vitamin D", None));
        assert!(check_medicines(&mut [med(0.1, None)]).is_err());
        let mut list = vec![daily(&[" 20:00", "8:00", "08:00"])];
        check_medicines(&mut list).unwrap();
        assert_eq!(list[0].times, ["08:00", "20:00"]);
        assert!(check_medicines(&mut [daily(&["24:00"])]).is_err());
        let mut list = vec![Medicine { days: Days { every_days: Some(1), weekdays: vec![5, 1, 1] }, ..daily(&["08:00"]) }];
        check_medicines(&mut list).unwrap();
        assert_eq!(list[0].days, Days { every_days: None, weekdays: vec![1, 5] });
        assert!(check_medicines(&mut [Medicine { days: Days { every_days: Some(2), weekdays: vec![] }, ..med(24.0, None) }]).is_err());
        assert!(check_routines(&mut [routine(&["19:00"], Days { every_days: Some(2), weekdays: vec![1] })]).is_err());
        assert!(check_routines(&mut [routine(&["19:00"], Days { every_days: None, weekdays: vec![8] })]).is_err());
        assert!(check_routines(&mut [routine(&[], Days::default()), Routine { name: "Bath ".into(), ..routine(&[], Days::default()) }]).is_err());
        let mut list = vec![routine(&["19:00"], Days { every_days: None, weekdays: (1..=7).collect() })];
        check_routines(&mut list).unwrap();
        assert!(list[0].days.weekdays.is_empty());
        assert_eq!(routine_key("Tummy  time"), routine_key("tummy_time"));
        assert!(check_reminders(&[Reminder { kind: "feed".into(), after_minutes: 180 }]).is_ok());
        assert!(check_reminders(&[Reminder { kind: "bath".into(), after_minutes: 180 }]).is_err());
        assert!(check_reminders(&[Reminder { kind: "feed".into(), after_minutes: 5 }]).is_err());
    }
}
