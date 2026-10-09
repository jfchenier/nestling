//! Live timers shared by every caregiver's device. A timer is a list of segments;
//! switching sides or pausing closes the current segment. Stopping a timer turns
//! it into a regular event.

use axum::{
    extract::{Path, State},
    http::StatusCode,
    Json,
};
use chrono_tz::Tz;
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};

use crate::{
    auth::{child_access, AuthUser},
    error::{bad, ApiJson, AppError, AppResult},
    model::{Details, Feed, FeedMethod, Pump, Side, Sleep},
    routes::events::{get_row, insert_event_in, NewEvent},
    state::AppState,
    util::{fmt_time, new_id, now_ms, parse_opt_time},
};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TimerKind {
    Breastfeed,
    Pump,
    Sleep,
}

impl TimerKind {
    pub fn as_str(self) -> &'static str {
        match self {
            TimerKind::Breastfeed => "breastfeed",
            TimerKind::Pump => "pump",
            TimerKind::Sleep => "sleep",
        }
    }
    pub fn parse(s: &str) -> AppResult<Self> {
        serde_json::from_value(json!(s)).map_err(|_| AppError::Other(anyhow::anyhow!("bad timer kind {s}")))
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Segment {
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub side: Option<Side>,
    pub start: i64,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub end: Option<i64>,
}

#[derive(Debug, Clone, sqlx::FromRow)]
pub struct TimerRow {
    pub id: String,
    pub family_id: String,
    pub child_id: String,
    pub kind: String,
    pub segments: String,
    pub created_by: Option<String>,
    pub created_at: i64,
    pub updated_at: i64,
}

pub const TIMER_COLS: &str = "id, family_id, child_id, kind, segments, created_by, created_at, updated_at";

/// Seconds spent on each side (both-sided segments count for both).
fn side_seconds(segments: &[Segment], now: i64) -> (i64, i64, i64) {
    let (mut left, mut right, mut total) = (0, 0, 0);
    for s in segments {
        let ms = s.end.unwrap_or(now) - s.start;
        total += ms;
        match s.side {
            Some(Side::Left) => left += ms,
            Some(Side::Right) => right += ms,
            Some(Side::Both) => {
                left += ms;
                right += ms;
            }
            None => {}
        }
    }
    (left / 1000, right / 1000, total / 1000)
}

impl TimerRow {
    fn segs(&self) -> AppResult<Vec<Segment>> {
        Ok(serde_json::from_str(&self.segments)?)
    }

    pub fn to_json(&self, tz: Tz) -> AppResult<Value> {
        let segs = self.segs()?;
        let now = now_ms();
        let running = segs.last().is_some_and(|s| s.end.is_none());
        let (left, right, total) = side_seconds(&segs, now);
        let started_at = segs.iter().map(|s| s.start).min().unwrap_or(self.created_at);
        let mut v = json!({
            "id": self.id,
            "child_id": self.child_id,
            "kind": self.kind,
            "started_at": fmt_time(started_at, tz),
            "running": running,
            "side": segs.last().and_then(|s| s.side),
            "elapsed_seconds": total,
            "segments": segs.iter().map(|s| json!({
                "side": s.side, "start": fmt_time(s.start, tz), "end": s.end.map(|e| fmt_time(e, tz))
            })).collect::<Vec<_>>(),
            "created_by": self.created_by,
            "updated_at": fmt_time(self.updated_at, tz),
        });
        if self.kind != "sleep" {
            v["left_seconds"] = json!(left);
            v["right_seconds"] = json!(right);
        }
        Ok(v)
    }
}

pub async fn family_timers(state: &AppState, family_id: &str, tz: Tz) -> AppResult<Vec<Value>> {
    let rows = sqlx::query_as::<_, TimerRow>(&format!("SELECT {TIMER_COLS} FROM timers WHERE family_id = ? ORDER BY created_at"))
        .bind(family_id)
        .fetch_all(&state.db)
        .await?;
    rows.iter().map(|r| r.to_json(tz)).collect()
}

pub async fn child_timers(state: &AppState, child_id: &str, tz: Tz) -> AppResult<Vec<Value>> {
    let rows = sqlx::query_as::<_, TimerRow>(&format!("SELECT {TIMER_COLS} FROM timers WHERE child_id = ? ORDER BY created_at"))
        .bind(child_id)
        .fetch_all(&state.db)
        .await?;
    rows.iter().map(|r| r.to_json(tz)).collect()
}

pub async fn list(State(state): State<AppState>, user: AuthUser, Path(child_id): Path<String>) -> AppResult<Json<Value>> {
    let ctx = child_access(&state.db, &child_id, &user.id).await?;
    Ok(Json(json!({ "timers": child_timers(&state, &child_id, ctx.tz).await? })))
}

pub fn check_side(kind: TimerKind, side: Option<Side>) -> AppResult<Option<Side>> {
    match kind {
        TimerKind::Sleep => Ok(None),
        TimerKind::Breastfeed => match side.unwrap_or(Side::Left) {
            Side::Both => bad("a breastfeed timer runs on one side at a time; use 'switch' to change sides"),
            s => Ok(Some(s)),
        },
        TimerKind::Pump => Ok(Some(side.unwrap_or(Side::Both))),
    }
}

#[derive(Deserialize)]
pub struct StartReq {
    /// Optional id chosen by the client (a UUID), so a retried start is harmless.
    #[serde(default)]
    id: Option<String>,
    kind: TimerKind,
    #[serde(default)]
    side: Option<Side>,
    /// Start in the past, e.g. "the nap started 10 minutes ago".
    #[serde(default)]
    start: Option<String>,
}

pub async fn start(State(state): State<AppState>, user: AuthUser, Path(child_id): Path<String>, ApiJson(req): ApiJson<StartReq>) -> AppResult<(StatusCode, Json<Value>)> {
    let ctx = child_access(&state.db, &child_id, &user.id).await?;
    let now = now_ms();
    let start = parse_opt_time(&req.start, ctx.tz)?.unwrap_or(now);
    if start > now + 60_000 {
        return bad("a timer cannot start in the future");
    }
    let side = check_side(req.kind, req.side)?;
    if let Some(id) = &req.id {
        if uuid::Uuid::parse_str(id).is_err() {
            return bad("id must be a UUID");
        }
        if let Ok(row) = load(&state, id).await {
            if row.child_id != child_id {
                return Err(AppError::Conflict("this id is already used".into()));
            }
            return Ok((StatusCode::OK, Json(row.to_json(ctx.tz)?)));
        }
    }
    let existing: Option<(String,)> = sqlx::query_as("SELECT id FROM timers WHERE child_id = ? AND kind = ?")
        .bind(&child_id)
        .bind(req.kind.as_str())
        .fetch_optional(&state.db)
        .await?;
    if let Some((id,)) = existing {
        return Err(AppError::Conflict(format!("a {} timer is already running ({id})", req.kind.as_str())));
    }
    let id = req.id.unwrap_or_else(new_id);
    let segs = vec![Segment { side, start, end: None }];
    sqlx::query("INSERT INTO timers (id, family_id, child_id, kind, segments, created_by, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)")
        .bind(&id)
        .bind(&ctx.family_id)
        .bind(&child_id)
        .bind(req.kind.as_str())
        .bind(serde_json::to_string(&segs)?)
        .bind(&user.id)
        .bind(now)
        .bind(now)
        .execute(&state.db)
        .await?;
    let json = load(&state, &id).await?.to_json(ctx.tz)?;
    state.publish(&ctx.family_id, "timer", "created", json.clone());
    Ok((StatusCode::CREATED, Json(json)))
}

pub async fn load(state: &AppState, id: &str) -> AppResult<TimerRow> {
    sqlx::query_as::<_, TimerRow>(&format!("SELECT {TIMER_COLS} FROM timers WHERE id = ?"))
        .bind(id)
        .fetch_optional(&state.db)
        .await?
        .ok_or(AppError::NotFound("timer"))
}

async fn accessible(state: &AppState, id: &str, user: &AuthUser) -> AppResult<(TimerRow, Tz)> {
    let row = load(state, id).await?;
    let ctx = child_access(&state.db, &row.child_id, &user.id)
        .await
        .map_err(|_| AppError::NotFound("timer"))?;
    Ok((row, ctx.tz))
}

async fn save(state: &AppState, row: &TimerRow, segs: &[Segment], tz: Tz) -> AppResult<Json<Value>> {
    sqlx::query("UPDATE timers SET segments = ?, updated_at = ? WHERE id = ?")
        .bind(serde_json::to_string(segs)?)
        .bind(now_ms())
        .bind(&row.id)
        .execute(&state.db)
        .await?;
    let json = load(state, &row.id).await?.to_json(tz)?;
    state.publish(&row.family_id, "timer", "updated", json.clone());
    Ok(Json(json))
}

pub async fn get(State(state): State<AppState>, user: AuthUser, Path(id): Path<String>) -> AppResult<Json<Value>> {
    let (row, tz) = accessible(&state, &id, &user).await?;
    Ok(Json(row.to_json(tz)?))
}

pub async fn pause(State(state): State<AppState>, user: AuthUser, Path(id): Path<String>) -> AppResult<Json<Value>> {
    let (row, tz) = accessible(&state, &id, &user).await?;
    let mut segs = row.segs()?;
    match segs.last_mut() {
        Some(last) if last.end.is_none() => last.end = Some(now_ms().max(last.start)),
        _ => return Err(AppError::Conflict("timer is already paused".into())),
    }
    save(&state, &row, &segs, tz).await
}

#[derive(Deserialize, Default)]
pub struct SideReq {
    #[serde(default)]
    side: Option<Side>,
}

fn parse_side_body(body: &[u8]) -> AppResult<SideReq> {
    if body.iter().all(|b| b.is_ascii_whitespace()) {
        return Ok(SideReq::default());
    }
    serde_json::from_slice(body).map_err(|e| AppError::BadRequest(format!("invalid JSON: {e}")))
}

/// Resume a paused timer, optionally on a different side.
pub async fn resume(State(state): State<AppState>, user: AuthUser, Path(id): Path<String>, body: axum::body::Bytes) -> AppResult<Json<Value>> {
    let req = parse_side_body(&body)?;
    let (row, tz) = accessible(&state, &id, &user).await?;
    let kind = TimerKind::parse(&row.kind)?;
    let mut segs = row.segs()?;
    if segs.last().is_some_and(|s| s.end.is_none()) {
        return Err(AppError::Conflict("timer is already running".into()));
    }
    let side = check_side(kind, req.side.or_else(|| segs.last().and_then(|s| s.side)))?;
    segs.push(Segment { side, start: now_ms(), end: None });
    save(&state, &row, &segs, tz).await
}

/// Switch sides (breastfeed / pump). Resumes the timer if it was paused.
pub async fn switch(State(state): State<AppState>, user: AuthUser, Path(id): Path<String>, body: axum::body::Bytes) -> AppResult<Json<Value>> {
    let req = parse_side_body(&body)?;
    let (row, tz) = accessible(&state, &id, &user).await?;
    let kind = TimerKind::parse(&row.kind)?;
    if kind == TimerKind::Sleep {
        return bad("sleep timers have no sides");
    }
    let mut segs = row.segs()?;
    let current = segs.last().and_then(|s| s.side);
    // Without an explicit side, flip left <-> right.
    let target = match (req.side, current) {
        (Some(s), _) => s,
        (None, Some(Side::Left)) => Side::Right,
        (None, _) => Side::Left,
    };
    let target = check_side(kind, Some(target))?;
    let now = now_ms();
    match segs.last_mut() {
        Some(last) if last.end.is_none() => {
            if last.side == target {
                return Ok(Json(row.to_json(tz)?));
            }
            last.end = Some(now.max(last.start));
        }
        _ => {}
    }
    segs.push(Segment { side: target, start: now, end: None });
    save(&state, &row, &segs, tz).await
}

/// Move the timer's start to `start`: the first segment grows (earlier start) or shrinks (later
/// start), so the total time changes by the same amount; the rest of the timer stays as it is.
/// A later start can swallow whole segments. Fails if nothing would be left.
fn set_start(segs: &mut Vec<Segment>, start: i64, now: i64) -> AppResult<()> {
    segs.sort_by_key(|s| s.start);
    let Some(first) = segs.first_mut() else { return Ok(()) };
    if start <= first.start {
        first.start = start;
        return Ok(());
    }
    // Later start: drop what ends before it, cut the segment it falls in.
    segs.retain(|s| s.end.unwrap_or(now) > start);
    match segs.first_mut() {
        Some(s) => {
            s.start = s.start.max(start);
            Ok(())
        }
        None => bad("the start must be before the timer's last minute"),
    }
}

/// Make the time spent on `side` (`None`: every segment, i.e. the total) add up to `target` ms by
/// growing or shrinking the latest matching segments (a running segment grows backwards, a closed one forwards). Segments may
/// overlap afterwards; only their lengths matter.
fn set_side(segs: &mut Vec<Segment>, side: Option<Side>, target: i64, now: i64) {
    let len = |s: &Segment| s.end.unwrap_or(now) - s.start;
    let matches = |s: &Segment| side.is_none() || s.side == side;
    let mut delta = target - segs.iter().filter(|s| matches(s)).map(len).sum::<i64>();
    for s in segs.iter_mut().rev().filter(|s| matches(s)) {
        if delta == 0 {
            break;
        }
        let change = delta.max(-len(s));
        match s.end {
            None => s.start -= change,
            Some(e) => s.end = Some(e + change),
        }
        delta -= change;
    }
    if delta > 0 {
        // This side was never used: add a closed segment just before the running one, or after the last.
        match segs.last() {
            Some(last) if last.end.is_none() => {
                let at = last.start;
                segs.insert(segs.len() - 1, Segment { side, start: at - delta, end: Some(at) });
            }
            last => {
                let at = last.and_then(|l| l.end).unwrap_or(now);
                segs.push(Segment { side, start: at, end: Some(at + delta) });
            }
        }
    }
    // Nothing may end in the future: pull the closed segments back if needed.
    let over = segs.iter().filter_map(|s| s.end).max().unwrap_or(now) - now;
    if over > 0 {
        for s in segs.iter_mut().filter(|s| s.end.is_some()) {
            s.start -= over;
            s.end = s.end.map(|e| e - over);
        }
    }
}

#[derive(Deserialize)]
pub struct EditReq {
    #[serde(default)]
    start: Option<String>,
    #[serde(default)]
    left_seconds: Option<u32>,
    #[serde(default)]
    right_seconds: Option<u32>,
    /// Sleep / pump: total time.
    #[serde(default)]
    seconds: Option<u32>,
}

/// Correct a timer: its start time, the time on each side (breastfeed) or the total time (sleep, pump).
pub async fn edit(State(state): State<AppState>, user: AuthUser, Path(id): Path<String>, ApiJson(req): ApiJson<EditReq>) -> AppResult<Json<Value>> {
    let (row, tz) = accessible(&state, &id, &user).await?;
    let kind = TimerKind::parse(&row.kind)?;
    if kind != TimerKind::Breastfeed && (req.left_seconds.is_some() || req.right_seconds.is_some()) {
        return bad("left_seconds / right_seconds can only be set on a breastfeed timer");
    }
    if kind == TimerKind::Breastfeed && req.seconds.is_some() {
        return bad("set left_seconds / right_seconds on a breastfeed timer");
    }
    if [req.left_seconds, req.right_seconds, req.seconds].iter().flatten().any(|&s| s > 12 * 3600) {
        return bad("a timer cannot be set to more than 12 hours");
    }
    let now = now_ms();
    let mut segs = row.segs()?;
    if let Some(start) = parse_opt_time(&req.start, tz)? {
        if start > now {
            return bad("a timer cannot start in the future");
        }
        set_start(&mut segs, start, now)?;
    }
    for (side, secs) in [(Some(Side::Left), req.left_seconds), (Some(Side::Right), req.right_seconds), (None, req.seconds)] {
        if let Some(secs) = secs {
            set_side(&mut segs, side, i64::from(secs) * 1000, now);
        }
    }
    save(&state, &row, &segs, tz).await
}

#[derive(Deserialize, Default)]
pub struct StopReq {
    /// Optional id for the saved event (a UUID), so a retried stop doesn't log twice.
    #[serde(default)]
    event_id: Option<String>,
    /// Override the end time (e.g. "fell asleep on the breast 5 minutes ago").
    #[serde(default)]
    end: Option<String>,
    #[serde(default)]
    note: Option<String>,
    /// Pump amounts.
    #[serde(default)]
    left_ml: Option<f64>,
    #[serde(default)]
    right_ml: Option<f64>,
    /// Sleep location.
    #[serde(default)]
    location: Option<String>,
}

/// Stop the timer and save it as an event. Returns the created event.
pub async fn stop(State(state): State<AppState>, user: AuthUser, Path(id): Path<String>, body: axum::body::Bytes) -> AppResult<(StatusCode, Json<Value>)> {
    let req: StopReq = if body.iter().all(|b| b.is_ascii_whitespace()) {
        StopReq::default()
    } else {
        serde_json::from_slice(&body).map_err(|e| AppError::BadRequest(format!("invalid JSON: {e}")))?
    };
    if let Some(event_id) = &req.event_id {
        // Already stopped by this same request (its answer got lost): return that event.
        if let Ok(event) = crate::routes::events::get_row(&state.db, event_id).await {
            let ctx = child_access(&state.db, &event.child_id, &user.id).await.map_err(|_| AppError::NotFound("timer"))?;
            if event.deleted_at.is_none() {
                return Ok((StatusCode::OK, Json(event.to_json(ctx.tz)?)));
            }
        }
        if uuid::Uuid::parse_str(event_id).is_err() {
            return bad("event_id must be a UUID");
        }
    }
    let (row, tz) = accessible(&state, &id, &user).await?;
    let kind = TimerKind::parse(&row.kind)?;
    let mut segs = row.segs()?;
    let now = now_ms();
    let end = parse_opt_time(&req.end, tz)?.unwrap_or(now).min(now);

    // Close the running segment, then cut anything past the requested end.
    if let Some(last) = segs.last_mut() {
        if last.end.is_none() {
            last.end = Some(now);
        }
    }
    let first_start = segs.iter().map(|s| s.start).min();
    segs.retain(|s| Some(s.start) == first_start || s.start < end);
    for s in segs.iter_mut() {
        if s.end.unwrap_or(now) > end {
            s.end = Some(end.max(s.start));
        }
    }
    let start = segs.iter().map(|s| s.start).min().unwrap_or(row.created_at);
    if end < start {
        return bad("end must be after the timer started");
    }
    let event_end = segs.iter().filter_map(|s| s.end).max().unwrap_or(end).max(start);
    let (left, right, _) = side_seconds(&segs, now);
    let opt = |s: i64| if s > 0 { Some(s as u32) } else { None };

    let details = match kind {
        TimerKind::Breastfeed => Details::Feed(Feed {
            method: FeedMethod::Breast,
            left_seconds: opt(left).or(Some(0)),
            right_seconds: opt(right).or(Some(0)),
            start_side: segs.first().and_then(|s| s.side),
            amount_ml: None,
            milk: None,
            formula_name: None,
            foods: None,
        }),
        TimerKind::Pump => Details::Pump(Pump {
            left_ml: req.left_ml,
            right_ml: req.right_ml,
            left_seconds: opt(left),
            right_seconds: opt(right),
        }),
        TimerKind::Sleep => Details::Sleep(Sleep { location: req.location.clone() }),
    };
    details.validate(start, Some(event_end), &req.note)?;

    // Delete the timer and save the event together, and only once: when two caregivers stop the
    // same timer at the same moment, the second finds it gone.
    let mut tx = state.db.begin().await?;
    let gone = sqlx::query("DELETE FROM timers WHERE id = ?").bind(&row.id).execute(&mut *tx).await?.rows_affected() == 0;
    if gone {
        return Err(AppError::NotFound("timer"));
    }
    let event_id = insert_event_in(
        &mut tx,
        NewEvent {
            id: req.event_id,
            family_id: row.family_id.clone(),
            child_id: row.child_id.clone(),
            start_at: start,
            end_at: Some(event_end),
            details,
            note: req.note,
            user_id: Some(user.id.clone()),
        },
    )
    .await?;
    tx.commit().await?;
    let event_json = get_row(&state.db, &event_id).await?.to_json(tz)?;
    state.publish(&row.family_id, "timer", "deleted", json!({ "id": row.id, "child_id": row.child_id, "kind": row.kind }));
    state.publish(&row.family_id, "event", "created", event_json.clone());
    Ok((StatusCode::CREATED, Json(event_json)))
}

/// Throw the timer away without saving an event.
pub async fn discard(State(state): State<AppState>, user: AuthUser, Path(id): Path<String>) -> AppResult<StatusCode> {
    let (row, _) = accessible(&state, &id, &user).await?;
    sqlx::query("DELETE FROM timers WHERE id = ?").bind(&row.id).execute(&state.db).await?;
    state.publish(&row.family_id, "timer", "deleted", json!({ "id": row.id, "child_id": row.child_id, "kind": row.kind }));
    Ok(StatusCode::NO_CONTENT)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn sums_sides() {
        let segs = vec![
            Segment { side: Some(Side::Left), start: 0, end: Some(60_000) },
            Segment { side: Some(Side::Right), start: 90_000, end: Some(150_000) },
            Segment { side: Some(Side::Both), start: 150_000, end: None },
        ];
        assert_eq!(side_seconds(&segs, 160_000), (70, 70, 130));
    }

    fn seg(side: Side, start: i64, end: Option<i64>) -> Segment {
        Segment { side: Some(side), start, end }
    }

    #[test]
    fn edits_sides() {
        // Left 60 s, then right running for 30 s.
        let base = vec![seg(Side::Left, 0, Some(60_000)), seg(Side::Right, 70_000, None)];
        let now = 100_000;

        let mut segs = base.clone();
        set_side(&mut segs, Some(Side::Right), 300_000, now);
        assert_eq!(side_seconds(&segs, now), (60, 300, 360));
        assert!(segs[1].end.is_none(), "still running");

        let mut segs = base.clone();
        set_side(&mut segs, Some(Side::Left), 120_000, now);
        assert_eq!(side_seconds(&segs, now).0, 120);
        assert!(segs.iter().filter_map(|s| s.end).all(|e| e <= now));

        let mut segs = base.clone();
        set_side(&mut segs, Some(Side::Left), 0, now);
        assert_eq!(side_seconds(&segs, now), (0, 30, 30));

        // A side never used gets its own segment, before the running one.
        let mut segs = vec![seg(Side::Left, 0, None)];
        set_side(&mut segs, Some(Side::Right), 20_000, now);
        assert_eq!(side_seconds(&segs, now), (100, 20, 120));
        assert_eq!(segs.last().unwrap().side, Some(Side::Left));

        // Total time (sleep has no sides; pump segments may be both-sided).
        let mut segs = vec![Segment { side: None, start: 50_000, end: None }];
        set_side(&mut segs, None, 3_600_000, now);
        assert_eq!(side_seconds(&segs, now).2, 3600);
        let mut segs = vec![seg(Side::Both, 0, Some(40_000)), seg(Side::Left, 60_000, None)];
        set_side(&mut segs, None, 30_000, now);
        assert_eq!(side_seconds(&segs, now).2, 30);
        assert!(segs.last().unwrap().end.is_none());

        // An earlier start adds time to the first segment (and the total).
        let mut segs = base.clone();
        set_start(&mut segs, -50_000, now).unwrap();
        assert_eq!(side_seconds(&segs, now), (110, 30, 140));
        assert_eq!(segs[0].start, -50_000);
        // A later one takes it away, across segments if needed.
        let mut segs = base.clone();
        set_start(&mut segs, 20_000, now).unwrap();
        assert_eq!(side_seconds(&segs, now), (40, 30, 70));
        let mut segs = base.clone();
        set_start(&mut segs, 80_000, now).unwrap();
        assert_eq!(side_seconds(&segs, now), (0, 20, 20));
        assert_eq!(segs.len(), 1);
        // Running alone: the clock simply restarts from the new start.
        let mut segs = vec![seg(Side::Left, 50_000, None)];
        set_start(&mut segs, 10_000, now).unwrap();
        assert_eq!(side_seconds(&segs, now), (90, 0, 90));
        // Paused timer: can't start after it ended.
        let mut segs = vec![seg(Side::Left, 0, Some(60_000))];
        assert!(set_start(&mut segs, 70_000, now).is_err());
    }
}
