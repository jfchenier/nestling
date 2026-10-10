use axum::{
    extract::{Path, State},
    http::StatusCode,
    Json,
};
use serde::Deserialize;
use serde_json::{json, Value};

use crate::{
    auth::{family_tz, require_member, require_owner, AuthUser},
    error::{bad, ApiJson, AppError, AppResult},
    routes::children::children_json,
    state::AppState,
    trends::{self, DayWindow},
    util::{fmt_time, invite_code, new_id, now_ms, parse_tz},
};

const INVITE_TTL_MS: i64 = 7 * 24 * 3600 * 1000;

pub async fn family_json(state: &AppState, family_id: &str, user_id: &str) -> AppResult<Value> {
    let role = require_member(&state.db, family_id, user_id).await?;
    let (id, name, timezone, created_at, day_start, day_end): (String, String, String, i64, u32, u32) =
        sqlx::query_as("SELECT id, name, timezone, created_at, day_start, day_end FROM families WHERE id = ?")
            .bind(family_id)
            .fetch_one(&state.db)
            .await?;
    let members: Vec<(String, String, String, String)> = sqlx::query_as(
        "SELECT u.id, u.name, u.email, m.role FROM memberships m JOIN users u ON u.id = m.user_id
         WHERE m.family_id = ? ORDER BY m.created_at",
    )
    .bind(family_id)
    .fetch_all(&state.db)
    .await?;
    let tz = parse_tz(&timezone)?;
    Ok(json!({
        "id": id,
        "name": name,
        "timezone": timezone,
        "created_at": fmt_time(created_at, tz),
        "day_start": trends::hhmm(day_start),
        "day_end": trends::hhmm(day_end),
        "role": role,
        "members": members.into_iter().map(|(id, name, email, role)| json!({
            "user_id": id, "name": name, "email": email, "role": role
        })).collect::<Vec<_>>(),
        "children": children_json(state, family_id, tz).await?,
    }))
}

pub async fn list(State(state): State<AppState>, user: AuthUser) -> AppResult<Json<Value>> {
    let ids: Vec<(String,)> = sqlx::query_as(
        "SELECT f.id FROM families f JOIN memberships m ON m.family_id = f.id WHERE m.user_id = ? ORDER BY f.created_at",
    )
    .bind(&user.id)
    .fetch_all(&state.db)
    .await?;
    let mut families = Vec::with_capacity(ids.len());
    for (id,) in ids {
        families.push(family_json(&state, &id, &user.id).await?);
    }
    Ok(Json(json!({ "families": families })))
}

#[derive(Deserialize)]
pub struct CreateFamilyReq {
    name: String,
    #[serde(default)]
    timezone: Option<String>,
}

pub async fn create(State(state): State<AppState>, user: AuthUser, ApiJson(req): ApiJson<CreateFamilyReq>) -> AppResult<(StatusCode, Json<Value>)> {
    if req.name.trim().is_empty() {
        return bad("name is required");
    }
    let timezone = req.timezone.unwrap_or_else(|| "UTC".into());
    parse_tz(&timezone)?;
    let id = new_id();
    let now = now_ms();
    let mut tx = state.db.begin().await?;
    sqlx::query("INSERT INTO families (id, name, timezone, created_at) VALUES (?, ?, ?, ?)")
        .bind(&id)
        .bind(req.name.trim())
        .bind(&timezone)
        .bind(now)
        .execute(&mut *tx)
        .await?;
    sqlx::query("INSERT INTO memberships (family_id, user_id, role, created_at) VALUES (?, ?, 'owner', ?)")
        .bind(&id)
        .bind(&user.id)
        .bind(now)
        .execute(&mut *tx)
        .await?;
    tx.commit().await?;
    Ok((StatusCode::CREATED, Json(family_json(&state, &id, &user.id).await?)))
}

pub async fn get(State(state): State<AppState>, user: AuthUser, Path(id): Path<String>) -> AppResult<Json<Value>> {
    Ok(Json(family_json(&state, &id, &user.id).await?))
}

#[derive(Deserialize)]
pub struct UpdateFamilyReq {
    name: Option<String>,
    timezone: Option<String>,
    /// Daytime for the stats, "HH:MM" local.
    day_start: Option<String>,
    day_end: Option<String>,
}

pub async fn update(State(state): State<AppState>, user: AuthUser, Path(id): Path<String>, ApiJson(req): ApiJson<UpdateFamilyReq>) -> AppResult<Json<Value>> {
    require_member(&state.db, &id, &user.id).await?;
    if let Some(name) = &req.name {
        if name.trim().is_empty() {
            return bad("name cannot be empty");
        }
        sqlx::query("UPDATE families SET name = ? WHERE id = ?").bind(name.trim()).bind(&id).execute(&state.db).await?;
    }
    if let Some(tz) = &req.timezone {
        parse_tz(tz)?;
        sqlx::query("UPDATE families SET timezone = ? WHERE id = ?").bind(tz).bind(&id).execute(&state.db).await?;
    }
    if req.day_start.is_some() || req.day_end.is_some() {
        let (start, end): (u32, u32) = sqlx::query_as("SELECT day_start, day_end FROM families WHERE id = ?").bind(&id).fetch_one(&state.db).await?;
        let parse = |v: &Option<String>, old: u32| match v {
            None => Ok(old),
            Some(s) => trends::parse_hhmm(s).ok_or_else(|| AppError::BadRequest(format!("'{s}' is not a time like '06:00'"))),
        };
        let (start, end) = (parse(&req.day_start, start)?, parse(&req.day_end, end)?);
        let Some(day) = DayWindow::new(start, end) else {
            return bad("daytime must start before it ends");
        };
        sqlx::query("UPDATE families SET day_start = ?, day_end = ? WHERE id = ?").bind(day.start).bind(day.end).bind(&id).execute(&state.db).await?;
    }
    let family = family_json(&state, &id, &user.id).await?;
    state.publish(&id, "family", "updated", json!({ "id": id }));
    Ok(Json(family))
}

pub async fn delete(State(state): State<AppState>, user: AuthUser, Path(id): Path<String>) -> AppResult<StatusCode> {
    require_owner(&state.db, &id, &user.id).await?;
    sqlx::query("DELETE FROM families WHERE id = ?").bind(&id).execute(&state.db).await?;
    state.publish(&id, "family", "deleted", json!({ "id": id }));
    Ok(StatusCode::NO_CONTENT)
}

#[derive(Deserialize, Default)]
pub struct InviteReq {
    #[serde(default)]
    role: Option<String>,
}

pub async fn create_invite(State(state): State<AppState>, user: AuthUser, Path(id): Path<String>, body: axum::body::Bytes) -> AppResult<(StatusCode, Json<Value>)> {
    // The body is optional: an empty POST creates a caregiver invite.
    let req: InviteReq = if body.iter().all(|b| b.is_ascii_whitespace()) {
        InviteReq::default()
    } else {
        serde_json::from_slice(&body).map_err(|e| AppError::BadRequest(format!("invalid JSON: {e}")))?
    };
    let my_role = require_member(&state.db, &id, &user.id).await?;
    let role = req.role.unwrap_or_else(|| "caregiver".into());
    if role != "caregiver" && role != "owner" {
        return bad("role must be 'caregiver' or 'owner'");
    }
    if role == "owner" && my_role != "owner" {
        return Err(AppError::Forbidden("only an owner can invite another owner".into()));
    }
    let code = invite_code();
    let expires_at = now_ms() + INVITE_TTL_MS;
    sqlx::query("INSERT INTO invites (code, family_id, role, created_by, expires_at) VALUES (?, ?, ?, ?, ?)")
        .bind(&code)
        .bind(&id)
        .bind(&role)
        .bind(&user.id)
        .bind(expires_at)
        .execute(&state.db)
        .await?;
    Ok((StatusCode::CREATED, Json(json!({ "code": code, "family_id": id, "role": role,
        "expires_at": fmt_time(expires_at, family_tz(&state.db, &id).await?) }))))
}

pub async fn accept_invite(State(state): State<AppState>, user: AuthUser, Path(code): Path<String>) -> AppResult<Json<Value>> {
    let code = code.trim().to_uppercase();
    let row: Option<(String, String, i64)> = sqlx::query_as("SELECT family_id, role, expires_at FROM invites WHERE code = ?")
        .bind(&code)
        .fetch_optional(&state.db)
        .await?;
    let (family_id, role, expires_at) = row.ok_or(AppError::NotFound("invite"))?;
    if expires_at < now_ms() {
        sqlx::query("DELETE FROM invites WHERE code = ?").bind(&code).execute(&state.db).await?;
        return Err(AppError::NotFound("invite"));
    }
    let mut tx = state.db.begin().await?;
    sqlx::query("INSERT OR IGNORE INTO memberships (family_id, user_id, role, created_at) VALUES (?, ?, ?, ?)")
        .bind(&family_id)
        .bind(&user.id)
        .bind(&role)
        .bind(now_ms())
        .execute(&mut *tx)
        .await?;
    sqlx::query("DELETE FROM invites WHERE code = ?").bind(&code).execute(&mut *tx).await?;
    tx.commit().await?;
    state.publish(&family_id, "family", "updated", json!({ "id": family_id }));
    Ok(Json(family_json(&state, &family_id, &user.id).await?))
}

pub async fn remove_member(State(state): State<AppState>, user: AuthUser, Path((family_id, member_id)): Path<(String, String)>) -> AppResult<StatusCode> {
    let my_role = require_member(&state.db, &family_id, &user.id).await?;
    if member_id != user.id && my_role != "owner" {
        return Err(AppError::Forbidden("only an owner can remove other members".into()));
    }
    let target_role = require_member(&state.db, &family_id, &member_id)
        .await
        .map_err(|_| AppError::NotFound("member"))?;
    if target_role == "owner" {
        let (owners,): (i64,) = sqlx::query_as("SELECT COUNT(*) FROM memberships WHERE family_id = ? AND role = 'owner'")
            .bind(&family_id)
            .fetch_one(&state.db)
            .await?;
        if owners <= 1 {
            return Err(AppError::Conflict("a family needs at least one owner; delete the family instead".into()));
        }
    }
    sqlx::query("DELETE FROM memberships WHERE family_id = ? AND user_id = ?")
        .bind(&family_id)
        .bind(&member_id)
        .execute(&state.db)
        .await?;
    state.publish(&family_id, "family", "updated", json!({ "id": family_id }));
    Ok(StatusCode::NO_CONTENT)
}
