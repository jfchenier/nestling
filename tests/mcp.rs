//! The MCP server and the OAuth sign-in its connector uses, end to end.

use axum::{
    body::Body,
    http::{Method, Request, StatusCode},
    Router,
};
use base64::{engine::general_purpose::URL_SAFE_NO_PAD, Engine};
use http_body_util::BodyExt;
use nestling::{app, connect, AppState, Config, NaraConfig};
use serde_json::{json, Value};
use sha2::{Digest, Sha256};
use tower::ServiceExt;

const REDIRECT: &str = "https://claude.ai/api/mcp/auth_callback";
const VERIFIER: &str = "a-long-random-code-verifier-string-of-at-least-43-characters";

struct Res {
    status: StatusCode,
    headers: axum::http::HeaderMap,
    body: String,
}

impl Res {
    fn json(&self) -> Value {
        serde_json::from_str(&self.body).unwrap_or(Value::Null)
    }
}

async fn send(app: &Router, method: Method, uri: &str, token: Option<&str>, content_type: &str, body: String) -> Res {
    let mut req = Request::builder().method(method).uri(uri).header("host", "nestling.example.com").header("x-forwarded-proto", "https");
    if let Some(t) = token {
        req = req.header("authorization", format!("Bearer {t}"));
    }
    if !content_type.is_empty() {
        req = req.header("content-type", content_type);
    }
    let res = app.clone().oneshot(req.body(Body::from(body)).unwrap()).await.unwrap();
    let status = res.status();
    let headers = res.headers().clone();
    let bytes = res.into_body().collect().await.unwrap().to_bytes();
    Res { status, headers, body: String::from_utf8_lossy(&bytes).into_owned() }
}

async fn api(app: &Router, method: Method, path: &str, token: &str, body: Option<Value>) -> Value {
    let res = send(app, method, &format!("/api/v1{path}"), Some(token), "application/json", body.map(|b| b.to_string()).unwrap_or_default()).await;
    assert!(res.status.is_success(), "{path}: {} {}", res.status, res.body);
    res.json()
}

fn form(pairs: &[(&str, &str)]) -> String {
    let mut s = reqwest::Url::parse("http://x/").unwrap();
    s.query_pairs_mut().extend_pairs(pairs);
    s.query().unwrap_or("").to_string()
}

/// A server with one owner (`mom@example.com`), a family and a child; returns the owner's token
/// and the family id.
async fn setup() -> (Router, String, String) {
    let db = connect("sqlite::memory:", 1).await.unwrap();
    let app = app(AppState::new(db, Config { open_registration: true, nara: NaraConfig::default() }), None);
    let reg = api(&app, Method::POST, "/auth/register", "", Some(json!({ "email": "mom@example.com", "password": "password123", "name": "Mom" }))).await;
    let token = reg["token"].as_str().unwrap().to_string();
    let fam = api(&app, Method::POST, "/families", &token, Some(json!({ "name": "Home", "timezone": "America/New_York" }))).await;
    let fid = fam["id"].as_str().unwrap().to_string();
    api(&app, Method::POST, &format!("/families/{fid}/children"), &token, Some(json!({ "name": "Léa Rose", "birth_date": "2026-06-01" }))).await;
    (app, token, fid)
}

/// Registers an app named `name` and signs in for it; returns the token.
async fn connect_app(app: &Router, name: &str) -> String {
    let reg = send(app, Method::POST, "/oauth/register", None, "application/json", json!({ "client_name": name, "redirect_uris": [REDIRECT] }).to_string()).await;
    assert_eq!(reg.status, StatusCode::CREATED, "{}", reg.body);
    let client_id = reg.json()["client_id"].as_str().unwrap().to_string();
    let challenge = URL_SAFE_NO_PAD.encode(Sha256::digest(VERIFIER.as_bytes()));
    let params = [
        ("response_type", "code"),
        ("client_id", client_id.as_str()),
        ("redirect_uri", REDIRECT),
        ("code_challenge", challenge.as_str()),
        ("code_challenge_method", "S256"),
        ("state", "xyz"),
    ];
    let page = send(app, Method::GET, &format!("/oauth/authorize?{}", form(&params)), None, "", String::new()).await;
    assert_eq!(page.status, StatusCode::OK, "{}", page.body);
    assert!(page.body.contains(&format!("Connect {name} to Nestling")), "{}", page.body);

    let mut wrong = params.to_vec();
    wrong.extend([("email", "mom@example.com"), ("password", "nope")]);
    let res = send(app, Method::POST, "/oauth/authorize", None, "application/x-www-form-urlencoded", form(&wrong)).await;
    assert_eq!(res.status, StatusCode::BAD_REQUEST);
    assert!(res.body.contains("Wrong email or password"));

    let mut signed_in = params.to_vec();
    signed_in.extend([("email", "MOM@example.com"), ("password", "password123")]);
    let res = send(app, Method::POST, "/oauth/authorize", None, "application/x-www-form-urlencoded", form(&signed_in)).await;
    assert_eq!(res.status, StatusCode::SEE_OTHER, "{}", res.body);
    let location = reqwest::Url::parse(res.headers["location"].to_str().unwrap()).unwrap();
    assert!(location.as_str().starts_with(REDIRECT));
    let q: std::collections::HashMap<_, _> = location.query_pairs().into_owned().collect();
    assert_eq!(q["state"], "xyz");
    let code = q["code"].clone();

    let bad = send(app, Method::POST, "/oauth/token", None, "application/x-www-form-urlencoded",
        form(&[("grant_type", "authorization_code"), ("code", &code), ("client_id", &client_id), ("redirect_uri", REDIRECT), ("code_verifier", "wrong-verifier")])).await;
    assert_eq!(bad.status, StatusCode::BAD_REQUEST);
    assert_eq!(bad.json()["error"], "invalid_grant");
    // The code was used up by the failed attempt: sign in again.
    let res = send(app, Method::POST, "/oauth/authorize", None, "application/x-www-form-urlencoded", form(&signed_in)).await;
    let location = reqwest::Url::parse(res.headers["location"].to_str().unwrap()).unwrap();
    let code = location.query_pairs().find(|(k, _)| k == "code").unwrap().1.into_owned();

    let tok = send(app, Method::POST, "/oauth/token", None, "application/x-www-form-urlencoded",
        form(&[("grant_type", "authorization_code"), ("code", &code), ("client_id", &client_id), ("redirect_uri", REDIRECT), ("code_verifier", VERIFIER)])).await;
    assert_eq!(tok.status, StatusCode::OK, "{}", tok.body);
    assert_eq!(tok.json()["token_type"], "Bearer");
    let again = send(app, Method::POST, "/oauth/token", None, "application/x-www-form-urlencoded",
        form(&[("grant_type", "authorization_code"), ("code", &code), ("client_id", &client_id), ("code_verifier", VERIFIER)])).await;
    assert_eq!(again.status, StatusCode::BAD_REQUEST, "a code works once");
    tok.json()["access_token"].as_str().unwrap().to_string()
}

async fn rpc(app: &Router, token: &str, id: i64, method: &str, params: Value) -> Value {
    let body = json!({ "jsonrpc": "2.0", "id": id, "method": method, "params": params }).to_string();
    let res = send(app, Method::POST, "/mcp", Some(token), "application/json", body).await;
    assert_eq!(res.status, StatusCode::OK, "{}", res.body);
    let v = res.json();
    assert_eq!(v["id"], id);
    v
}

async fn tool(app: &Router, token: &str, name: &str, args: Value) -> (bool, Value) {
    let v = rpc(app, token, 7, "tools/call", json!({ "name": name, "arguments": args })).await;
    let r = &v["result"];
    let failed = r["isError"].as_bool().unwrap();
    (failed, if failed { json!(r["content"][0]["text"]) } else { r["structuredContent"].clone() })
}

#[tokio::test]
async fn discovery_and_unauthorized() {
    let (app, _, _) = setup().await;
    let res = send(&app, Method::POST, "/mcp", None, "application/json", "{}".into()).await;
    assert_eq!(res.status, StatusCode::UNAUTHORIZED);
    assert_eq!(
        res.headers["www-authenticate"],
        r#"Bearer resource_metadata="https://nestling.example.com/.well-known/oauth-protected-resource/mcp""#
    );
    let res = send(&app, Method::POST, "/mcp", Some("not-a-token"), "application/json", "{}".into()).await;
    assert_eq!(res.status, StatusCode::UNAUTHORIZED);

    let pr = send(&app, Method::GET, "/.well-known/oauth-protected-resource/mcp", None, "", String::new()).await.json();
    assert_eq!(pr["resource"], "https://nestling.example.com/mcp");
    assert_eq!(pr["authorization_servers"][0], "https://nestling.example.com");
    let asm = send(&app, Method::GET, "/.well-known/oauth-authorization-server", None, "", String::new()).await.json();
    assert_eq!(asm["token_endpoint"], "https://nestling.example.com/oauth/token");
    assert_eq!(asm["code_challenge_methods_supported"][0], "S256");

    let bad = send(&app, Method::POST, "/oauth/register", None, "application/json", json!({ "redirect_uris": ["http://evil.example.com/cb"] }).to_string()).await;
    assert_eq!(bad.status, StatusCode::BAD_REQUEST);
    let page = send(&app, Method::GET, "/oauth/authorize?client_id=nope&response_type=code", None, "", String::new()).await;
    assert_eq!(page.status, StatusCode::BAD_REQUEST);
    assert!(page.body.contains("not registered"));
}

#[tokio::test]
async fn claude_logs_and_runs_timers() {
    let (app, owner, fid) = setup().await;
    let token = connect_app(&app, "Claude").await;

    // It is a connected app named after the client; connecting again reuses it.
    let list = api(&app, Method::GET, &format!("/families/{fid}/integrations"), &owner, None).await;
    assert_eq!(list["integrations"].as_array().unwrap().len(), 1);
    assert_eq!(list["integrations"][0]["name"], "Claude");
    connect_app(&app, "Claude").await;
    let list = api(&app, Method::GET, &format!("/families/{fid}/integrations"), &owner, None).await;
    assert_eq!(list["integrations"].as_array().unwrap().len(), 1);

    let init = rpc(&app, &token, 1, "initialize", json!({ "protocolVersion": "2025-06-18", "capabilities": {}, "clientInfo": { "name": "test", "version": "1" } })).await;
    assert_eq!(init["result"]["protocolVersion"], "2025-06-18");
    assert!(init["result"]["capabilities"]["tools"].is_object());
    let note = send(&app, Method::POST, "/mcp", Some(&token), "application/json", json!({ "jsonrpc": "2.0", "method": "notifications/initialized" }).to_string()).await;
    assert_eq!(note.status, StatusCode::ACCEPTED);
    let tools = rpc(&app, &token, 2, "tools/list", json!({})).await;
    let names: Vec<&str> = tools["result"]["tools"].as_array().unwrap().iter().map(|t| t["name"].as_str().unwrap()).collect();
    assert!(names.contains(&"log_entry") && names.contains(&"stop_timer"), "{names:?}");
    let unknown = rpc(&app, &token, 3, "nope", json!({})).await;
    assert_eq!(unknown["error"]["code"], -32601);

    let (failed, kids) = tool(&app, &token, "list_children", json!({})).await;
    assert!(!failed, "{kids}");
    assert_eq!(kids["result"]["families"][0]["children"][0]["name"], "Léa Rose");
    assert!(kids["now"].as_str().unwrap().contains("-04:00") || kids["now"].as_str().unwrap().contains("-05:00"), "{kids}");

    // One child: `child` can be left out; a first name finds her too.
    let (failed, fed) = tool(&app, &token, "log_entry", json!({ "type": "feed", "method": "bottle", "amount_ml": 120, "milk": "formula", "start": "now" })).await;
    assert!(!failed, "{fed}");
    assert_eq!(fed["result"]["amount_ml"], 120.0);
    let entry_id = fed["result"]["id"].as_str().unwrap().to_string();
    let (failed, diaper) = tool(&app, &token, "log_entry", json!({ "child": "léa", "type": "diaper", "wet": true })).await;
    assert!(!failed, "{diaper}");
    let (failed, err) = tool(&app, &token, "log_entry", json!({ "child": "Max", "type": "diaper", "wet": true })).await;
    assert!(failed && err.as_str().unwrap().contains("no child named"), "{err}");
    let (failed, err) = tool(&app, &token, "log_entry", json!({ "type": "feed", "method": "breast", "milk": "formula" })).await;
    assert!(failed && err.as_str().unwrap().contains("milk only applies"), "{err}");

    let (failed, changed) = tool(&app, &token, "update_entry", json!({ "id": entry_id, "changes": { "amount_ml": 150 } })).await;
    assert!(!failed, "{changed}");
    assert_eq!(changed["result"]["amount_ml"], 150.0);

    let (failed, timer) = tool(&app, &token, "start_timer", json!({ "kind": "sleep" })).await;
    assert!(!failed, "{timer}");
    let (failed, summary) = tool(&app, &token, "get_summary", json!({})).await;
    assert!(!failed, "{summary}");
    assert_eq!(summary["result"]["timers"][0]["kind"], "sleep");
    assert_eq!(summary["result"]["last"]["feed"]["amount_ml"], 150.0);
    let (failed, slept) = tool(&app, &token, "stop_timer", json!({ "location": "crib" })).await;
    assert!(!failed, "{slept}");
    assert_eq!(slept["result"]["type"], "sleep");
    assert_eq!(slept["result"]["location"], "crib");
    let (failed, err) = tool(&app, &token, "stop_timer", json!({})).await;
    assert!(failed && err.as_str().unwrap().contains("no timer is running"), "{err}");

    let (failed, entries) = tool(&app, &token, "list_entries", json!({ "types": "feed,sleep", "limit": 5 })).await;
    assert!(!failed, "{entries}");
    assert_eq!(entries["result"]["events"].as_array().unwrap().len(), 2);
    // Entries show the connected app as who logged them.
    assert!(entries["result"]["events"][0]["created_by"].is_string());

    let (failed, _) = tool(&app, &token, "delete_entry", json!({ "id": entry_id })).await;
    assert!(!failed);
    let (failed, trends) = tool(&app, &token, "get_trends", json!({ "days": 3 })).await;
    assert!(!failed, "{trends}");
    let (failed, err) = tool(&app, &token, "delete_entry", json!({ "id": "../families" })).await;
    assert!(failed && err.as_str().unwrap().contains("not a valid id"), "{err}");

    // The connected app still can't do anything else with its token.
    let res = send(&app, Method::DELETE, &format!("/api/v1/families/{fid}"), Some(&token), "", String::new()).await;
    assert_eq!(res.status, StatusCode::FORBIDDEN);

    // Removing it in the app turns the connector off.
    let app_id = list["integrations"][0]["id"].as_str().unwrap();
    api(&app, Method::DELETE, &format!("/families/{fid}/integrations/{app_id}"), &owner, None).await;
    let res = send(&app, Method::POST, "/mcp", Some(&token), "application/json", json!({ "jsonrpc": "2.0", "id": 1, "method": "ping" }).to_string()).await;
    assert_eq!(res.status, StatusCode::UNAUTHORIZED);
}

#[tokio::test]
async fn owners_of_several_families_pick_one() {
    let (app, owner, _) = setup().await;
    let second = api(&app, Method::POST, "/families", &owner, Some(json!({ "name": "Cottage", "timezone": "Europe/Paris" }))).await;
    let second_id = second["id"].as_str().unwrap();
    let reg = send(&app, Method::POST, "/oauth/register", None, "application/json", json!({ "client_name": "Claude", "redirect_uris": [REDIRECT] }).to_string()).await;
    let client_id = reg.json()["client_id"].as_str().unwrap().to_string();
    let challenge = URL_SAFE_NO_PAD.encode(Sha256::digest(VERIFIER.as_bytes()));
    let body = form(&[
        ("response_type", "code"),
        ("client_id", &client_id),
        ("redirect_uri", REDIRECT),
        ("code_challenge", &challenge),
        ("code_challenge_method", "S256"),
        ("email", "mom@example.com"),
        ("password", "password123"),
    ]);
    let res = send(&app, Method::POST, "/oauth/authorize", None, "application/x-www-form-urlencoded", body).await;
    assert_eq!(res.status, StatusCode::OK, "{}", res.body);
    assert!(res.body.contains("Which family?") && res.body.contains("Cottage"));
    let ticket = res.body.split(r#"name="ticket" value=""#).nth(1).unwrap().split('"').next().unwrap().to_string();
    let res = send(&app, Method::POST, "/oauth/authorize", None, "application/x-www-form-urlencoded", form(&[("ticket", &ticket), ("family_id", second_id)])).await;
    assert_eq!(res.status, StatusCode::SEE_OTHER, "{}", res.body);
    let location = reqwest::Url::parse(res.headers["location"].to_str().unwrap()).unwrap();
    let code = location.query_pairs().find(|(k, _)| k == "code").unwrap().1.into_owned();
    let tok = send(&app, Method::POST, "/oauth/token", None, "application/x-www-form-urlencoded",
        form(&[("grant_type", "authorization_code"), ("code", &code), ("client_id", &client_id), ("code_verifier", VERIFIER)])).await;
    let token = tok.json()["access_token"].as_str().unwrap().to_string();
    let (failed, kids) = tool(&app, &token, "list_children", json!({})).await;
    assert!(!failed);
    assert_eq!(kids["result"]["families"].as_array().unwrap().len(), 1);
    assert_eq!(kids["result"]["families"][0]["family"], "Cottage");
    let (failed, err) = tool(&app, &token, "log_entry", json!({ "type": "note", "note": "hi" })).await;
    assert!(failed && err.as_str().unwrap().contains("no children"), "{err}");
}
