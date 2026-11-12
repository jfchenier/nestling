//! Single sign-on against a fake OpenID Connect provider.

use std::sync::{Arc, Mutex};

use axum::{
    body::Body,
    extract::{Form, State},
    http::{Method, Request, StatusCode},
    routing::{get, post},
    Json, Router,
};
use base64::{engine::general_purpose::URL_SAFE_NO_PAD, Engine};
use http_body_util::BodyExt;
use nestling::{app, connect, sso::OidcConfig, AppState, Config, NaraConfig};
use reqwest::Url;
use serde_json::{json, Value};
use sha2::{Digest, Sha256};
use std::collections::HashMap;
use tower::ServiceExt;

/// What the fake provider says about the next person who signs in, and the PKCE challenge it got.
#[derive(Default)]
struct Provider {
    issuer: String,
    claims: Value,
    challenge: String,
    nonce: String,
    token_requests: Vec<HashMap<String, String>>,
}

type Shared = Arc<Mutex<Provider>>;

async fn fake_provider() -> Shared {
    let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
    let issuer = format!("http://{}", listener.local_addr().unwrap());
    let shared: Shared = Arc::new(Mutex::new(Provider { issuer: issuer.clone(), ..Default::default() }));
    let router = Router::new()
        .route(
            "/.well-known/openid-configuration",
            get(|State(s): State<Shared>| async move {
                let iss = s.lock().unwrap().issuer.clone();
                Json(json!({
                    "issuer": iss,
                    "authorization_endpoint": format!("{iss}/authorize"),
                    "token_endpoint": format!("{iss}/api/oidc/token"),
                    "userinfo_endpoint": format!("{iss}/api/oidc/userinfo"),
                }))
            }),
        )
        .route(
            "/api/oidc/token",
            post(|State(s): State<Shared>, headers: axum::http::HeaderMap, Form(f): Form<HashMap<String, String>>| async move {
                let mut p = s.lock().unwrap();
                p.token_requests.push(f.clone());
                let verifier = f.get("code_verifier").cloned().unwrap_or_default();
                let authed = headers.get("authorization").and_then(|v| v.to_str().ok())
                    == Some(&format!("Basic {}", base64::engine::general_purpose::STANDARD.encode("nestling:secret")));
                if f.get("code").map(String::as_str) != Some("provider-code") || !authed
                    || URL_SAFE_NO_PAD.encode(Sha256::digest(verifier.as_bytes())) != p.challenge
                {
                    return (StatusCode::BAD_REQUEST, Json(json!({ "error": "invalid_grant" })));
                }
                let mut claims = p.claims.clone();
                claims["iss"] = json!(p.issuer);
                claims["aud"] = json!("nestling");
                claims["exp"] = json!(chrono::Utc::now().timestamp() + 300);
                claims["nonce"] = json!(p.nonce);
                let jwt = format!("eyJhbGciOiJSUzI1NiJ9.{}.c2ln", URL_SAFE_NO_PAD.encode(claims.to_string()));
                (StatusCode::OK, Json(json!({ "access_token": "at", "token_type": "Bearer", "id_token": jwt })))
            }),
        )
        .with_state(shared.clone());
    tokio::spawn(async move { axum::serve(listener, router).await.unwrap() });
    shared
}

struct Client {
    app: Router,
    provider: Shared,
}

const HOST: &str = "nestling.example.com";

impl Client {
    async fn new(signup: bool) -> Self {
        let provider = fake_provider().await;
        let issuer = provider.lock().unwrap().issuer.clone();
        let db = connect("sqlite::memory:", 1).await.unwrap();
        let state = AppState::new(db, Config { open_registration: false, nara: NaraConfig::default() }).with_oidc(OidcConfig {
            issuer,
            client_id: "nestling".into(),
            client_secret: "secret".into(),
            name: "Pocket ID".into(),
            scopes: "openid email profile".into(),
            signup,
        });
        Client { app: app(state, None), provider }
    }

    async fn call(&self, method: Method, path: &str, token: Option<&str>, body: Option<Value>) -> (StatusCode, Value, Option<String>) {
        let mut req = Request::builder().method(method).uri(path).header("host", HOST).header("x-forwarded-proto", "https");
        if let Some(t) = token {
            req = req.header("authorization", format!("Bearer {t}"));
        }
        let req = match body {
            Some(b) => req.header("content-type", "application/json").body(Body::from(b.to_string())),
            None => req.body(Body::empty()),
        }
        .unwrap();
        let res = self.app.clone().oneshot(req).await.unwrap();
        let status = res.status();
        let location = res.headers().get("location").map(|v| v.to_str().unwrap().to_string());
        let bytes = res.into_body().collect().await.unwrap().to_bytes();
        (status, serde_json::from_slice(&bytes).unwrap_or(Value::Null), location)
    }

    /// The whole browser trip for someone the provider describes with `claims`. Returns where the
    /// browser lands back in the app.
    async fn sso(&self, claims: Value, verifier: &str) -> Url {
        let challenge = URL_SAFE_NO_PAD.encode(Sha256::digest(verifier.as_bytes()));
        let return_to = format!("https://{HOST}/");
        let start = Url::parse_with_params("http://x/api/v1/auth/sso/start", [("return_to", return_to.as_str()), ("challenge", &challenge)]).unwrap();
        let (s, _, location) = self.call(Method::GET, &format!("{}?{}", start.path(), start.query().unwrap()), None, None).await;
        assert_eq!(s, StatusCode::SEE_OTHER);
        let to_provider = Url::parse(&location.unwrap()).unwrap();
        let q: HashMap<String, String> = to_provider.query_pairs().into_owned().collect();
        assert_eq!(q["client_id"], "nestling");
        assert_eq!(q["redirect_uri"], format!("https://{HOST}/api/v1/auth/sso/callback"));
        assert_eq!(q["code_challenge_method"], "S256");
        {
            let mut p = self.provider.lock().unwrap();
            p.claims = claims;
            p.challenge = q["code_challenge"].clone();
            p.nonce = q["nonce"].clone();
        }
        // The provider sends the browser back.
        let back = format!("/api/v1/auth/sso/callback?code=provider-code&state={}", q["state"]);
        let (s, _, location) = self.call(Method::GET, &back, None, None).await;
        assert_eq!(s, StatusCode::SEE_OTHER);
        let landed = Url::parse(&location.unwrap()).unwrap();
        assert!(landed.as_str().starts_with(&return_to), "{landed}");
        // The same callback again (a reload) does nothing.
        let (s, _, _) = self.call(Method::GET, &back, None, None).await;
        assert_eq!(s, StatusCode::BAD_REQUEST);
        landed
    }
}

fn param(url: &Url, key: &str) -> Option<String> {
    url.query_pairs().find(|(k, _)| k == key).map(|(_, v)| v.into_owned())
}

#[tokio::test]
async fn sso_sign_in() {
    let c = Client::new(false).await;
    let (_, setup, _) = c.call(Method::GET, "/api/v1/auth/setup", None, None).await;
    assert_eq!(setup["sso"]["name"], "Pocket ID");

    // A new server: the first person becomes the admin.
    let ada = json!({ "sub": "ada-1", "email": "Ada@Example.com", "email_verified": true, "name": "Ada" });
    let landed = c.sso(ada.clone(), "verifier-one").await;
    let code = param(&landed, "sso_code").expect("sso_code");
    let (s, b, _) = c.call(Method::POST, "/api/v1/auth/sso/token", None, Some(json!({ "code": code, "verifier": "wrong" }))).await;
    assert_eq!(s, StatusCode::BAD_REQUEST, "{b}");
    // A code is single use, even after a wrong verifier.
    let (s, _, _) = c.call(Method::POST, "/api/v1/auth/sso/token", None, Some(json!({ "code": code, "verifier": "verifier-one" }))).await;
    assert_eq!(s, StatusCode::BAD_REQUEST);

    let landed = c.sso(ada.clone(), "verifier-two").await;
    let code = param(&landed, "sso_code").unwrap();
    let (s, b, _) = c.call(Method::POST, "/api/v1/auth/sso/token", None, Some(json!({ "code": code, "verifier": "verifier-two" }))).await;
    assert_eq!(s, StatusCode::OK, "{b}");
    assert_eq!(b["user"]["email"], "ada@example.com");
    assert_eq!(b["user"]["name"], "Ada");
    assert_eq!(b["user"]["is_admin"], true);
    let admin = b["token"].as_str().unwrap().to_string();
    let last = c.provider.lock().unwrap().token_requests.last().cloned().unwrap();
    assert_eq!(last["redirect_uri"], format!("https://{HOST}/api/v1/auth/sso/callback"));

    // Sign-up is closed: someone the provider knows but Nestling doesn't is refused...
    let bob = json!({ "sub": "bob-1", "email": "bob@example.com", "email_verified": true, "name": "Bob" });
    let landed = c.sso(bob.clone(), "verifier-three").await;
    assert!(param(&landed, "sso_code").is_none());
    assert!(param(&landed, "sso_error").unwrap().contains("no Nestling account for bob@example.com"));

    // ...until an admin adds an account with that email: then it is linked by the email,
    // and later by the provider's account even after the email changes.
    let (s, _, _) = c
        .call(Method::POST, "/api/v1/admin/users", Some(&admin), Some(json!({ "email": "bob@example.com", "name": "Bob", "password": "whatever-123" })))
        .await;
    assert_eq!(s, StatusCode::CREATED);
    let landed = c.sso(bob, "verifier-four").await;
    let (s, b, _) = c
        .call(Method::POST, "/api/v1/auth/sso/token", None, Some(json!({ "code": param(&landed, "sso_code").unwrap(), "verifier": "verifier-four" })))
        .await;
    assert_eq!(s, StatusCode::OK, "{b}");
    let bob_id = b["user"]["id"].clone();
    let renamed = json!({ "sub": "bob-1", "email": "robert@example.com", "email_verified": true });
    let landed = c.sso(renamed, "verifier-five").await;
    let (_, b, _) = c
        .call(Method::POST, "/api/v1/auth/sso/token", None, Some(json!({ "code": param(&landed, "sso_code").unwrap(), "verifier": "verifier-five" })))
        .await;
    assert_eq!(b["user"]["id"], bob_id);

    // An unverified email doesn't take over an account.
    let mallory = json!({ "sub": "m-1", "email": "ada@example.com", "email_verified": false });
    let landed = c.sso(mallory, "verifier-six").await;
    assert!(param(&landed, "sso_error").unwrap().contains("isn't verified"));

    // Password sign-in still works, and an SSO-only account has no password.
    let (s, _, _) = c.call(Method::POST, "/api/v1/auth/login", None, Some(json!({ "email": "bob@example.com", "password": "whatever-123" }))).await;
    assert_eq!(s, StatusCode::OK);
    let (s, _, _) = c.call(Method::POST, "/api/v1/auth/login", None, Some(json!({ "email": "ada@example.com", "password": "" }))).await;
    assert_eq!(s, StatusCode::BAD_REQUEST);
}

#[tokio::test]
async fn sso_sign_up_and_return_addresses() {
    let c = Client::new(true).await;
    // With NESTLING_OIDC_SIGNUP, anyone the provider knows gets an account (not an admin after the first).
    for (i, email) in ["first@example.com", "second@example.com"].into_iter().enumerate() {
        let landed = c.sso(json!({ "sub": email, "email": email, "preferred_username": "kid" }), "v").await;
        let (s, b, _) = c
            .call(Method::POST, "/api/v1/auth/sso/token", None, Some(json!({ "code": param(&landed, "sso_code").unwrap(), "verifier": "v" })))
            .await;
        assert_eq!(s, StatusCode::OK, "{b}");
        assert_eq!(b["user"]["is_admin"], i == 0);
        assert_eq!(b["user"]["name"], "kid");
    }

    // Codes only go back to this server's pages or the app.
    let challenge = "a".repeat(43);
    for (return_to, ok) in [
        ("https://evil.example.com/", false),
        ("io.github.jfchenier.nestling://sso", true),
        ("https://nestling.example.com/", true),
    ] {
        let url = Url::parse_with_params("http://x/api/v1/auth/sso/start", [("return_to", return_to), ("challenge", &challenge)]).unwrap();
        let (s, _, _) = c.call(Method::GET, &format!("{}?{}", url.path(), url.query().unwrap()), None, None).await;
        assert_eq!(s == StatusCode::SEE_OTHER, ok, "{return_to}");
    }

    // The provider says no: the app hears why.
    let url = Url::parse_with_params("http://x/api/v1/auth/sso/start", [("return_to", "https://nestling.example.com/"), ("challenge", &challenge)]).unwrap();
    let (_, _, location) = c.call(Method::GET, &format!("{}?{}", url.path(), url.query().unwrap()), None, None).await;
    let state = param(&Url::parse(&location.unwrap()).unwrap(), "state").unwrap();
    let (_, _, location) = c
        .call(Method::GET, &format!("/api/v1/auth/sso/callback?error=access_denied&error_description=Not%20allowed&state={state}"), None, None)
        .await;
    assert!(param(&Url::parse(&location.unwrap()).unwrap(), "sso_error").unwrap().contains("Not allowed"));
}

#[tokio::test]
async fn sso_off_by_default() {
    let db = connect("sqlite::memory:", 1).await.unwrap();
    let app = app(AppState::new(db, Config { open_registration: false, nara: NaraConfig::default() }), None);
    let res = app.clone().oneshot(Request::get("/api/v1/auth/setup").body(Body::empty()).unwrap()).await.unwrap();
    let b: Value = serde_json::from_slice(&res.into_body().collect().await.unwrap().to_bytes()).unwrap();
    assert_eq!(b["sso"], Value::Null);
    let req = Request::post("/api/v1/auth/sso/token").header("content-type", "application/json").body(Body::from(r#"{"code":"x","verifier":"y"}"#)).unwrap();
    assert_eq!(app.oneshot(req).await.unwrap().status(), StatusCode::NOT_FOUND);
}
