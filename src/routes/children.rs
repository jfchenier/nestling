use axum::{
    extract::{Path, State},
    http::StatusCode,
    Json,
};
use chrono::NaiveDate;
use chrono_tz::Tz;
use serde::Deserialize;
use serde_json::{json, Value};

use crate::{
    auth::{child_access, family_tz, require_member, AuthUser},
    error::{bad, ApiJson, AppResult},
    state::AppState,
    util::{fmt_time, new_id, now_ms},
};

type ChildRow = (String, String, String, Option<String>, Option<String>, i64, i64, Option<i64>);

fn child_value(row: ChildRow, tz: Tz) -> Value {
    let (id, family_id, name, birth_date, sex, created_at, updated_at, photo_version) = row;
    json!({
        "id": id, "family_id": family_id, "name": name, "birth_date": birth_date, "sex": sex,
        "created_at": fmt_time(created_at, tz), "updated_at": fmt_time(updated_at, tz),
        // Changes whenever the photo does (null: no photo); fetch it from /children/{id}/photo.
        "photo_version": photo_version,
    })
}

const CHILD_COLS: &str = "id, family_id, name, birth_date, sex, created_at, updated_at, \
    (SELECT p.updated_at FROM child_photos p WHERE p.child_id = children.id) AS photo_version";

pub async fn children_json(state: &AppState, family_id: &str, tz: Tz) -> AppResult<Vec<Value>> {
    let rows: Vec<ChildRow> = sqlx::query_as(&format!("SELECT {CHILD_COLS} FROM children WHERE family_id = ? ORDER BY created_at"))
        .bind(family_id)
        .fetch_all(&state.db)
        .await?;
    Ok(rows.into_iter().map(|r| child_value(r, tz)).collect())
}

pub async fn child_json(state: &AppState, child_id: &str, tz: Tz) -> AppResult<Value> {
    let row: ChildRow = sqlx::query_as(&format!("SELECT {CHILD_COLS} FROM children WHERE id = ?"))
        .bind(child_id)
        .fetch_one(&state.db)
        .await?;
    Ok(child_value(row, tz))
}

fn check_sex(sex: &Option<String>) -> AppResult<()> {
    match sex.as_deref() {
        None | Some("female") | Some("male") | Some("other") => Ok(()),
        Some(_) => bad("sex must be 'female', 'male' or 'other'"),
    }
}

/// Insert a child; used by the API and the Nara importer.
pub async fn insert_child(state: &AppState, family_id: &str, name: &str, birth_date: Option<NaiveDate>, sex: Option<String>) -> AppResult<String> {
    let id = new_id();
    let now = now_ms();
    sqlx::query("INSERT INTO children (id, family_id, name, birth_date, sex, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?)")
        .bind(&id)
        .bind(family_id)
        .bind(name)
        .bind(birth_date.map(|d| d.to_string()))
        .bind(sex)
        .bind(now)
        .bind(now)
        .execute(&state.db)
        .await?;
    Ok(id)
}

pub async fn list(State(state): State<AppState>, user: AuthUser, Path(family_id): Path<String>) -> AppResult<Json<Value>> {
    require_member(&state.db, &family_id, &user.id).await?;
    let tz = family_tz(&state.db, &family_id).await?;
    Ok(Json(json!({ "children": children_json(&state, &family_id, tz).await? })))
}

#[derive(Deserialize)]
pub struct CreateChildReq {
    name: String,
    #[serde(default)]
    birth_date: Option<NaiveDate>,
    #[serde(default)]
    sex: Option<String>,
}

pub async fn create(State(state): State<AppState>, user: AuthUser, Path(family_id): Path<String>, ApiJson(req): ApiJson<CreateChildReq>) -> AppResult<(StatusCode, Json<Value>)> {
    require_member(&state.db, &family_id, &user.id).await?;
    if req.name.trim().is_empty() {
        return bad("name is required");
    }
    // Required for new babies; existing ones (and Nara imports) may still have none.
    if req.birth_date.is_none() {
        return bad("birth_date is required");
    }
    check_sex(&req.sex)?;
    let id = insert_child(&state, &family_id, req.name.trim(), req.birth_date, req.sex).await?;
    let tz = family_tz(&state.db, &family_id).await?;
    let child = child_json(&state, &id, tz).await?;
    state.publish(&family_id, "child", "created", child.clone());
    Ok((StatusCode::CREATED, Json(child)))
}

pub async fn get(State(state): State<AppState>, user: AuthUser, Path(child_id): Path<String>) -> AppResult<Json<Value>> {
    let ctx = child_access(&state.db, &child_id, &user.id).await?;
    Ok(Json(child_json(&state, &child_id, ctx.tz).await?))
}

/// `birth_date` / `sex` can be cleared by sending null.
#[derive(Deserialize)]
pub struct UpdateChildReq {
    name: Option<String>,
    #[serde(default, deserialize_with = "double_option")]
    birth_date: Option<Option<NaiveDate>>,
    #[serde(default, deserialize_with = "double_option")]
    sex: Option<Option<String>>,
}

fn double_option<'de, T, D>(d: D) -> Result<Option<Option<T>>, D::Error>
where
    T: serde::Deserialize<'de>,
    D: serde::Deserializer<'de>,
{
    Option::<T>::deserialize(d).map(Some)
}

pub async fn update(State(state): State<AppState>, user: AuthUser, Path(child_id): Path<String>, ApiJson(req): ApiJson<UpdateChildReq>) -> AppResult<Json<Value>> {
    let ctx = child_access(&state.db, &child_id, &user.id).await?;
    if let Some(name) = &req.name {
        if name.trim().is_empty() {
            return bad("name cannot be empty");
        }
        sqlx::query("UPDATE children SET name = ? WHERE id = ?").bind(name.trim()).bind(&child_id).execute(&state.db).await?;
    }
    if let Some(bd) = req.birth_date {
        sqlx::query("UPDATE children SET birth_date = ? WHERE id = ?")
            .bind(bd.map(|d| d.to_string()))
            .bind(&child_id)
            .execute(&state.db)
            .await?;
    }
    if let Some(sex) = req.sex {
        check_sex(&sex)?;
        sqlx::query("UPDATE children SET sex = ? WHERE id = ?").bind(sex).bind(&child_id).execute(&state.db).await?;
    }
    sqlx::query("UPDATE children SET updated_at = ? WHERE id = ?").bind(now_ms()).bind(&child_id).execute(&state.db).await?;
    let child = child_json(&state, &child_id, ctx.tz).await?;
    state.publish(&ctx.family_id, "child", "updated", child.clone());
    Ok(Json(child))
}

pub async fn delete(State(state): State<AppState>, user: AuthUser, Path(child_id): Path<String>) -> AppResult<StatusCode> {
    let ctx = child_access(&state.db, &child_id, &user.id).await?;
    sqlx::query("DELETE FROM children WHERE id = ?").bind(&child_id).execute(&state.db).await?;
    state.publish(&ctx.family_id, "child", "deleted", json!({ "id": child_id }));
    Ok(StatusCode::NO_CONTENT)
}

/// Largest profile picture accepted (the app sends a ~512 px square, far smaller).
pub const PHOTO_LIMIT: usize = 5 * 1024 * 1024;

/// Image type from the file's first bytes (the Content-Type header isn't trusted).
fn image_type(data: &[u8]) -> Option<&'static str> {
    match data {
        [0xFF, 0xD8, 0xFF, ..] => Some("image/jpeg"),
        [0x89, b'P', b'N', b'G', ..] => Some("image/png"),
        [b'R', b'I', b'F', b'F', _, _, _, _, b'W', b'E', b'B', b'P', ..] => Some("image/webp"),
        _ => None,
    }
}

/// Set the profile picture: the raw image (JPEG, PNG or WebP) as the request body.
pub async fn put_photo(State(state): State<AppState>, user: AuthUser, Path(child_id): Path<String>, body: axum::body::Bytes) -> AppResult<Json<Value>> {
    let ctx = child_access(&state.db, &child_id, &user.id).await?;
    let Some(content_type) = image_type(&body) else {
        return bad("the photo must be a JPEG, PNG or WebP image");
    };
    let now = now_ms();
    sqlx::query(
        "INSERT INTO child_photos (child_id, content_type, data, updated_at) VALUES (?, ?, ?, ?)
         ON CONFLICT(child_id) DO UPDATE SET content_type = excluded.content_type, data = excluded.data, updated_at = excluded.updated_at",
    )
    .bind(&child_id)
    .bind(content_type)
    .bind(body.as_ref())
    .bind(now)
    .execute(&state.db)
    .await?;
    let json = child_json(&state, &child_id, ctx.tz).await?;
    state.publish(&ctx.family_id, "child", "updated", json.clone());
    Ok(Json(json))
}

pub async fn get_photo(State(state): State<AppState>, user: AuthUser, Path(child_id): Path<String>) -> AppResult<axum::response::Response> {
    use axum::{http::header, response::IntoResponse};
    child_access(&state.db, &child_id, &user.id).await?;
    let row: Option<(String, Vec<u8>)> = sqlx::query_as("SELECT content_type, data FROM child_photos WHERE child_id = ?")
        .bind(&child_id)
        .fetch_optional(&state.db)
        .await?;
    let Some((content_type, data)) = row else {
        return Err(crate::error::AppError::NotFound("photo"));
    };
    Ok(([(header::CONTENT_TYPE, content_type), (header::CACHE_CONTROL, "private, no-cache".to_string())], data).into_response())
}

pub async fn delete_photo(State(state): State<AppState>, user: AuthUser, Path(child_id): Path<String>) -> AppResult<StatusCode> {
    let ctx = child_access(&state.db, &child_id, &user.id).await?;
    sqlx::query("DELETE FROM child_photos WHERE child_id = ?").bind(&child_id).execute(&state.db).await?;
    let json = child_json(&state, &child_id, ctx.tz).await?;
    state.publish(&ctx.family_id, "child", "updated", json);
    Ok(StatusCode::NO_CONTENT)
}

#[cfg(test)]
mod tests {
    use super::image_type;

    #[test]
    fn sniffs_images() {
        assert_eq!(image_type(&[0xFF, 0xD8, 0xFF, 0xE0]), Some("image/jpeg"));
        assert_eq!(image_type(b"\x89PNG\r\n"), Some("image/png"));
        assert_eq!(image_type(b"RIFF\0\0\0\0WEBPVP8 "), Some("image/webp"));
        assert_eq!(image_type(b"<svg></svg>"), None);
    }
}
