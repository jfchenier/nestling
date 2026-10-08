use argon2::{
    password_hash::{PasswordHash, PasswordHasher, PasswordVerifier, SaltString},
    Argon2,
};
use axum::{extract::FromRequestParts, http::request::Parts};
use chrono_tz::Tz;
use sqlx::SqlitePool;

use crate::{
    error::{AppError, AppResult},
    state::AppState,
    util::{new_id, now_ms, parse_tz, random_token, sha256_hex},
};

pub fn hash_password(password: &str) -> AppResult<String> {
    let salt = SaltString::generate(&mut rand::rngs::OsRng);
    Argon2::default()
        .hash_password(password.as_bytes(), &salt)
        .map(|h| h.to_string())
        .map_err(|e| AppError::Other(anyhow::anyhow!("hashing failed: {e}")))
}

pub fn verify_password(password: &str, hash: &str) -> bool {
    match PasswordHash::new(hash) {
        Ok(parsed) => Argon2::default().verify_password(password.as_bytes(), &parsed).is_ok(),
        Err(_) => false,
    }
}

/// Create a token for a user. Returns (token id, plaintext token).
pub async fn issue_token(db: &SqlitePool, user_id: &str, name: &str, kind: &str) -> AppResult<(String, String)> {
    let id = new_id();
    let token = random_token();
    sqlx::query("INSERT INTO tokens (id, token_hash, user_id, name, kind, created_at) VALUES (?, ?, ?, ?, ?, ?)")
        .bind(&id)
        .bind(sha256_hex(&token))
        .bind(user_id)
        .bind(name)
        .bind(kind)
        .bind(now_ms())
        .execute(db)
        .await?;
    Ok((id, token))
}

/// The authenticated caller. Accepts `Authorization: Bearer <token>`, or
/// `?access_token=<token>` (for EventSource, which cannot set headers).
#[derive(Debug, Clone)]
pub struct AuthUser {
    pub id: String,
    pub name: String,
    pub email: String,
    pub token_hash: String,
}

fn token_from_parts(parts: &Parts) -> Option<String> {
    if let Some(v) = parts.headers.get(axum::http::header::AUTHORIZATION) {
        if let Ok(s) = v.to_str() {
            if let Some(t) = s.strip_prefix("Bearer ").or_else(|| s.strip_prefix("bearer ")) {
                return Some(t.trim().to_string());
            }
        }
    }
    parts.uri.query().and_then(|q| {
        q.split('&')
            .find_map(|kv| kv.strip_prefix("access_token="))
            .map(|t| t.to_string())
    })
}

impl FromRequestParts<AppState> for AuthUser {
    type Rejection = AppError;

    async fn from_request_parts(parts: &mut Parts, state: &AppState) -> Result<Self, Self::Rejection> {
        let token = token_from_parts(parts).ok_or(AppError::Unauthorized)?;
        let token_hash = sha256_hex(&token);
        let row: Option<(String, String, String)> = sqlx::query_as(
            "SELECT u.id, u.name, u.email FROM tokens t JOIN users u ON u.id = t.user_id WHERE t.token_hash = ?",
        )
        .bind(&token_hash)
        .fetch_optional(&state.db)
        .await?;
        let (id, name, email) = row.ok_or(AppError::Unauthorized)?;
        sqlx::query("UPDATE tokens SET last_used_at = ? WHERE token_hash = ?")
            .bind(now_ms())
            .bind(&token_hash)
            .execute(&state.db)
            .await?;
        Ok(AuthUser { id, name, email, token_hash })
    }
}

/// Returns the caller's role in the family, or 404 if they are not a member
/// (so family ids can't be probed).
pub async fn require_member(db: &SqlitePool, family_id: &str, user_id: &str) -> AppResult<String> {
    let role: Option<(String,)> = sqlx::query_as("SELECT role FROM memberships WHERE family_id = ? AND user_id = ?")
        .bind(family_id)
        .bind(user_id)
        .fetch_optional(db)
        .await?;
    role.map(|r| r.0).ok_or(AppError::NotFound("family"))
}

pub async fn require_owner(db: &SqlitePool, family_id: &str, user_id: &str) -> AppResult<()> {
    if require_member(db, family_id, user_id).await? != "owner" {
        return Err(AppError::Forbidden("only a family owner can do this".into()));
    }
    Ok(())
}

pub async fn family_tz(db: &SqlitePool, family_id: &str) -> AppResult<Tz> {
    let (tz,): (String,) = sqlx::query_as("SELECT timezone FROM families WHERE id = ?")
        .bind(family_id)
        .fetch_optional(db)
        .await?
        .ok_or(AppError::NotFound("family"))?;
    parse_tz(&tz)
}

/// Context for a child the caller can access.
pub struct ChildCtx {
    pub child_id: String,
    pub family_id: String,
    pub tz: Tz,
}

pub async fn child_access(db: &SqlitePool, child_id: &str, user_id: &str) -> AppResult<ChildCtx> {
    let row: Option<(String, String)> = sqlx::query_as(
        "SELECT c.family_id, f.timezone FROM children c
         JOIN families f ON f.id = c.family_id
         JOIN memberships m ON m.family_id = c.family_id AND m.user_id = ?
         WHERE c.id = ?",
    )
    .bind(user_id)
    .bind(child_id)
    .fetch_optional(db)
    .await?;
    let (family_id, tz) = row.ok_or(AppError::NotFound("child"))?;
    Ok(ChildCtx { child_id: child_id.to_string(), family_id, tz: parse_tz(&tz)? })
}
