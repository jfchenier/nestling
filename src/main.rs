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
        open_registration: env_bool("NESTLING_OPEN_REGISTRATION", false),
        nara: NaraConfig::default(),
    };

    let db = connect(&database_url, 8).await?;

    // Recovery from the command line (e.g. `docker exec <container> nestling make-admin me@example.com`).
    let args: Vec<String> = env::args().skip(1).collect();
    if !args.is_empty() {
        return admin_command(&db, &args).await;
    }

    let state = AppState::new(db, config);
    let listener = tokio::net::TcpListener::bind(&bind).await?;
    tracing::info!("Nestling listening on http://{bind} (database: {database_url})");
    axum::serve(listener, app(state, web_dir))
        .with_graceful_shutdown(shutdown_signal())
        .await?;
    Ok(())
}

async fn admin_command(db: &sqlx::SqlitePool, args: &[String]) -> anyhow::Result<()> {
    let (query, value, done) = match args {
        [cmd, email] if cmd == "make-admin" => ("UPDATE users SET is_admin = 1 WHERE email = ?", None, "is now an admin"),
        [cmd, email, password] if cmd == "set-password" => {
            if password.chars().count() < 8 {
                anyhow::bail!("password must be at least 8 characters");
            }
            ("UPDATE users SET password_hash = ? WHERE email = ?", Some(nestling::auth::hash_password(password)?), "has a new password")
        }
        _ => anyhow::bail!("usage: nestling [make-admin <email> | set-password <email> <password>]"),
    };
    let email = args[1].trim().to_lowercase();
    let mut q = sqlx::query(query);
    if let Some(v) = &value {
        q = q.bind(v);
    }
    if q.bind(&email).execute(db).await?.rows_affected() == 0 {
        anyhow::bail!("no account with email {email}");
    }
    println!("{email} {done}");
    Ok(())
}
