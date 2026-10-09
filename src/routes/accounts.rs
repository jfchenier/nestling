use axum::{
    extract::{Path, State},
    http::StatusCode,
    Json,
};
use serde::Deserialize;
use serde_json::{json, Value};

use crate::{
    auth::{hash_password, issue_token, verify_password, AuthUser},
    error::{bad, ApiJson, AppError, AppResult},
    state::AppState,
    util::{new_id, now_ms},
};

#[derive(Deserialize)]
pub struct RegisterReq {
    email: String,
    password: String,
    name: String,
    #[serde(default)]
    units: Option<String>,
}

#[derive(Deserialize)]
pub struct LoginReq {
    email: String,
    password: String,
}

fn check_units(units: &str) -> AppResult<()> {
    if units != "metric" && units != "imperial" {
        return bad("units must be 'metric' or 'imperial'");
    }
    Ok(())
}

pub(crate) async fn user_json(state: &AppState, user_id: &str) -> AppResult<Value> {
    let (id, email, name, units, is_admin): (String, String, String, String, bool) =
        sqlx::query_as("SELECT id, email, name, units, is_admin FROM users WHERE id = ?")
            .bind(user_id)
            .fetch_one(&state.db)
            .await?;
    Ok(json!({ "id": id, "email": email, "name": name, "units": units, "is_admin": is_admin }))
}

/// Shared checks for a new account's email, password and name. Returns the normalized email.
pub(crate) fn check_new_account(email: &str, password: &str, name: &str) -> AppResult<String> {
    let email = email.trim().to_lowercase();
    if !email.contains('@') || email.len() < 3 {
        return bad("a valid email is required");
    }
    if password.chars().count() < 8 {
        return bad("password must be at least 8 characters");
    }
    if name.trim().is_empty() {
        return bad("name is required");
    }
    Ok(email)
}

pub(crate) async fn insert_user(state: &AppState, email: &str, name: &str, password: &str, units: &str, is_admin: bool) -> AppResult<String> {
    let exists: Option<(String,)> = sqlx::query_as("SELECT id FROM users WHERE email = ?")
        .bind(email)
        .fetch_optional(&state.db)
        .await?;
    if exists.is_some() {
        return Err(AppError::Conflict("an account with this email already exists".into()));
    }
    let id = new_id();
    sqlx::query("INSERT INTO users (id, email, name, password_hash, units, created_at, is_admin) VALUES (?, ?, ?, ?, ?, ?, ?)")
        .bind(&id)
        .bind(email)
        .bind(name.trim())
        .bind(hash_password(password)?)
        .bind(units)
        .bind(now_ms())
        .bind(is_admin)
        .execute(&state.db)
        .await?;
    Ok(id)
}

/// Public: whether the server still needs its first (admin) account, and whether anyone may sign up.
pub async fn setup_status(State(state): State<AppState>) -> AppResult<Json<Value>> {
    let (users,): (i64,) = sqlx::query_as("SELECT COUNT(*) FROM users").fetch_one(&state.db).await?;
    Ok(Json(json!({ "needs_setup": users == 0, "open_registration": users == 0 || state.config.open_registration })))
}

/// Sign up. The first account on a server is its admin; after that only admins create accounts
/// (`/admin/users`), unless NESTLING_OPEN_REGISTRATION is on.
pub async fn register(State(state): State<AppState>, ApiJson(req): ApiJson<RegisterReq>) -> AppResult<(StatusCode, Json<Value>)> {
    let email = check_new_account(&req.email, &req.password, &req.name)?;
    let units = req.units.unwrap_or_else(|| "metric".into());
    check_units(&units)?;

    let (user_count,): (i64,) = sqlx::query_as("SELECT COUNT(*) FROM users").fetch_one(&state.db).await?;
    if user_count > 0 && !state.config.open_registration {
        return Err(AppError::Forbidden("sign-up is closed on this server: ask its admin for an account".into()));
    }
    let id = insert_user(&state, &email, &req.name, &req.password, &units, user_count == 0).await?;
    let (_, token) = issue_token(&state.db, &id, "login", "session").await?;
    Ok((StatusCode::CREATED, Json(json!({ "token": token, "user": user_json(&state, &id).await? }))))
}

pub async fn login(State(state): State<AppState>, ApiJson(req): ApiJson<LoginReq>) -> AppResult<Json<Value>> {
    let row: Option<(String, String)> = sqlx::query_as("SELECT id, password_hash FROM users WHERE email = ?")
        .bind(req.email.trim().to_lowercase())
        .fetch_optional(&state.db)
        .await?;
    let Some((id, hash)) = row.filter(|(_, h)| verify_password(&req.password, h)) else {
        return Err(AppError::BadRequest("wrong email or password".into()));
    };
    let _ = hash;
    let (_, token) = issue_token(&state.db, &id, "login", "session").await?;
    Ok(Json(json!({ "token": token, "user": user_json(&state, &id).await? })))
}

pub async fn logout(State(state): State<AppState>, user: AuthUser) -> AppResult<StatusCode> {
    sqlx::query("DELETE FROM tokens WHERE token_hash = ?")
        .bind(&user.token_hash)
        .execute(&state.db)
        .await?;
    Ok(StatusCode::NO_CONTENT)
}

pub async fn me(State(state): State<AppState>, user: AuthUser) -> AppResult<Json<Value>> {
    let mut me = user_json(&state, &user.id).await?;
    let families: Vec<(String, String, String)> = sqlx::query_as(
        "SELECT f.id, f.name, m.role FROM families f JOIN memberships m ON m.family_id = f.id
         WHERE m.user_id = ? ORDER BY f.created_at",
    )
    .bind(&user.id)
    .fetch_all(&state.db)
    .await?;
    me["families"] = families
        .into_iter()
        .map(|(id, name, role)| json!({ "id": id, "name": name, "role": role }))
        .collect();
    Ok(Json(me))
}

#[derive(Deserialize)]
pub struct UpdateMeReq {
    name: Option<String>,
    units: Option<String>,
    password: Option<String>,
    current_password: Option<String>,
}

pub async fn update_me(State(state): State<AppState>, user: AuthUser, ApiJson(req): ApiJson<UpdateMeReq>) -> AppResult<Json<Value>> {
    if let Some(name) = &req.name {
        if name.trim().is_empty() {
            return bad("name cannot be empty");
        }
        sqlx::query("UPDATE users SET name = ? WHERE id = ?").bind(name.trim()).bind(&user.id).execute(&state.db).await?;
    }
    if let Some(units) = &req.units {
        check_units(units)?;
        sqlx::query("UPDATE users SET units = ? WHERE id = ?").bind(units).bind(&user.id).execute(&state.db).await?;
    }
    if let Some(password) = &req.password {
        let (hash,): (String,) = sqlx::query_as("SELECT password_hash FROM users WHERE id = ?")
            .bind(&user.id)
            .fetch_one(&state.db)
            .await?;
        let current = req.current_password.as_deref().unwrap_or("");
        if !verify_password(current, &hash) {
            return bad("current_password is wrong");
        }
        if password.chars().count() < 8 {
            return bad("password must be at least 8 characters");
        }
        sqlx::query("UPDATE users SET password_hash = ? WHERE id = ?")
            .bind(hash_password(password)?)
            .bind(&user.id)
            .execute(&state.db)
            .await?;
        // Sign out other sessions, keep this one and API tokens.
        sqlx::query("DELETE FROM tokens WHERE user_id = ? AND kind = 'session' AND token_hash != ?")
            .bind(&user.id)
            .bind(&user.token_hash)
            .execute(&state.db)
            .await?;
    }
    Ok(Json(user_json(&state, &user.id).await?))
}

pub async fn list_tokens(State(state): State<AppState>, user: AuthUser) -> AppResult<Json<Value>> {
    let rows: Vec<(String, String, String, i64, Option<i64>, String)> = sqlx::query_as(
        "SELECT id, name, kind, created_at, last_used_at, token_hash FROM tokens WHERE user_id = ? ORDER BY created_at",
    )
    .bind(&user.id)
    .fetch_all(&state.db)
    .await?;
    let tokens: Vec<Value> = rows
        .into_iter()
        .map(|(id, name, kind, created, used, hash)| {
            json!({ "id": id, "name": name, "kind": kind, "created_at": created,
                    "last_used_at": used, "current": hash == user.token_hash })
        })
        .collect();
    Ok(Json(json!({ "tokens": tokens })))
}

#[derive(Deserialize)]
pub struct CreateTokenReq {
    name: String,
}

pub async fn create_token(State(state): State<AppState>, user: AuthUser, ApiJson(req): ApiJson<CreateTokenReq>) -> AppResult<(StatusCode, Json<Value>)> {
    if req.name.trim().is_empty() {
        return bad("name is required (e.g. 'Home Assistant')");
    }
    let (id, token) = issue_token(&state.db, &user.id, req.name.trim(), "api").await?;
    Ok((StatusCode::CREATED, Json(json!({ "id": id, "name": req.name.trim(), "token": token }))))
}

pub async fn delete_token(State(state): State<AppState>, user: AuthUser, Path(id): Path<String>) -> AppResult<StatusCode> {
    let res = sqlx::query("DELETE FROM tokens WHERE id = ? AND user_id = ?")
        .bind(&id)
        .bind(&user.id)
        .execute(&state.db)
        .await?;
    if res.rows_affected() == 0 {
        return Err(AppError::NotFound("token"));
    }
    Ok(StatusCode::NO_CONTENT)
}
