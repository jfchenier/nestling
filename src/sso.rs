//! Optional single sign-on through an OpenID Connect provider (e.g. Pocket ID, Authelia,
//! Keycloak, authentik). Off unless `NESTLING_OIDC_ISSUER` and `NESTLING_OIDC_CLIENT_ID` are set;
//! signing in with a password keeps working.
//!
//! 1. The app opens `GET /api/v1/auth/sso/start?return_to=…&challenge=…` in the browser. The
//!    server remembers the sign-in and sends the browser to the provider (authorization code flow
//!    with PKCE and a nonce).
//! 2. The provider sends the browser back to `GET /api/v1/auth/sso/callback`. The server trades
//!    the code for the ID token (directly with the provider over TLS, so the token's signature
//!    needn't be checked: OpenID Connect Core 3.1.3.7), finds the account, and sends the browser
//!    back to `return_to` with a one-time `sso_code`.
//! 3. The app trades `sso_code` and its verifier (`challenge` = base64url(SHA-256(verifier))) for
//!    a session at `POST /api/v1/auth/sso/token`. The verifier never leaves the app, so a code
//!    caught on the way back (another app claiming the link) is useless.
//!
//! Accounts: the provider's account is linked on first use (`user_identities`), to the Nestling
//! account with the same (verified) email. Someone without one gets an account only on a new
//! server (the first account, the admin), or with `NESTLING_OIDC_SIGNUP` (or open registration).

use std::{sync::Arc, time::Duration};

use axum::{
    extract::{Query, State},
    http::HeaderMap,
    response::{IntoResponse, Redirect, Response},
    Json,
};
use base64::{engine::general_purpose::URL_SAFE_NO_PAD, Engine};
use reqwest::Url;
use serde::Deserialize;
use serde_json::{json, Value};
use sha2::{Digest, Sha256};
use tokio::sync::RwLock;

use crate::{
    auth::issue_token,
    error::{bad, ApiJson, AppError, AppResult},
    routes::accounts::user_json,
    state::AppState,
    util::{new_id, now_ms, random_token, sha256_hex},
};

/// How long a sign-in may take, from the start to the app's token request.
const LOGIN_TTL_MS: i64 = 10 * 60 * 1000;
/// The link the Android app comes back on (`io.github.jfchenier.nestling://sso`).
pub const APP_SCHEME: &str = "io.github.jfchenier.nestling";

/// Settings from the environment.
#[derive(Debug, Clone)]
pub struct OidcConfig {
    /// e.g. `https://id.example.com` (its `/.well-known/openid-configuration` is read).
    pub issuer: String,
    pub client_id: String,
    /// Empty for a public client (PKCE only).
    pub client_secret: String,
    /// The button's label in the app ("Sign in with …").
    pub name: String,
    pub scopes: String,
    /// Create an account for someone the provider knows but Nestling doesn't.
    pub signup: bool,
}

impl OidcConfig {
    /// `None` when SSO isn't set up (`NESTLING_OIDC_ISSUER` / `NESTLING_OIDC_CLIENT_ID` unset).
    pub fn from_env() -> Option<Self> {
        let var = |k: &str| std::env::var(k).ok().map(|v| v.trim().to_string()).filter(|v| !v.is_empty());
        let issuer = var("NESTLING_OIDC_ISSUER")?.trim_end_matches('/').to_string();
        let client_id = var("NESTLING_OIDC_CLIENT_ID")?;
        Some(OidcConfig {
            issuer,
            client_id,
            client_secret: var("NESTLING_OIDC_CLIENT_SECRET").unwrap_or_default(),
            name: var("NESTLING_OIDC_NAME").unwrap_or_else(|| "SSO".into()),
            scopes: var("NESTLING_OIDC_SCOPES").unwrap_or_else(|| "openid email profile".into()),
            signup: var("NESTLING_OIDC_SIGNUP").is_some_and(|v| matches!(v.to_lowercase().as_str(), "1" | "true" | "yes" | "on")),
        })
    }
}

/// The provider's endpoints (from its discovery document).
#[derive(Debug, Clone, Deserialize)]
struct Discovery {
    issuer: String,
    authorization_endpoint: String,
    token_endpoint: String,
    #[serde(default)]
    userinfo_endpoint: Option<String>,
}

/// SSO when it is set up: the settings and the provider's endpoints, read on first use (so the
/// server starts even while the provider is down) and again after a failure.
pub struct Oidc {
    pub config: OidcConfig,
    http: reqwest::Client,
    discovery: RwLock<Option<Discovery>>,
}

impl Oidc {
    pub fn new(config: OidcConfig) -> Arc<Self> {
        let http = reqwest::Client::builder()
            .timeout(Duration::from_secs(15))
            .redirect(reqwest::redirect::Policy::none())
            .build()
            .expect("http client");
        Arc::new(Oidc { config, http, discovery: RwLock::new(None) })
    }

    async fn discovery(&self) -> AppResult<Discovery> {
        if let Some(d) = self.discovery.read().await.clone() {
            return Ok(d);
        }
        let url = format!("{}/.well-known/openid-configuration", self.config.issuer);
        let d: Discovery = async {
            self.http.get(&url).send().await?.error_for_status()?.json().await
        }
        .await
        .map_err(|e| upstream(format!("can't read the sign-in provider's settings at {url}: {e}")))?;
        if d.issuer.trim_end_matches('/') != self.config.issuer {
            return Err(upstream(format!(
                "the sign-in provider calls itself {}, not {} (check NESTLING_OIDC_ISSUER)",
                d.issuer, self.config.issuer
            )));
        }
        *self.discovery.write().await = Some(d.clone());
        Ok(d)
    }
}

fn upstream(msg: String) -> AppError {
    tracing::warn!("SSO: {msg}");
    AppError::Upstream(msg)
}

fn oidc(state: &AppState) -> AppResult<&Arc<Oidc>> {
    state.oidc.as_ref().ok_or(AppError::NotFound("single sign-on (not set up on this server)"))
}

/// For `/auth/setup`: the button's label, or null.
pub fn setup_json(state: &AppState) -> Value {
    state.oidc.as_ref().map_or(Value::Null, |o| json!({ "name": o.config.name }))
}

fn b64_sha256(s: &str) -> String {
    URL_SAFE_NO_PAD.encode(Sha256::digest(s.as_bytes()))
}

/// The origins the web app may be served from: this server's public address, and the address the
/// request came to (a home-network address while the public one is set, for example).
fn own_origins(headers: &HeaderMap) -> Vec<String> {
    let header = |name: &str| {
        headers.get(name).and_then(|v| v.to_str().ok()).and_then(|v| v.split(',').next()).map(str::trim).filter(|v| !v.is_empty())
    };
    let mut out = vec![crate::oauth::base_url(headers)];
    if let Some(host) = header("x-forwarded-host").or_else(|| header("host")) {
        let proto = header("x-forwarded-proto").unwrap_or("http");
        out.push(format!("{proto}://{host}"));
    }
    out
}

/// Where the browser may be sent back with a code: a page of this server (the web app), or the
/// Android app's link. Anything else is refused, so a link can't send a code elsewhere.
fn valid_return(return_to: &str, headers: &HeaderMap) -> bool {
    let Ok(url) = Url::parse(return_to) else { return false };
    if return_to.len() > 1000 || url.fragment().is_some() {
        return false;
    }
    if url.scheme() == APP_SCHEME {
        return true;
    }
    let origin = url.origin().ascii_serialization();
    matches!(url.scheme(), "http" | "https") && own_origins(headers).iter().any(|o| Url::parse(o).is_ok_and(|u| u.origin().ascii_serialization() == origin))
}

/// A redirect to `url` with `params` added to its query.
fn back_to(url: &str, params: &[(&str, &str)]) -> Response {
    let Ok(mut url) = Url::parse(url) else {
        return AppError::BadRequest("bad return address".into()).into_response();
    };
    {
        let mut q = url.query_pairs_mut();
        for (k, v) in params {
            q.append_pair(k, v);
        }
    }
    Redirect::to(url.as_str()).into_response()
}

#[derive(Deserialize)]
pub struct StartParams {
    return_to: String,
    challenge: String,
}

/// Step 1: remember the sign-in and send the browser to the provider.
pub async fn start(State(state): State<AppState>, headers: HeaderMap, Query(p): Query<StartParams>) -> Response {
    if !valid_return(&p.return_to, &headers) {
        return AppError::BadRequest("return_to must be a page of this server or the Nestling app".into()).into_response();
    }
    match start_url(&state, &headers, &p).await {
        Ok(url) => Redirect::to(&url).into_response(),
        Err(e) => back_to(&p.return_to, &[("sso_error", &e.to_string())]),
    }
}

async fn start_url(state: &AppState, headers: &HeaderMap, p: &StartParams) -> AppResult<String> {
    let oidc = oidc(state)?;
    if p.challenge.len() < 43 || p.challenge.len() > 128 {
        return bad("challenge must be base64url(SHA-256(verifier)) (43 characters)");
    }
    let d = oidc.discovery().await?;
    let now = now_ms();
    sqlx::query("DELETE FROM sso_logins WHERE expires_at < ?").bind(now).execute(&state.db).await?;
    let (state_token, nonce, verifier) = (random_token(), random_token(), random_token());
    let redirect_uri = format!("{}/api/v1/auth/sso/callback", crate::oauth::base_url(headers));
    sqlx::query(
        "INSERT INTO sso_logins (state_hash, nonce, pkce_verifier, redirect_uri, return_to, app_challenge, expires_at)
         VALUES (?, ?, ?, ?, ?, ?, ?)",
    )
    .bind(sha256_hex(&state_token))
    .bind(&nonce)
    .bind(&verifier)
    .bind(&redirect_uri)
    .bind(&p.return_to)
    .bind(&p.challenge)
    .bind(now + LOGIN_TTL_MS)
    .execute(&state.db)
    .await?;
    let mut url = Url::parse(&d.authorization_endpoint).map_err(|_| upstream("the provider's authorization_endpoint is not a URL".into()))?;
    url.query_pairs_mut()
        .append_pair("response_type", "code")
        .append_pair("client_id", &oidc.config.client_id)
        .append_pair("redirect_uri", &redirect_uri)
        .append_pair("scope", &oidc.config.scopes)
        .append_pair("state", &state_token)
        .append_pair("nonce", &nonce)
        .append_pair("code_challenge", &b64_sha256(&verifier))
        .append_pair("code_challenge_method", "S256");
    Ok(url.into())
}

#[derive(Deserialize)]
pub struct CallbackParams {
    state: Option<String>,
    code: Option<String>,
    error: Option<String>,
    error_description: Option<String>,
}

/// Step 2: the provider sends the browser back here.
pub async fn callback(State(state): State<AppState>, Query(p): Query<CallbackParams>) -> Response {
    let Some(state_token) = p.state.as_deref().filter(|s| !s.is_empty()) else {
        return AppError::BadRequest("state is missing".into()).into_response();
    };
    let row: Option<(String, String, String, String)> = match sqlx::query_as(
        "SELECT nonce, pkce_verifier, redirect_uri, return_to FROM sso_logins
         WHERE state_hash = ? AND code_hash IS NULL AND expires_at >= ?",
    )
    .bind(sha256_hex(state_token))
    .bind(now_ms())
    .fetch_optional(&state.db)
    .await
    {
        Ok(r) => r,
        Err(e) => return AppError::from(e).into_response(),
    };
    let Some((nonce, verifier, redirect_uri, return_to)) = row else {
        return AppError::BadRequest("this sign-in has expired or was already used: start again from the app".into()).into_response();
    };
    let result = match (&p.code, &p.error) {
        (_, Some(err)) => Err(AppError::Forbidden(format!(
            "the sign-in provider refused: {}",
            p.error_description.as_deref().filter(|d| !d.is_empty()).unwrap_or(err)
        ))),
        (Some(code), None) => finish(&state, code, &nonce, &verifier, &redirect_uri).await,
        (None, None) => Err(AppError::BadRequest("the sign-in provider sent no code".into())),
    };
    let state_hash = sha256_hex(state_token);
    match result {
        Ok(user_id) => {
            let code = random_token();
            if let Err(e) = sqlx::query("UPDATE sso_logins SET code_hash = ?, user_id = ? WHERE state_hash = ?")
                .bind(sha256_hex(&code))
                .bind(&user_id)
                .bind(&state_hash)
                .execute(&state.db)
                .await
            {
                return AppError::from(e).into_response();
            }
            back_to(&return_to, &[("sso_code", &code)])
        }
        Err(e) => {
            let _ = sqlx::query("DELETE FROM sso_logins WHERE state_hash = ?").bind(&state_hash).execute(&state.db).await;
            back_to(&return_to, &[("sso_error", &e.to_string())])
        }
    }
}

/// What the provider says about the person.
#[derive(Debug, Default, Deserialize)]
struct Claims {
    #[serde(default)]
    iss: String,
    #[serde(default)]
    sub: String,
    #[serde(default)]
    aud: Value,
    #[serde(default)]
    exp: i64,
    #[serde(default)]
    nonce: Option<String>,
    #[serde(default)]
    email: Option<String>,
    #[serde(default)]
    email_verified: Option<Value>,
    #[serde(default)]
    name: Option<String>,
    #[serde(default)]
    given_name: Option<String>,
    #[serde(default)]
    family_name: Option<String>,
    #[serde(default)]
    preferred_username: Option<String>,
}

impl Claims {
    /// Only `false` (or "false") counts as unverified: some providers leave the claim out.
    fn email_verified(&self) -> bool {
        !matches!(&self.email_verified, Some(Value::Bool(false))) && !matches!(&self.email_verified, Some(Value::String(s)) if s == "false")
    }

    fn display_name(&self) -> String {
        let full = [self.given_name.as_deref(), self.family_name.as_deref()].into_iter().flatten().collect::<Vec<_>>().join(" ");
        [self.name.clone(), Some(full), self.preferred_username.clone()]
            .into_iter()
            .flatten()
            .map(|n| n.trim().to_string())
            .find(|n| !n.is_empty())
            .or_else(|| self.email.as_deref().and_then(|e| e.split('@').next()).map(str::to_string))
            .unwrap_or_else(|| "Parent".into())
    }
}

/// The payload of a JWT, unchecked (see the module's note on why the signature isn't).
fn jwt_claims(jwt: &str) -> AppResult<Claims> {
    let payload = jwt.split('.').nth(1).ok_or_else(|| upstream("the ID token is not a JWT".into()))?;
    let bytes = URL_SAFE_NO_PAD.decode(payload.trim_end_matches('=')).map_err(|_| upstream("the ID token is not a JWT".into()))?;
    serde_json::from_slice(&bytes).map_err(|_| upstream("the ID token's claims can't be read".into()))
}

/// Trades the provider's code for the person's claims, then finds (or makes) their account.
async fn finish(state: &AppState, code: &str, nonce: &str, verifier: &str, redirect_uri: &str) -> AppResult<String> {
    let oidc = oidc(state)?;
    let d = oidc.discovery().await?;
    let cfg = &oidc.config;
    let mut form = vec![
        ("grant_type", "authorization_code"),
        ("code", code),
        ("redirect_uri", redirect_uri),
        ("code_verifier", verifier),
    ];
    let mut req = oidc.http.post(&d.token_endpoint);
    if cfg.client_secret.is_empty() {
        form.push(("client_id", &cfg.client_id));
    } else {
        req = req.basic_auth(&cfg.client_id, Some(&cfg.client_secret));
    }
    let res = req.form(&form).send().await.map_err(|e| upstream(format!("can't reach the sign-in provider: {e}")))?;
    let status = res.status();
    let body: Value = res.json().await.unwrap_or(Value::Null);
    if !status.is_success() {
        let why = body["error_description"].as_str().or(body["error"].as_str()).unwrap_or("no reason given");
        return Err(upstream(format!("the sign-in provider refused the code ({status}): {why}")));
    }
    let id_token = body["id_token"].as_str().ok_or_else(|| upstream("the sign-in provider sent no ID token (is `openid` in the scopes?)".into()))?;
    let mut claims = jwt_claims(id_token)?;

    // OpenID Connect Core 3.1.3.7.
    if claims.iss.trim_end_matches('/') != cfg.issuer {
        return Err(upstream(format!("the ID token comes from {}, not {}", claims.iss, cfg.issuer)));
    }
    let audience_ok = match &claims.aud {
        Value::String(a) => *a == cfg.client_id,
        Value::Array(a) => a.iter().any(|v| v.as_str() == Some(&cfg.client_id)),
        _ => false,
    };
    if !audience_ok {
        return Err(upstream("the ID token is for another app (check NESTLING_OIDC_CLIENT_ID)".into()));
    }
    if claims.exp * 1000 < now_ms() - 60_000 {
        return Err(upstream("the ID token has expired (is the server's clock right?)".into()));
    }
    if claims.nonce.as_deref() != Some(nonce) {
        return Err(upstream("the ID token doesn't belong to this sign-in".into()));
    }
    if claims.sub.is_empty() {
        return Err(upstream("the ID token has no subject".into()));
    }

    // Some providers put the email and name only in the user info.
    if claims.email.is_none() {
        if let (Some(url), Some(access)) = (&d.userinfo_endpoint, body["access_token"].as_str()) {
            if let Ok(res) = oidc.http.get(url).bearer_auth(access).send().await {
                if let Ok(info) = res.json::<Claims>().await {
                    if info.sub == claims.sub {
                        claims.email = info.email;
                        claims.email_verified = info.email_verified;
                        claims.name = claims.name.or(info.name);
                        claims.given_name = claims.given_name.or(info.given_name);
                        claims.family_name = claims.family_name.or(info.family_name);
                        claims.preferred_username = claims.preferred_username.or(info.preferred_username);
                    }
                }
            }
        }
    }
    account_for(state, &cfg.issuer, &claims, cfg.signup).await
}

/// The Nestling account for the provider's account: linked before, else by email, else a new one
/// when allowed.
async fn account_for(state: &AppState, issuer: &str, claims: &Claims, signup: bool) -> AppResult<String> {
    let linked: Option<(String,)> = sqlx::query_as(
        "SELECT i.user_id FROM user_identities i JOIN users u ON u.id = i.user_id
         WHERE i.issuer = ? AND i.subject = ? AND u.kind = 'person'",
    )
    .bind(issuer)
    .bind(&claims.sub)
    .fetch_optional(&state.db)
    .await?;
    if let Some((id,)) = linked {
        return Ok(id);
    }
    let email = claims.email.as_deref().map(|e| e.trim().to_lowercase()).filter(|e| e.contains('@'));
    let Some(email) = email else {
        return Err(AppError::Forbidden("the sign-in provider didn't share an email address (add `email` to the scopes)".into()));
    };
    if !claims.email_verified() {
        return Err(AppError::Forbidden(format!("{email} isn't verified with the sign-in provider")));
    }
    let existing: Option<(String,)> = sqlx::query_as("SELECT id FROM users WHERE email = ? AND kind = 'person'")
        .bind(&email)
        .fetch_optional(&state.db)
        .await?;
    let id = match existing {
        Some((id,)) => id,
        None => {
            let (users,): (i64,) = sqlx::query_as("SELECT COUNT(*) FROM users").fetch_one(&state.db).await?;
            if users > 0 && !signup && !state.config.open_registration {
                return Err(AppError::Forbidden(format!(
                    "there is no Nestling account for {email}: ask the server's admin to add one with this email"
                )));
            }
            let id = new_id();
            // No password: this account signs in with SSO (an admin can still give it one).
            sqlx::query("INSERT INTO users (id, email, name, password_hash, units, created_at, is_admin) VALUES (?, ?, ?, '', 'metric', ?, ?)")
                .bind(&id)
                .bind(&email)
                .bind(claims.display_name())
                .bind(now_ms())
                .bind(users == 0)
                .execute(&state.db)
                .await?;
            id
        }
    };
    sqlx::query("INSERT OR IGNORE INTO user_identities (issuer, subject, user_id, created_at) VALUES (?, ?, ?, ?)")
        .bind(issuer)
        .bind(&claims.sub)
        .bind(&id)
        .bind(now_ms())
        .execute(&state.db)
        .await?;
    Ok(id)
}

#[derive(Deserialize)]
pub struct TokenReq {
    code: String,
    verifier: String,
}

/// Step 3: the app trades the one-time code and its verifier for a session.
pub async fn token(State(state): State<AppState>, ApiJson(req): ApiJson<TokenReq>) -> AppResult<Json<Value>> {
    oidc(&state)?;
    let row: Option<(String, String)> = sqlx::query_as(
        "DELETE FROM sso_logins WHERE code_hash = ? AND expires_at >= ? AND user_id IS NOT NULL RETURNING user_id, app_challenge",
    )
    .bind(sha256_hex(req.code.trim()))
    .bind(now_ms())
    .fetch_optional(&state.db)
    .await?;
    let Some((user_id, challenge)) = row else {
        return bad("this sign-in code has expired or was already used: sign in again");
    };
    if b64_sha256(req.verifier.trim()) != challenge {
        return bad("the verifier doesn't match this sign-in");
    }
    let (_, token) = issue_token(&state.db, &user_id, "login", "session").await?;
    Ok(Json(json!({ "token": token, "user": user_json(&state, &user_id).await? })))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn return_addresses() {
        let mut h = HeaderMap::new();
        h.insert("host", "nestling.example.com".parse().unwrap());
        h.insert("x-forwarded-proto", "https".parse().unwrap());
        assert!(valid_return("https://nestling.example.com/", &h));
        assert!(valid_return("https://nestling.example.com/?x=1", &h));
        assert!(valid_return("io.github.jfchenier.nestling://sso", &h));
        assert!(!valid_return("https://evil.example.com/", &h));
        assert!(!valid_return("http://nestling.example.com/", &h));
        assert!(!valid_return("https://nestling.example.com.evil.example.com/", &h));
        assert!(!valid_return("javascript:alert(1)", &h));
        assert!(!valid_return("https://nestling.example.com/#x", &h));
    }

    #[test]
    fn names_and_verified_emails() {
        let c: Claims = serde_json::from_value(json!({ "given_name": "Ada", "family_name": "L", "email": "a@b.c" })).unwrap();
        assert_eq!(c.display_name(), "Ada L");
        assert!(c.email_verified());
        let c: Claims = serde_json::from_value(json!({ "email": "ada@b.c", "email_verified": false })).unwrap();
        assert_eq!(c.display_name(), "ada");
        assert!(!c.email_verified());
        let c: Claims = serde_json::from_value(json!({ "preferred_username": "ada", "email_verified": "true" })).unwrap();
        assert_eq!(c.display_name(), "ada");
        assert!(c.email_verified());
    }
}
