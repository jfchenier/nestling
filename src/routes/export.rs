//! Download a family's data as CSV (see `csv_export` for the layout).

use std::collections::HashMap;

use axum::{
    extract::{Path, State},
    http::header,
    response::{IntoResponse, Response},
};
use chrono::Utc;

use crate::{
    auth::{family_tz, require_member, AuthUser},
    csv_export::{self, ExportChild, ExportEvent},
    error::AppResult,
    model::Details,
    state::AppState,
};

type EventRow = (String, String, i64, Option<i64>, String, Option<String>, Option<String>, Option<String>, Option<String>);

pub async fn export_csv(State(state): State<AppState>, user: AuthUser, Path(family_id): Path<String>) -> AppResult<Response> {
    require_member(&state.db, &family_id, &user.id).await?;
    let tz = family_tz(&state.db, &family_id).await?;
    let (family_name,): (String,) = sqlx::query_as("SELECT name FROM families WHERE id = ?").bind(&family_id).fetch_one(&state.db).await?;

    let children: Vec<ExportChild> =
        sqlx::query_as::<_, (String, String, Option<String>, Option<String>)>("SELECT id, name, birth_date, sex FROM children WHERE family_id = ? ORDER BY created_at")
            .bind(&family_id)
            .fetch_all(&state.db)
            .await?
            .into_iter()
            .map(|(id, name, birth_date, sex)| ExportChild { id, name, birth_date, sex })
            .collect();

    let rows: Vec<EventRow> = sqlx::query_as(
        "SELECT id, child_id, start_at, end_at, data, note, created_by, updated_by, source_id FROM events
         WHERE family_id = ? AND deleted_at IS NULL ORDER BY start_at",
    )
    .bind(&family_id)
    .fetch_all(&state.db)
    .await?;
    let mut events = Vec::with_capacity(rows.len());
    for (id, child_id, start_at, end_at, data, note, created_by, updated_by, source_id) in rows {
        let details: Details = serde_json::from_str(&data)?;
        events.push(ExportEvent { id, child_id, start_at, end_at, details, note, created_by, updated_by, source_id });
    }

    let names: HashMap<String, String> = sqlx::query_as::<_, (String, String)>("SELECT id, name FROM users").fetch_all(&state.db).await?.into_iter().collect();

    let csv = csv_export::write(&family_id, tz, &children, &events, &names);
    let slug: String = family_name.chars().map(|c| if c.is_ascii_alphanumeric() { c.to_ascii_lowercase() } else { '-' }).collect();
    let file = format!("nestling-{}-{}.csv", slug.trim_matches('-'), Utc::now().with_timezone(&tz).format("%Y-%m-%d"));
    Ok((
        [
            (header::CONTENT_TYPE, "text/csv; charset=utf-8".to_string()),
            (header::CONTENT_DISPOSITION, format!("attachment; filename=\"{file}\"")),
            (header::CACHE_CONTROL, "no-store".to_string()),
        ],
        csv,
    )
        .into_response())
}
