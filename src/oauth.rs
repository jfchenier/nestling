//! OAuth 2.1 for MCP clients such as Claude (see `mcp.rs`). An app registers itself
//! (`/oauth/register`, RFC 7591), sends the owner to `/oauth/authorize` to sign in and pick a
//! family, then trades the code (with PKCE) for a token at `/oauth/token`. The token is the API
//! token of a connected app named after the client (e.g. "Claude") in that family, so it can do
//! what connected apps do (`auth::integration_may`) and the owner removes it under Family →
//! Connected apps. Tokens don't expire, so there is no refresh token.

use std::net::SocketAddr;

use axum::{
    extract::{ConnectInfo, Form, Query, State},
    http::{header, HeaderMap, HeaderValue, StatusCode},
    response::{Html, IntoResponse, Redirect, Response},
    routing::{get, post},
    Extension, Json, Router,
};
use base64::{engine::general_purpose::URL_SAFE_NO_PAD, Engine};
use reqwest::Url;
use serde::Deserialize;
use serde_json::{json, Value};
use sha2::{Digest, Sha256};

use crate::{
    auth::{issue_token, verify_password},
    limiter::{client_addr, PER_ACCOUNT, PER_ADDRESS},
    routes::integrations,
    state::AppState,
    util::{new_id, now_ms, random_token, sha256_hex},
};

/// How long a sign-in code (or the pick-a-family step) stays valid.
const CODE_TTL_MS: i64 = 10 * 60 * 1000;
/// Registered apps that never got a token are forgotten after this long.
const UNUSED_CLIENT_TTL_MS: i64 = 7 * 24 * 3600 * 1000;

pub fn routes() -> Router<AppState> {
    Router::new()
        .route("/.well-known/oauth-protected-resource", get(protected_resource))
        .route("/.well-known/oauth-protected-resource/mcp", get(protected_resource))
        .route("/.well-known/oauth-authorization-server", get(authorization_server))
        .route("/oauth/register", post(register))
        .route("/oauth/authorize", get(authorize_page).post(authorize_submit))
        .route("/oauth/token", post(token))
}

/// The server's public address, for the URLs in the metadata: `NESTLING_PUBLIC_URL` if set
/// (e.g. `https://nestling.example.com`), else what the reverse proxy reports
/// (`X-Forwarded-Proto`, `X-Forwarded-Host`), else the `Host` header over plain HTTP.
pub fn base_url(headers: &HeaderMap) -> String {
    if let Ok(url) = std::env::var("NESTLING_PUBLIC_URL") {
        let url = url.trim().trim_end_matches('/');
        if !url.is_empty() {
            return url.to_string();
        }
    }
    let header = |name: &str| {
        headers.get(name).and_then(|v| v.to_str().ok()).and_then(|v| v.split(',').next()).map(str::trim).filter(|v| !v.is_empty())
    };
    let proto = header("x-forwarded-proto").unwrap_or("http");
    let host = header("x-forwarded-host").or_else(|| header("host")).unwrap_or("localhost");
    format!("{proto}://{host}")
}

/// RFC 9728: where the MCP endpoint's tokens come from.
async fn protected_resource(headers: HeaderMap) -> Json<Value> {
    let base = base_url(&headers);
    Json(json!({
        "resource": format!("{base}/mcp"),
        "authorization_servers": [base],
        "bearer_methods_supported": ["header"],
        "resource_name": "Nestling",
    }))
}

/// RFC 8414.
async fn authorization_server(headers: HeaderMap) -> Json<Value> {
    let base = base_url(&headers);
    Json(json!({
        "issuer": base,
        "authorization_endpoint": format!("{base}/oauth/authorize"),
        "token_endpoint": format!("{base}/oauth/token"),
        "registration_endpoint": format!("{base}/oauth/register"),
        "response_types_supported": ["code"],
        "grant_types_supported": ["authorization_code"],
        "code_challenge_methods_supported": ["S256"],
        "token_endpoint_auth_methods_supported": ["none"],
    }))
}

/// An OAuth error answer (`{"error", "error_description"}`).
fn oauth_error(status: StatusCode, error: &str, description: &str) -> Response {
    (status, [(header::CACHE_CONTROL, "no-store")], Json(json!({ "error": error, "error_description": description }))).into_response()
}

/// A redirect URI an app may register: `https`, or `http` back to this computer (desktop apps).
fn valid_redirect(uri: &str) -> bool {
    let Ok(url) = Url::parse(uri) else { return false };
    if uri.len() > 500 || url.fragment().is_some() {
        return false;
    }
    match url.scheme() {
        "https" => url.host().is_some(),
        "http" => matches!(url.host_str(), Some("localhost" | "127.0.0.1" | "[::1]")),
        _ => false,
    }
}

#[derive(Deserialize)]
struct RegisterReq {
    #[serde(default)]
    redirect_uris: Vec<String>,
    #[serde(default)]
    client_name: Option<String>,
}

/// Dynamic client registration (RFC 7591). Open to anyone, like a sign-in page: an app gets
/// nothing until an owner signs in for it. Limited per address.
async fn register(
    State(state): State<AppState>,
    headers: HeaderMap,
    conn: Option<Extension<ConnectInfo<SocketAddr>>>,
    body: axum::body::Bytes,
) -> Response {
    let now = now_ms();
    let addr_key = format!("oauth-register:{}", client_addr(&headers, conn.as_deref()));
    if let Err(e) = state.limiter.check(&addr_key, PER_ADDRESS, now) {
        return oauth_error(StatusCode::TOO_MANY_REQUESTS, "slow_down", &e.to_string());
    }
    state.limiter.hit(&addr_key, now);
    let req: RegisterReq = match serde_json::from_slice(&body) {
        Ok(r) => r,
        Err(e) => return oauth_error(StatusCode::BAD_REQUEST, "invalid_client_metadata", &format!("invalid JSON: {e}")),
    };
    if req.redirect_uris.is_empty() || req.redirect_uris.len() > 5 || !req.redirect_uris.iter().all(|u| valid_redirect(u)) {
        return oauth_error(
            StatusCode::BAD_REQUEST,
            "invalid_redirect_uri",
            "redirect_uris: 1 to 5 https addresses (or http on localhost)",
        );
    }
    let name: String = req.client_name.as_deref().map(str::trim).filter(|n| !n.is_empty()).unwrap_or("MCP client").chars().take(60).collect();
    let id = new_id();
    let saved = async {
        sqlx::query("DELETE FROM oauth_clients WHERE used_at IS NULL AND created_at < ?").bind(now - UNUSED_CLIENT_TTL_MS).execute(&state.db).await?;
        sqlx::query("INSERT INTO oauth_clients (id, name, redirect_uris, created_at) VALUES (?, ?, ?, ?)")
            .bind(&id)
            .bind(&name)
            .bind(json!(req.redirect_uris).to_string())
            .bind(now)
            .execute(&state.db)
            .await
    };
    if let Err(e) = saved.await {
        tracing::error!("could not register an OAuth client: {e}");
        return oauth_error(StatusCode::INTERNAL_SERVER_ERROR, "server_error", "could not register the app");
    }
    (
        StatusCode::CREATED,
        [(header::CACHE_CONTROL, "no-store")],
        Json(json!({
            "client_id": id,
            "client_name": name,
            "redirect_uris": req.redirect_uris,
            "client_id_issued_at": now / 1000,
            "token_endpoint_auth_method": "none",
            "grant_types": ["authorization_code"],
            "response_types": ["code"],
        })),
    )
        .into_response()
}

/// The sign-in request's parameters, carried in the page's form between steps.
#[derive(Deserialize, Default, Clone)]
struct AuthParams {
    #[serde(default)]
    response_type: Option<String>,
    #[serde(default)]
    client_id: Option<String>,
    #[serde(default)]
    redirect_uri: Option<String>,
    #[serde(default)]
    code_challenge: Option<String>,
    #[serde(default)]
    code_challenge_method: Option<String>,
    #[serde(default)]
    state: Option<String>,
    #[serde(default)]
    scope: Option<String>,
    #[serde(default)]
    resource: Option<String>,
}

/// A checked sign-in request.
struct Request {
    client_id: String,
    client_name: String,
    redirect_uri: String,
    code_challenge: String,
    state: Option<String>,
}

/// Checks the request. An unknown app or redirect URI gets an error page (never a redirect to
/// an address we can't trust); other mistakes go back to the app.
async fn check_request(state: &AppState, p: &AuthParams) -> Result<Request, Response> {
    let client_id = p.client_id.clone().unwrap_or_default();
    let client: Option<(String, String)> = sqlx::query_as("SELECT name, redirect_uris FROM oauth_clients WHERE id = ?")
        .bind(&client_id)
        .fetch_optional(&state.db)
        .await
        .map_err(|e| error_page(StatusCode::INTERNAL_SERVER_ERROR, &format!("database error: {e}")))?;
    let Some((client_name, uris)) = client else {
        return Err(error_page(StatusCode::BAD_REQUEST, "This app is not registered with this Nestling server. Try connecting it again."));
    };
    let uris: Vec<String> = serde_json::from_str(&uris).unwrap_or_default();
    let redirect_uri = match &p.redirect_uri {
        Some(u) if uris.contains(u) => u.clone(),
        None if uris.len() == 1 => uris[0].clone(),
        _ => return Err(error_page(StatusCode::BAD_REQUEST, "This app's return address doesn't match the one it registered.")),
    };
    let back = |error: &str| redirect_with(&redirect_uri, &[("error", error)], p.state.as_deref());
    if p.response_type.as_deref() != Some("code") {
        return Err(back("unsupported_response_type"));
    }
    let challenge = p.code_challenge.clone().unwrap_or_default();
    if p.code_challenge_method.as_deref() != Some("S256") || challenge.len() < 43 || challenge.len() > 128 {
        return Err(back("invalid_request"));
    }
    Ok(Request { client_id, client_name, redirect_uri, code_challenge: challenge, state: p.state.clone() })
}

/// 303 to the app's redirect URI with `params` and `state` added.
fn redirect_with(redirect_uri: &str, params: &[(&str, &str)], state: Option<&str>) -> Response {
    let mut url = match Url::parse(redirect_uri) {
        Ok(u) => u,
        Err(_) => return error_page(StatusCode::BAD_REQUEST, "bad return address"),
    };
    {
        let mut q = url.query_pairs_mut();
        for (k, v) in params {
            q.append_pair(k, v);
        }
        if let Some(s) = state {
            q.append_pair("state", s);
        }
    }
    Redirect::to(url.as_str()).into_response()
}

async fn authorize_page(State(state): State<AppState>, Query(p): Query<AuthParams>) -> Response {
    match check_request(&state, &p).await {
        Ok(req) => sign_in_page(&req, &p, None, ""),
        Err(r) => r,
    }
}

#[derive(Deserialize)]
struct AuthForm {
    #[serde(flatten)]
    params: AuthParams,
    #[serde(default)]
    email: Option<String>,
    #[serde(default)]
    password: Option<String>,
    /// Second step: the pending sign-in and the family picked.
    #[serde(default)]
    ticket: Option<String>,
    #[serde(default)]
    family_id: Option<String>,
    /// The Cancel button.
    #[serde(default)]
    cancel: Option<String>,
}

async fn authorize_submit(
    State(state): State<AppState>,
    headers: HeaderMap,
    conn: Option<Extension<ConnectInfo<SocketAddr>>>,
    Form(form): Form<AuthForm>,
) -> Response {
    if let Some(ticket) = &form.ticket {
        return pick_family(&state, ticket, form.family_id.as_deref().unwrap_or(""), form.cancel.is_some()).await;
    }
    let req = match check_request(&state, &form.params).await {
        Ok(r) => r,
        Err(r) => return r,
    };
    if form.cancel.is_some() {
        return redirect_with(&req.redirect_uri, &[("error", "access_denied")], req.state.as_deref());
    }
    let email = form.email.as_deref().unwrap_or("").trim().to_lowercase();
    let password = form.password.as_deref().unwrap_or("");
    let account_key = format!("login:{email}");
    let addr_key = format!("addr:{}", client_addr(&headers, conn.as_deref()));
    let now = now_ms();
    if let Err(e) = state.limiter.check(&account_key, PER_ACCOUNT, now).and_then(|_| state.limiter.check(&addr_key, PER_ADDRESS, now)) {
        return sign_in_page(&req, &form.params, Some(&e.to_string()), &email);
    }
    let row: Option<(String, String)> = match sqlx::query_as("SELECT id, password_hash FROM users WHERE email = ? AND kind = 'person'")
        .bind(&email)
        .fetch_optional(&state.db)
        .await
    {
        Ok(r) => r,
        Err(e) => return error_page(StatusCode::INTERNAL_SERVER_ERROR, &format!("database error: {e}")),
    };
    let Some((user_id, _)) = row.filter(|(_, h)| verify_password(password, h)) else {
        state.limiter.hit(&account_key, now);
        state.limiter.hit(&addr_key, now);
        return sign_in_page(&req, &form.params, Some("Wrong email or password."), &email);
    };
    state.limiter.clear(&account_key);
    let families = match owned_families(&state, &user_id).await {
        Ok(f) => f,
        Err(e) => return error_page(StatusCode::INTERNAL_SERVER_ERROR, &format!("database error: {e}")),
    };
    if families.is_empty() {
        return error_page(StatusCode::FORBIDDEN, "Only a family's owner can connect an app, and this account owns no family.");
    }
    let single = (families.len() == 1).then(|| families[0].0.clone());
    let code = random_token();
    let saved = async {
        sqlx::query("DELETE FROM oauth_codes WHERE expires_at < ?").bind(now).execute(&state.db).await?;
        sqlx::query(
            "INSERT INTO oauth_codes (code_hash, client_id, user_id, family_id, redirect_uri, code_challenge, state, expires_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        )
        .bind(sha256_hex(&code))
        .bind(&req.client_id)
        .bind(&user_id)
        .bind(&single)
        .bind(&req.redirect_uri)
        .bind(&req.code_challenge)
        .bind(&req.state)
        .bind(now + CODE_TTL_MS)
        .execute(&state.db)
        .await
    };
    if let Err(e) = saved.await {
        return error_page(StatusCode::INTERNAL_SERVER_ERROR, &format!("database error: {e}"));
    }
    if single.is_some() {
        return redirect_with(&req.redirect_uri, &[("code", &code)], req.state.as_deref());
    }
    family_page(&req.client_name, &code, &families)
}

async fn owned_families(state: &AppState, user_id: &str) -> Result<Vec<(String, String)>, sqlx::Error> {
    sqlx::query_as(
        "SELECT f.id, f.name FROM families f JOIN memberships m ON m.family_id = f.id
         WHERE m.user_id = ? AND m.role = 'owner' ORDER BY f.created_at",
    )
    .bind(user_id)
    .fetch_all(&state.db)
    .await
}

/// Second step, for owners of several families: the ticket becomes a code for the family picked.
async fn pick_family(state: &AppState, ticket: &str, family_id: &str, cancel: bool) -> Response {
    let row: Option<(String, String, Option<String>)> = match sqlx::query_as(
        "SELECT user_id, redirect_uri, state FROM oauth_codes WHERE code_hash = ? AND family_id IS NULL AND expires_at >= ?",
    )
    .bind(sha256_hex(ticket))
    .bind(now_ms())
    .fetch_optional(&state.db)
    .await
    {
        Ok(r) => r,
        Err(e) => return error_page(StatusCode::INTERNAL_SERVER_ERROR, &format!("database error: {e}")),
    };
    let Some((user_id, redirect_uri, app_state)) = row else {
        return error_page(StatusCode::BAD_REQUEST, "This sign-in has expired. Start connecting the app again.");
    };
    if cancel {
        let _ = sqlx::query("DELETE FROM oauth_codes WHERE code_hash = ?").bind(sha256_hex(ticket)).execute(&state.db).await;
        return redirect_with(&redirect_uri, &[("error", "access_denied")], app_state.as_deref());
    }
    match owned_families(state, &user_id).await {
        Ok(f) if f.iter().any(|(id, _)| id == family_id) => {}
        Ok(_) => return error_page(StatusCode::BAD_REQUEST, "Pick one of your families."),
        Err(e) => return error_page(StatusCode::INTERNAL_SERVER_ERROR, &format!("database error: {e}")),
    }
    let code = random_token();
    let res = sqlx::query("UPDATE oauth_codes SET code_hash = ?, family_id = ? WHERE code_hash = ? AND family_id IS NULL")
        .bind(sha256_hex(&code))
        .bind(family_id)
        .bind(sha256_hex(ticket))
        .execute(&state.db)
        .await;
    match res {
        Ok(r) if r.rows_affected() == 1 => redirect_with(&redirect_uri, &[("code", &code)], app_state.as_deref()),
        Ok(_) => error_page(StatusCode::BAD_REQUEST, "This sign-in was already used. Start connecting the app again."),
        Err(e) => error_page(StatusCode::INTERNAL_SERVER_ERROR, &format!("database error: {e}")),
    }
}

#[derive(Deserialize)]
struct TokenReq {
    #[serde(default)]
    grant_type: String,
    #[serde(default)]
    code: String,
    #[serde(default)]
    redirect_uri: Option<String>,
    #[serde(default)]
    client_id: String,
    #[serde(default)]
    code_verifier: String,
}

type CodeRow = (String, String, Option<String>, String, String, i64);

/// The code (used once) for the API token of the client's connected app in the family.
async fn token(State(state): State<AppState>, Form(req): Form<TokenReq>) -> Response {
    if req.grant_type != "authorization_code" {
        return oauth_error(StatusCode::BAD_REQUEST, "unsupported_grant_type", "only authorization_code is supported");
    }
    let invalid = |why: &str| oauth_error(StatusCode::BAD_REQUEST, "invalid_grant", why);
    let row: Option<CodeRow> = match sqlx::query_as(
        "DELETE FROM oauth_codes WHERE code_hash = ?
         RETURNING client_id, user_id, family_id, redirect_uri, code_challenge, expires_at",
    )
    .bind(sha256_hex(&req.code))
    .fetch_optional(&state.db)
    .await
    {
        Ok(r) => r,
        Err(e) => {
            tracing::error!("oauth token: {e}");
            return oauth_error(StatusCode::INTERNAL_SERVER_ERROR, "server_error", "database error");
        }
    };
    let Some((client_id, user_id, family_id, redirect_uri, challenge, expires_at)) = row else {
        return invalid("unknown or already used code");
    };
    let Some(family_id) = family_id else { return invalid("no family was picked") };
    if expires_at < now_ms() {
        return invalid("the code has expired");
    }
    if client_id != req.client_id || req.redirect_uri.as_ref().is_some_and(|u| *u != redirect_uri) {
        return invalid("the code was given to another app or return address");
    }
    if URL_SAFE_NO_PAD.encode(Sha256::digest(req.code_verifier.as_bytes())) != challenge {
        return invalid("code_verifier doesn't match the code_challenge");
    }
    match connect_app(&state, &client_id, &user_id, &family_id).await {
        Ok(Some(token)) => {
            (StatusCode::OK, [(header::CACHE_CONTROL, "no-store")], Json(json!({ "access_token": token, "token_type": "Bearer" }))).into_response()
        }
        Ok(None) => invalid("the account is no longer an owner of that family"),
        Err(e) => {
            tracing::error!("oauth token: {e}");
            oauth_error(StatusCode::INTERNAL_SERVER_ERROR, "server_error", "could not connect the app")
        }
    }
}

/// A token for the client's connected app in the family, which is added the first time (same
/// name, same app: connecting again adds a token to it). None if the user no longer owns it.
async fn connect_app(state: &AppState, client_id: &str, user_id: &str, family_id: &str) -> crate::error::AppResult<Option<String>> {
    let owner: Option<(String,)> = sqlx::query_as("SELECT role FROM memberships WHERE family_id = ? AND user_id = ? AND role = 'owner'")
        .bind(family_id)
        .bind(user_id)
        .fetch_optional(&state.db)
        .await?;
    if owner.is_none() {
        return Ok(None);
    }
    let (name,): (String,) = sqlx::query_as("SELECT name FROM oauth_clients WHERE id = ?").bind(client_id).fetch_one(&state.db).await?;
    let existing: Option<(String,)> = sqlx::query_as(
        "SELECT u.id FROM memberships m JOIN users u ON u.id = m.user_id
         WHERE m.family_id = ? AND u.kind = 'integration' AND u.name = ? ORDER BY u.created_at LIMIT 1",
    )
    .bind(family_id)
    .bind(&name)
    .fetch_optional(&state.db)
    .await?;
    let app_id = match existing {
        Some((id,)) => id,
        None => integrations::add(&state.db, family_id, &name).await?.0,
    };
    let (_, token) = issue_token(&state.db, &app_id, &name, "api").await?;
    sqlx::query("UPDATE oauth_clients SET used_at = ? WHERE id = ? AND used_at IS NULL").bind(now_ms()).bind(client_id).execute(&state.db).await?;
    state.publish(family_id, "family", "updated", json!({ "id": family_id }));
    Ok(Some(token))
}

// --- Pages -------------------------------------------------------------------------------

fn esc(s: &str) -> String {
    s.replace('&', "&amp;").replace('<', "&lt;").replace('>', "&gt;").replace('"', "&quot;").replace('\'', "&#39;")
}

fn hidden(name: &str, value: &Option<String>) -> String {
    value.as_ref().map(|v| format!(r#"<input type="hidden" name="{}" value="{}">"#, name, esc(v))).unwrap_or_default()
}

/// A plain page in the app's colors (oat and eucalyptus), light or dark like the device.
fn page(status: StatusCode, title: &str, body: &str) -> Response {
    let html = format!(
        r#"<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title} · Nestling</title><style>
:root{{--bg:#f6f1e9;--card:#fffdf9;--text:#2f2a24;--muted:#6f675c;--accent:#4f7a68;--on-accent:#fff;--line:#e4dccf;--error:#a8432f}}
@media (prefers-color-scheme:dark){{:root{{--bg:#1d1b18;--card:#28251f;--text:#efe9df;--muted:#b3aa9c;--accent:#8fbca7;--on-accent:#14211b;--line:#3a352d;--error:#f0a08d}}}}
*{{box-sizing:border-box}}body{{margin:0;background:var(--bg);color:var(--text);font:16px/1.45 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;display:flex;justify-content:center;padding:32px 16px}}
main{{width:100%;max-width:400px;background:var(--card);border:1px solid var(--line);border-radius:20px;padding:28px}}
h1{{font-size:22px;margin:0 0 8px}}p{{margin:0 0 16px;color:var(--muted)}}strong{{color:var(--text)}}
label{{display:block;font-weight:600;margin:12px 0 4px}}input[type=email],input[type=password]{{width:100%;padding:12px;border-radius:12px;border:1px solid var(--line);background:var(--bg);color:var(--text);font:inherit}}
.choice{{display:flex;gap:10px;align-items:center;padding:12px;border:1px solid var(--line);border-radius:12px;margin:8px 0;font-weight:600}}
.buttons{{display:flex;gap:10px;margin-top:20px}}button{{flex:1;padding:12px;border-radius:12px;border:0;font:inherit;font-weight:700;cursor:pointer}}
.primary{{background:var(--accent);color:var(--on-accent)}}.secondary{{background:transparent;color:var(--muted);border:1px solid var(--line)}}
.error{{color:var(--error);font-weight:600}}ul{{color:var(--muted);padding-left:20px;margin:0 0 8px}}
</style></head><body><main>{body}</main></body></html>"#,
        title = esc(title),
    );
    let mut res = (status, Html(html)).into_response();
    let h = res.headers_mut();
    h.insert(header::CACHE_CONTROL, HeaderValue::from_static("no-store"));
    h.insert("x-frame-options", HeaderValue::from_static("DENY"));
    h.insert(header::CONTENT_SECURITY_POLICY, HeaderValue::from_static("frame-ancestors 'none'"));
    res
}

fn error_page(status: StatusCode, message: &str) -> Response {
    page(status, "Can't connect", &format!("<h1>Can't connect</h1><p>{}</p>", esc(message)))
}

fn host_of(uri: &str) -> String {
    Url::parse(uri).ok().and_then(|u| u.host_str().map(str::to_string)).unwrap_or_default()
}

fn sign_in_page(req: &Request, p: &AuthParams, error: Option<&str>, email: &str) -> Response {
    let params = [
        ("response_type", &p.response_type),
        ("client_id", &p.client_id),
        ("redirect_uri", &Some(req.redirect_uri.clone())),
        ("code_challenge", &p.code_challenge),
        ("code_challenge_method", &p.code_challenge_method),
        ("state", &p.state),
        ("scope", &p.scope),
        ("resource", &p.resource),
    ]
    .iter()
    .map(|(k, v)| hidden(k, v))
    .collect::<String>();
    let error = error.map(|e| format!(r#"<p class="error">{}</p>"#, esc(e))).unwrap_or_default();
    let body = format!(
        r#"<h1>Connect {name} to Nestling</h1>
<p><strong>{name}</strong> ({host}) wants to:</p>
<ul><li>see your children, their entries and summaries</li><li>log, change and delete entries</li><li>start and stop timers</li></ul>
<p>It joins the family as a connected app named <strong>{name}</strong>. A family owner can remove it in the app under Family → Connected apps.</p>
{error}<form method="post" action="/oauth/authorize">{params}
<label for="email">Email</label><input id="email" name="email" type="email" autocomplete="username" required value="{email}">
<label for="password">Password</label><input id="password" name="password" type="password" autocomplete="current-password" required>
<div class="buttons"><button class="secondary" name="cancel" value="1" formnovalidate>Cancel</button><button class="primary" type="submit">Sign in and allow</button></div>
</form>"#,
        name = esc(&req.client_name),
        host = esc(&host_of(&req.redirect_uri)),
        email = esc(email),
    );
    page(if error.is_empty() { StatusCode::OK } else { StatusCode::BAD_REQUEST }, "Connect an app", &body)
}

fn family_page(client_name: &str, ticket: &str, families: &[(String, String)]) -> Response {
    let choices = families
        .iter()
        .enumerate()
        .map(|(i, (id, name))| {
            format!(
                r#"<label class="choice"><input type="radio" name="family_id" value="{}"{}> {}</label>"#,
                esc(id),
                if i == 0 { " checked" } else { "" },
                esc(name)
            )
        })
        .collect::<String>();
    let body = format!(
        r#"<h1>Which family?</h1><p>Pick the family <strong>{name}</strong> will log for.</p>
<form method="post" action="/oauth/authorize"><input type="hidden" name="ticket" value="{ticket}">{choices}
<div class="buttons"><button class="secondary" name="cancel" value="1">Cancel</button><button class="primary" type="submit">Allow</button></div></form>"#,
        name = esc(client_name),
        ticket = esc(ticket),
    );
    page(StatusCode::OK, "Pick a family", &body)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn redirect_uris() {
        assert!(valid_redirect("https://claude.ai/api/mcp/auth_callback"));
        assert!(valid_redirect("http://localhost:33418/callback"));
        assert!(valid_redirect("http://127.0.0.1/cb"));
        assert!(!valid_redirect("http://evil.example.com/cb"));
        assert!(!valid_redirect("https://claude.ai/cb#frag"));
        assert!(!valid_redirect("javascript:alert(1)"));
        assert!(!valid_redirect("not a url"));
    }

    #[test]
    fn base_url_from_headers() {
        let mut h = HeaderMap::new();
        h.insert("host", "nestling.local:8080".parse().unwrap());
        assert_eq!(base_url(&h), "http://nestling.local:8080");
        h.insert("x-forwarded-proto", "https".parse().unwrap());
        h.insert("x-forwarded-host", "nestling.example.com".parse().unwrap());
        assert_eq!(base_url(&h), "https://nestling.example.com");
    }
}
