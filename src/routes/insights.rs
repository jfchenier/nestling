//! Summary (home screen), trends and the live change stream.

use std::convert::Infallible;

use axum::{
    extract::{Path, State},
    http::{header::HeaderName, HeaderValue},
    response::{
        sse::{Event as SseEvent, KeepAlive, Sse},
        IntoResponse,
    },
    Json,
};
use chrono::{Duration, NaiveDate};
use futures::stream::{self, StreamExt};
use serde::Deserialize;
use serde_json::{json, Value};
use tokio_stream::wrappers::BroadcastStream;

use crate::{
    auth::{child_access, require_member, AuthUser},
    error::{bad, ApiQuery, AppResult},
    routes::{
        children::child_json,
        events::{EventRow, EVENT_COLS},
        timers::child_timers,
    },
    state::AppState,
    trends::{self, TrendEvent},
    util::now_ms,
};

async fn trend_events(state: &AppState, child_id: &str, r0: i64, r1: i64) -> AppResult<Vec<TrendEvent>> {
    // Look back 2 days so sleep that started before the range is counted.
    let rows = sqlx::query_as::<_, EventRow>(&format!(
        "SELECT {EVENT_COLS} FROM events WHERE child_id = ? AND deleted_at IS NULL
         AND type IN ('feed', 'sleep', 'diaper', 'pump') AND start_at >= ? AND start_at < ?"
    ))
    .bind(child_id)
    .bind(r0 - 2 * 24 * 3600 * 1000)
    .bind(r1)
    .fetch_all(&state.db)
    .await?;
    rows.into_iter()
        .map(|r| Ok(TrendEvent { start: r.start_at, end: r.end_at, details: r.details()? }))
        .collect()
}

#[derive(Deserialize)]
pub struct TrendsQuery {
    /// Number of days (1-90), default 7.
    days: Option<u32>,
    /// Last day of the range (YYYY-MM-DD), default today.
    to: Option<NaiveDate>,
}

pub async fn get_trends(State(state): State<AppState>, user: AuthUser, Path(child_id): Path<String>, ApiQuery(q): ApiQuery<TrendsQuery>) -> AppResult<Json<Value>> {
    let ctx = child_access(&state.db, &child_id, &user.id).await?;
    let days = q.days.unwrap_or(7);
    if !(1..=90).contains(&days) {
        return bad("days must be between 1 and 90");
    }
    let now = now_ms();
    let today = chrono::Utc::now().with_timezone(&ctx.tz).date_naive();
    let to = q.to.unwrap_or(today);
    let from = to - Duration::days(days as i64 - 1);
    // From the start of the previous period, for the comparison.
    let (r0, r1) = trends::range_ms(ctx.tz, from - Duration::days(days as i64), days * 2);
    let events = trend_events(&state, &child_id, r0, r1).await?;
    Ok(Json(serde_json::to_value(trends::compute_with_previous(&events, ctx.tz, ctx.day, from, days, now))?))
}

/// Everything a home screen needs: last feed/sleep/diaper/pump, running timers, today's totals.
pub async fn summary(State(state): State<AppState>, user: AuthUser, Path(child_id): Path<String>) -> AppResult<Json<Value>> {
    let ctx = child_access(&state.db, &child_id, &user.id).await?;
    let now = now_ms();
    let mut last = serde_json::Map::new();
    let mut since = serde_json::Map::new();
    for kind in ["feed", "sleep", "diaper", "pump"] {
        let row = sqlx::query_as::<_, EventRow>(&format!(
            "SELECT {EVENT_COLS} FROM events WHERE child_id = ? AND type = ? AND deleted_at IS NULL ORDER BY start_at DESC LIMIT 1"
        ))
        .bind(&child_id)
        .bind(kind)
        .fetch_optional(&state.db)
        .await?;
        match row {
            Some(r) => {
                // For sleep, "since" means time awake (since it ended).
                let reference = if kind == "sleep" { r.end_at.unwrap_or(r.start_at) } else { r.start_at };
                since.insert(format!("{kind}_seconds"), json!(((now - reference) / 1000).max(0)));
                last.insert(kind.into(), r.to_json(ctx.tz)?);
            }
            None => {
                last.insert(kind.into(), Value::Null);
                since.insert(format!("{kind}_seconds"), Value::Null);
            }
        }
    }
    let timers = child_timers(&state, &child_id, ctx.tz).await?;
    if timers.iter().any(|t| t["kind"] == "sleep") {
        since.insert("sleep_seconds".into(), Value::Null);
    }
    let today = chrono::Utc::now().with_timezone(&ctx.tz).date_naive();
    let (r0, r1) = trends::range_ms(ctx.tz, today, 1);
    let events = trend_events(&state, &child_id, r0, r1).await?;
    let t = trends::compute(&events, ctx.tz, ctx.day, today, 1, now);
    Ok(Json(json!({
        "child": child_json(&state, &child_id, ctx.tz).await?,
        "last": last,
        "since": since,
        "timers": timers,
        "today": t.days.into_iter().next(),
        // Rolling: the 24 hours up to now (what the home screen's totals show).
        "last_24h": trends::last_24h(&events, ctx.tz, ctx.day, now),
    })))
}

/// Server-Sent Events stream of every change in a family.
/// Each message has `event: change` and data `{"entity", "action", "data"}`.
/// If a client falls behind, it receives `event: resync` and should call `/sync`.
/// An `event: ping` is sent every [KEEP_ALIVE] so clients can tell a dead connection from a quiet
/// one (a comment would be invisible to browsers' `EventSource`).
pub async fn stream(State(state): State<AppState>, user: AuthUser, Path(family_id): Path<String>) -> AppResult<impl IntoResponse> {
    require_member(&state.db, &family_id, &user.id).await?;
    let rx = state.changes.subscribe();
    let hello = stream::once(async { Ok::<_, Infallible>(SseEvent::default().event("ready").data("{}")) });
    let fid = family_id.clone();
    let changes = BroadcastStream::new(rx).filter_map(move |msg| {
        let fid = fid.clone();
        async move {
            match msg {
                Ok(change) if change.family_id == fid => {
                    let data = serde_json::to_string(&change).unwrap_or_else(|_| "{}".into());
                    Some(Ok(SseEvent::default().event("change").data(data)))
                }
                Ok(_) => None,
                Err(_) => Some(Ok(SseEvent::default().event("resync").data("{}"))),
            }
        }
    });
    let sse = Sse::new(hello.chain(changes)).keep_alive(KeepAlive::new().interval(KEEP_ALIVE).event(SseEvent::default().event("ping").data("{}")));
    // nginx (and proxies built on it) would otherwise hold events back until its buffer fills.
    Ok(([(HeaderName::from_static("x-accel-buffering"), HeaderValue::from_static("no"))], sse))
}

pub const KEEP_ALIVE: std::time::Duration = std::time::Duration::from_secs(15);
