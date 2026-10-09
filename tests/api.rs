//! End-to-end tests against an in-memory database.

use axum::{
    body::Body,
    http::{Method, Request, StatusCode},
    Router,
};
use http_body_util::BodyExt;
use nestling::{app, connect, AppState, Config, NaraConfig};
use serde_json::{json, Value};
use tower::ServiceExt;

struct Client {
    app: Router,
    db: sqlx::SqlitePool,
}

impl Client {
    async fn new() -> Self {
        Self::with_registration(true).await
    }

    async fn with_registration(open_registration: bool) -> Self {
        let db = connect("sqlite::memory:", 1).await.unwrap();
        let state = AppState::new(db.clone(), Config { open_registration, nara: NaraConfig::default() });
        Client { app: app(state, None), db }
    }

    fn db(&self) -> sqlx::SqlitePool {
        self.db.clone()
    }

    async fn call(&self, method: Method, path: &str, token: Option<&str>, body: Option<Value>) -> (StatusCode, Value) {
        let mut req = Request::builder().method(method).uri(format!("/api/v1{path}"));
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
        let bytes = res.into_body().collect().await.unwrap().to_bytes();
        let json = if bytes.is_empty() { Value::Null } else { serde_json::from_slice(&bytes).unwrap_or(Value::Null) };
        (status, json)
    }

    async fn call_csv(&self, path: &str, token: &str, csv: &str) -> (StatusCode, Value) {
        let req = Request::builder()
            .method(Method::POST)
            .uri(format!("/api/v1{path}"))
            .header("authorization", format!("Bearer {token}"))
            .header("content-type", "text/csv")
            .body(Body::from(csv.to_string()))
            .unwrap();
        let res = self.app.clone().oneshot(req).await.unwrap();
        let status = res.status();
        let bytes = res.into_body().collect().await.unwrap().to_bytes();
        (status, serde_json::from_slice(&bytes).unwrap_or(Value::Null))
    }

    /// Raw-bytes request; returns the status, the content type and the body bytes.
    async fn call_raw(&self, method: Method, path: &str, token: &str, body: Vec<u8>) -> (StatusCode, String, Vec<u8>) {
        let req = Request::builder()
            .method(method)
            .uri(format!("/api/v1{path}"))
            .header("authorization", format!("Bearer {token}"))
            .header("content-type", "application/octet-stream")
            .body(Body::from(body))
            .unwrap();
        let res = self.app.clone().oneshot(req).await.unwrap();
        let status = res.status();
        let ct = res.headers().get("content-type").map(|v| v.to_str().unwrap().to_string()).unwrap_or_default();
        (status, ct, res.into_body().collect().await.unwrap().to_bytes().to_vec())
    }

    async fn register(&self, email: &str, name: &str) -> String {
        let (s, b) = self
            .call(Method::POST, "/auth/register", None, Some(json!({ "email": email, "password": "correct horse", "name": name })))
            .await;
        assert_eq!(s, StatusCode::CREATED, "{b}");
        b["token"].as_str().unwrap().to_string()
    }
}

#[tokio::test]
async fn full_flow() {
    let c = Client::new().await;
    let mom = c.register("mom@example.com", "Mom").await;
    let dad = c.register("dad@example.com", "Dad").await;

    // Auth required
    let (s, _) = c.call(Method::GET, "/me", None, None).await;
    assert_eq!(s, StatusCode::UNAUTHORIZED);

    // Family + child
    let (s, fam) = c.call(Method::POST, "/families", Some(&mom), Some(json!({ "name": "Home", "timezone": "America/New_York" }))).await;
    assert_eq!(s, StatusCode::CREATED, "{fam}");
    let fid = fam["id"].as_str().unwrap().to_string();
    let (s, err) = c.call(Method::POST, &format!("/families/{fid}/children"), Some(&mom), Some(json!({ "name": "Léa" }))).await;
    assert_eq!(s, StatusCode::BAD_REQUEST, "birth date is required: {err}");
    let (s, child) = c
        .call(Method::POST, &format!("/families/{fid}/children"), Some(&mom), Some(json!({ "name": "Léa", "birth_date": "2026-06-01" })))
        .await;
    assert_eq!(s, StatusCode::CREATED, "{child}");
    let cid = child["id"].as_str().unwrap().to_string();

    // Dad can't see it until invited
    let (s, _) = c.call(Method::GET, &format!("/children/{cid}"), Some(&dad), None).await;
    assert_eq!(s, StatusCode::NOT_FOUND);
    let (s, inv) = c.call(Method::POST, &format!("/families/{fid}/invites"), Some(&mom), None).await;
    assert_eq!(s, StatusCode::CREATED, "{inv}");
    let code = inv["code"].as_str().unwrap();
    let (s, joined) = c.call(Method::POST, &format!("/invites/{code}/accept"), Some(&dad), None).await;
    assert_eq!(s, StatusCode::OK, "{joined}");
    assert_eq!(joined["members"].as_array().unwrap().len(), 2);
    assert_eq!(joined["role"], "caregiver");

    // Events
    let (s, ev) = c
        .call(Method::POST, &format!("/children/{cid}/events"), Some(&dad),
            Some(json!({ "type": "feed", "method": "bottle", "amount_ml": 120, "milk": "formula", "start": "2026-10-08T08:00" })))
        .await;
    assert_eq!(s, StatusCode::CREATED, "{ev}");
    assert_eq!(ev["start"], "2026-10-08T08:00:00-04:00");
    assert_eq!(ev["amount_ml"], 120.0);
    let eid = ev["id"].as_str().unwrap().to_string();

    let (s, err) = c.call(Method::POST, &format!("/children/{cid}/events"), Some(&dad), Some(json!({ "type": "diaper" }))).await;
    assert_eq!(s, StatusCode::BAD_REQUEST);
    assert_eq!(err["error"]["code"], "bad_request");

    let (s, _) = c
        .call(Method::POST, &format!("/children/{cid}/events"), Some(&mom),
            Some(json!({ "type": "diaper", "wet": true, "dirty": true, "color": "yellow", "consistency": "mushy", "start": "2026-10-08T08:30" })))
        .await;
    assert_eq!(s, StatusCode::CREATED);
    let (s, _) = c
        .call(Method::POST, &format!("/children/{cid}/events"), Some(&mom),
            Some(json!({ "type": "sleep", "start": "2026-10-08T09:00", "end": "2026-10-08T10:30" })))
        .await;
    assert_eq!(s, StatusCode::CREATED);
    let (s, _) = c
        .call(Method::POST, &format!("/children/{cid}/events"), Some(&mom),
            Some(json!({ "type": "growth", "weight_g": 6400, "length_cm": 62 })))
        .await;
    assert_eq!(s, StatusCode::CREATED);
    let (s, h) = c
        .call(Method::POST, &format!("/children/{cid}/events"), Some(&mom),
            Some(json!({ "type": "health", "kind": "medicine", "name": "Tylenol", "dose": 2.5, "dose_unit": "ml" })))
        .await;
    assert_eq!(s, StatusCode::CREATED, "{h}");

    // Patch
    let (s, ev2) = c.call(Method::PATCH, &format!("/events/{eid}"), Some(&mom), Some(json!({ "amount_ml": 150, "note": "hungry" }))).await;
    assert_eq!(s, StatusCode::OK, "{ev2}");
    assert_eq!(ev2["amount_ml"], 150.0);
    assert_eq!(ev2["milk"], "formula");
    assert_eq!(ev2["note"], "hungry");

    // List + filter
    let (_, list) = c.call(Method::GET, &format!("/children/{cid}/events?type=feed,diaper"), Some(&dad), None).await;
    assert_eq!(list["events"].as_array().unwrap().len(), 2);
    let (_, list) = c.call(Method::GET, &format!("/children/{cid}/events?limit=2"), Some(&dad), None).await;
    assert_eq!(list["events"].as_array().unwrap().len(), 2);
    assert!(list["next_to"].is_string());

    // Trends for that day
    let (s, t) = c.call(Method::GET, &format!("/children/{cid}/trends?days=1&to=2026-10-08"), Some(&dad), None).await;
    assert_eq!(s, StatusCode::OK, "{t}");
    assert_eq!(t["days"][0]["feed"]["bottle_ml"], 150.0);
    assert_eq!(t["days"][0]["sleep"]["total_seconds"], 5400);
    assert_eq!(t["days"][0]["diaper"]["dirty"], 1);

    // Delete shows as tombstone in sync
    let (_, sync0) = c.call(Method::GET, &format!("/families/{fid}/sync"), Some(&dad), None).await;
    let cursor = sync0["cursor"].as_i64().unwrap();
    assert_eq!(sync0["events"].as_array().unwrap().len(), 5);
    let (s, _) = c.call(Method::DELETE, &format!("/events/{eid}"), Some(&dad), None).await;
    assert_eq!(s, StatusCode::NO_CONTENT);
    let (_, sync1) = c.call(Method::GET, &format!("/families/{fid}/sync?since={cursor}"), Some(&dad), None).await;
    let evs = sync1["events"].as_array().unwrap();
    assert_eq!(evs.len(), 1);
    assert_eq!(evs[0]["deleted"], true);

    // Summary
    let (s, sum) = c.call(Method::GET, &format!("/children/{cid}/summary"), Some(&mom), None).await;
    assert_eq!(s, StatusCode::OK, "{sum}");
    assert_eq!(sum["last"]["feed"], Value::Null);
    assert_eq!(sum["last"]["diaper"]["dirty"], true);
}

#[tokio::test]
async fn timers() {
    let c = Client::new().await;
    let t = c.register("a@example.com", "A").await;
    let (_, fam) = c.call(Method::POST, "/families", Some(&t), Some(json!({ "name": "F" }))).await;
    let fid = fam["id"].as_str().unwrap();
    let (_, child) = c.call(Method::POST, &format!("/families/{fid}/children"), Some(&t), Some(json!({ "name": "B", "birth_date": "2026-06-01" }))).await;
    let cid = child["id"].as_str().unwrap();

    // Breastfeed that started 20 minutes ago on the left
    let start = (chrono::Utc::now() - chrono::Duration::minutes(20)).to_rfc3339();
    let (s, timer) = c
        .call(Method::POST, &format!("/children/{cid}/timers"), Some(&t), Some(json!({ "kind": "breastfeed", "side": "left", "start": start })))
        .await;
    assert_eq!(s, StatusCode::CREATED, "{timer}");
    let tid = timer["id"].as_str().unwrap();
    assert_eq!(timer["running"], true);
    assert!(timer["elapsed_seconds"].as_i64().unwrap() >= 1199);

    let (s, _) = c.call(Method::POST, &format!("/children/{cid}/timers"), Some(&t), Some(json!({ "kind": "breastfeed" }))).await;
    assert_eq!(s, StatusCode::CONFLICT);

    let (s, sw) = c.call(Method::POST, &format!("/timers/{tid}/switch"), Some(&t), None).await;
    assert_eq!(s, StatusCode::OK, "{sw}");
    assert_eq!(sw["side"], "right");
    let (s, p) = c.call(Method::POST, &format!("/timers/{tid}/pause"), Some(&t), None).await;
    assert_eq!(s, StatusCode::OK, "{p}");
    assert_eq!(p["running"], false);
    let (s, _) = c.call(Method::POST, &format!("/timers/{tid}/pause"), Some(&t), None).await;
    assert_eq!(s, StatusCode::CONFLICT);
    let (s, _) = c.call(Method::POST, &format!("/timers/{tid}/resume"), Some(&t), Some(json!({ "side": "left" }))).await;
    assert_eq!(s, StatusCode::OK);

    let (s, ev) = c.call(Method::POST, &format!("/timers/{tid}/stop"), Some(&t), Some(json!({ "note": "sleepy" }))).await;
    assert_eq!(s, StatusCode::CREATED, "{ev}");
    assert_eq!(ev["type"], "feed");
    assert_eq!(ev["method"], "breast");
    assert_eq!(ev["start_side"], "left");
    assert!(ev["left_seconds"].as_i64().unwrap() >= 1199);
    assert_eq!(ev["note"], "sleepy");

    let (_, timers) = c.call(Method::GET, &format!("/children/{cid}/timers"), Some(&t), None).await;
    assert_eq!(timers["timers"].as_array().unwrap().len(), 0);

    // Sleep timer -> sleep event
    let (_, st) = c.call(Method::POST, &format!("/children/{cid}/timers"), Some(&t), Some(json!({ "kind": "sleep", "start": "now" }))).await;
    let sid = st["id"].as_str().unwrap();
    let (s, e) = c.call(Method::PATCH, &format!("/timers/{sid}"), Some(&t), Some(json!({ "seconds": 1800 }))).await;
    assert_eq!(s, StatusCode::OK, "{e}");
    assert!((1800..=1801).contains(&e["elapsed_seconds"].as_i64().unwrap()), "{e}");
    let (s, _) = c.call(Method::PATCH, &format!("/timers/{sid}"), Some(&t), Some(json!({ "left_seconds": 10 }))).await;
    assert_eq!(s, StatusCode::BAD_REQUEST);
    let (_, pt) = c.call(Method::POST, &format!("/children/{cid}/timers"), Some(&t), Some(json!({ "kind": "pump" }))).await;
    let pid = pt["id"].as_str().unwrap();
    let (s, e) = c.call(Method::PATCH, &format!("/timers/{pid}"), Some(&t), Some(json!({ "seconds": 900 }))).await;
    assert_eq!(s, StatusCode::OK, "{e}");
    assert!((900..=901).contains(&e["left_seconds"].as_i64().unwrap()), "{e}");
    let (s, _) = c.call(Method::DELETE, &format!("/timers/{pid}"), Some(&t), None).await;
    assert_eq!(s, StatusCode::NO_CONTENT);
    let (s, ev) = c.call(Method::POST, &format!("/timers/{sid}/stop"), Some(&t), None).await;
    assert_eq!(s, StatusCode::CREATED, "{ev}");
    assert_eq!(ev["type"], "sleep");

    // Correct a running breastfeed: start time and the time on each side
    let (_, bt) = c.call(Method::POST, &format!("/children/{cid}/timers"), Some(&t), Some(json!({ "kind": "breastfeed", "side": "left" }))).await;
    let bid = bt["id"].as_str().unwrap();
    let (s, e) = c
        .call(Method::PATCH, &format!("/timers/{bid}"), Some(&t), Some(json!({ "left_seconds": 600, "right_seconds": 300 })))
        .await;
    assert_eq!(s, StatusCode::OK, "{e}");
    assert_eq!(e["running"], true);
    assert_eq!(e["side"], "left");
    assert!((600..=601).contains(&e["left_seconds"].as_i64().unwrap()), "{e}");
    assert_eq!(e["right_seconds"], 300);
    let (s, e) = c.call(Method::PATCH, &format!("/timers/{bid}"), Some(&t), Some(json!({ "start": "2999-01-01T00:00" }))).await;
    assert_eq!(s, StatusCode::BAD_REQUEST, "{e}");
    // Moving the start 10 minutes earlier adds 10 minutes, though it's running.
    let before = e_total(&c, &t, bid).await;
    let earlier = chrono::DateTime::parse_from_rfc3339(c.call(Method::GET, &format!("/timers/{bid}"), Some(&t), None).await.1["started_at"].as_str().unwrap()).unwrap()
        - chrono::Duration::minutes(10);
    let (s, e) = c.call(Method::PATCH, &format!("/timers/{bid}"), Some(&t), Some(json!({ "start": earlier.to_rfc3339() }))).await;
    assert_eq!(s, StatusCode::OK, "{e}");
    let after = e["elapsed_seconds"].as_i64().unwrap();
    assert!((before + 599..=before + 602).contains(&after), "{before} -> {after}");
    assert_eq!(e["running"], true);
    let (s, ev) = c.call(Method::POST, &format!("/timers/{bid}/stop"), Some(&t), None).await;
    assert_eq!(s, StatusCode::CREATED, "{ev}");
    // The right side came first in time, so the earlier start went to it: 300 + 600 s.
    assert_eq!(ev["right_seconds"], 900);
    assert!(ev["left_seconds"].as_i64().unwrap() >= 600);
}

#[tokio::test]
async fn nara_import_from_upload() {
    let c = Client::new().await;
    let t = c.register("a@example.com", "A").await;
    let (_, fam) = c.call(Method::POST, "/families", Some(&t), Some(json!({ "name": "F", "timezone": "America/New_York" }))).await;
    let fid = fam["id"].as_str().unwrap();
    let tracks = json!({
        "-Ovk1": { "type": "FEED", "feedType": "BOTTLE", "beginDt": 1759921200000i64, "childKey": "kid",
                   "bottleTypeBreastMilk": true, "bottleVolumeNum": 40, "bottleVolumeExp": 1, "bottleVolumeUnit": "FLOZ" },
        "-Ovk2": { "type": "DIAPER", "beginDt": 1759924800000i64, "childKey": "kid", "diaperTypePee": true },
        "-Ovk3": { "type": "SLEEP", "beginDt": 1759928400000i64, "childKey": "kid" },
        "-Ovk4": { "type": "PARENT_NOTE", "beginDt": 1759928400000i64, "childKey": "kid", "note": "First smile!" }
    });

    let (s, dry) = c.call(Method::POST, &format!("/families/{fid}/import/nara"), Some(&t), Some(json!({ "tracks": tracks, "dry_run": true }))).await;
    assert_eq!(s, StatusCode::OK, "{dry}");
    assert_eq!(dry["importable"], 3);
    assert_eq!(dry["children_to_create"], 1);

    let (s, res) = c.call(Method::POST, &format!("/families/{fid}/import/nara"), Some(&t), Some(json!({ "tracks": tracks }))).await;
    assert_eq!(s, StatusCode::OK, "{res}");
    assert_eq!(res["imported"], 3);
    assert_eq!(res["skipped"]["sleep still in progress"], 1);
    let cid = res["children_created"][0]["id"].as_str().unwrap().to_string();

    // Re-import is idempotent
    let (_, res2) = c.call(Method::POST, &format!("/families/{fid}/import/nara"), Some(&t), Some(json!({ "tracks": tracks }))).await;
    assert_eq!(res2["imported"], 0);
    assert_eq!(res2["updated"], 3);

    let (_, list) = c.call(Method::GET, &format!("/children/{cid}/events"), Some(&t), None).await;
    let evs = list["events"].as_array().unwrap();
    assert_eq!(evs.len(), 3);
    let feed = evs.iter().find(|e| e["type"] == "feed").unwrap();
    assert_eq!(feed["amount_ml"], 118.3);
    assert_eq!(feed["source"], "nara");
}

#[tokio::test]
async fn nara_csv_import() {
    let c = Client::new().await;
    let t = c.register("csv@example.com", "C").await;
    let (_, fam) = c.call(Method::POST, "/families", Some(&t), Some(json!({ "name": "F", "timezone": "America/Toronto" }))).await;
    let fid = fam["id"].as_str().unwrap();
    // Subset of a Nara export's columns; the importer reads columns by name.
    let csv = "\u{feff}\"Type\",\"Profile Name\",\"Start Date/time\",\"Start Date/time (Epoch)\",\"Note\",\"Time Zone\",\"[Breastfeed] Begin Side\",\"[Breastfeed] End Side\",\"[Breastfeed] Left Duration (Seconds)\",\"[Breastfeed] Right Duration (Seconds)\",\"[Diaper] Type\",\"[Profile] Birth Date\",\"[Profile] Sex\",\"_profileKey\",\"_activityKey\"
\"Breastfeed\",\"Mia\",\"2026-10-07 18:30:00\",\"1791412200000\",\"sleepy\",\"America/Toronto\",\"LEFT\",\"LEFT.nonTimer\",\"600\",,,,,\"c-1\",\"t-1\"
\"Diaper\",\"Mia\",\"2026-10-07 19:00:00\",\"1791414000000\",,\"America/Toronto\",,,,,\"Wet\",,,\"c-1\",\"t-2\"
\"Profile\",\"Mia\",,,,,,,,,,\"2026-05-30\",\"FEMALE\",\"c-1\",
";
    let url = format!("/families/{fid}/import/nara-csv");

    let (s, dry) = c.call_csv(&format!("{url}?dry_run=true"), &t, csv).await;
    assert_eq!(s, StatusCode::OK, "{dry}");
    assert_eq!(dry["importable"], 2);
    assert_eq!(dry["children_to_create"], 1);
    assert_eq!(dry["nara_children"][0]["name"], "Mia");

    let (s, res) = c.call_csv(&url, &t, csv).await;
    assert_eq!(s, StatusCode::OK, "{res}");
    assert_eq!(res["imported"], 2);
    assert_eq!(res["children_created"][0]["name"], "Mia");
    let cid = res["children_created"][0]["id"].as_str().unwrap().to_string();
    let (_, child) = c.call(Method::GET, &format!("/children/{cid}"), Some(&t), None).await;
    assert_eq!(child["birth_date"], "2026-05-30");
    assert_eq!(child["sex"], "female");

    // Re-import updates instead of duplicating.
    let (_, res2) = c.call_csv(&url, &t, csv).await;
    assert_eq!((res2["imported"].clone(), res2["updated"].clone()), (json!(0), json!(2)));

    let (_, list) = c.call(Method::GET, &format!("/children/{cid}/events"), Some(&t), None).await;
    let evs = list["events"].as_array().unwrap();
    assert_eq!(evs.len(), 2);
    let feed = evs.iter().find(|e| e["type"] == "feed").unwrap();
    assert_eq!((feed["method"].as_str(), feed["left_seconds"].as_i64(), feed["start_side"].as_str()), (Some("breast"), Some(600), Some("left")));
    assert_eq!((feed["source"].as_str(), feed["note"].as_str()), (Some("nara"), Some("sleepy")));

    // Not a Nara export.
    let (s, _) = c.call_csv(&url, &t, "a,b\n1,2\n").await;
    assert_eq!(s, StatusCode::BAD_REQUEST);
}

#[tokio::test]
async fn admin_creates_accounts() {
    let c = Client::with_registration(false).await;
    let (_, setup) = c.call(Method::GET, "/auth/setup", None, None).await;
    assert_eq!(setup["needs_setup"], true);

    // First account: the admin.
    let admin = c.register("admin@example.com", "Admin").await;
    let (_, me) = c.call(Method::GET, "/me", Some(&admin), None).await;
    assert_eq!(me["is_admin"], true);
    let (_, setup) = c.call(Method::GET, "/auth/setup", None, None).await;
    assert_eq!(setup["needs_setup"], false);
    assert_eq!(setup["open_registration"], false);

    // Sign-up is now closed.
    let (s, _) = c
        .call(Method::POST, "/auth/register", None, Some(json!({ "email": "x@example.com", "password": "correct horse", "name": "X" })))
        .await;
    assert_eq!(s, StatusCode::FORBIDDEN);

    // The admin creates a caregiver, straight into a family.
    let (_, fam) = c.call(Method::POST, "/families", Some(&admin), Some(json!({ "name": "Home" }))).await;
    let fid = fam["id"].as_str().unwrap();
    let (s, u) = c
        .call(
            Method::POST,
            "/admin/users",
            Some(&admin),
            Some(json!({ "email": "Partner@Example.com", "name": "Partner", "password": "temporary1", "family_id": fid })),
        )
        .await;
    assert_eq!(s, StatusCode::CREATED, "{u}");
    assert_eq!(u["is_admin"], false);
    assert_eq!(u["email"], "partner@example.com");
    let uid = u["id"].as_str().unwrap();
    let (s, login) = c
        .call(Method::POST, "/auth/login", None, Some(json!({ "email": "partner@example.com", "password": "temporary1" })))
        .await;
    assert_eq!(s, StatusCode::OK);
    let partner = login["token"].as_str().unwrap().to_string();
    let (_, me) = c.call(Method::GET, "/me", Some(&partner), None).await;
    assert_eq!(me["families"][0]["id"], fid);

    // Not an admin: no access to accounts.
    let (s, _) = c.call(Method::GET, "/admin/users", Some(&partner), None).await;
    assert_eq!(s, StatusCode::FORBIDDEN);
    let (_, list) = c.call(Method::GET, "/admin/users", Some(&admin), None).await;
    assert_eq!(list["users"].as_array().unwrap().len(), 2);

    // Password reset signs them out.
    let (s, _) = c.call(Method::PATCH, &format!("/admin/users/{uid}"), Some(&admin), Some(json!({ "password": "brand new pw" }))).await;
    assert_eq!(s, StatusCode::OK);
    let (s, _) = c.call(Method::GET, "/me", Some(&partner), None).await;
    assert_eq!(s, StatusCode::UNAUTHORIZED);

    // Promote, then the last-admin and self-delete guards.
    let (_, u) = c.call(Method::PATCH, &format!("/admin/users/{uid}"), Some(&admin), Some(json!({ "is_admin": true }))).await;
    assert_eq!(u["is_admin"], true);
    let (_, me) = c.call(Method::GET, "/me", Some(&admin), None).await;
    let admin_id = me["id"].as_str().unwrap().to_string();
    let (s, _) = c.call(Method::DELETE, &format!("/admin/users/{admin_id}"), Some(&admin), None).await;
    assert_eq!(s, StatusCode::BAD_REQUEST);
    let (s, _) = c.call(Method::PATCH, &format!("/admin/users/{uid}"), Some(&admin), Some(json!({ "is_admin": false }))).await;
    assert_eq!(s, StatusCode::OK);
    let (s, _) = c.call(Method::PATCH, &format!("/admin/users/{admin_id}"), Some(&admin), Some(json!({ "is_admin": false }))).await;
    assert_eq!(s, StatusCode::BAD_REQUEST, "last admin");
    let (s, _) = c.call(Method::DELETE, &format!("/admin/users/{uid}"), Some(&admin), None).await;
    assert_eq!(s, StatusCode::NO_CONTENT);
}

#[tokio::test]
async fn child_photo() {
    let c = Client::new().await;
    let t = c.register("a@example.com", "A").await;
    let (_, fam) = c.call(Method::POST, "/families", Some(&t), Some(json!({ "name": "F" }))).await;
    let fid = fam["id"].as_str().unwrap();
    let (_, child) = c.call(Method::POST, &format!("/families/{fid}/children"), Some(&t), Some(json!({ "name": "B", "birth_date": "2026-06-01" }))).await;
    let cid = child["id"].as_str().unwrap();
    assert!(child["photo_version"].is_null());

    let png = b"\x89PNG\r\n\x1a\nnot really a png".to_vec();
    let (s, _, body) = c.call_raw(Method::PUT, &format!("/children/{cid}/photo"), &t, png.clone()).await;
    assert_eq!(s, StatusCode::OK, "{}", String::from_utf8_lossy(&body));
    let (_, child) = c.call(Method::GET, &format!("/children/{cid}"), Some(&t), None).await;
    assert!(child["photo_version"].is_i64(), "{child}");
    let (s, ct, body) = c.call_raw(Method::GET, &format!("/children/{cid}/photo"), &t, vec![]).await;
    assert_eq!((s, ct.as_str(), body), (StatusCode::OK, "image/png", png));

    let (s, _, _) = c.call_raw(Method::PUT, &format!("/children/{cid}/photo"), &t, b"<svg/>".to_vec()).await;
    assert_eq!(s, StatusCode::BAD_REQUEST);

    // Someone outside the family can't see it.
    let other = c.register("b@example.com", "B").await;
    let (s, _, _) = c.call_raw(Method::GET, &format!("/children/{cid}/photo"), &other, vec![]).await;
    assert_eq!(s, StatusCode::NOT_FOUND);

    let (s, _, _) = c.call_raw(Method::DELETE, &format!("/children/{cid}/photo"), &t, vec![]).await;
    assert_eq!(s, StatusCode::NO_CONTENT);
    let (s, _, _) = c.call_raw(Method::GET, &format!("/children/{cid}/photo"), &t, vec![]).await;
    assert_eq!(s, StatusCode::NOT_FOUND);
}

#[tokio::test]
async fn csv_export_round_trip() {
    let c = Client::new().await;
    let t = c.register("export@example.com", "Ex").await;
    let (_, fam) = c.call(Method::POST, "/families", Some(&t), Some(json!({ "name": "Home", "timezone": "America/Toronto" }))).await;
    let fid = fam["id"].as_str().unwrap();
    let (_, child) = c
        .call(Method::POST, &format!("/families/{fid}/children"), Some(&t), Some(json!({ "name": "Léa", "birth_date": "2026-06-12", "sex": "female" })))
        .await;
    let cid = child["id"].as_str().unwrap();
    let entries = [
        json!({ "type": "feed", "method": "breast", "left_seconds": 600, "right_seconds": 300, "start_side": "left", "start": "2026-10-01T08:00", "note": "sleepy" }),
        json!({ "type": "feed", "method": "bottle", "amount_ml": 120, "milk": "formula", "formula_name": "Brand", "start": "2026-10-01T09:00" }),
        json!({ "type": "feed", "method": "combo", "left_seconds": 300, "amount_ml": 60, "milk": "breast_milk", "start": "2026-10-01T10:00" }),
        json!({ "type": "feed", "method": "solids", "foods": "Avocado", "start": "2026-10-01T11:00" }),
        json!({ "type": "sleep", "start": "2026-10-01T12:00", "end": "2026-10-01T13:30", "location": "crib" }),
        json!({ "type": "diaper", "wet": true, "dirty": true, "color": "yellow", "consistency": "mushy", "blowout": true, "start": "2026-10-01T14:00" }),
        json!({ "type": "pump", "left_ml": 80, "right_ml": 70, "left_seconds": 600, "right_seconds": 600, "start": "2026-10-01T15:00" }),
        json!({ "type": "growth", "weight_g": 5850, "length_cm": 60.5, "head_cm": 40.1, "start": "2026-10-01T16:00" }),
        json!({ "type": "health", "kind": "medicine", "name": "Vitamin D", "dose": 1, "dose_unit": "drop", "start": "2026-10-01T17:00" }),
        json!({ "type": "health", "kind": "temperature", "temperature_c": 37.8, "start": "2026-10-01T17:30" }),
        json!({ "type": "health", "kind": "vaccine", "name": "Rotavirus", "start": "2026-10-01T18:00" }),
        json!({ "type": "activity", "kind": "tummy_time", "start": "2026-10-01T19:00", "end": "2026-10-01T19:10" }),
        json!({ "type": "milestone", "name": "First smile", "start": "2026-10-01T20:00" }),
        json!({ "type": "note", "note": "Visited grandma", "start": "2026-10-01T21:00" }),
    ];
    for e in &entries {
        let (s, b) = c.call(Method::POST, &format!("/children/{cid}/events"), Some(&t), Some(e.clone())).await;
        assert_eq!(s, StatusCode::CREATED, "{e} -> {b}");
    }

    let (s, ct, body) = c.call_raw(Method::GET, &format!("/families/{fid}/export.csv"), &t, vec![]).await;
    assert_eq!(s, StatusCode::OK);
    assert!(ct.starts_with("text/csv"), "{ct}");
    let csv = String::from_utf8(body).unwrap();
    assert!(csv.starts_with("\u{feff}\"Type\",\"Profile Name\""), "{}", &csv[..80]);
    assert!(csv.contains("\"Profile\",\"Léa\""));

    // Import it into an empty family: same records, same values.
    let (_, fam2) = c.call(Method::POST, "/families", Some(&t), Some(json!({ "name": "Copy", "timezone": "America/Toronto" }))).await;
    let fid2 = fam2["id"].as_str().unwrap();
    let (s, res) = c.call_csv(&format!("/families/{fid2}/import/nara-csv"), &t, &csv).await;
    assert_eq!(s, StatusCode::OK, "{res}");
    assert_eq!(res["imported"], entries.len(), "{res}");
    assert_eq!(res["children_created"][0]["name"], "Léa");
    let cid2 = res["children_created"][0]["id"].as_str().unwrap();
    let (_, child2) = c.call(Method::GET, &format!("/children/{cid2}"), Some(&t), None).await;
    assert_eq!((child2["birth_date"].as_str(), child2["sex"].as_str()), (Some("2026-06-12"), Some("female")));

    let (_, a) = c.call(Method::GET, &format!("/children/{cid}/events?limit=100"), Some(&t), None).await;
    let (_, b) = c.call(Method::GET, &format!("/children/{cid2}/events?limit=100"), Some(&t), None).await;
    let strip = |v: &Value| {
        let mut v = v.clone();
        for k in ["id", "child_id", "created_at", "updated_at", "source", "created_by", "updated_by"] {
            v.as_object_mut().unwrap().remove(k);
        }
        v
    };
    let (a, b) = (a["events"].as_array().unwrap(), b["events"].as_array().unwrap());
    assert_eq!(a.len(), b.len());
    for (x, y) in a.iter().zip(b) {
        assert_eq!(strip(x), strip(y));
    }
}

async fn e_total(c: &Client, t: &str, id: &str) -> i64 {
    c.call(Method::GET, &format!("/timers/{id}"), Some(t), None).await.1["elapsed_seconds"].as_i64().unwrap()
}

#[tokio::test]
async fn offline_push_and_conflicts() {
    let c = Client::new().await;
    let mom = c.register("mom@example.com", "Mom").await;
    let (_, fam) = c.call(Method::POST, "/families", Some(&mom), Some(json!({ "name": "F", "timezone": "America/New_York" }))).await;
    let fid = fam["id"].as_str().unwrap().to_string();
    let (_, child) = c.call(Method::POST, &format!("/families/{fid}/children"), Some(&mom), Some(json!({ "name": "B", "birth_date": "2026-06-01" }))).await;
    let cid = child["id"].as_str().unwrap().to_string();
    let ago = |m: i64| (chrono::Utc::now() - chrono::Duration::minutes(m)).to_rfc3339();
    let push = |body: Value| {
        let (c, mom, fid) = (&c, mom.clone(), fid.clone());
        async move { c.call(Method::POST, &format!("/families/{fid}/sync"), Some(&mom), Some(body)).await }
    };

    // A diaper logged offline, with the device's own id; pushing twice is harmless.
    let offline_id = "0199c5a0-0000-7000-8000-000000000001";
    let diaper = json!({ "events": [{ "id": offline_id, "child_id": cid, "changed_at": ago(30), "type": "diaper", "wet": true, "start": ago(30) }] });
    let (s, r) = push(diaper.clone()).await;
    assert_eq!(s, StatusCode::OK, "{r}");
    assert_eq!(r["events"][0]["status"], "applied", "{r}");
    let (_, r) = push(diaper).await;
    assert_eq!(r["events"][0]["status"], "applied");
    let (_, list) = c.call(Method::GET, &format!("/children/{cid}/events"), Some(&mom), None).await;
    assert_eq!(list["events"].as_array().unwrap().len(), 1);
    assert_eq!(list["events"][0]["id"], offline_id);

    // Edited online a minute ago; an older offline edit loses, a newer one wins.
    let (s, _) = c.call(Method::PATCH, &format!("/events/{offline_id}"), Some(&mom), Some(json!({ "dirty": true }))).await;
    assert_eq!(s, StatusCode::OK);
    let (_, r) = push(json!({ "events": [{ "id": offline_id, "child_id": cid, "changed_at": ago(10), "type": "diaper", "dry": true, "start": ago(30) }] })).await;
    assert_eq!(r["events"][0]["status"], "conflict", "{r}");
    assert_eq!(r["events"][0]["current"]["dirty"], true, "the server's copy comes back");
    let (_, ev) = c.call(Method::GET, &format!("/events/{offline_id}"), Some(&mom), None).await;
    assert_eq!(ev["dirty"], true);
    let (_, r) = push(json!({ "events": [{ "id": offline_id, "child_id": cid, "changed_at": "now", "type": "diaper", "dry": true, "start": ago(30) }] })).await;
    assert_eq!(r["events"][0]["status"], "applied", "{r}");
    let (_, ev) = c.call(Method::GET, &format!("/events/{offline_id}"), Some(&mom), None).await;
    assert_eq!((ev["dry"].clone(), ev["dirty"].clone()), (json!(true), json!(false)));

    // Invalid records are rejected one by one; the rest of the batch still applies.
    let (_, r) = push(json!({ "events": [
        { "id": "0199c5a0-0000-7000-8000-000000000002", "child_id": cid, "changed_at": "now", "type": "diaper", "start": ago(5) },
        { "id": "0199c5a0-0000-7000-8000-000000000003", "child_id": cid, "changed_at": "now", "type": "sleep", "start": ago(90), "end": ago(30) },
    ] })).await;
    assert_eq!(r["events"][0]["status"], "rejected");
    assert_eq!(r["events"][1]["status"], "applied", "{r}");

    // Deleted offline; a later offline edit can't bring it back.
    let (_, r) = push(json!({ "events": [{ "id": offline_id, "changed_at": "now", "deleted": true }] })).await;
    assert_eq!(r["events"][0]["status"], "applied", "{r}");
    let (s, _) = c.call(Method::GET, &format!("/events/{offline_id}"), Some(&mom), None).await;
    assert_eq!(s, StatusCode::NOT_FOUND);
    let (_, r) = push(json!({ "events": [{ "id": offline_id, "child_id": cid, "changed_at": "now", "type": "diaper", "wet": true, "start": ago(30) }] })).await;
    assert_eq!(r["events"][0]["status"], "conflict");

    // A sleep timer started offline 40 minutes ago, while another device started one 10 minutes ago:
    // the earlier start wins and takes over the existing timer.
    let (s, online) = c.call(Method::POST, &format!("/children/{cid}/timers"), Some(&mom), Some(json!({ "kind": "sleep", "start": ago(10) }))).await;
    assert_eq!(s, StatusCode::CREATED);
    let timer = |id: &str, start: String| json!({ "timers": [{ "id": id, "child_id": cid, "kind": "sleep", "changed_at": "now", "segments": [{ "start": start }] }] });
    let (_, r) = push(timer("0199c5a0-0000-7000-8000-0000000000a1", ago(40))).await;
    assert_eq!(r["timers"][0]["status"], "applied", "{r}");
    let (_, ts) = c.call(Method::GET, &format!("/children/{cid}/timers"), Some(&mom), None).await;
    assert_eq!(ts["timers"].as_array().unwrap().len(), 1);
    assert_eq!(ts["timers"][0]["id"], online["id"]);
    assert!(ts["timers"][0]["elapsed_seconds"].as_i64().unwrap() >= 40 * 60 - 1);
    let (_, r) = push(timer("0199c5a0-0000-7000-8000-0000000000a2", ago(20))).await;
    assert_eq!(r["timers"][0]["status"], "conflict");
    assert_eq!(r["timers"][0]["current"], Value::Null, "the losing timer never reached the server");

    // Stopped offline: the event arrives with the timer's deletion.
    let tid = online["id"].as_str().unwrap();
    let (_, r) = push(json!({
        "events": [{ "id": "0199c5a0-0000-7000-8000-000000000004", "child_id": cid, "changed_at": "now", "type": "sleep", "start": ago(40), "end": ago(1) }],
        "timers": [{ "id": tid, "child_id": cid, "kind": "sleep", "changed_at": "now", "deleted": true }],
    })).await;
    assert_eq!((r["events"][0]["status"].clone(), r["timers"][0]["status"].clone()), (json!("applied"), json!("applied")), "{r}");
    let (_, ts) = c.call(Method::GET, &format!("/children/{cid}/timers"), Some(&mom), None).await;
    assert!(ts["timers"].as_array().unwrap().is_empty());

    // Another family's child is off limits.
    let other = c.register("x@example.com", "X").await;
    let (_, fam2) = c.call(Method::POST, "/families", Some(&other), Some(json!({ "name": "G" }))).await;
    let (s, _) = c.call(Method::POST, &format!("/families/{}/sync", fam2["id"].as_str().unwrap()), Some(&mom), Some(json!({}))).await;
    assert_eq!(s, StatusCode::NOT_FOUND);

    // The pull side sees everything, deletions included.
    let (_, sync) = c.call(Method::GET, &format!("/families/{fid}/sync?since=0"), Some(&mom), None).await;
    let ids: Vec<&str> = sync["events"].as_array().unwrap().iter().map(|e| e["id"].as_str().unwrap()).collect();
    assert!(ids.contains(&offline_id) && ids.contains(&"0199c5a0-0000-7000-8000-000000000004"));
}

#[tokio::test]
async fn client_ids_make_retries_safe() {
    let c = Client::new().await;
    let t = c.register("a@example.com", "A").await;
    let (_, fam) = c.call(Method::POST, "/families", Some(&t), Some(json!({ "name": "F" }))).await;
    let fid = fam["id"].as_str().unwrap();
    let (_, child) = c.call(Method::POST, &format!("/families/{fid}/children"), Some(&t), Some(json!({ "name": "B", "birth_date": "2026-06-01" }))).await;
    let cid = child["id"].as_str().unwrap();

    let body = json!({ "id": "0199c5a0-0000-7000-8000-0000000000e1", "type": "diaper", "wet": true });
    let (s, a) = c.call(Method::POST, &format!("/children/{cid}/events"), Some(&t), Some(body.clone())).await;
    assert_eq!(s, StatusCode::CREATED, "{a}");
    let (s, b) = c.call(Method::POST, &format!("/children/{cid}/events"), Some(&t), Some(body)).await;
    assert_eq!(s, StatusCode::OK);
    assert_eq!(a["id"], b["id"]);

    let start = json!({ "id": "0199c5a0-0000-7000-8000-0000000000e2", "kind": "sleep" });
    let (s, _) = c.call(Method::POST, &format!("/children/{cid}/timers"), Some(&t), Some(start.clone())).await;
    assert_eq!(s, StatusCode::CREATED);
    let (s, _) = c.call(Method::POST, &format!("/children/{cid}/timers"), Some(&t), Some(start)).await;
    assert_eq!(s, StatusCode::OK);
    let stop = json!({ "event_id": "0199c5a0-0000-7000-8000-0000000000e3" });
    let (s, ev) = c.call(Method::POST, "/timers/0199c5a0-0000-7000-8000-0000000000e2/stop", Some(&t), Some(stop.clone())).await;
    assert_eq!(s, StatusCode::CREATED, "{ev}");
    assert_eq!(ev["id"], "0199c5a0-0000-7000-8000-0000000000e3");
    let (s, again) = c.call(Method::POST, "/timers/0199c5a0-0000-7000-8000-0000000000e2/stop", Some(&t), Some(stop)).await;
    assert_eq!(s, StatusCode::OK);
    assert_eq!(again["id"], ev["id"]);
    // A second stop without an id finds the timer gone instead of logging the sleep twice.
    let (s, _) = c.call(Method::POST, "/timers/0199c5a0-0000-7000-8000-0000000000e2/stop", Some(&t), None).await;
    assert_eq!(s, StatusCode::NOT_FOUND);
    let (_, list) = c.call(Method::GET, &format!("/children/{cid}/events"), Some(&t), None).await;
    assert_eq!(list["events"].as_array().unwrap().len(), 2);
}

#[tokio::test]
async fn timer_started_by_one_caregiver_reaches_the_others_live() {
    let c = Client::new().await;
    let mom = c.register("mom@example.com", "Mom").await;
    let dad = c.register("dad@example.com", "Dad").await;
    let (_, fam) = c.call(Method::POST, "/families", Some(&mom), Some(json!({ "name": "Home" }))).await;
    let fid = fam["id"].as_str().unwrap().to_string();
    let (_, child) = c
        .call(Method::POST, &format!("/families/{fid}/children"), Some(&mom), Some(json!({ "name": "Léa", "birth_date": "2026-06-01" })))
        .await;
    let cid = child["id"].as_str().unwrap().to_string();
    let (_, inv) = c.call(Method::POST, &format!("/families/{fid}/invites"), Some(&mom), None).await;
    c.call(Method::POST, &format!("/invites/{}/accept", inv["code"].as_str().unwrap()), Some(&dad), None).await;

    let req = Request::builder()
        .uri(format!("/api/v1/families/{fid}/stream"))
        .header("authorization", format!("Bearer {dad}"))
        .body(Body::empty())
        .unwrap();
    let res = c.app.clone().oneshot(req).await.unwrap();
    assert_eq!(res.status(), StatusCode::OK);
    // Reverse proxies (nginx) must pass events through as they come.
    assert_eq!(res.headers()["x-accel-buffering"], "no");
    let mut body = res.into_body();
    let mut next = async || {
        let frame = tokio::time::timeout(std::time::Duration::from_secs(2), body.frame()).await.expect("no event").unwrap().unwrap();
        String::from_utf8(frame.into_data().unwrap().to_vec()).unwrap()
    };
    assert!(next().await.starts_with("event: ready"));

    let (s, timer) = c.call(Method::POST, &format!("/children/{cid}/timers"), Some(&mom), Some(json!({ "kind": "sleep" }))).await;
    assert_eq!(s, StatusCode::CREATED, "{timer}");
    let msg = next().await;
    assert!(msg.starts_with("event: change"), "{msg}");
    assert!(msg.contains(timer["id"].as_str().unwrap()), "{msg}");
}

/// A stand-in for Google's OAuth and FCM endpoints, recording the messages sent.
async fn fake_fcm() -> (String, std::sync::Arc<std::sync::Mutex<Vec<Value>>>) {
    use axum::{routing::post, Json};
    let sent = std::sync::Arc::new(std::sync::Mutex::new(Vec::<Value>::new()));
    let log = sent.clone();
    let app = Router::new()
        .route("/token", post(|| async { Json(json!({ "access_token": "fake", "expires_in": 3600 })) }))
        .route(
            "/v1/projects/{*rest}",
            post(move |Json(body): Json<Value>| {
                let log = log.clone();
                async move {
                    let gone = body["message"]["token"] == "uninstalled-phone";
                    log.lock().unwrap().push(body);
                    if gone {
                        (StatusCode::NOT_FOUND, Json(json!({ "error": { "status": "NOT_FOUND", "details": [{ "errorCode": "UNREGISTERED" }] } })))
                    } else {
                        (StatusCode::OK, Json(json!({ "name": "projects/p/messages/1" })))
                    }
                }
            }),
        );
    let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
    let url = format!("http://{}", listener.local_addr().unwrap());
    tokio::spawn(async move { axum::serve(listener, app).await.unwrap() });
    (url, sent)
}

#[tokio::test]
async fn timer_changes_reach_registered_phones() {
    use nestling::push::{Push, PushConfig, ServiceAccount};
    // A throwaway signing key for the fake OAuth endpoint.
    let key = std::process::Command::new("openssl")
        .args(["genpkey", "-algorithm", "RSA", "-pkeyopt", "rsa_keygen_bits:2048"])
        .output()
        .expect("openssl is needed for this test");
    let (fake, sent) = fake_fcm().await;
    let db = connect("sqlite::memory:", 1).await.unwrap();
    let state = AppState::new(db.clone(), Config { open_registration: true, nara: NaraConfig::default() }).with_push(Push::new(PushConfig {
        account: ServiceAccount {
            project_id: "p".into(),
            client_email: "nestling@p.iam.gserviceaccount.com".into(),
            private_key: String::from_utf8(key.stdout).unwrap(),
            token_uri: format!("{fake}/token"),
        },
        app_id: "1:1234:android:abcd".into(),
        api_key: "key".into(),
        fcm_url: fake,
    }));
    let c = Client { app: app(state, None), db };
    let mom = c.register("mom@example.com", "Mom").await;
    let dad = c.register("dad@example.com", "Dad").await;
    let (_, fam) = c.call(Method::POST, "/families", Some(&mom), Some(json!({ "name": "Home", "timezone": "America/Toronto" }))).await;
    let fid = fam["id"].as_str().unwrap().to_string();
    let (_, child) = c
        .call(Method::POST, &format!("/families/{fid}/children"), Some(&mom), Some(json!({ "name": "Léa", "birth_date": "2026-06-01" })))
        .await;
    let cid = child["id"].as_str().unwrap().to_string();
    let (_, inv) = c.call(Method::POST, &format!("/families/{fid}/invites"), Some(&mom), None).await;
    c.call(Method::POST, &format!("/invites/{}/accept", inv["code"].as_str().unwrap()), Some(&dad), None).await;

    let (s, cfg) = c.call(Method::GET, "/push/config", Some(&dad), None).await;
    assert_eq!(s, StatusCode::OK);
    assert_eq!(cfg["android"]["sender_id"], "1234");
    let (s, _) = c.call(Method::POST, "/me/push-devices", Some(&dad), Some(json!({ "token": "dads-phone" }))).await;
    assert_eq!(s, StatusCode::NO_CONTENT);
    c.call(Method::POST, "/me/push-devices", Some(&dad), Some(json!({ "token": "uninstalled-phone" }))).await;

    let wait_for = |n: usize| {
        let sent = sent.clone();
        async move {
            for _ in 0..100 {
                if sent.lock().unwrap().len() >= n {
                    return sent.lock().unwrap().clone();
                }
                tokio::time::sleep(std::time::Duration::from_millis(20)).await;
            }
            panic!("only {} messages sent", sent.lock().unwrap().len());
        }
    };

    // Mom starts a sleep: Dad's phone shows it (the uninstalled one is forgotten).
    let (_, timer) = c.call(Method::POST, &format!("/children/{cid}/timers"), Some(&mom), Some(json!({ "kind": "sleep" }))).await;
    let msgs = wait_for(2).await;
    let shown = msgs.iter().find(|m| m["message"]["token"] == "dads-phone").expect("sent to Dad's phone");
    let data = &shown["message"]["data"];
    assert_eq!(data["action"], "show");
    assert_eq!(data["title"], "Léa · Sleeping");
    assert!(data["body"].as_str().unwrap().starts_with("Since "), "{data}");
    assert_eq!(data["id"], "2");
    assert_eq!(shown["message"]["android"]["priority"], "high");
    tokio::time::sleep(std::time::Duration::from_millis(100)).await;
    let (n,): (i64,) = sqlx::query_as("SELECT COUNT(*) FROM push_devices WHERE fcm_token = 'uninstalled-phone'").fetch_one(&c.db()).await.unwrap();
    assert_eq!(n, 0);

    // Mom stops it: the notification goes away.
    c.call(Method::POST, &format!("/timers/{}/stop", timer["id"].as_str().unwrap()), Some(&mom), None).await;
    let msgs = wait_for(3).await;
    assert_eq!(msgs[2]["message"]["data"]["action"], "cancel");
    assert_eq!(msgs[2]["message"]["data"]["id"], "2");

    // Signing out stops the notifications to that phone.
    c.call(Method::POST, "/auth/logout", Some(&dad), None).await;
    let (n,): (i64,) = sqlx::query_as("SELECT COUNT(*) FROM push_devices").fetch_one(&c.db()).await.unwrap();
    assert_eq!(n, 0);
}
