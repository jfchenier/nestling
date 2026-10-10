use axum::{
    extract::{Path, State},
    http::StatusCode,
    Json,
};
use chrono_tz::Tz;
use serde::{Deserialize, Serialize};
use serde_json::{json, Map, Value};
use sqlx::{SqliteConnection, SqlitePool};

use crate::{
    auth::{book_only, child_access, child_book_access, AuthUser, BOOK_TYPES},
    error::{bad, ApiJson, ApiQuery, AppError, AppResult},
    model::{Details, EVENT_TYPES},
    state::AppState,
    util::{fmt_time, new_id, now_ms, parse_opt_time, parse_tz},
};

#[derive(Debug, Clone, sqlx::FromRow)]
pub struct EventRow {
    pub id: String,
    pub family_id: String,
    pub child_id: String,
    #[sqlx(rename = "type")]
    pub kind: String,
    pub start_at: i64,
    pub end_at: Option<i64>,
    pub data: String,
    pub note: Option<String>,
    pub created_by: Option<String>,
    pub updated_by: Option<String>,
    pub created_at: i64,
    pub updated_at: i64,
    pub deleted_at: Option<i64>,
    pub source: Option<String>,
    /// When the entry's photo was last set (null: no photo).
    pub photo_version: Option<i64>,
}

pub const EVENT_COLS: &str = "id, family_id, child_id, type, start_at, end_at, data, note, created_by, updated_by, created_at, updated_at, deleted_at, source,
    (SELECT p.updated_at FROM event_photos p WHERE p.event_id = events.id) AS photo_version";

impl EventRow {
    pub fn details(&self) -> AppResult<Details> {
        Ok(serde_json::from_str(&self.data)?)
    }

    pub fn to_json(&self, tz: Tz) -> AppResult<Value> {
        if self.deleted_at.is_some() {
            return Ok(json!({ "id": self.id, "child_id": self.child_id, "deleted": true,
                              "updated_at": fmt_time(self.updated_at, tz) }));
        }
        let out = EventOut {
            id: &self.id,
            child_id: &self.child_id,
            details: self.details()?,
            start: fmt_time(self.start_at, tz),
            end: self.end_at.map(|e| fmt_time(e, tz)),
            duration_seconds: self.end_at.map(|e| (e - self.start_at) / 1000),
            note: self.note.as_deref(),
            created_by: self.created_by.as_deref(),
            updated_by: self.updated_by.as_deref(),
            created_at: fmt_time(self.created_at, tz),
            updated_at: fmt_time(self.updated_at, tz),
            source: self.source.as_deref(),
            photo_version: self.photo_version,
        };
        Ok(serde_json::to_value(out)?)
    }
}

#[derive(Serialize)]
struct EventOut<'a> {
    id: &'a str,
    child_id: &'a str,
    #[serde(flatten)]
    details: Details,
    start: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    end: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    duration_seconds: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    note: Option<&'a str>,
    created_by: Option<&'a str>,
    updated_by: Option<&'a str>,
    created_at: String,
    updated_at: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    source: Option<&'a str>,
    /// Changes whenever the photo does (null: none); fetch it from `/events/{id}/photo`.
    photo_version: Option<i64>,
}

/// Request body for creating (and, after merging, patching) an event.
#[derive(Debug, Deserialize)]
pub struct EventInput {
    /// Optional id chosen by the client (a UUID), so a retried create doesn't log twice.
    #[serde(default)]
    pub id: Option<String>,
    #[serde(default)]
    pub start: Option<String>,
    #[serde(default)]
    pub end: Option<String>,
    #[serde(default)]
    pub note: Option<String>,
    #[serde(flatten)]
    pub details: Details,
}

pub struct NewEvent {
    /// Client-chosen id; a new one is made when absent.
    pub id: Option<String>,
    pub family_id: String,
    pub child_id: String,
    pub start_at: i64,
    pub end_at: Option<i64>,
    pub details: Details,
    pub note: Option<String>,
    pub user_id: Option<String>,
}

pub async fn get_row(db: &SqlitePool, id: &str) -> AppResult<EventRow> {
    sqlx::query_as::<_, EventRow>(&format!("SELECT {EVENT_COLS} FROM events WHERE id = ?"))
        .bind(id)
        .fetch_optional(db)
        .await?
        .ok_or(AppError::NotFound("event"))
}

pub async fn insert_event(db: &SqlitePool, ev: NewEvent) -> AppResult<EventRow> {
    let mut conn = db.acquire().await?;
    let id = insert_event_in(&mut conn, ev).await?;
    drop(conn);
    get_row(db, &id).await
}

/// Insert on a given connection (e.g. inside a transaction); returns the new event's id.
pub async fn insert_event_in(conn: &mut SqliteConnection, ev: NewEvent) -> AppResult<String> {
    let id = ev.id.unwrap_or_else(new_id);
    let now = now_ms();
    sqlx::query(
        "INSERT INTO events (id, family_id, child_id, type, start_at, end_at, data, note, created_by, updated_by, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
    )
    .bind(&id)
    .bind(&ev.family_id)
    .bind(&ev.child_id)
    .bind(ev.details.type_name())
    .bind(ev.start_at)
    .bind(ev.end_at)
    .bind(serde_json::to_string(&ev.details)?)
    .bind(clean_note(ev.note))
    .bind(&ev.user_id)
    .bind(&ev.user_id)
    .bind(now)
    .bind(now)
    .execute(&mut *conn)
    .await?;
    Ok(id)
}

/// A client-chosen id that is already taken: the earlier event when it is the same family's
/// (a retried request whose first answer got lost), an error otherwise.
pub async fn existing_client_id(db: &SqlitePool, id: &str, family_id: &str) -> AppResult<Option<EventRow>> {
    if uuid::Uuid::parse_str(id).is_err() {
        return bad("id must be a UUID");
    }
    match sqlx::query_as::<_, EventRow>(&format!("SELECT {EVENT_COLS} FROM events WHERE id = ?")).bind(id).fetch_optional(db).await? {
        Some(row) if row.family_id == family_id && row.deleted_at.is_none() => Ok(Some(row)),
        Some(_) => Err(AppError::Conflict("this id is already used".into())),
        None => Ok(None),
    }
}

pub fn clean_note(note: Option<String>) -> Option<String> {
    note.map(|n| n.trim().to_string()).filter(|n| !n.is_empty())
}

#[derive(Deserialize)]
pub struct ListQuery {
    /// Comma-separated list of types, e.g. "feed,diaper".
    #[serde(rename = "type")]
    kind: Option<String>,
    /// Only events starting at or after this time.
    from: Option<String>,
    /// Only events starting before this time (use the last event's start to page back).
    to: Option<String>,
    limit: Option<i64>,
}

pub async fn list(State(state): State<AppState>, user: AuthUser, Path(child_id): Path<String>, ApiQuery(q): ApiQuery<ListQuery>) -> AppResult<Json<Value>> {
    let ctx = child_book_access(&state.db, &child_id, &user.id).await?;
    let limit = q.limit.unwrap_or(100).clamp(1, 1000);
    let from = parse_opt_time(&q.from, ctx.tz)?.unwrap_or(i64::MIN);
    let to = parse_opt_time(&q.to, ctx.tz)?.unwrap_or(i64::MAX);
    let types: Vec<String> = match &q.kind {
        Some(t) => t.split(',').map(|s| s.trim().to_lowercase()).filter(|s| !s.is_empty()).collect(),
        None => vec![],
    };
    for t in &types {
        if !EVENT_TYPES.contains(&t.as_str()) {
            return bad(format!("unknown type '{t}' (expected one of {})", EVENT_TYPES.join(", ")));
        }
    }
    // Book viewers see the book's entries only.
    let types = if !ctx.book_only {
        types
    } else if types.is_empty() {
        BOOK_TYPES.iter().map(|t| t.to_string()).collect()
    } else if types.iter().all(|t| BOOK_TYPES.contains(&t.as_str())) {
        types
    } else {
        return Err(book_only());
    };
    let type_filter = if types.is_empty() {
        String::new()
    } else {
        format!(" AND type IN ({})", vec!["?"; types.len()].join(","))
    };
    let sql = format!(
        "SELECT {EVENT_COLS} FROM events WHERE child_id = ? AND deleted_at IS NULL AND start_at >= ? AND start_at < ?{type_filter}
         ORDER BY start_at DESC LIMIT ?"
    );
    let mut query = sqlx::query_as::<_, EventRow>(&sql).bind(&child_id).bind(from).bind(to);
    for t in &types {
        query = query.bind(t);
    }
    let rows = query.bind(limit + 1).fetch_all(&state.db).await?;
    let has_more = rows.len() as i64 > limit;
    let rows = &rows[..rows.len().min(limit as usize)];
    let events = rows.iter().map(|r| r.to_json(ctx.tz)).collect::<AppResult<Vec<_>>>()?;
    let next = if has_more { rows.last().map(|r| fmt_time(r.start_at, ctx.tz)) } else { None };
    Ok(Json(json!({ "events": events, "next_to": next })))
}

pub async fn create(State(state): State<AppState>, user: AuthUser, Path(child_id): Path<String>, ApiJson(input): ApiJson<EventInput>) -> AppResult<(StatusCode, Json<Value>)> {
    let ctx = child_access(&state.db, &child_id, &user.id).await?;
    if let Some(id) = &input.id {
        if let Some(row) = existing_client_id(&state.db, id, &ctx.family_id).await? {
            return Ok((StatusCode::OK, Json(row.to_json(ctx.tz)?)));
        }
    }
    let start = parse_opt_time(&input.start, ctx.tz)?.unwrap_or_else(now_ms);
    let end = parse_opt_time(&input.end, ctx.tz)?;
    input.details.validate(start, end, &input.note)?;
    let row = insert_event(
        &state.db,
        NewEvent {
            id: input.id,
            family_id: ctx.family_id.clone(),
            child_id,
            start_at: start,
            end_at: end,
            details: input.details,
            note: input.note,
            user_id: Some(user.id),
        },
    )
    .await?;
    let json = row.to_json(ctx.tz)?;
    state.publish(&ctx.family_id, "event", "created", json.clone());
    Ok((StatusCode::CREATED, Json(json)))
}

/// Load an event the caller may change, plus its family's timezone.
async fn accessible_event(state: &AppState, id: &str, user: &AuthUser) -> AppResult<(EventRow, Tz)> {
    let (row, tz, book_only) = readable_event(state, id, user).await?;
    if book_only {
        return Err(crate::auth::book_only());
    }
    Ok((row, tz))
}

/// Load an event the caller may read (book viewers: memories and growth only), plus its
/// family's timezone and whether the caller is a book viewer.
async fn readable_event(state: &AppState, id: &str, user: &AuthUser) -> AppResult<(EventRow, Tz, bool)> {
    let row = get_row(&state.db, id).await?;
    if row.deleted_at.is_some() {
        return Err(AppError::NotFound("event"));
    }
    let ctx = child_book_access(&state.db, &row.child_id, &user.id)
        .await
        .map_err(|_| AppError::NotFound("event"))?;
    if ctx.book_only && !BOOK_TYPES.contains(&row.kind.as_str()) {
        return Err(AppError::NotFound("event"));
    }
    Ok((row, ctx.tz, ctx.book_only))
}

pub async fn get(State(state): State<AppState>, user: AuthUser, Path(id): Path<String>) -> AppResult<Json<Value>> {
    let (row, tz, _) = readable_event(&state, &id, &user).await?;
    Ok(Json(row.to_json(tz)?))
}

/// Partial update: send only the fields to change; `null` clears a field.
/// Changing `type` is allowed (fields of the old type that don't apply are dropped).
pub async fn update(State(state): State<AppState>, user: AuthUser, Path(id): Path<String>, ApiJson(patch): ApiJson<Map<String, Value>>) -> AppResult<Json<Value>> {
    let (row, tz) = accessible_event(&state, &id, &user).await?;
    for key in ["id", "child_id", "created_by", "updated_by", "created_at", "updated_at", "duration_seconds", "source"] {
        if patch.contains_key(key) {
            return bad(format!("'{key}' cannot be changed"));
        }
    }
    let mut current = serde_json::to_value(row.details()?)?;
    let obj = current.as_object_mut().expect("details serialize to an object");
    obj.insert("start".into(), json!(fmt_time(row.start_at, tz)));
    if let Some(end) = row.end_at {
        obj.insert("end".into(), json!(fmt_time(end, tz)));
    }
    if let Some(note) = &row.note {
        obj.insert("note".into(), json!(note));
    }
    for (k, v) in patch {
        if v.is_null() {
            obj.remove(&k);
        } else {
            obj.insert(k, v);
        }
    }
    let input: EventInput = serde_json::from_value(current).map_err(|e| AppError::BadRequest(e.to_string()))?;
    let start = match &input.start {
        Some(s) => crate::util::parse_time(s, tz)?,
        None => return bad("start cannot be removed"),
    };
    let end = parse_opt_time(&input.end, tz)?;
    input.details.validate(start, end, &input.note)?;

    sqlx::query("UPDATE events SET type = ?, start_at = ?, end_at = ?, data = ?, note = ?, updated_by = ?, updated_at = ?, changed_at = NULL WHERE id = ?")
        .bind(input.details.type_name())
        .bind(start)
        .bind(end)
        .bind(serde_json::to_string(&input.details)?)
        .bind(clean_note(input.note))
        .bind(&user.id)
        .bind(now_ms())
        .bind(&id)
        .execute(&state.db)
        .await?;
    let row = get_row(&state.db, &id).await?;
    let json = row.to_json(tz)?;
    state.publish(&row.family_id, "event", "updated", json.clone());
    Ok(Json(json))
}

pub async fn delete(State(state): State<AppState>, user: AuthUser, Path(id): Path<String>) -> AppResult<StatusCode> {
    let (row, tz) = accessible_event(&state, &id, &user).await?;
    let now = now_ms();
    sqlx::query("UPDATE events SET deleted_at = ?, updated_at = ?, updated_by = ?, changed_at = NULL WHERE id = ?")
        .bind(now)
        .bind(now)
        .bind(&user.id)
        .bind(&id)
        .execute(&state.db)
        .await?;
    sqlx::query("DELETE FROM event_photos WHERE event_id = ?").bind(&id).execute(&state.db).await?;
    state.publish(&row.family_id, "event", "deleted", json!({ "id": id, "child_id": row.child_id, "deleted": true, "updated_at": fmt_time(now, tz) }));
    Ok(StatusCode::NO_CONTENT)
}

/// Largest entry photo accepted (the app sends a JPEG of at most 1600 px, a few hundred KB).
pub const PHOTO_LIMIT: usize = 5 * 1024 * 1024;

/// Set an entry's photo: the raw image (JPEG, PNG or WebP) as the request body. The entry's
/// `updated_at` moves too, so `GET /families/{id}/sync` brings the new `photo_version`.
pub async fn put_photo(State(state): State<AppState>, user: AuthUser, Path(id): Path<String>, body: axum::body::Bytes) -> AppResult<Json<Value>> {
    let (row, tz) = accessible_event(&state, &id, &user).await?;
    let Some(content_type) = crate::routes::children::image_type(&body) else {
        return bad("the photo must be a JPEG, PNG or WebP image");
    };
    let now = now_ms();
    let mut tx = state.db.begin().await?;
    sqlx::query(
        "INSERT INTO event_photos (event_id, content_type, data, updated_at) VALUES (?, ?, ?, ?)
         ON CONFLICT(event_id) DO UPDATE SET content_type = excluded.content_type, data = excluded.data, updated_at = excluded.updated_at",
    )
    .bind(&id)
    .bind(content_type)
    .bind(body.as_ref())
    .bind(now)
    .execute(&mut *tx)
    .await?;
    sqlx::query("UPDATE events SET changed_at = COALESCE(changed_at, updated_at), updated_at = ? WHERE id = ?").bind(now).bind(&id).execute(&mut *tx).await?;
    tx.commit().await?;
    let json = get_row(&state.db, &id).await?.to_json(tz)?;
    state.publish(&row.family_id, "event", "updated", json.clone());
    Ok(Json(json))
}

pub async fn get_photo(State(state): State<AppState>, user: AuthUser, Path(id): Path<String>) -> AppResult<axum::response::Response> {
    use axum::{http::header, response::IntoResponse};
    readable_event(&state, &id, &user).await?;
    let row: Option<(String, Vec<u8>)> = sqlx::query_as("SELECT content_type, data FROM event_photos WHERE event_id = ?")
        .bind(&id)
        .fetch_optional(&state.db)
        .await?;
    let Some((content_type, data)) = row else {
        return Err(AppError::NotFound("photo"));
    };
    Ok(([(header::CONTENT_TYPE, content_type), (header::CACHE_CONTROL, "private, no-cache".to_string())], data).into_response())
}

pub async fn delete_photo(State(state): State<AppState>, user: AuthUser, Path(id): Path<String>) -> AppResult<StatusCode> {
    let (row, tz) = accessible_event(&state, &id, &user).await?;
    let gone = sqlx::query("DELETE FROM event_photos WHERE event_id = ?").bind(&id).execute(&state.db).await?;
    if gone.rows_affected() > 0 {
        sqlx::query("UPDATE events SET changed_at = COALESCE(changed_at, updated_at), updated_at = ? WHERE id = ?").bind(now_ms()).bind(&id).execute(&state.db).await?;
        let json = get_row(&state.db, &id).await?.to_json(tz)?;
        state.publish(&row.family_id, "event", "updated", json);
    }
    Ok(StatusCode::NO_CONTENT)
}

#[derive(Deserialize)]
pub struct SyncQuery {
    /// Cursor returned by the previous sync (omit for a full sync).
    since: Option<i64>,
}

/// Incremental sync for offline-capable clients: everything changed since the cursor,
/// including deletions (`{"id": ..., "deleted": true}`).
pub async fn sync(State(state): State<AppState>, user: AuthUser, Path(family_id): Path<String>, ApiQuery(q): ApiQuery<SyncQuery>) -> AppResult<Json<Value>> {
    let book_only = crate::auth::member_role(&state.db, &family_id, &user.id).await? == crate::auth::BOOK_VIEWER;
    let (tz,): (String,) = sqlx::query_as("SELECT timezone FROM families WHERE id = ?")
        .bind(&family_id)
        .fetch_one(&state.db)
        .await?;
    let tz = parse_tz(&tz)?;
    // Small overlap guards against writes landing in the same millisecond as the cursor.
    let cursor = now_ms();
    let since = q.since.unwrap_or(i64::MIN);
    let mut sql = format!("SELECT {EVENT_COLS} FROM events WHERE family_id = ? AND updated_at >= ?");
    if book_only {
        let types = BOOK_TYPES.map(|t| format!("'{t}'")).join(", ");
        sql.push_str(&format!(" AND type IN ({types})"));
    }
    if q.since.is_none() {
        sql.push_str(" AND deleted_at IS NULL");
    }
    sql.push_str(" ORDER BY updated_at");
    let rows = sqlx::query_as::<_, EventRow>(&sql).bind(&family_id).bind(since).fetch_all(&state.db).await?;
    let events = rows.iter().map(|r| r.to_json(tz)).collect::<AppResult<Vec<_>>>()?;
    let mut children = crate::routes::children::children_json(&state, &family_id, tz).await?;
    let timers = if book_only {
        children.iter_mut().for_each(crate::routes::children::book_view);
        vec![]
    } else {
        crate::routes::timers::family_timers(&state, &family_id, tz).await?
    };
    Ok(Json(json!({ "cursor": cursor, "full": q.since.is_none(), "children": children, "events": events, "timers": timers })))
}
