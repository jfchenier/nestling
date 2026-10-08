use std::{env, path::PathBuf};

use nestling::{app, connect, AppState, Config, NaraConfig};
use tracing_subscriber::EnvFilter;

fn env_bool(key: &str, default: bool) -> bool {
    match env::var(key) {
        Ok(v) => matches!(v.to_lowercase().as_str(), "1" | "true" | "yes" | "on"),
        Err(_) => default,
    }
}

/// Ctrl-C, or SIGTERM from `docker stop`.
async fn shutdown_signal() {
    let ctrl_c = async {
        let _ = tokio::signal::ctrl_c().await;
    };
    #[cfg(unix)]
    let term = async {
        if let Ok(mut s) = tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate()) {
            s.recv().await;
        }
    };
    #[cfg(not(unix))]
    let term = std::future::pending::<()>();
    tokio::select! { _ = ctrl_c => {}, _ = term => {} }
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter(EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("nestling=info,tower_http=info")))
        .init();

    let database_url = env::var("NESTLING_DATABASE_URL").unwrap_or_else(|_| "sqlite://nestling.db".into());
    let bind = env::var("NESTLING_BIND").unwrap_or_else(|_| "0.0.0.0:8080".into());
    let web_dir = env::var("NESTLING_WEB_DIR").ok().map(PathBuf::from).filter(|p| p.join("index.html").exists());
    let config = Config {
        open_registration: env_bool("NESTLING_OPEN_REGISTRATION", true),
        nara: NaraConfig::default(),
    };

    let db = connect(&database_url, 8).await?;
    let state = AppState::new(db, config);
    let listener = tokio::net::TcpListener::bind(&bind).await?;
    tracing::info!("Nestling listening on http://{bind} (database: {database_url})");
    axum::serve(listener, app(state, web_dir))
        .with_graceful_shutdown(shutdown_signal())
        .await?;
    Ok(())
}
