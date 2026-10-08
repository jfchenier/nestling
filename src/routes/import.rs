use std::collections::{BTreeMap, HashMap};

use axum::{
    extract::{Path, State},
    Json,
};
use serde::Deserialize;
use serde_json::{json, Value};

use crate::{
    auth::{require_member, AuthUser},
    error::{bad, ApiJson, AppError, AppResult},
    nara,
    routes::children::insert_child,
    state::AppState,
    util::{new_id, now_ms},
};

#[derive(Deserialize)]
pub struct NaraImportReq {
    /// Nara account credentials (used once, never stored)...
    email: Option<String>,
    password: Option<String>,
    /// ...or an uploaded export: the `trackz` object, the full sync2 response, or an array of tracks.
    tracks: Option<Value>,
    /// Map Nara child keys to children of this family.
    #[serde(default)]
    children: HashMap<String, String>,
    /// Put all unmapped Nara children into this child.
    child_id: Option<String>,
    /// Report what would happen without writing anything.
    #[serde(default)]
    dry_run: bool,
}

pub async fn import_nara(State(state): State<AppState>, user: AuthUser, Path(family_id): Path<String>, ApiJson(req): ApiJson<NaraImportReq>) -> AppResult<Json<Value>> {
    require_member(&state.db, &family_id, &user.id).await?;

    let tracks = match (req.tracks, req.email, req.password) {
        (Some(t), _, _) => nara::tracks_from_upload(t)?,
        (None, Some(email), Some(password)) => {
            let session = nara::login(&state.config.nara, email.trim(), &password).await?;
            nara::fetch_tracks(&state.config.nara, &session).await?
        }
        _ => return bad("send either {email, password} of your Nara account or {tracks} from an export"),
    };

    // Convert everything first.
    let mut converted = Vec::new();
    let mut skipped: BTreeMap<String, u32> = BTreeMap::new();
    for (key, track) in &tracks {
        match nara::convert(key, track) {
            Ok(c) => converted.push((c, track)),
            Err(reason) => *skipped.entry(reason).or_default() += 1,
        }
    }

    // Work out which child each Nara child key goes to.
    let family_children: Vec<(String, String)> = sqlx::query_as("SELECT id, name FROM children WHERE family_id = ? ORDER BY created_at")
        .bind(&family_id)
        .fetch_all(&state.db)
        .await?;
    let valid_child = |id: &str| family_children.iter().any(|(c, _)| c == id);
    for target in req.children.values().chain(req.child_id.iter()) {
        if !valid_child(target) {
            return bad(format!("child '{target}' is not in this family"));
        }
    }
    let mut nara_children: BTreeMap<String, u32> = BTreeMap::new();
    for (c, _) in &converted {
        *nara_children.entry(c.child_key.clone().unwrap_or_default()).or_default() += 1;
    }
    let mut mapping: HashMap<String, String> = HashMap::new();
    let mut to_create: Vec<String> = Vec::new();
    for key in nara_children.keys() {
        if let Some(target) = req.children.get(key).or(req.child_id.as_ref()) {
            mapping.insert(key.clone(), target.clone());
        } else if family_children.len() == 1 && nara_children.len() == 1 {
            mapping.insert(key.clone(), family_children[0].0.clone());
        } else if family_children.is_empty() {
            to_create.push(key.clone());
        } else {
            return Err(AppError::BadRequest(format!(
                "this family has several children; say where each Nara child goes with \"children\": {{\"<nara child key>\": \"<child id>\"}} or \"child_id\". Nara child keys found (with event counts): {}",
                serde_json::to_string(&nara_children).unwrap_or_default()
            )));
        }
    }

    let mut by_type: BTreeMap<&'static str, u32> = BTreeMap::new();
    for (c, _) in &converted {
        *by_type.entry(c.details.type_name()).or_default() += 1;
    }

    if req.dry_run {
        return Ok(Json(json!({
            "dry_run": true,
            "tracks": tracks.len(),
            "importable": converted.len(),
            "by_type": by_type,
            "skipped": skipped,
            "nara_children": nara_children,
            "children_to_create": to_create.len(),
        })));
    }

    let mut created_children = Vec::new();
    for (i, key) in to_create.iter().enumerate() {
        let name = if to_create.len() == 1 { "Baby".to_string() } else { format!("Baby {}", i + 1) };
        let id = insert_child(&state, &family_id, &name, None, None).await?;
        mapping.insert(key.clone(), id.clone());
        created_children.push(json!({ "id": id, "name": name, "nara_child_key": key }));
    }

    let (mut inserted, mut updated) = (0u32, 0u32);
    let now = now_ms();
    let mut tx = state.db.begin().await?;
    for (c, raw) in &converted {
        let child_id = &mapping[&c.child_key.clone().unwrap_or_default()];
        let existing: Option<(String,)> = sqlx::query_as("SELECT id FROM events WHERE family_id = ? AND source = 'nara' AND source_id = ?")
            .bind(&family_id)
            .bind(&c.source_id)
            .fetch_optional(&mut *tx)
            .await?;
        let data = serde_json::to_string(&c.details)?;
        let raw = serde_json::to_string(raw)?;
        match existing {
            Some((id,)) => {
                sqlx::query(
                    "UPDATE events SET child_id = ?, type = ?, start_at = ?, end_at = ?, data = ?, note = ?, raw = ?,
                     updated_by = ?, updated_at = ?, deleted_at = NULL WHERE id = ?",
                )
                .bind(child_id)
                .bind(c.details.type_name())
                .bind(c.start_at)
                .bind(c.end_at)
                .bind(&data)
                .bind(&c.note)
                .bind(&raw)
                .bind(&user.id)
                .bind(now)
                .bind(&id)
                .execute(&mut *tx)
                .await?;
                updated += 1;
            }
            None => {
                sqlx::query(
                    "INSERT INTO events (id, family_id, child_id, type, start_at, end_at, data, note, created_by, updated_by,
                     created_at, updated_at, source, source_id, raw) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'nara', ?, ?)",
                )
                .bind(new_id())
                .bind(&family_id)
                .bind(child_id)
                .bind(c.details.type_name())
                .bind(c.start_at)
                .bind(c.end_at)
                .bind(&data)
                .bind(&c.note)
                .bind(&user.id)
                .bind(&user.id)
                .bind(now)
                .bind(now)
                .bind(&c.source_id)
                .bind(&raw)
                .execute(&mut *tx)
                .await?;
                inserted += 1;
            }
        }
    }
    tx.commit().await?;

    state.publish(&family_id, "import", "created", json!({ "source": "nara", "imported": inserted, "updated": updated }));
    Ok(Json(json!({
        "tracks": tracks.len(),
        "imported": inserted,
        "updated": updated,
        "by_type": by_type,
        "skipped": skipped,
        "children_created": created_children,
    })))
}
