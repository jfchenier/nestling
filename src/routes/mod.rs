pub mod accounts;
pub mod children;
pub mod events;
pub mod families;
pub mod import;
pub mod insights;
pub mod timers;

use axum::{
    extract::DefaultBodyLimit,
    routing::{delete, get, post},
    Json, Router,
};
use serde_json::json;

use crate::state::AppState;

const IMPORT_LIMIT: usize = 64 * 1024 * 1024;

pub fn api() -> Router<AppState> {
    Router::new()
        // Accounts
        .route("/auth/register", post(accounts::register))
        .route("/auth/login", post(accounts::login))
        .route("/auth/logout", post(accounts::logout))
        .route("/me", get(accounts::me).patch(accounts::update_me))
        .route("/me/tokens", get(accounts::list_tokens).post(accounts::create_token))
        .route("/me/tokens/{id}", delete(accounts::delete_token))
        // Families & caregivers
        .route("/families", get(families::list).post(families::create))
        .route("/families/{id}", get(families::get).patch(families::update).delete(families::delete))
        .route("/families/{id}/invites", post(families::create_invite))
        .route("/families/{id}/members/{user_id}", delete(families::remove_member))
        .route("/invites/{code}/accept", post(families::accept_invite))
        .route("/families/{id}/children", get(children::list).post(children::create))
        .route("/families/{id}/sync", get(events::sync))
        .route("/families/{id}/stream", get(insights::stream))
        // Imports can be large (a year of Nara history is several MB).
        .route("/families/{id}/import/nara", post(import::import_nara).layer(DefaultBodyLimit::max(IMPORT_LIMIT)))
        .route("/families/{id}/import/nara-csv", post(import::import_nara_csv).layer(DefaultBodyLimit::max(IMPORT_LIMIT)))
        // Children
        .route("/children/{id}", get(children::get).patch(children::update).delete(children::delete))
        .route("/children/{id}/events", get(events::list).post(events::create))
        .route("/children/{id}/timers", get(timers::list).post(timers::start))
        .route("/children/{id}/summary", get(insights::summary))
        .route("/children/{id}/trends", get(insights::get_trends))
        // Events
        .route("/events/{id}", get(events::get).patch(events::update).delete(events::delete))
        // Timers
        .route("/timers/{id}", get(timers::get).patch(timers::edit).delete(timers::discard))
        .route("/timers/{id}/pause", post(timers::pause))
        .route("/timers/{id}/resume", post(timers::resume))
        .route("/timers/{id}/switch", post(timers::switch))
        .route("/timers/{id}/stop", post(timers::stop))
        .fallback(|| async {
            (
                axum::http::StatusCode::NOT_FOUND,
                Json(json!({ "error": { "code": "not_found", "message": "no such endpoint" } })),
            )
        })
}
