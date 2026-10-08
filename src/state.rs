use std::sync::Arc;

use serde::Serialize;
use sqlx::SqlitePool;
use tokio::sync::broadcast;

#[derive(Debug, Clone)]
pub struct Config {
    /// Allow anyone to create an account. The first account can always be created.
    pub open_registration: bool,
    pub nara: NaraConfig,
}

#[derive(Debug, Clone)]
pub struct NaraConfig {
    pub api_key: String,
    pub auth_url: String,
    pub db_url: String,
    pub functions_url: String,
}

impl Default for NaraConfig {
    fn default() -> Self {
        // Public Firebase client configuration of the Nara Baby app
        // (from github.com/jfchenier/nara-baby-tracker-api).
        NaraConfig {
            api_key: "AIzaSyApsJ5h5-JCjp9SJvWbHG4Fxq8NbxDW0EQ".into(),
            auth_url: "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword".into(),
            db_url: "https://amazing-ripple-221320.firebaseio.com".into(),
            functions_url: "https://us-central1-amazing-ripple-221320.cloudfunctions.net/app".into(),
        }
    }
}

/// A change pushed to live clients over the family stream.
#[derive(Debug, Clone, Serialize)]
pub struct Change {
    #[serde(skip)]
    pub family_id: String,
    /// "event" | "timer" | "child" | "family" | "import"
    pub entity: &'static str,
    /// "created" | "updated" | "deleted"
    pub action: &'static str,
    pub data: serde_json::Value,
}

#[derive(Clone)]
pub struct AppState {
    pub db: SqlitePool,
    pub config: Arc<Config>,
    pub changes: broadcast::Sender<Change>,
}

impl AppState {
    pub fn new(db: SqlitePool, config: Config) -> Self {
        let (changes, _) = broadcast::channel(256);
        AppState { db, config: Arc::new(config), changes }
    }

    pub fn publish(&self, family_id: &str, entity: &'static str, action: &'static str, data: serde_json::Value) {
        // No receivers is fine.
        let _ = self.changes.send(Change { family_id: family_id.to_string(), entity, action, data });
    }
}
