//! Nara Baby import: logs in to Nara's Firebase backend (same flow as
//! github.com/jfchenier/nara-baby-tracker-api) and converts its "tracks" into events.
//!
//! Nara stores quantities as `<field>Num` / `<field>Exp` / `<field>Unit`, meaning
//! value = Num / 10^Exp in Unit (e.g. bottleVolumeNum=45, Exp=1, Unit=FLOZ -> 4.5 fl oz).

use serde_json::{json, Map, Value};

use crate::{
    error::{AppError, AppResult},
    model::*,
    state::NaraConfig,
};

pub struct NaraSession {
    pub id_token: String,
    pub family_key: String,
}

pub async fn login(cfg: &NaraConfig, email: &str, password: &str) -> AppResult<NaraSession> {
    let http = reqwest::Client::new();
    let res = http
        .post(format!("{}?key={}", cfg.auth_url, cfg.api_key))
        .json(&json!({ "email": email, "password": password, "returnSecureToken": true }))
        .send()
        .await
        .map_err(|e| AppError::Upstream(format!("could not reach Nara: {e}")))?;
    if !res.status().is_success() {
        let body: Value = res.json().await.unwrap_or(Value::Null);
        let reason = body["error"]["message"].as_str().unwrap_or("unknown error").to_string();
        return Err(AppError::BadRequest(format!("Nara login failed: {reason}")));
    }
    let auth: Value = res.json().await.map_err(|e| AppError::Upstream(e.to_string()))?;
    let id_token = auth["idToken"].as_str().unwrap_or_default().to_string();
    let uid = auth["localId"].as_str().unwrap_or_default().to_string();

    let fams: Value = http
        .get(format!("{}/userz/{}/familyKeyz.json", cfg.db_url, uid))
        .query(&[("auth", &id_token)])
        .send()
        .await
        .and_then(|r| r.error_for_status())
        .map_err(|e| AppError::Upstream(format!("could not read Nara family: {e}")))?
        .json()
        .await
        .map_err(|e| AppError::Upstream(e.to_string()))?;
    let family_key = fams
        .as_object()
        .and_then(|m| m.keys().next().cloned())
        .ok_or_else(|| AppError::Upstream("no family found on this Nara account".into()))?;
    Ok(NaraSession { id_token, family_key })
}

/// Fetch every track of the family (keyed by Nara track id).
pub async fn fetch_tracks(cfg: &NaraConfig, session: &NaraSession) -> AppResult<Map<String, Value>> {
    let res: Value = reqwest::Client::new()
        .post(&cfg.functions_url)
        .bearer_auth(&session.id_token)
        .json(&json!({ "data": { "action": "/family/trackz/sync2", "familyKey": session.family_key, "prevSyncKey": null } }))
        .send()
        .await
        .and_then(|r| r.error_for_status())
        .map_err(|e| AppError::Upstream(format!("could not download Nara data: {e}")))?
        .json()
        .await
        .map_err(|e| AppError::Upstream(e.to_string()))?;
    match &res["result"]["data"]["trackz"] {
        Value::Object(m) => Ok(m.clone()),
        Value::Null => Ok(Map::new()),
        _ => Err(AppError::Upstream("unexpected response from Nara".into())),
    }
}

/// A Nara track converted to our model.
#[derive(Debug)]
pub struct Converted {
    pub source_id: String,
    pub child_key: Option<String>,
    pub start_at: i64,
    pub end_at: Option<i64>,
    pub note: Option<String>,
    pub details: Details,
}

fn num(v: &Value, key: &str) -> Option<f64> {
    v.get(key).and_then(|x| x.as_f64())
}

fn s<'a>(v: &'a Value, key: &str) -> Option<&'a str> {
    v.get(key).and_then(|x| x.as_str()).filter(|x| !x.trim().is_empty())
}

fn flag(v: &Value, key: &str) -> bool {
    v.get(key).and_then(|x| x.as_bool()).unwrap_or(false)
}

/// Decode `<prefix>Num` / `<prefix>Exp` / `<prefix>Unit`.
fn qty(v: &Value, prefix: &str) -> Option<(f64, String)> {
    let n = num(v, &format!("{prefix}Num"))?;
    let exp = num(v, &format!("{prefix}Exp")).unwrap_or(0.0);
    let unit = s(v, &format!("{prefix}Unit")).unwrap_or("").to_uppercase();
    Some((n / 10f64.powf(exp), unit))
}

fn round(x: f64, places: i32) -> f64 {
    let f = 10f64.powi(places);
    (x * f).round() / f
}

fn volume_ml(v: &Value, prefix: &str) -> Option<f64> {
    let (x, unit) = qty(v, prefix)?;
    let ml = match unit.as_str() {
        "FLOZ" | "OZ" => x * 29.5735,
        "L" => x * 1000.0,
        _ => x, // ML (or unknown: assume metric)
    };
    Some(round(ml, 1))
}

fn weight_g(v: &Value, prefix: &str) -> Option<f64> {
    let (x, unit) = qty(v, prefix)?;
    let g = match unit.as_str() {
        "LB" => x * 453.59237,
        "OZ" => x * 28.349523,
        "KG" => x * 1000.0,
        _ => x,
    };
    Some(round(g, 0))
}

fn length_cm(v: &Value, prefix: &str) -> Option<f64> {
    let (x, unit) = qty(v, prefix)?;
    let cm = match unit.as_str() {
        "IN" => x * 2.54,
        "MM" => x / 10.0,
        "M" => x * 100.0,
        _ => x,
    };
    Some(round(cm, 1))
}

fn temp_c(v: &Value, prefix: &str) -> Option<f64> {
    let (x, unit) = qty(v, prefix)?;
    Some(round(if unit == "F" { (x - 32.0) * 5.0 / 9.0 } else { x }, 1))
}

fn side(v: &Value, key: &str) -> Option<Side> {
    match s(v, key)?.to_uppercase().as_str() {
        "LEFT" => Some(Side::Left),
        "RIGHT" => Some(Side::Right),
        _ => None,
    }
}

fn secs(v: &Value, key: &str) -> Option<u32> {
    num(v, key).map(|ms| (ms / 1000.0).round().max(0.0) as u32)
}

fn positive(x: Option<f64>) -> Option<f64> {
    x.filter(|v| *v > 0.0)
}

fn bottle_milk(v: &Value) -> Option<Milk> {
    match (flag(v, "bottleTypeBreastMilk"), flag(v, "bottleTypeFormula")) {
        (true, true) => Some(Milk::Mixed),
        (true, false) => Some(Milk::BreastMilk),
        (false, true) => Some(Milk::Formula),
        _ => None,
    }
}

fn bottle_ml(v: &Value) -> Option<f64> {
    positive(volume_ml(v, "bottleVolume")).or_else(|| {
        let bm = volume_ml(v, "bottleBreastMilkVolume").unwrap_or(0.0);
        let f = volume_ml(v, "bottleFormulaVolume").unwrap_or(0.0);
        positive(Some(round(bm + f, 1)))
    })
}

fn color(v: &Value) -> Option<PoopColor> {
    Some(match s(v, "diaperPoopColor")?.to_uppercase().as_str() {
        "YELLOW" => PoopColor::Yellow,
        "GREEN" => PoopColor::Green,
        "BROWN" => PoopColor::Brown,
        "BLACK" => PoopColor::Black,
        "RED" => PoopColor::Red,
        "GRAY" | "GREY" => PoopColor::Gray,
        _ => return None,
    })
}

fn consistency(v: &Value) -> Option<PoopConsistency> {
    Some(match s(v, "diaperPoopTexture")?.to_uppercase().as_str() {
        "RUN" | "RUNNY" => PoopConsistency::Runny,
        "MUSH" | "MUSHY" => PoopConsistency::Mushy,
        "MUCOUS" => PoopConsistency::Mucousy,
        "PEBBLE" => PoopConsistency::Pebbles,
        "SOLID" => PoopConsistency::Solid,
        _ => return None,
    })
}

/// Convert one Nara track. `Err(reason)` means it is skipped.
pub fn convert(key: &str, t: &Value) -> Result<Converted, String> {
    if flag(t, "deleted") || t.get("deleteDt").is_some_and(|d| !d.is_null()) {
        return Err("deleted".into());
    }
    let ty = s(t, "type").ok_or("missing type")?.to_uppercase();
    let start_at = num(t, "beginDt").ok_or("missing beginDt")? as i64;
    let end_at = num(t, "endDt").map(|e| e as i64).filter(|e| *e >= start_at);
    let note = s(t, "note").map(|n| n.to_string());
    let timer_running = t.get("breastLeftBeginDt").is_some_and(|x| !x.is_null())
        || t.get("breastRightBeginDt").is_some_and(|x| !x.is_null());

    let details = match ty.as_str() {
        "FEED" => {
            if timer_running {
                return Err("timer still running".into());
            }
            let method = match s(t, "feedType").unwrap_or("").to_uppercase().as_str() {
                "BREAST" => FeedMethod::Breast,
                "BOTTLE" => FeedMethod::Bottle,
                "COMBO" => FeedMethod::Combo,
                "SOLID" | "SOLIDS" => FeedMethod::Solids,
                other => return Err(format!("unknown feedType {other}")),
            };
            let has_breast = matches!(method, FeedMethod::Breast | FeedMethod::Combo);
            let has_bottle = matches!(method, FeedMethod::Bottle | FeedMethod::Combo);
            Details::Feed(Feed {
                method,
                left_seconds: if has_breast { secs(t, "breastLeftDuration") } else { None },
                right_seconds: if has_breast { secs(t, "breastRightDuration") } else { None },
                start_side: if has_breast { side(t, "breastBeginSide") } else { None },
                amount_ml: if has_bottle { bottle_ml(t) } else { None },
                milk: if has_bottle { bottle_milk(t) } else { None },
                formula_name: if has_bottle { s(t, "formulaName").map(String::from) } else { None },
                foods: None,
            })
        }
        "SLEEP" => {
            if end_at.is_none() {
                return Err("sleep still in progress".into());
            }
            Details::Sleep(Sleep::default())
        }
        "DIAPER" => {
            let dirty = flag(t, "diaperTypePoop");
            let d = Diaper {
                wet: flag(t, "diaperTypePee"),
                dirty,
                dry: flag(t, "diaperTypeDry"),
                rash: flag(t, "diaperTypeRash"),
                blowout: dirty && flag(t, "diaperPoopBlowout"),
                color: if dirty { color(t) } else { None },
                consistency: if dirty { consistency(t) } else { None },
                potty: None,
            };
            if !(d.wet || d.dirty || d.dry) {
                return Err("empty diaper".into());
            }
            Details::Diaper(d)
        }
        "PUMP" => {
            if timer_running {
                return Err("timer still running".into());
            }
            Details::Pump(Pump {
                left_ml: volume_ml(t, "breastLeftVolume"),
                right_ml: volume_ml(t, "breastRightVolume"),
                left_seconds: secs(t, "breastLeftDuration").filter(|s| *s > 0),
                right_seconds: secs(t, "breastRightDuration").filter(|s| *s > 0),
            })
        }
        "GROW" => {
            let g = Growth {
                weight_g: positive(weight_g(t, "weight")),
                length_cm: positive(length_cm(t, "height")),
                head_cm: positive(length_cm(t, "headSize")),
            };
            if g.weight_g.is_none() && g.length_cm.is_none() && g.head_cm.is_none() {
                return Err("empty growth entry".into());
            }
            Details::Growth(g)
        }
        "GROW.MILESTONE" => Details::Milestone(Milestone {
            name: s(t, "milestoneName").unwrap_or("Milestone").to_string(),
        }),
        "MEDICAL.MEDICINE" => {
            let name = s(t, "medicineName")
                .map(String::from)
                .or_else(|| t["medicinez"].as_array().and_then(|a| a.first()).and_then(|m| m["key"].as_str()).map(String::from))
                .unwrap_or_else(|| "Medicine".into());
            Details::Health(Health { kind: HealthKind::Medicine, name: Some(name), dose: None, dose_unit: None, temperature_c: None })
        }
        "MEDICAL.TEMPERATURE" => {
            let c = temp_c(t, "temperature").ok_or("missing temperature")?;
            Details::Health(Health { kind: HealthKind::Temperature, name: None, dose: None, dose_unit: None, temperature_c: Some(c) })
        }
        "MEDICAL.VACCINE" => Details::Health(Health {
            kind: HealthKind::Vaccine,
            name: Some(s(t, "vaccineName").unwrap_or("Vaccine").to_string()),
            dose: None,
            dose_unit: None,
            temperature_c: None,
        }),
        "MEDICAL.APPOINTMENT" => Details::Health(Health {
            kind: HealthKind::Appointment,
            name: s(t, "doctorName").map(String::from),
            dose: None,
            dose_unit: None,
            temperature_c: None,
        }),
        "ROUTINE" => Details::Activity(Activity {
            kind: match s(t, "routineName").unwrap_or("OTHER").to_uppercase().as_str() {
                "TUMMYTIME" => "tummy_time".into(),
                "NAILTRIM" => "nail_trim".into(),
                other => other.to_lowercase(),
            },
        }),
        "PARENT_NOTE" | "NOTE" => {
            if note.is_none() {
                return Err("empty note".into());
            }
            Details::Note(NoteDetails {})
        }
        other => return Err(format!("unsupported type {other}")),
    };
    // Solid feeds: Nara keeps the food in the note.
    let (details, note) = match details {
        Details::Feed(mut f) if f.method == FeedMethod::Solids => {
            f.foods = note.clone();
            (Details::Feed(f), note)
        }
        d => (d, note),
    };

    Ok(Converted {
        source_id: key.to_string(),
        child_key: s(t, "childKey").map(String::from),
        start_at,
        end_at: if matches!(details, Details::Diaper(_) | Details::Note(_) | Details::Milestone(_)) { None } else { end_at },
        note,
        details,
    })
}

/// Normalise uploaded data: accepts the `trackz` map, the full sync2 response,
/// or an array of tracks with a `key` field.
pub fn tracks_from_upload(v: Value) -> AppResult<Map<String, Value>> {
    let v = match v {
        Value::Object(ref m) if m.contains_key("result") => v["result"]["data"]["trackz"].clone(),
        Value::Object(ref m) if m.contains_key("trackz") => v["trackz"].clone(),
        other => other,
    };
    match v {
        Value::Object(m) => Ok(m),
        Value::Array(a) => Ok(a
            .into_iter()
            .filter_map(|t| t.get("key").and_then(|k| k.as_str()).map(|k| (k.to_string(), t.clone())))
            .collect()),
        _ => Err(AppError::BadRequest("tracks must be an object keyed by track id or an array of tracks".into())),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn converts_bottle() {
        let t = json!({"type": "FEED", "feedType": "BOTTLE", "beginDt": 1000, "bottleTypeFormula": true,
                       "bottleVolumeNum": 45, "bottleVolumeExp": 1, "bottleVolumeUnit": "FLOZ",
                       "formulaName": "Similac", "childKey": "c1"});
        let c = convert("k1", &t).unwrap();
        match c.details {
            Details::Feed(f) => {
                assert_eq!(f.method, FeedMethod::Bottle);
                assert_eq!(f.amount_ml, Some(133.1));
                assert_eq!(f.milk, Some(Milk::Formula));
                assert_eq!(f.formula_name.as_deref(), Some("Similac"));
            }
            _ => panic!(),
        }
        assert_eq!(c.child_key.as_deref(), Some("c1"));
    }

    #[test]
    fn converts_breast_and_growth_and_diaper() {
        let t = json!({"type": "FEED", "feedType": "BREAST", "beginDt": 0, "endDt": 900000,
                       "breastLeftDuration": 600000, "breastRightDuration": 300000, "breastBeginSide": "LEFT",
                       "breastLeftBeginDt": null});
        let Details::Feed(f) = convert("a", &t).unwrap().details else { panic!() };
        assert_eq!((f.left_seconds, f.right_seconds, f.start_side), (Some(600), Some(300), Some(Side::Left)));

        let t = json!({"type": "GROW", "beginDt": 0, "weightNum": 1425, "weightExp": 2, "weightUnit": "LB",
                       "heightNum": 245, "heightExp": 1, "heightUnit": "IN"});
        let Details::Growth(g) = convert("b", &t).unwrap().details else { panic!() };
        assert_eq!(g.weight_g, Some(6464.0));
        assert_eq!(g.length_cm, Some(62.2));

        let t = json!({"type": "DIAPER", "beginDt": 0, "diaperTypePee": true, "diaperTypePoop": true,
                       "diaperPoopColor": "YELLOW", "diaperPoopTexture": "MUSH"});
        let Details::Diaper(d) = convert("c", &t).unwrap().details else { panic!() };
        assert!(d.wet && d.dirty);
        assert_eq!(d.consistency, Some(PoopConsistency::Mushy));

        let t = json!({"type": "MEDICAL.TEMPERATURE", "beginDt": 0, "temperatureNum": 1012, "temperatureExp": 1, "temperatureUnit": "F"});
        let Details::Health(h) = convert("d", &t).unwrap().details else { panic!() };
        assert_eq!(h.temperature_c, Some(38.4));
    }

    #[test]
    fn skips_running_and_unknown() {
        let t = json!({"type": "SLEEP", "beginDt": 0, "endDt": null});
        assert!(convert("a", &t).is_err());
        let t = json!({"type": "FEED", "feedType": "BREAST", "beginDt": 0, "breastLeftBeginDt": 5});
        assert!(convert("b", &t).is_err());
        let t = json!({"type": "SOMETHING", "beginDt": 0});
        assert!(convert("c", &t).is_err());
    }
}
