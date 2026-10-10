use std::collections::{BTreeMap, HashMap};

use axum::{
    extract::{Path, Query, State},
    Json,
};
use serde::Deserialize;
use serde_json::{json, Value};

use crate::{
    auth::{require_member, AuthUser},
    error::{bad, ApiJson, AppError, AppResult},
    nara::{self, Converted},
    nara_csv::{self, Profile},
    routes::children::{check_book, insert_child},
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

    let mut records = Vec::new();
    let mut skipped: BTreeMap<String, u32> = BTreeMap::new();
    for (key, track) in &tracks {
        match nara::convert(key, track) {
            Ok(c) => records.push((c, track.clone())),
            Err(reason) => *skipped.entry(reason).or_default() += 1,
        }
    }
    let plan = Plan { total: tracks.len(), records, skipped, profiles: HashMap::new(), children: req.children, child_id: req.child_id, dry_run: req.dry_run };
    apply(&state, &user, &family_id, plan).await
}

#[derive(Deserialize)]
pub struct NaraCsvQuery {
    /// Put every Nara child into this child.
    child_id: Option<String>,
    /// Per-child mapping: `<nara profile key>:<child id>`, comma-separated.
    children: Option<String>,
    #[serde(default)]
    dry_run: bool,
}

/// `POST /families/{id}/import/nara-csv` with the CSV file exported from the Nara app as the body.
pub async fn import_nara_csv(
    State(state): State<AppState>,
    user: AuthUser,
    Path(family_id): Path<String>,
    Query(q): Query<NaraCsvQuery>,
    body: String,
) -> AppResult<Json<Value>> {
    require_member(&state.db, &family_id, &user.id).await?;
    if body.trim().is_empty() {
        return bad("send the CSV file exported from the Nara app as the request body");
    }
    let parsed = nara_csv::parse(&body).map_err(AppError::BadRequest)?;
    let children = q
        .children
        .unwrap_or_default()
        .split(',')
        .filter_map(|pair| pair.split_once(':'))
        .map(|(k, v)| (k.trim().to_string(), v.trim().to_string()))
        .collect();
    let plan = Plan {
        total: parsed.rows,
        records: parsed.records,
        skipped: parsed.skipped,
        profiles: parsed.profiles,
        children,
        child_id: q.child_id,
        dry_run: q.dry_run,
    };
    apply(&state, &user, &family_id, plan).await
}

/// Converted Nara records plus how to place them.
struct Plan {
    /// Records read from the source (tracks or CSV rows).
    total: usize,
    records: Vec<(Converted, Value)>,
    skipped: BTreeMap<String, u32>,
    /// Nara child key → name / birth date / sex, when the source has them.
    profiles: HashMap<String, Profile>,
    children: HashMap<String, String>,
    child_id: Option<String>,
    dry_run: bool,
}

/// Map Nara children to family children (creating them if the family has none), then insert
/// or update events matched on the Nara id, so re-running an import never duplicates.
async fn apply(state: &AppState, user: &AuthUser, family_id: &str, plan: Plan) -> AppResult<Json<Value>> {
    let Plan { total, records, mut skipped, profiles, children, child_id, dry_run } = plan;

    // Drop anything our own validation would refuse.
    let mut converted = Vec::with_capacity(records.len());
    for (c, raw) in records {
        match c.details.validate(c.start_at, c.end_at, &c.note) {
            Ok(()) => converted.push((c, raw)),
            Err(e) => *skipped.entry(format!("invalid: {e}")).or_default() += 1,
        }
    }

    // Work out which child each Nara child key goes to.
    let family_children: Vec<(String, String)> = sqlx::query_as("SELECT id, name FROM children WHERE family_id = ? ORDER BY created_at")
        .bind(family_id)
        .fetch_all(&state.db)
        .await?;
    let valid_child = |id: &str| family_children.iter().any(|(c, _)| c == id);
    for target in children.values().chain(child_id.iter()) {
        if !valid_child(target) {
            return bad(format!("child '{target}' is not in this family"));
        }
    }
    let mut nara_children: BTreeMap<String, u32> = BTreeMap::new();
    for (c, _) in &converted {
        *nara_children.entry(c.child_key.clone().unwrap_or_default()).or_default() += 1;
    }
    let label = |key: &str| match profiles.get(key).and_then(|p| p.name.as_deref()) {
        Some(name) => format!("{name} ({key})"),
        None => key.to_string(),
    };
    let mut mapping: HashMap<String, String> = HashMap::new();
    let mut to_create: Vec<String> = Vec::new();
    for key in nara_children.keys() {
        if let Some(target) = children.get(key).or(child_id.as_ref()) {
            mapping.insert(key.clone(), target.clone());
        } else if family_children.len() == 1 && nara_children.len() == 1 {
            mapping.insert(key.clone(), family_children[0].0.clone());
        } else if family_children.is_empty() {
            to_create.push(key.clone());
        } else {
            let found: BTreeMap<String, u32> = nara_children.iter().map(|(k, n)| (label(k), *n)).collect();
            return Err(AppError::BadRequest(format!(
                "this family has several children; say where each Nara child goes with \"children\" (<nara child key>: <child id>) or \"child_id\". Nara children found (with event counts): {}",
                serde_json::to_string(&found).unwrap_or_default()
            )));
        }
    }

    let mut by_type: BTreeMap<&'static str, u32> = BTreeMap::new();
    for (c, _) in &converted {
        *by_type.entry(c.details.type_name()).or_default() += 1;
    }
    let (from, to) = (converted.iter().map(|(c, _)| c.start_at).min(), converted.iter().map(|(c, _)| c.start_at).max());
    let children_out = |mapping: &HashMap<String, String>| -> Vec<Value> {
        nara_children
            .iter()
            .map(|(k, n)| {
                let p = profiles.get(k);
                json!({ "key": k, "name": p.and_then(|p| p.name.clone()), "birth_date": p.and_then(|p| p.birth_date), "events": n, "child_id": mapping.get(k) })
            })
            .collect()
    };

    if dry_run {
        return Ok(Json(json!({
            "dry_run": true,
            "tracks": total,
            "importable": converted.len(),
            "by_type": by_type,
            "skipped": skipped,
            "nara_children": children_out(&mapping),
            "children_to_create": to_create.len(),
            "first_ms": from,
            "last_ms": to,
        })));
    }

    let mut created_children = Vec::new();
    for (i, key) in to_create.iter().enumerate() {
        let p = profiles.get(key).cloned().unwrap_or_default();
        let name = p.name.clone().unwrap_or_else(|| if to_create.len() == 1 { "Baby".to_string() } else { format!("Baby {}", i + 1) });
        let id = insert_child(state, family_id, &name, p.birth_date, p.sex.clone()).await?;
        mapping.insert(key.clone(), id.clone());
        created_children.push(json!({ "id": id, "name": name, "nara_child_key": key }));
    }
    // Fill in a birth date / sex the existing child doesn't have yet.
    for (key, child) in &mapping {
        if let Some(p) = profiles.get(key) {
            sqlx::query("UPDATE children SET birth_date = COALESCE(birth_date, ?), sex = COALESCE(sex, ?) WHERE id = ?")
                .bind(p.birth_date.map(|d| d.to_string()))
                .bind(&p.sex)
                .bind(child)
                .execute(&state.db)
                .await?;
            // The baby book's pages, when the child has none yet.
            if let Some(mut book) = p.book.clone() {
                if check_book(&mut book).is_ok() && !book.is_empty() {
                    sqlx::query("UPDATE children SET book = ? WHERE id = ? AND book = '{}'")
                        .bind(serde_json::to_string(&book)?)
                        .bind(child)
                        .execute(&state.db)
                        .await?;
                }
            }
        }
    }

    let (mut inserted, mut updated) = (0u32, 0u32);
    let now = now_ms();
    let mut tx = state.db.begin().await?;
    for (c, raw) in &converted {
        let child_id = &mapping[&c.child_key.clone().unwrap_or_default()];
        let existing: Option<(String,)> = sqlx::query_as("SELECT id FROM events WHERE family_id = ? AND source = 'nara' AND source_id = ?")
            .bind(family_id)
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
                .bind(family_id)
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

    state.publish(family_id, "import", "created", json!({ "source": "nara", "imported": inserted, "updated": updated }));
    Ok(Json(json!({
        "tracks": total,
        "imported": inserted,
        "updated": updated,
        "by_type": by_type,
        "skipped": skipped,
        "nara_children": children_out(&mapping),
        "children_created": created_children,
    })))
}
