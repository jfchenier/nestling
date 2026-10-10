pub mod auth;
pub mod csv_export;
pub mod error;
pub mod limiter;
pub mod model;
pub mod nara;
pub mod nara_csv;
pub mod push;
pub mod reminders;
pub mod routes;
pub mod schedule;
pub mod state;
pub mod trends;
pub mod util;

use std::{path::PathBuf, str::FromStr};

use axum::{routing::get, Json, Router};
use serde_json::json;
use sqlx::{
    sqlite::{SqliteConnectOptions, SqliteJournalMode, SqlitePoolOptions},
    SqlitePool,
};
use tower_http::{
    cors::CorsLayer,
    services::{ServeDir, ServeFile},
    set_header::SetResponseHeader,
    trace::TraceLayer,
};

pub use state::{AppState, Config, NaraConfig};

pub async fn connect(url: &str, max_connections: u32) -> anyhow::Result<SqlitePool> {
    let opts = SqliteConnectOptions::from_str(url)?
        .create_if_missing(true)
        .foreign_keys(true)
        .journal_mode(SqliteJournalMode::Wal)
        .busy_timeout(std::time::Duration::from_secs(5));
    let pool = SqlitePoolOptions::new().max_connections(max_connections).connect_with(opts).await?;
    sqlx::migrate!("./migrations").run(&pool).await?;
    Ok(pool)
}

/// Build the HTTP app. `web_dir`, if set, is served at `/` (for the web app).
pub fn app(state: AppState, web_dir: Option<PathBuf>) -> Router {
    let mut router = Router::new()
        .route("/health", get(|| async { Json(json!({ "status": "ok", "version": env!("CARGO_PKG_VERSION") })) }))
        .nest("/api/v1", routes::api())
        .with_state(state);
    if let Some(dir) = web_dir {
        let index = dir.join("index.html");
        // Flutter's file names don't change between releases (main.dart.js…), so browsers and
        // proxies must revalidate them (cheap: ETag / Last-Modified) or they keep an old app.
        let files = ServeDir::new(dir).fallback(ServeFile::new(index));
        router = router.fallback_service(SetResponseHeader::overriding(
            files,
            axum::http::header::CACHE_CONTROL,
            axum::http::HeaderValue::from_static("no-cache"),
        ));
    }
    router.layer(CorsLayer::permissive()).layer(TraceLayer::new_for_http())
}
