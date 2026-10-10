//! Offline writes. A device that logged things while it couldn't reach the server pushes the
//! events and timers it changed, each with the time it was changed on the device. Conflicts are
//! settled one record at a time:
//! - the most recent edit wins (by the device's edit time; a time in the future counts as now),
//! - a deletion is final (an offline edit doesn't bring a deleted entry back),
//! - two timers of the same kind started apart for one child: the one that started first stays.
//!
//! Records carry their own ids (UUIDs made on the device), so pushing the same batch twice
//! changes nothing the second time.

use axum::{
    extract::{Path, State},
    Json,
};
use chrono_tz::Tz;
use serde::Deserialize;
use serde_json::{json, Map, Value};
use sqlx::{Sqlite, Transaction};

use crate::{
    auth::{require_member, AuthUser},
    error::{bad, ApiJson, AppError, AppResult},
    model::Side,
    routes::{
        events::{clean_note, EventInput},
        timers::{check_side, Segment, TimerKind},
    },
    state::AppState,
    util::{now_ms, parse_opt_time, parse_time},
};

#[derive(Deserialize)]
pub struct PushReq {
    #[serde(default)]
    events: Vec<Map<String, Value>>,
    #[serde(default)]
    timers: Vec<TimerPush>,
}

#[derive(Deserialize)]
struct SegmentIn {
    #[serde(default)]
    side: Option<Side>,
    start: String,
    #[serde(default)]
    end: Option<String>,
}

#[derive(Deserialize)]
struct TimerPush {
    id: String,
    child_id: String,
    kind: String,
    #[serde(default)]
    segments: Vec<SegmentIn>,
    changed_at: String,
    #[serde(default)]
    deleted: bool,
}

/// Outcome of one pushed record.
enum Outcome {
    Applied,
    /// The server's copy is newer (or deleted) and was kept.
    Conflict(String),
    Rejected(String),
}

fn result(id: &str, outcome: Outcome) -> Value {
    match outcome {
        Outcome::Applied => json!({ "id": id, "status": "applied" }),
        Outcome::Conflict(m) => json!({ "id": id, "status": "conflict", "message": m }),
        Outcome::Rejected(m) => json!({ "id": id, "status": "rejected", "message": m }),
    }
}

fn valid_id(id: &str) -> bool {
    uuid::Uuid::parse_str(id).is_ok()
}

/// The device's edit time, never later than now.
fn changed_time(s: &str, tz: Tz, now: i64) -> AppResult<i64> {
    Ok(parse_time(s, tz)?.min(now))
}

async fn child_in_family(tx: &mut Transaction<'_, Sqlite>, child_id: &str, family_id: &str) -> AppResult<bool> {
    let row: Option<(i64,)> = sqlx::query_as("SELECT 1 FROM children WHERE id = ? AND family_id = ?")
        .bind(child_id)
        .bind(family_id)
        .fetch_optional(&mut **tx)
        .await?;
    Ok(row.is_some())
}

/// `POST /families/{id}/sync`: apply changes made offline. Returns one result per record:
/// `applied`, `conflict` (the server kept its newer copy) or `rejected` (invalid; with a message).
pub async fn push(State(state): State<AppState>, user: AuthUser, Path(family_id): Path<String>, ApiJson(req): ApiJson<PushReq>) -> AppResult<Json<Value>> {
    require_member(&state.db, &family_id, &user.id).await?;
    if req.events.len() + req.timers.len() > 5000 {
        return bad("too many changes in one push (at most 5000)");
    }
    let tz = crate::auth::family_tz(&state.db, &family_id).await?;
    let now = now_ms();
    let mut tx = state.db.begin().await?;
    let mut events = Vec::with_capacity(req.events.len());
    for record in req.events {
        let id = record.get("id").and_then(Value::as_str).unwrap_or_default().to_string();
        let outcome = match push_event(&mut tx, &family_id, &user.id, record, tz, now).await {
            Ok(o) => o,
            Err(AppError::BadRequest(m)) => Outcome::Rejected(m),
            Err(e) => return Err(e),
        };
        events.push(result(&id, outcome));
    }
    let mut timers = Vec::with_capacity(req.timers.len());
    for t in req.timers {
        let id = t.id.clone();
        let outcome = match push_timer(&mut tx, &family_id, &user.id, t, tz, now).await {
            Ok(o) => o,
            Err(AppError::BadRequest(m)) => Outcome::Rejected(m),
            Err(e) => return Err(e),
        };
        timers.push(result(&id, outcome));
    }
    tx.commit().await?;
    // Records that weren't applied come back with the server's copy (null: none), so the
    // device can replace its own.
    for r in events.iter_mut().filter(|r| r["status"] != "applied") {
        let id = r["id"].as_str().unwrap_or_default().to_string();
        r["current"] = match crate::routes::events::get_row(&state.db, &id).await {
            Ok(row) if row.family_id == family_id => row.to_json(tz)?,
            _ => Value::Null,
        };
    }
    for r in timers.iter_mut().filter(|r| r["status"] != "applied") {
        let id = r["id"].as_str().unwrap_or_default().to_string();
        r["current"] = match crate::routes::timers::load(&state, &id).await {
            Ok(row) if row.family_id == family_id => row.to_json(tz)?,
            _ => Value::Null,
        };
    }
    let applied = |v: &Vec<Value>| v.iter().filter(|r| r["status"] == "applied").count();
    let (e, t) = (applied(&events), applied(&timers));
    if e + t > 0 {
        state.publish(&family_id, "sync", "applied", json!({ "events": e, "timers": t }));
    }
    Ok(Json(json!({ "events": events, "timers": timers })))
}

async fn push_event(tx: &mut Transaction<'_, Sqlite>, family_id: &str, user_id: &str, mut record: Map<String, Value>, tz: Tz, now: i64) -> AppResult<Outcome> {
    let take_str = |r: &mut Map<String, Value>, k: &str| match r.remove(k) {
        Some(Value::String(s)) => Some(s),
        _ => None,
    };
    let id = take_str(&mut record, "id").unwrap_or_default();
    if !valid_id(&id) {
        return bad("id must be a UUID");
    }
    let child_id = take_str(&mut record, "child_id").unwrap_or_default();
    let Some(changed) = take_str(&mut record, "changed_at") else { return bad("changed_at is required") };
    let changed = changed_time(&changed, tz, now)?;
    let deleted = record.remove("deleted").and_then(|v| v.as_bool()).unwrap_or(false);
    // Read-only fields a client may echo back from an earlier response.
    for key in ["created_by", "updated_by", "created_at", "updated_at", "duration_seconds", "source"] {
        record.remove(key);
    }

    let existing: Option<(String, Option<i64>, i64)> =
        sqlx::query_as("SELECT family_id, deleted_at, COALESCE(changed_at, updated_at) FROM events WHERE id = ?")
            .bind(&id)
            .fetch_optional(&mut **tx)
            .await?;
    if let Some((fid, deleted_at, server_changed)) = &existing {
        if fid != family_id {
            return bad("this entry belongs to another family");
        }
        if deleted_at.is_some() {
            return Ok(Outcome::Conflict("deleted on another device".into()));
        }
        if *server_changed > changed {
            return Ok(Outcome::Conflict("changed more recently on another device".into()));
        }
        if deleted {
            sqlx::query("UPDATE events SET deleted_at = ?, updated_at = ?, updated_by = ?, changed_at = ? WHERE id = ?")
                .bind(now)
                .bind(now)
                .bind(user_id)
                .bind(changed)
                .bind(&id)
                .execute(&mut **tx)
                .await?;
            sqlx::query("DELETE FROM event_photos WHERE event_id = ?").bind(&id).execute(&mut **tx).await?;
            return Ok(Outcome::Applied);
        }
    } else if deleted {
        // Created and deleted offline, or already gone: nothing to do.
        return Ok(Outcome::Applied);
    }

    let input: EventInput = serde_json::from_value(Value::Object(record)).map_err(|e| AppError::BadRequest(e.to_string()))?;
    let Some(start) = parse_opt_time(&input.start, tz)? else { return bad("start is required") };
    let end = parse_opt_time(&input.end, tz)?;
    input.details.validate(start, end, &input.note)?;
    let data = serde_json::to_string(&input.details)?;
    if existing.is_some() {
        sqlx::query("UPDATE events SET type = ?, start_at = ?, end_at = ?, data = ?, note = ?, updated_by = ?, updated_at = ?, changed_at = ? WHERE id = ?")
            .bind(input.details.type_name())
            .bind(start)
            .bind(end)
            .bind(data)
            .bind(clean_note(input.note))
            .bind(user_id)
            .bind(now)
            .bind(changed)
            .bind(&id)
            .execute(&mut **tx)
            .await?;
    } else {
        if !child_in_family(tx, &child_id, family_id).await? {
            return bad("unknown child");
        }
        sqlx::query(
            "INSERT INTO events (id, family_id, child_id, type, start_at, end_at, data, note, created_by, updated_by, created_at, updated_at, changed_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        )
        .bind(&id)
        .bind(family_id)
        .bind(&child_id)
        .bind(input.details.type_name())
        .bind(start)
        .bind(end)
        .bind(data)
        .bind(clean_note(input.note))
        .bind(user_id)
        .bind(user_id)
        .bind(now)
        .bind(now)
        .bind(changed)
        .execute(&mut **tx)
        .await?;
    }
    Ok(Outcome::Applied)
}

async fn push_timer(tx: &mut Transaction<'_, Sqlite>, family_id: &str, user_id: &str, t: TimerPush, tz: Tz, now: i64) -> AppResult<Outcome> {
    if !valid_id(&t.id) {
        return bad("id must be a UUID");
    }
    let changed = changed_time(&t.changed_at, tz, now)?;
    let existing: Option<(String, i64)> = sqlx::query_as("SELECT family_id, updated_at FROM timers WHERE id = ?")
        .bind(&t.id)
        .fetch_optional(&mut **tx)
        .await?;
    if let Some((fid, server_changed)) = &existing {
        if fid != family_id {
            return bad("this timer belongs to another family");
        }
        if *server_changed > changed {
            return Ok(Outcome::Conflict("changed more recently on another device".into()));
        }
        if t.deleted {
            sqlx::query("DELETE FROM timers WHERE id = ?").bind(&t.id).execute(&mut **tx).await?;
            return Ok(Outcome::Applied);
        }
    } else if t.deleted {
        // Stopped or thrown away offline, or already stopped elsewhere.
        return Ok(Outcome::Applied);
    }

    let kind = TimerKind::parse(&t.kind).map_err(|_| AppError::BadRequest(format!("unknown timer kind '{}'", t.kind)))?;
    if t.segments.is_empty() {
        return bad("a timer needs at least one segment");
    }
    let mut segs = Vec::with_capacity(t.segments.len());
    for s in &t.segments {
        let start = parse_time(&s.start, tz)?;
        let end = parse_opt_time(&s.end, tz)?;
        if end.is_some_and(|e| e < start) {
            return bad("a timer segment ends before it starts");
        }
        let side = match kind {
            TimerKind::Sleep => None,
            // Pump segments may be both-sided; a breastfeed segment is one side.
            _ => check_side(kind, s.side)?,
        };
        segs.push(Segment { side, start, end });
    }
    if segs.iter().any(|s| s.start > now + 60_000) {
        return bad("a timer cannot start in the future");
    }
    let json = serde_json::to_string(&segs)?;

    if existing.is_some() {
        sqlx::query("UPDATE timers SET segments = ?, updated_at = ? WHERE id = ?")
            .bind(&json)
            .bind(changed)
            .bind(&t.id)
            .execute(&mut **tx)
            .await?;
        return Ok(Outcome::Applied);
    }
    if !child_in_family(tx, &t.child_id, family_id).await? {
        return bad("unknown child");
    }
    // One timer per kind and child: if another device started one meanwhile, the earlier start wins.
    let other: Option<(String, String)> = sqlx::query_as("SELECT id, segments FROM timers WHERE child_id = ? AND kind = ?")
        .bind(&t.child_id)
        .bind(kind.as_str())
        .fetch_optional(&mut **tx)
        .await?;
    if let Some((other_id, other_segs)) = other {
        let other_segs: Vec<Segment> = serde_json::from_str(&other_segs)?;
        let first = |v: &[Segment]| v.iter().map(|s| s.start).min().unwrap_or(i64::MAX);
        if first(&segs) >= first(&other_segs) {
            return Ok(Outcome::Conflict("another device started this timer first".into()));
        }
        sqlx::query("UPDATE timers SET segments = ?, updated_at = ? WHERE id = ?")
            .bind(&json)
            .bind(changed)
            .bind(&other_id)
            .execute(&mut **tx)
            .await?;
        return Ok(Outcome::Applied);
    }
    sqlx::query("INSERT INTO timers (id, family_id, child_id, kind, segments, created_by, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)")
        .bind(&t.id)
        .bind(family_id)
        .bind(&t.child_id)
        .bind(kind.as_str())
        .bind(&json)
        .bind(user_id)
        .bind(now)
        .bind(changed)
        .execute(&mut **tx)
        .await?;
    Ok(Outcome::Applied)
}
