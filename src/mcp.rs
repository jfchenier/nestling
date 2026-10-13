//! MCP server (Model Context Protocol, streamable HTTP, stateless) at `/mcp`, so an assistant
//! such as Claude can log entries and run timers: add the server's `/mcp` address as a custom
//! connector and sign in (see `oauth.rs`). Each tool is a call to the REST API with the caller's
//! token, so it can do exactly what that token can (a connected app: `auth::integration_may`).

use axum::{
    body::{Body, Bytes},
    extract::State,
    http::{header, HeaderMap, HeaderValue, Method, Request, StatusCode},
    response::{IntoResponse, Response},
    Json,
};
use reqwest::Url;
use serde_json::{json, Map, Value};
use tower::ServiceExt;

use crate::{
    oauth::base_url,
    state::AppState,
    util::{parse_tz, sha256_hex},
    VERSION,
};

/// Protocol versions this server speaks, newest first.
const PROTOCOL_VERSIONS: [&str; 4] = ["2025-11-25", "2025-06-18", "2025-03-26", "2024-11-05"];

const INSTRUCTIONS: &str = "Nestling is a baby tracker. Use these tools to log feeds, sleep, diapers, pumping, growth, \
health, activities and milestones, to start and stop timers, and to answer questions such as when the baby last ate. \
Units are metric (mL, g, cm, °C, seconds): convert what the user says. Times are 'now', a local time in the \
family's time zone like '2026-10-08T14:30', or RFC 3339; every answer includes `now` (the family's local time) to \
work out times such as '20 minutes ago'. `child` can be left out when the family has one child.";

fn bearer(headers: &HeaderMap) -> Option<String> {
    let v = headers.get(header::AUTHORIZATION)?.to_str().ok()?;
    let t = v.strip_prefix("Bearer ").or_else(|| v.strip_prefix("bearer "))?.trim();
    (!t.is_empty()).then(|| t.to_string())
}

/// 401 pointing at the OAuth metadata, which starts the sign-in in MCP clients.
fn unauthorized(headers: &HeaderMap) -> Response {
    let meta = format!(r#"Bearer resource_metadata="{}/.well-known/oauth-protected-resource/mcp""#, base_url(headers));
    let mut res = (StatusCode::UNAUTHORIZED, Json(json!({ "error": { "code": "unauthorized", "message": "authentication required" } }))).into_response();
    if let Ok(v) = HeaderValue::from_str(&meta) {
        res.headers_mut().insert(header::WWW_AUTHENTICATE, v);
    }
    res
}

/// `GET /mcp`: no server-to-client stream (the server is stateless).
pub async fn get() -> Response {
    (StatusCode::METHOD_NOT_ALLOWED, [(header::ALLOW, "POST")]).into_response()
}

/// `POST /mcp`: one JSON-RPC message (or a batch).
pub async fn post(State(state): State<AppState>, headers: HeaderMap, body: Bytes) -> Response {
    let Some(token) = bearer(&headers) else { return unauthorized(&headers) };
    let known: Result<Option<(i64,)>, _> =
        sqlx::query_as("SELECT 1 FROM tokens WHERE token_hash = ?").bind(sha256_hex(&token)).fetch_optional(&state.db).await;
    match known {
        Ok(Some(_)) => {}
        Ok(None) => return unauthorized(&headers),
        Err(e) => {
            tracing::error!("mcp: {e}");
            return StatusCode::INTERNAL_SERVER_ERROR.into_response();
        }
    }
    let msg: Value = match serde_json::from_slice(&body) {
        Ok(v) => v,
        Err(e) => return Json(rpc_error(Value::Null, -32700, &format!("parse error: {e}"))).into_response(),
    };
    let api = Api { state, token };
    match msg {
        Value::Array(batch) => {
            let mut out = Vec::new();
            for m in batch {
                if let Some(r) = api.handle(m).await {
                    out.push(r);
                }
            }
            if out.is_empty() {
                StatusCode::ACCEPTED.into_response()
            } else {
                Json(Value::Array(out)).into_response()
            }
        }
        m => match api.handle(m).await {
            Some(r) => Json(r).into_response(),
            None => StatusCode::ACCEPTED.into_response(),
        },
    }
}

fn rpc_error(id: Value, code: i64, message: &str) -> Value {
    json!({ "jsonrpc": "2.0", "id": id, "error": { "code": code, "message": message } })
}

/// The caller's view of the REST API.
struct Api {
    state: AppState,
    token: String,
}

/// A tool's failure, shown to the assistant as an error result.
type ToolResult = Result<Value, String>;

impl Api {
    /// One JSON-RPC message; None for notifications and responses (nothing to answer).
    async fn handle(&self, msg: Value) -> Option<Value> {
        let id = msg.get("id").cloned()?;
        let Some(method) = msg.get("method").and_then(Value::as_str) else {
            return if msg.get("result").is_some() || msg.get("error").is_some() { None } else { Some(rpc_error(id, -32600, "invalid request")) };
        };
        let params = msg.get("params").cloned().unwrap_or(json!({}));
        let result = match method {
            "initialize" => {
                let asked = params["protocolVersion"].as_str().unwrap_or("");
                let version = PROTOCOL_VERSIONS.iter().find(|v| **v == asked).unwrap_or(&PROTOCOL_VERSIONS[0]);
                json!({
                    "protocolVersion": version,
                    "capabilities": { "tools": { "listChanged": false } },
                    "serverInfo": { "name": "nestling", "title": "Nestling", "version": VERSION },
                    "instructions": INSTRUCTIONS,
                })
            }
            "ping" => json!({}),
            "tools/list" => json!({ "tools": tools() }),
            "tools/call" => {
                let name = params["name"].as_str().unwrap_or("");
                let args = params.get("arguments").and_then(Value::as_object).cloned().unwrap_or_default();
                if !tools().iter().any(|t| t["name"] == name) {
                    return Some(rpc_error(id, -32602, &format!("unknown tool '{name}'")));
                }
                match self.call_tool(name, args).await {
                    Ok(v) => json!({
                        "content": [{ "type": "text", "text": serde_json::to_string_pretty(&v).unwrap_or_default() }],
                        "structuredContent": v,
                        "isError": false,
                    }),
                    Err(e) => json!({ "content": [{ "type": "text", "text": e }], "isError": true }),
                }
            }
            _ => return Some(rpc_error(id, -32601, &format!("method '{method}' not found"))),
        };
        Some(json!({ "jsonrpc": "2.0", "id": id, "result": result }))
    }

    /// A request to the REST API (`path` relative to `/api/v1`) as the caller.
    async fn call(&self, method: Method, path: &str, body: Option<Value>) -> ToolResult {
        let mut req = Request::builder().method(method).uri(path).header(header::AUTHORIZATION, format!("Bearer {}", self.token));
        let req = match body {
            Some(b) => req.header(header::CONTENT_TYPE, "application/json").body(Body::from(b.to_string())),
            None => {
                req = req.header(header::CONTENT_LENGTH, "0");
                req.body(Body::empty())
            }
        }
        .map_err(|e| format!("bad request: {e}"))?;
        let res = crate::routes::api().with_state(self.state.clone()).oneshot(req).await.unwrap_or_else(|e| match e {});
        let status = res.status();
        let bytes = axum::body::to_bytes(res.into_body(), 16 * 1024 * 1024).await.map_err(|e| e.to_string())?;
        let value: Value = if bytes.is_empty() { json!({ "ok": true }) } else { serde_json::from_slice(&bytes).unwrap_or(Value::Null) };
        if status.is_success() {
            Ok(value)
        } else {
            Err(value["error"]["message"].as_str().map(str::to_string).unwrap_or_else(|| format!("request failed ({status})")))
        }
    }

    /// The families the caller logs for (book viewers can't), each with its children.
    async fn families(&self) -> Result<Vec<Value>, String> {
        let v = self.call(Method::GET, "/families", None).await?;
        Ok(v["families"].as_array().cloned().unwrap_or_default().into_iter().filter(|f| f["role"] != "book_viewer").collect())
    }

    /// The child named in `args["child"]` (an id or a name), or the only one.
    /// Returns the child and its family.
    async fn child(&self, args: &Map<String, Value>) -> Result<(Value, Value), String> {
        let families = self.families().await?;
        let all: Vec<(Value, Value)> = families
            .iter()
            .flat_map(|f| f["children"].as_array().cloned().unwrap_or_default().into_iter().map(move |c| (c, f.clone())))
            .collect();
        let names = || all.iter().filter_map(|(c, _)| c["name"].as_str()).collect::<Vec<_>>().join(", ");
        let wanted = args.get("child").and_then(Value::as_str).map(str::trim).filter(|s| !s.is_empty());
        let Some(wanted) = wanted else {
            return match all.as_slice() {
                [one] => Ok(one.clone()),
                [] => Err("there are no children in this family yet (add one in the Nestling app)".into()),
                _ => Err(format!("several children: say which one with `child` ({})", names())),
            };
        };
        if let Some(c) = all.iter().find(|(c, _)| c["id"] == wanted) {
            return Ok(c.clone());
        }
        let lower = wanted.to_lowercase();
        let by_name = |exact: bool| -> Vec<&(Value, Value)> {
            all.iter()
                .filter(|(c, _)| {
                    let n = c["name"].as_str().unwrap_or("").to_lowercase();
                    if exact { n == lower } else { n.split_whitespace().any(|w| w == lower) || n.starts_with(&lower) }
                })
                .collect()
        };
        for exact in [true, false] {
            match by_name(exact).as_slice() {
                [one] => return Ok((*one).clone()),
                [] => {}
                _ => return Err(format!("more than one child matches '{wanted}': use the child's id (from list_children)")),
            }
        }
        Err(format!("no child named '{wanted}' (children: {})", names()))
    }

    /// The local time now in the family's time zone (the first family's when none is given).
    async fn now(&self, family: Option<&Value>) -> String {
        let tz = match family {
            Some(f) => f["timezone"].as_str().map(str::to_string),
            None => self.families().await.ok().and_then(|f| f.first().and_then(|f| f["timezone"].as_str().map(str::to_string))),
        };
        let tz = tz.and_then(|t| parse_tz(&t).ok()).unwrap_or(chrono_tz::UTC);
        chrono::Utc::now().with_timezone(&tz).format("%Y-%m-%dT%H:%M:%S%:z (%A)").to_string()
    }

    /// The timer named by `timer_id`, or the child's running timer (of `kind`, if given).
    async fn timer(&self, args: &Map<String, Value>) -> Result<(String, Option<Value>), String> {
        if let Some(id) = args.get("timer_id").and_then(Value::as_str).filter(|s| !s.is_empty()) {
            return Ok((path_id(id)?, None));
        }
        let (child, family) = self.child(args).await?;
        let timers = self.call(Method::GET, &format!("/children/{}/timers", child["id"].as_str().unwrap_or("")), None).await?;
        let kind = args.get("kind").and_then(Value::as_str);
        let found: Vec<&Value> = timers["timers"].as_array().map(|t| t.iter().filter(|t| kind.is_none_or(|k| t["kind"] == k)).collect()).unwrap_or_default();
        let child_name = child["name"].as_str().unwrap_or("the child");
        match found.as_slice() {
            [one] => Ok((one["id"].as_str().unwrap_or("").to_string(), Some(family))),
            [] => Err(format!("no {}timer is running for {child_name}", kind.map(|k| format!("{k} ")).unwrap_or_default())),
            _ => Err(format!("{child_name} has several timers running: say which with `kind` or `timer_id`")),
        }
    }

    async fn call_tool(&self, name: &str, mut args: Map<String, Value>) -> ToolResult {
        let (result, family) = match name {
            "list_children" => {
                let families = self.families().await?;
                let out: Vec<Value> = families
                    .iter()
                    .map(|f| {
                        json!({
                            "family": f["name"], "timezone": f["timezone"],
                            "children": f["children"].as_array().map(|cs| cs.iter().map(|c| json!({
                                "id": c["id"], "name": c["name"], "birth_date": c["birth_date"], "sex": c["sex"],
                            })).collect::<Vec<_>>()),
                        })
                    })
                    .collect();
                (json!({ "families": out }), families.into_iter().next())
            }
            "get_summary" => {
                let (child, family) = self.child(&args).await?;
                (self.call(Method::GET, &format!("/children/{}/summary", id_of(&child)), None).await?, Some(family))
            }
            "list_entries" => {
                let (child, family) = self.child(&args).await?;
                let mut url = Url::parse(&format!("http://api/children/{}/events", id_of(&child))).expect("valid url");
                {
                    let mut q = url.query_pairs_mut();
                    for (key, param) in [("types", "type"), ("from", "from"), ("to", "to")] {
                        if let Some(v) = args.get(key).and_then(Value::as_str) {
                            q.append_pair(param, v);
                        }
                    }
                    q.append_pair("limit", &args.get("limit").and_then(Value::as_i64).unwrap_or(20).to_string());
                }
                let path = format!("{}?{}", url.path(), url.query().unwrap_or(""));
                (self.call(Method::GET, &path, None).await?, Some(family))
            }
            "log_entry" => {
                let (child, family) = self.child(&args).await?;
                args.remove("child");
                (self.call(Method::POST, &format!("/children/{}/events", id_of(&child)), Some(Value::Object(args))).await?, Some(family))
            }
            "update_entry" => {
                let id = path_id(args.get("id").and_then(Value::as_str).unwrap_or(""))?;
                let changes = args.get("changes").cloned().filter(Value::is_object).ok_or("`changes` must be an object of the fields to change")?;
                (self.call(Method::PATCH, &format!("/events/{id}"), Some(changes)).await?, None)
            }
            "delete_entry" => {
                let id = path_id(args.get("id").and_then(Value::as_str).unwrap_or(""))?;
                self.call(Method::DELETE, &format!("/events/{id}"), None).await?;
                (json!({ "deleted": id }), None)
            }
            "start_timer" => {
                let (child, family) = self.child(&args).await?;
                let body: Map<String, Value> = args.into_iter().filter(|(k, _)| ["kind", "side", "start"].contains(&k.as_str())).collect();
                (self.call(Method::POST, &format!("/children/{}/timers", id_of(&child)), Some(Value::Object(body))).await?, Some(family))
            }
            "stop_timer" => {
                let (id, family) = self.timer(&args).await?;
                let body: Map<String, Value> =
                    args.into_iter().filter(|(k, _)| ["end", "note", "left_ml", "right_ml", "location"].contains(&k.as_str())).collect();
                (self.call(Method::POST, &format!("/timers/{id}/stop"), Some(Value::Object(body))).await?, family)
            }
            "control_timer" => {
                let (id, family) = self.timer(&args).await?;
                let side = args.get("side").cloned().map(|s| json!({ "side": s })).unwrap_or(json!({}));
                let res = match args.get("action").and_then(Value::as_str).unwrap_or("") {
                    "pause" => self.call(Method::POST, &format!("/timers/{id}/pause"), None).await?,
                    "resume" => self.call(Method::POST, &format!("/timers/{id}/resume"), Some(side)).await?,
                    "switch" => self.call(Method::POST, &format!("/timers/{id}/switch"), Some(side)).await?,
                    "discard" => {
                        self.call(Method::DELETE, &format!("/timers/{id}"), None).await?;
                        json!({ "discarded": id })
                    }
                    "adjust" => {
                        let body: Map<String, Value> = args
                            .into_iter()
                            .filter(|(k, _)| ["start", "left_seconds", "right_seconds", "seconds"].contains(&k.as_str()))
                            .collect();
                        self.call(Method::PATCH, &format!("/timers/{id}"), Some(Value::Object(body))).await?
                    }
                    other => return Err(format!("unknown action '{other}' (pause, resume, switch, adjust or discard)")),
                };
                (res, family)
            }
            "get_trends" => {
                let (child, family) = self.child(&args).await?;
                let days = args.get("days").and_then(Value::as_u64).unwrap_or(7);
                let mut path = format!("/children/{}/trends?days={days}", id_of(&child));
                if let Some(to) = args.get("to").and_then(Value::as_str) {
                    path.push_str(&format!("&to={}", url_part(to)));
                }
                (self.call(Method::GET, &path, None).await?, Some(family))
            }
            _ => return Err(format!("unknown tool '{name}'")),
        };
        Ok(json!({ "now": self.now(family.as_ref()).await, "result": result }))
    }
}

fn id_of(v: &Value) -> &str {
    v["id"].as_str().unwrap_or("")
}

/// An id from the assistant, safe to put in a path.
fn path_id(id: &str) -> Result<String, String> {
    if !id.is_empty() && id.len() <= 64 && id.chars().all(|c| c.is_ascii_alphanumeric() || c == '-' || c == '_') {
        Ok(id.to_string())
    } else {
        Err(format!("'{id}' is not a valid id"))
    }
}

fn url_part(s: &str) -> String {
    s.bytes().map(|b| if b.is_ascii_alphanumeric() || b"-_.".contains(&b) { (b as char).to_string() } else { format!("%{b:02X}") }).collect()
}

fn child_prop() -> Value {
    json!({ "type": "string", "description": "The child's name or id; leave out when the family has one child." })
}

fn time_prop(what: &str) -> Value {
    json!({ "type": "string", "description": format!("{what}: 'now', a local time like '2026-10-08T14:30' (family time zone) or RFC 3339.") })
}

fn tool(name: &str, title: &str, description: &str, properties: Value, required: &[&str], read_only: bool, destructive: bool) -> Value {
    json!({
        "name": name,
        "title": title,
        "description": description,
        "inputSchema": { "type": "object", "properties": properties, "required": required },
        "annotations": { "title": title, "readOnlyHint": read_only, "destructiveHint": destructive, "openWorldHint": false },
    })
}

fn timer_target() -> Map<String, Value> {
    let v = json!({
        "child": child_prop(),
        "timer_id": { "type": "string", "description": "The timer's id; leave out to use the child's running timer." },
        "kind": { "type": "string", "enum": ["breastfeed", "pump", "sleep"], "description": "Which running timer, when the child has several." },
    });
    v.as_object().cloned().unwrap_or_default()
}

fn tools() -> Vec<Value> {
    let with = |mut base: Map<String, Value>, more: Value| {
        base.extend(more.as_object().cloned().unwrap_or_default());
        Value::Object(base)
    };
    vec![
        tool("list_children", "List children", "The families and children you can log for, with each family's time zone.", json!({}), &[], true, false),
        tool(
            "get_summary",
            "Get summary",
            "What's happening now for a child: the last feed, sleep, diaper and pump (and how long ago), running timers, \
             today's totals, the last 24 hours and when the next medicine dose is allowed.",
            json!({ "child": child_prop() }),
            &[],
            true,
            false,
        ),
        tool(
            "list_entries",
            "List entries",
            "A child's latest entries, newest first.",
            json!({
                "child": child_prop(),
                "types": { "type": "string", "description": "Only these types, comma-separated (feed, sleep, diaper, pump, growth, health, activity, milestone, note)." },
                "from": time_prop("Only entries starting at or after this time"),
                "to": time_prop("Only entries starting before this time"),
                "limit": { "type": "integer", "minimum": 1, "maximum": 200, "description": "How many (default 20)." },
            }),
            &[],
            true,
            false,
        ),
        tool(
            "log_entry",
            "Log an entry",
            "Log something that happened (for something still going on, prefer start_timer). Fields by type: \
             feed: method (breast, bottle, combo, solids, required), amount_ml, milk (breast_milk, formula, mixed; bottle or combo only), \
             left_seconds, right_seconds, start_side (left, right), formula_name, foods (solids). \
             sleep: location (e.g. crib, stroller), with start and end. \
             diaper: wet, dirty, dry, rash, blowout (booleans), color (yellow, green, brown, black, red, gray), \
             consistency (runny, mushy, mucousy, pebbles, solid), potty (sat_dry, success, accident; a potty trip, wet/dirty = pee/poo). \
             pump: left_ml, right_ml, left_seconds, right_seconds. growth: weight_g, length_cm, head_cm. \
             health: kind (medicine, temperature, vaccine, appointment, symptom, required), name, dose, dose_unit, temperature_c. \
             activity: kind (e.g. bath, tummy_time, outdoor, play, read). milestone: name. note: just the note.",
            json!({
                "child": child_prop(),
                "type": { "type": "string", "enum": ["feed", "sleep", "diaper", "pump", "growth", "health", "activity", "milestone", "note"] },
                "start": time_prop("When it started (default now)"),
                "end": time_prop("When it ended (feeds, sleep, pumping)"),
                "note": { "type": "string" },
                "method": { "type": "string", "enum": ["breast", "bottle", "combo", "solids"] },
                "amount_ml": { "type": "number" },
                "milk": { "type": "string", "enum": ["breast_milk", "formula", "mixed"] },
                "left_seconds": { "type": "integer" },
                "right_seconds": { "type": "integer" },
                "start_side": { "type": "string", "enum": ["left", "right"] },
                "foods": { "type": "string" },
                "location": { "type": "string" },
                "wet": { "type": "boolean" },
                "dirty": { "type": "boolean" },
                "dry": { "type": "boolean" },
                "potty": { "type": "string", "enum": ["sat_dry", "success", "accident"] },
                "left_ml": { "type": "number" },
                "right_ml": { "type": "number" },
                "weight_g": { "type": "number" },
                "length_cm": { "type": "number" },
                "head_cm": { "type": "number" },
                "kind": { "type": "string", "description": "health: medicine, temperature, vaccine, appointment, symptom. activity: e.g. bath, tummy_time." },
                "name": { "type": "string", "description": "health or milestone name." },
                "dose": { "type": "number" },
                "dose_unit": { "type": "string" },
                "temperature_c": { "type": "number" },
            }),
            &["type"],
            false,
            false,
        ),
        tool(
            "update_entry",
            "Change an entry",
            "Change fields of an entry (its id from list_entries or get_summary). Send only what changes; null clears a field.",
            json!({
                "id": { "type": "string" },
                "changes": { "type": "object", "description": "Fields to change, as in log_entry (e.g. {\"amount_ml\": 150} or {\"end\": \"now\"})." },
            }),
            &["id", "changes"],
            false,
            false,
        ),
        tool("delete_entry", "Delete an entry", "Delete an entry by its id.", json!({ "id": { "type": "string" } }), &["id"], false, true),
        tool(
            "start_timer",
            "Start a timer",
            "Start a live timer that shows on everyone's phone: breastfeed (one side at a time), pump or sleep.",
            json!({
                "child": child_prop(),
                "kind": { "type": "string", "enum": ["breastfeed", "pump", "sleep"] },
                "side": { "type": "string", "enum": ["left", "right", "both"], "description": "Breastfeed: left or right (default left). Pump: default both." },
                "start": time_prop("When it started, if earlier (default now)"),
            }),
            &["kind"],
            false,
            false,
        ),
        tool(
            "stop_timer",
            "Stop a timer",
            "Stop a running timer and save it as an entry.",
            with(
                timer_target(),
                json!({
                    "end": time_prop("When it ended, if earlier (default now)"),
                    "note": { "type": "string" },
                    "left_ml": { "type": "number", "description": "Pump: amount from the left side." },
                    "right_ml": { "type": "number", "description": "Pump: amount from the right side." },
                    "location": { "type": "string", "description": "Sleep: where (e.g. crib)." },
                }),
            ),
            &[],
            false,
            false,
        ),
        tool(
            "control_timer",
            "Control a timer",
            "pause, resume, switch (breastfeed: change sides), adjust (correct start or durations) or discard (delete without saving) a running timer.",
            with(
                timer_target(),
                json!({
                    "action": { "type": "string", "enum": ["pause", "resume", "switch", "adjust", "discard"] },
                    "side": { "type": "string", "enum": ["left", "right", "both"], "description": "resume or switch: the side to go on with." },
                    "start": time_prop("adjust: the corrected start"),
                    "left_seconds": { "type": "integer", "description": "adjust (breastfeed): time on the left." },
                    "right_seconds": { "type": "integer", "description": "adjust (breastfeed): time on the right." },
                    "seconds": { "type": "integer", "description": "adjust (sleep, pump): total time." },
                }),
            ),
            &["action"],
            false,
            true,
        ),
        tool(
            "get_trends",
            "Get trends",
            "Daily stats for a child over the last days (feeds, sleep by day and night, diapers, pumping), with averages and the period before.",
            json!({
                "child": child_prop(),
                "days": { "type": "integer", "minimum": 1, "maximum": 90, "description": "Default 7." },
                "to": { "type": "string", "description": "Last day (YYYY-MM-DD), default today." },
            }),
            &[],
            true,
            false,
        ),
    ]
}
