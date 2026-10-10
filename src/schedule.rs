//! Medicine schedules and reminders, both kept on the child (`children.medicines` /
//! `children.reminders`, JSON lists) so they travel with it everywhere a child does.
//!
//! - A medicine schedule says how often a medicine may be given (`every_hours`, and optionally
//!   `max_per_day` in any 24 hours). Its doses are the child's `health` / `medicine` entries with
//!   the same name (case and spaces ignored). The summary shows when the next dose is allowed.
//! - A reminder ("no feed in 3 h") and a medicine's `remind` flag become phone notifications,
//!   only on a server set up for them (see `reminders.rs`).
//!
//! `app/lib/local/schedule.dart` is a port of this file: keep both in step.

use serde::{Deserialize, Serialize};
use serde_json::{json, Value};

use crate::error::{bad, AppResult};

pub const REMINDER_TYPES: [&str; 4] = ["feed", "sleep", "diaper", "pump"];
const MAX_ITEMS: usize = 20;
pub const DAY_MS: i64 = 24 * 3600 * 1000;

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
}

pub fn medicine_status(m: &Medicine, doses: &[i64], now: i64) -> MedicineStatus {
    let Some(&last) = doses.first() else {
        return MedicineStatus { last_at: None, next_at: None, doses_24h: 0, limited: false };
    };
    let recent: Vec<i64> = doses.iter().copied().filter(|&t| t > now - DAY_MS && t <= now).collect();
    let mut next = last + (m.every_hours * 3_600_000.0).round() as i64;
    let mut limited = false;
    if let Some(max) = m.max_per_day {
        // Doses newest first: the max-th newest leaves the window 24 h after it was given.
        if let Some(&oldest) = recent.get(max as usize - 1) {
            if oldest + DAY_MS > next {
                next = oldest + DAY_MS;
                limited = true;
            }
        }
    }
    MedicineStatus { last_at: Some(last), next_at: Some(next), doses_24h: recent.len() as u32, limited }
}

/// A medicine and its status, as the summary shows it (`fmt` formats times).
pub fn medicine_json(m: &Medicine, st: &MedicineStatus, now: i64, fmt: impl Fn(i64) -> String) -> Value {
    let mut v = serde_json::to_value(m).unwrap_or_default();
    v["last_at"] = json!(st.last_at.map(&fmt));
    v["next_at"] = json!(st.next_at.map(&fmt));
    v["due"] = json!(st.next_at.is_none_or(|n| n <= now));
    v["doses_24h"] = json!(st.doses_24h);
    v["limited"] = json!(st.limited);
    v
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

    fn med(every: f64, max: Option<u32>) -> Medicine {
        Medicine { name: "Tylenol".into(), every_hours: every, max_per_day: max, dose: None, dose_unit: None, remind: false }
    }

    #[test]
    fn next_dose() {
        let now = 100 * H;
        assert_eq!(medicine_status(&med(4.0, None), &[], now).next_at, None);
        let st = medicine_status(&med(4.0, None), &[now - H, now - 6 * H], now);
        assert_eq!((st.last_at, st.next_at, st.doses_24h, st.limited), (Some(now - H), Some(now + 3 * H), 2, false));
        // 4 doses in 24 h, every 4 h: the 4th newest (20 h ago) must leave the window first.
        let doses = [now - H, now - 6 * H, now - 12 * H, now - 20 * H, now - 30 * H];
        let st = medicine_status(&med(4.0, Some(4)), &doses, now);
        assert_eq!((st.next_at, st.doses_24h, st.limited), (Some(now + 4 * H), 4, true));
        let st = medicine_status(&med(4.0, Some(5)), &doses, now);
        assert_eq!((st.next_at, st.limited), (Some(now + 3 * H), false));
    }

    #[test]
    fn validation() {
        let mut list = vec![med(4.0, Some(4)), Medicine { name: "  tylenol ".into(), ..med(6.0, None) }];
        assert!(check_medicines(&mut list).is_err());
        let mut list = vec![Medicine { name: " Vitamin   D ".into(), dose_unit: Some(" ".into()), ..med(24.0, None) }];
        check_medicines(&mut list).unwrap();
        assert_eq!((list[0].name.as_str(), list[0].dose_unit.clone()), ("Vitamin D", None));
        assert!(check_medicines(&mut [med(0.1, None)]).is_err());
        assert!(check_reminders(&[Reminder { kind: "feed".into(), after_minutes: 180 }]).is_ok());
        assert!(check_reminders(&[Reminder { kind: "bath".into(), after_minutes: 180 }]).is_err());
        assert!(check_reminders(&[Reminder { kind: "feed".into(), after_minutes: 5 }]).is_err());
    }
}
