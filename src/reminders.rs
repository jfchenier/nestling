//! Reminders sent to the family's phones (only on a server set up for notifications, see
//! `push.rs`): "no feed in 3 h" and "next dose of Tylenol is due". Checked every minute; each
//! reminder goes out once per entry it is about (`reminders_sent`), so logging a feed (or a dose)
//! arms it again.

use std::{sync::Arc, time::Duration};

use chrono_tz::Tz;
use serde_json::{json, Value};
use sqlx::SqlitePool;

use crate::{
    error::AppResult,
    push::{duration, Push},
    schedule::{medicine_key, medicine_status, parse_medicines, parse_reminders, Medicine, MedicineStatus},
    state::AppState,
    util::{now_ms, parse_tz},
};

const CHECK_EVERY: Duration = Duration::from_secs(60);
/// A reminder this late (nobody has logged anything for half a day) is not sent anymore.
const STALE_MS: i64 = 12 * 3600 * 1000;

/// Dose times (ms) of a medicine for a child, newest first: at least those of the last 24 hours.
/// Names are compared in Rust (`medicine_key`), since SQLite's lower() only folds ASCII.
pub async fn medicine_doses(db: &SqlitePool, child_id: &str, name: &str, now: i64) -> AppResult<Vec<i64>> {
    let rows: Vec<(i64, Option<String>)> = sqlx::query_as(
        "SELECT start_at, json_extract(data, '$.name') FROM events
         WHERE child_id = ? AND type = 'health' AND deleted_at IS NULL
           AND json_extract(data, '$.kind') = 'medicine' AND start_at <= ?
         ORDER BY start_at DESC",
    )
    .bind(child_id)
    .bind(now)
    .fetch_all(db)
    .await?;
    let key = medicine_key(name);
    Ok(rows
        .into_iter()
        .filter(|(_, n)| n.as_deref().is_some_and(|n| medicine_key(n) == key))
        .map(|(t, _)| t)
        .take(30)
        .collect())
}

pub async fn medicines_status(db: &SqlitePool, child_id: &str, medicines: &[Medicine], now: i64) -> AppResult<Vec<(Medicine, MedicineStatus)>> {
    let mut out = Vec::new();
    for m in medicines {
        let doses = medicine_doses(db, child_id, &m.name, now).await?;
        let st = medicine_status(m, &doses, now);
        out.push((m.clone(), st));
    }
    Ok(out)
}

/// Checks the reminders every minute (until the server stops).
pub fn spawn(state: AppState, push: Arc<Push>) {
    tokio::spawn(async move {
        let mut tick = tokio::time::interval(CHECK_EVERY);
        tick.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Delay);
        loop {
            tick.tick().await;
            if let Err(e) = check(&state, &push, now_ms()).await {
                tracing::warn!("reminders: {e}");
            }
        }
    });
}

/// A reminder that is due: what it is about (`key`, `ref_at`) and its message.
#[derive(Debug, PartialEq)]
pub struct Due {
    pub key: String,
    pub ref_at: i64,
    pub title: String,
    pub body: String,
}

/// The reminders due now for every child that has some (sent or not).
pub async fn due(db: &SqlitePool, now: i64) -> AppResult<Vec<(String, String, Due)>> {
    let children: Vec<(String, String, String, String, String, String)> = sqlx::query_as(
        "SELECT c.id, c.family_id, c.name, c.medicines, c.reminders, f.timezone FROM children c
         JOIN families f ON f.id = c.family_id
         WHERE c.reminders != '[]' OR c.medicines LIKE '%\"remind\":true%'",
    )
    .fetch_all(db)
    .await?;
    let mut out = Vec::new();
    for (child_id, family_id, name, medicines, reminders, tz) in children {
        let tz = parse_tz(&tz)?;
        let at = |ms: i64| hhmm(ms, tz);
        for r in parse_reminders(&reminders) {
            let timer = match r.kind.as_str() {
                "feed" => "breastfeed",
                other => other,
            };
            let running: Option<(i64,)> = sqlx::query_as("SELECT 1 FROM timers WHERE child_id = ? AND kind = ?")
                .bind(&child_id)
                .bind(timer)
                .fetch_optional(db)
                .await?;
            if running.is_some() {
                continue;
            }
            let last: Option<(i64, Option<i64>)> = sqlx::query_as(
                "SELECT start_at, end_at FROM events WHERE child_id = ? AND type = ? AND deleted_at IS NULL AND start_at <= ?
                 ORDER BY start_at DESC LIMIT 1",
            )
            .bind(&child_id)
            .bind(&r.kind)
            .bind(now)
            .fetch_optional(db)
            .await?;
            let Some((start, end)) = last else { continue };
            // Sleep: time awake, since the last sleep ended (like the home screen's card).
            let since = if r.kind == "sleep" { end.unwrap_or(start) } else { start };
            let after = i64::from(r.after_minutes) * 60_000;
            if now - since < after || now - since > after + STALE_MS {
                continue;
            }
            let ago = duration((now - since) / 1000);
            let (what, body) = match r.kind.as_str() {
                "feed" => ("Feed", format!("No feed in {ago} (last at {})", at(since))),
                "sleep" => ("Sleep", format!("Awake for {ago} (since {})", at(since))),
                "diaper" => ("Diaper", format!("No diaper change in {ago} (last at {})", at(since))),
                _ => ("Pump", format!("No pumping in {ago} (last at {})", at(since))),
            };
            out.push((
                child_id.clone(),
                family_id.clone(),
                Due { key: r.kind.clone(), ref_at: since, title: format!("{name} · {what} reminder"), body },
            ));
        }
        for m in parse_medicines(&medicines).into_iter().filter(|m| m.remind) {
            let doses = medicine_doses(db, &child_id, &m.name, now).await?;
            let st = medicine_status(&m, &doses, now);
            let (Some(last), Some(next)) = (st.last_at, st.next_at) else { continue };
            if next > now || now - next > STALE_MS {
                continue;
            }
            let body = match m.max_per_day {
                Some(max) => format!("Next dose can be given now (last at {}, {} of {max} in 24 h)", at(last), st.doses_24h),
                None => format!("Next dose can be given now (last at {})", at(last)),
            };
            out.push((
                child_id.clone(),
                family_id.clone(),
                Due { key: format!("medicine:{}", medicine_key(&m.name)), ref_at: next, title: format!("{name} · {}", m.name), body },
            ));
        }
    }
    Ok(out)
}

fn hhmm(ms: i64, tz: Tz) -> String {
    use chrono::TimeZone;
    tz.timestamp_millis_opt(ms).single().map(|t| t.format("%H:%M").to_string()).unwrap_or_default()
}

/// Sends the reminders that are due and not sent yet.
pub async fn check(state: &AppState, push: &Push, now: i64) -> AppResult<()> {
    for (child_id, family_id, d) in due(&state.db, now).await? {
        let sent: Option<(i64,)> = sqlx::query_as("SELECT ref_at FROM reminders_sent WHERE child_id = ? AND key = ?")
            .bind(&child_id)
            .bind(&d.key)
            .fetch_optional(&state.db)
            .await?;
        if sent.is_some_and(|(r,)| r == d.ref_at) {
            continue;
        }
        sqlx::query("INSERT INTO reminders_sent (child_id, key, ref_at) VALUES (?, ?, ?) ON CONFLICT (child_id, key) DO UPDATE SET ref_at = excluded.ref_at")
            .bind(&child_id)
            .bind(&d.key)
            .bind(d.ref_at)
            .execute(&state.db)
            .await?;
        let data = reminder_message(&child_id, &d);
        let collapse = format!("reminder-{child_id}-{}", d.key);
        if let Err(e) = push.send_family(state, &family_id, data, &collapse).await {
            tracing::warn!("reminders: {e}");
        }
    }
    Ok(())
}

/// The data message (`action: "remind"`, shown by the Android app as an ordinary notification).
/// `id` is the same for a child's reminder each time, so a newer one replaces the older.
pub fn reminder_message(child_id: &str, d: &Due) -> Value {
    let id = 100 + (fnv(&format!("{child_id}/{}", d.key)) % 1_000_000) as u32;
    json!({
        "action": "remind",
        "id": id.to_string(),
        "title": d.title,
        "body": d.body,
        "seq": now_ms().to_string(),
    })
}

/// Stable string hash (FNV-1a), for notification ids.
fn fnv(s: &str) -> u64 {
    s.bytes().fold(0xcbf29ce484222325, |h, b| (h ^ u64::from(b)).wrapping_mul(0x100000001b3))
}
