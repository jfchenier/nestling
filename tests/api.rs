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
}

impl Client {
    async fn new() -> Self {
        let db = connect("sqlite::memory:", 1).await.unwrap();
        let state = AppState::new(db, Config { open_registration: true, nara: NaraConfig::default() });
        Client { app: app(state, None) }
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
    let (_, child) = c.call(Method::POST, &format!("/families/{fid}/children"), Some(&t), Some(json!({ "name": "B" }))).await;
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
    let (s, ev) = c.call(Method::POST, &format!("/timers/{bid}/stop"), Some(&t), None).await;
    assert_eq!(s, StatusCode::CREATED, "{ev}");
    assert_eq!(ev["right_seconds"], 300);
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
