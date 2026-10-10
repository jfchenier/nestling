//! Notifications to caregivers' phones through Firebase Cloud Messaging (optional).
//!
//! When a timer starts, changes or stops, every phone registered by a member of the family gets
//! a data message, and the Android app shows (or removes) the same running-timer notification it
//! shows for its own timers, even while the app is closed. The texts are made here, in the
//! family's time zone, the same way as `app/lib/timer_notifications.dart`: keep both in step.
//!
//! Set up with `NESTLING_FCM_CREDENTIALS` (path to a Firebase service-account JSON key),
//! `NESTLING_FCM_APP_ID` and `NESTLING_FCM_API_KEY` (the Android app's Firebase config). The app
//! reads the client part from `GET /push/config`, so one APK works with any server.

use std::{sync::Arc, time::Duration};

use serde::Deserialize;
use serde_json::{json, Value};
use tokio::sync::Mutex;

use crate::{state::AppState, util::now_ms};

#[derive(Debug, Clone, Deserialize)]
pub struct ServiceAccount {
    pub project_id: String,
    pub client_email: String,
    pub private_key: String,
    #[serde(default = "default_token_uri")]
    pub token_uri: String,
}

fn default_token_uri() -> String {
    "https://oauth2.googleapis.com/token".into()
}

#[derive(Debug, Clone)]
pub struct PushConfig {
    pub account: ServiceAccount,
    /// Firebase Android app id, `1:<sender id>:android:<hex>`.
    pub app_id: String,
    pub api_key: String,
    /// FCM HTTP v1 base URL (overridden in tests).
    pub fcm_url: String,
}

impl PushConfig {
    /// From the environment; `None` when notifications aren't set up.
    pub fn from_env() -> anyhow::Result<Option<Self>> {
        let Ok(path) = std::env::var("NESTLING_FCM_CREDENTIALS") else { return Ok(None) };
        let account: ServiceAccount = serde_json::from_slice(&std::fs::read(&path)?)?;
        let var = |k: &str| std::env::var(k).map_err(|_| anyhow::anyhow!("{k} is needed with NESTLING_FCM_CREDENTIALS"));
        Ok(Some(PushConfig {
            account,
            app_id: var("NESTLING_FCM_APP_ID")?,
            api_key: var("NESTLING_FCM_API_KEY")?,
            fcm_url: "https://fcm.googleapis.com".into(),
        }))
    }
}

pub struct Push {
    cfg: PushConfig,
    http: reqwest::Client,
    /// OAuth access token and when it expires (ms).
    token: Mutex<Option<(String, i64)>>,
}

impl Push {
    pub fn new(cfg: PushConfig) -> Self {
        let http = reqwest::Client::builder().timeout(Duration::from_secs(15)).build().expect("http client");
        Push { cfg, http, token: Mutex::new(None) }
    }

    /// What the app needs to register with Firebase.
    pub fn client_config(&self) -> Value {
        // The sender id is the project number, the second part of the app id.
        let sender_id = self.cfg.app_id.split(':').nth(1).unwrap_or_default();
        json!({
            "enabled": true,
            "android": {
                "api_key": self.cfg.api_key,
                "app_id": self.cfg.app_id,
                "project_id": self.cfg.account.project_id,
                "sender_id": sender_id,
            }
        })
    }

    async fn access_token(&self) -> anyhow::Result<String> {
        let mut cached = self.token.lock().await;
        if let Some((token, expires)) = &*cached {
            if *expires > now_ms() + 60_000 {
                return Ok(token.clone());
            }
        }
        let now = now_ms() / 1000;
        let claims = json!({
            "iss": self.cfg.account.client_email,
            "scope": "https://www.googleapis.com/auth/firebase.messaging",
            "aud": self.cfg.account.token_uri,
            "iat": now,
            "exp": now + 3600,
        });
        let key = jsonwebtoken::EncodingKey::from_rsa_pem(self.cfg.account.private_key.as_bytes())?;
        let jwt = jsonwebtoken::encode(&jsonwebtoken::Header::new(jsonwebtoken::Algorithm::RS256), &claims, &key)?;
        let res: Value = self
            .http
            .post(&self.cfg.account.token_uri)
            .form(&[("grant_type", "urn:ietf:params:oauth:grant-type:jwt-bearer"), ("assertion", &jwt)])
            .send()
            .await?
            .error_for_status()?
            .json()
            .await?;
        let token = res["access_token"].as_str().ok_or_else(|| anyhow::anyhow!("no access_token in {res}"))?.to_string();
        let expires_in = res["expires_in"].as_i64().unwrap_or(3600);
        *cached = Some((token.clone(), now_ms() + expires_in * 1000));
        Ok(token)
    }

    /// Sends [data] to one phone. `Ok(false)`: the phone's token is no longer valid.
    async fn send_one(&self, fcm_token: &str, data: &Value, collapse_key: &str) -> anyhow::Result<bool> {
        let url = format!("{}/v1/projects/{}/messages:send", self.cfg.fcm_url, self.cfg.account.project_id);
        let body = json!({
            "message": {
                "token": fcm_token,
                "data": data,
                // High priority wakes a phone in Doze; the message replaces older ones for the timer.
                "android": { "priority": "high", "ttl": "3600s", "collapse_key": collapse_key },
            }
        });
        let res = self.http.post(url).bearer_auth(self.access_token().await?).json(&body).send().await?;
        let status = res.status();
        if status.is_success() {
            return Ok(true);
        }
        let text = res.text().await.unwrap_or_default();
        // The app was uninstalled or its token replaced (a wrong project or URL is also a 404,
        // but without this code, and must not wipe the phones).
        if text.contains("UNREGISTERED") {
            return Ok(false);
        }
        anyhow::bail!("FCM answered {status}: {text}")
    }

    /// Sends [data] to every phone of the family's caregivers (not book viewers).
    pub(crate) async fn send_family(&self, state: &AppState, family_id: &str, data: Value, collapse_key: &str) -> anyhow::Result<()> {
        let tokens: Vec<(String,)> = sqlx::query_as(
            "SELECT p.fcm_token FROM push_devices p JOIN memberships m ON m.user_id = p.user_id WHERE m.family_id = ? AND m.role != 'book_viewer'",
        )
        .bind(family_id)
        .fetch_all(&state.db)
        .await?;
        for (token,) in tokens {
            match self.send_one(&token, &data, collapse_key).await {
                Ok(true) => {}
                Ok(false) => {
                    sqlx::query("DELETE FROM push_devices WHERE fcm_token = ?").bind(&token).execute(&state.db).await?;
                }
                Err(e) => tracing::warn!("push: {e}"),
            }
        }
        Ok(())
    }
}

/// Watches the family changes and sends timer notifications (until the server stops).
pub fn spawn(state: AppState, push: Arc<Push>) {
    let mut rx = state.changes.subscribe();
    tokio::spawn(async move {
        loop {
            let change = match rx.recv().await {
                Ok(c) => c,
                Err(tokio::sync::broadcast::error::RecvError::Lagged(_)) => continue,
                Err(_) => return,
            };
            if change.entity != "timer" {
                continue;
            }
            let push = push.clone();
            let state = state.clone();
            // One task per change, so a slow FCM answer doesn't hold up the others.
            tokio::spawn(async move {
                let data = match timer_message(&state, change.action, &change.data).await {
                    Ok(Some(d)) => d,
                    Ok(None) => return,
                    Err(e) => return tracing::warn!("push: {e}"),
                };
                let collapse = format!("timer-{}", data["id"].as_str().unwrap_or_default());
                if let Err(e) = push.send_family(&state, &change.family_id, data, &collapse).await {
                    tracing::warn!("push: {e}");
                }
            });
        }
    });
}

/// The notification id the app uses for a timer kind (one per kind).
fn notification_id(kind: &str) -> u32 {
    match kind {
        "breastfeed" => 1,
        "sleep" => 2,
        _ => 3,
    }
}

/// The data message for a timer change: `{action: "show"|"cancel", id, title, body, running,
/// started_at, chip, seq}` (all strings, as FCM requires). `seq` orders messages that arrive
/// out of order.
pub async fn timer_message(state: &AppState, action: &str, timer: &Value) -> anyhow::Result<Option<Value>> {
    let kind = timer["kind"].as_str().unwrap_or_default();
    if kind.is_empty() {
        return Ok(None);
    }
    let id = notification_id(kind).to_string();
    let seq = now_ms().to_string();
    if action == "deleted" {
        return Ok(Some(json!({ "action": "cancel", "id": id, "seq": seq })));
    }
    let child: Option<(String,)> = sqlx::query_as("SELECT name FROM children WHERE id = ?")
        .bind(timer["child_id"].as_str().unwrap_or_default())
        .fetch_optional(&state.db)
        .await?;
    let running = timer["running"].as_bool().unwrap_or(false);
    let elapsed = timer["elapsed_seconds"].as_i64().unwrap_or(0);
    let what = match (kind, running) {
        ("breastfeed", true) => format!("Breastfeeding · {} side", if timer["side"] == "right" { "right" } else { "left" }),
        ("breastfeed", false) => "Breastfeed paused".into(),
        ("sleep", true) => "Sleeping".into(),
        ("sleep", false) => "Sleep paused".into(),
        (_, true) => "Pumping".into(),
        (_, false) => "Pump paused".into(),
    };
    let title = match child {
        Some((name,)) if kind != "pump" => format!("{name} · {what}"),
        _ => what,
    };
    // `started_at` is RFC 3339 in the family's time zone: its HH:MM is the local time.
    let since = timer["started_at"].as_str().and_then(|s| s.get(11..16)).unwrap_or_default();
    let body = if running {
        format!("Since {since} · tap to open")
    } else {
        format!("{} so far · tap to resume", duration(elapsed))
    };
    Ok(Some(json!({
        "action": "show",
        "id": id,
        "title": title,
        "body": body,
        "running": running.to_string(),
        // The clock counts up from "now minus the time already on the timer".
        "started_at": (now_ms() - elapsed * 1000).to_string(),
        "chip": if running { "" } else { "Paused" },
        "seq": seq,
    })))
}

/// Same as `duration(seconds, showSeconds: true)` in `app/lib/format.dart`.
pub(crate) fn duration(seconds: i64) -> String {
    if seconds >= 86400 {
        return format!("{}d {}h", seconds / 86400, (seconds % 86400) / 3600);
    }
    let (h, m, s) = (seconds / 3600, (seconds % 3600) / 60, seconds % 60);
    if h > 0 {
        format!("{h}h {m:02}m")
    } else if m > 0 {
        format!("{m}m {s:02}s")
    } else {
        format!("{s}s")
    }
}
