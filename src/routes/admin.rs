//! Server administration: admins create and manage the accounts (sign-up is closed after the
//! first account, which is the first admin).

use axum::{
    extract::{Path, State},
    http::StatusCode,
    Json,
};
use chrono::{TimeZone, Utc};
use serde::Deserialize;
use serde_json::{json, Value};

use crate::{
    auth::{hash_password, AuthUser},
    error::{bad, ApiJson, AppError, AppResult},
    routes::accounts::{check_new_account, insert_user, user_json},
    state::AppState,
    util::now_ms,
};

async fn require_admin(state: &AppState, user: &AuthUser) -> AppResult<()> {
    let (is_admin,): (bool,) = sqlx::query_as("SELECT is_admin FROM users WHERE id = ?")
        .bind(&user.id)
        .fetch_one(&state.db)
        .await?;
    if is_admin {
        Ok(())
    } else {
        Err(AppError::Forbidden("only a server admin can manage accounts".into()))
    }
}

async fn admin_count(state: &AppState) -> AppResult<i64> {
    let (n,): (i64,) = sqlx::query_as("SELECT COUNT(*) FROM users WHERE is_admin = 1").fetch_one(&state.db).await?;
    Ok(n)
}

fn rfc3339(ms: i64) -> String {
    Utc.timestamp_millis_opt(ms).single().map(|t| t.to_rfc3339()).unwrap_or_default()
}

/// Every account on the server, with its families.
pub async fn list_users(State(state): State<AppState>, user: AuthUser) -> AppResult<Json<Value>> {
    require_admin(&state, &user).await?;
    let rows: Vec<(String, String, String, bool, i64)> =
        sqlx::query_as("SELECT id, email, name, is_admin, created_at FROM users ORDER BY created_at, rowid")
            .fetch_all(&state.db)
            .await?;
    let families: Vec<(String, String, String, String)> = sqlx::query_as(
        "SELECT m.user_id, f.id, f.name, m.role FROM memberships m JOIN families f ON f.id = m.family_id ORDER BY f.created_at",
    )
    .fetch_all(&state.db)
    .await?;
    let users: Vec<Value> = rows
        .into_iter()
        .map(|(id, email, name, is_admin, created)| {
            let fams: Vec<Value> = families
                .iter()
                .filter(|(uid, ..)| *uid == id)
                .map(|(_, fid, fname, role)| json!({ "id": fid, "name": fname, "role": role }))
                .collect();
            json!({ "id": id, "email": email, "name": name, "is_admin": is_admin,
                    "created_at": rfc3339(created), "families": fams, "you": id == user.id })
        })
        .collect();
    Ok(Json(json!({ "users": users })))
}

#[derive(Deserialize)]
pub struct CreateUserReq {
    email: String,
    name: String,
    password: String,
    #[serde(default)]
    is_admin: bool,
    /// Add the new account to this family as a caregiver (saves an invite code).
    #[serde(default)]
    family_id: Option<String>,
}

pub async fn create_user(State(state): State<AppState>, user: AuthUser, ApiJson(req): ApiJson<CreateUserReq>) -> AppResult<(StatusCode, Json<Value>)> {
    require_admin(&state, &user).await?;
    let email = check_new_account(&req.email, &req.password, &req.name)?;
    if let Some(fid) = &req.family_id {
        let exists: Option<(String,)> = sqlx::query_as("SELECT id FROM families WHERE id = ?").bind(fid).fetch_optional(&state.db).await?;
        if exists.is_none() {
            return Err(AppError::NotFound("family"));
        }
    }
    let id = insert_user(&state, &email, &req.name, &req.password, "metric", req.is_admin).await?;
    if let Some(fid) = &req.family_id {
        sqlx::query("INSERT INTO memberships (family_id, user_id, role, created_at) VALUES (?, ?, 'caregiver', ?)")
            .bind(fid)
            .bind(&id)
            .bind(now_ms())
            .execute(&state.db)
            .await?;
    }
    Ok((StatusCode::CREATED, Json(user_json(&state, &id).await?)))
}

#[derive(Deserialize)]
pub struct UpdateUserReq {
    name: Option<String>,
    is_admin: Option<bool>,
    /// New password (e.g. they forgot theirs); signs them out everywhere.
    password: Option<String>,
}

pub async fn update_user(
    State(state): State<AppState>,
    user: AuthUser,
    Path(id): Path<String>,
    ApiJson(req): ApiJson<UpdateUserReq>,
) -> AppResult<Json<Value>> {
    require_admin(&state, &user).await?;
    let target: Option<(bool,)> = sqlx::query_as("SELECT is_admin FROM users WHERE id = ?").bind(&id).fetch_optional(&state.db).await?;
    let Some((was_admin,)) = target else {
        return Err(AppError::NotFound("user"));
    };
    if let Some(name) = &req.name {
        if name.trim().is_empty() {
            return bad("name cannot be empty");
        }
        sqlx::query("UPDATE users SET name = ? WHERE id = ?").bind(name.trim()).bind(&id).execute(&state.db).await?;
    }
    if let Some(admin) = req.is_admin {
        if was_admin && !admin && admin_count(&state).await? <= 1 {
            return bad("the server needs at least one admin");
        }
        sqlx::query("UPDATE users SET is_admin = ? WHERE id = ?").bind(admin).bind(&id).execute(&state.db).await?;
    }
    if let Some(password) = &req.password {
        if password.chars().count() < 8 {
            return bad("password must be at least 8 characters");
        }
        sqlx::query("UPDATE users SET password_hash = ? WHERE id = ?")
            .bind(hash_password(password)?)
            .bind(&id)
            .execute(&state.db)
            .await?;
        if id != user.id {
            sqlx::query("DELETE FROM tokens WHERE user_id = ? AND kind = 'session'").bind(&id).execute(&state.db).await?;
        }
    }
    Ok(Json(user_json(&state, &id).await?))
}

/// Delete an account (its sessions and memberships go with it; the families and their data stay).
pub async fn delete_user(State(state): State<AppState>, user: AuthUser, Path(id): Path<String>) -> AppResult<StatusCode> {
    require_admin(&state, &user).await?;
    if id == user.id {
        return bad("you can't delete your own account");
    }
    let res = sqlx::query("DELETE FROM users WHERE id = ?").bind(&id).execute(&state.db).await?;
    if res.rows_affected() == 0 {
        return Err(AppError::NotFound("user"));
    }
    Ok(StatusCode::NO_CONTENT)
}
