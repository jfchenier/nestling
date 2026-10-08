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
    routes::events::{insert_event, NewEvent},
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
    fn as_str(self) -> &'static str {
        match self {
            TimerKind::Breastfeed => "breastfeed",
            TimerKind::Pump => "pump",
            TimerKind::Sleep => "sleep",
        }
    }
    fn parse(s: &str) -> AppResult<Self> {
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

const TIMER_COLS: &str = "id, family_id, child_id, kind, segments, created_by, created_at, updated_at";

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
        let started_at = segs.first().map(|s| s.start).unwrap_or(self.created_at);
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

fn check_side(kind: TimerKind, side: Option<Side>) -> AppResult<Option<Side>> {
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
    let existing: Option<(String,)> = sqlx::query_as("SELECT id FROM timers WHERE child_id = ? AND kind = ?")
        .bind(&child_id)
        .bind(req.kind.as_str())
        .fetch_optional(&state.db)
        .await?;
    if let Some((id,)) = existing {
        return Err(AppError::Conflict(format!("a {} timer is already running ({id})", req.kind.as_str())));
    }
    let id = new_id();
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

async fn load(state: &AppState, id: &str) -> AppResult<TimerRow> {
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

#[derive(Deserialize, Default)]
pub struct StopReq {
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
    let first_start = segs.first().map(|s| s.start);
    segs.retain(|s| Some(s.start) == first_start || s.start < end);
    for s in segs.iter_mut() {
        if s.end.unwrap_or(now) > end {
            s.end = Some(end.max(s.start));
        }
    }
    let start = segs.first().map(|s| s.start).unwrap_or(row.created_at);
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

    let event = insert_event(
        &state.db,
        NewEvent {
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
    sqlx::query("DELETE FROM timers WHERE id = ?").bind(&row.id).execute(&state.db).await?;
    let event_json = event.to_json(tz)?;
    state.publish(&row.family_id, "timer", "deleted", json!({ "id": row.id, "child_id": row.child_id }));
    state.publish(&row.family_id, "event", "created", event_json.clone());
    Ok((StatusCode::CREATED, Json(event_json)))
}

/// Throw the timer away without saving an event.
pub async fn discard(State(state): State<AppState>, user: AuthUser, Path(id): Path<String>) -> AppResult<StatusCode> {
    let (row, _) = accessible(&state, &id, &user).await?;
    sqlx::query("DELETE FROM timers WHERE id = ?").bind(&row.id).execute(&state.db).await?;
    state.publish(&row.family_id, "timer", "deleted", json!({ "id": row.id, "child_id": row.child_id }));
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
}
