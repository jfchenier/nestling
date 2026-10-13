//! Connected apps (e.g. Home Assistant): family members that are not a person. An owner adds
//! one and gets its API token once; its entries show its name as the caregiver. It can only log
//! entries and use timers (`auth::integration_may`).

use axum::{
    extract::{Path, State},
    http::StatusCode,
    Json,
};
use serde::Deserialize;
use sqlx::SqlitePool;
use serde_json::{json, Value};

use crate::{
    auth::{issue_token, require_owner, AuthUser, INTEGRATION},
    error::{bad, ApiJson, AppError, AppResult},
    state::AppState,
    util::{fmt_utc, new_id, now_ms},
};

/// The family's connected apps (owners only).
pub async fn list(State(state): State<AppState>, user: AuthUser, Path(family_id): Path<String>) -> AppResult<Json<Value>> {
    require_owner(&state.db, &family_id, &user.id).await?;
    let rows: Vec<(String, String, i64, Option<i64>)> = sqlx::query_as(
        "SELECT u.id, u.name, u.created_at, (SELECT MAX(t.last_used_at) FROM tokens t WHERE t.user_id = u.id)
         FROM memberships m JOIN users u ON u.id = m.user_id
         WHERE m.family_id = ? AND u.kind = 'integration' ORDER BY u.created_at, u.rowid",
    )
    .bind(&family_id)
    .fetch_all(&state.db)
    .await?;
    let integrations: Vec<Value> = rows
        .into_iter()
        .map(|(id, name, created, used)| json!({ "id": id, "name": name, "created_at": fmt_utc(created), "last_used_at": used.map(fmt_utc) }))
        .collect();
    Ok(Json(json!({ "integrations": integrations })))
}

#[derive(Deserialize)]
pub struct CreateReq {
    name: String,
}

/// Add a connected app to the family (owners only). The token is only shown in this answer.
pub async fn create(
    State(state): State<AppState>,
    user: AuthUser,
    Path(family_id): Path<String>,
    ApiJson(req): ApiJson<CreateReq>,
) -> AppResult<(StatusCode, Json<Value>)> {
    require_owner(&state.db, &family_id, &user.id).await?;
    let name = req.name.trim();
    if name.is_empty() || name.chars().count() > 60 {
        return bad("name is required (e.g. 'Home Assistant'), 60 characters at most");
    }
    let (id, now) = add(&state.db, &family_id, name).await?;
    let (_, token) = issue_token(&state.db, &id, name, "api").await?;
    state.publish(&family_id, "family", "updated", json!({ "id": family_id }));
    Ok((
        StatusCode::CREATED,
        Json(json!({ "id": id, "name": name, "created_at": fmt_utc(now), "last_used_at": null, "token": token })),
    ))
}

/// Add a connected app named `name` to the family (no checks: callers check the owner and name).
/// Returns its user id and creation time; it has no token yet.
pub async fn add(db: &SqlitePool, family_id: &str, name: &str) -> AppResult<(String, i64)> {
    let id = new_id();
    let now = now_ms();
    let mut tx = db.begin().await?;
    // No password (an empty hash never verifies) and an address nobody can sign in with.
    sqlx::query("INSERT INTO users (id, email, name, password_hash, units, created_at, kind) VALUES (?, ?, ?, '', 'metric', ?, ?)")
        .bind(&id)
        .bind(format!("{id}@integration.invalid"))
        .bind(name)
        .bind(now)
        .bind(INTEGRATION)
        .execute(&mut *tx)
        .await?;
    sqlx::query("INSERT INTO memberships (family_id, user_id, role, created_at) VALUES (?, ?, ?, ?)")
        .bind(family_id)
        .bind(&id)
        .bind(INTEGRATION)
        .bind(now)
        .execute(&mut *tx)
        .await?;
    tx.commit().await?;
    Ok((id, now))
}

/// Remove a connected app (owners only): its token stops working at once. The entries it
/// logged stay, still under its name.
pub async fn delete(
    State(state): State<AppState>,
    user: AuthUser,
    Path((family_id, id)): Path<(String, String)>,
) -> AppResult<StatusCode> {
    require_owner(&state.db, &family_id, &user.id).await?;
    let mut tx = state.db.begin().await?;
    let res = sqlx::query(
        "DELETE FROM memberships WHERE family_id = ? AND user_id = ?
         AND user_id IN (SELECT id FROM users WHERE kind = 'integration')",
    )
    .bind(&family_id)
    .bind(&id)
    .execute(&mut *tx)
    .await?;
    if res.rows_affected() == 0 {
        return Err(AppError::NotFound("integration"));
    }
    sqlx::query("DELETE FROM tokens WHERE user_id = ?").bind(&id).execute(&mut *tx).await?;
    tx.commit().await?;
    state.publish(&family_id, "family", "updated", json!({ "id": family_id }));
    Ok(StatusCode::NO_CONTENT)
}
