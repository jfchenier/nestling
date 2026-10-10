//! Event types. All quantities use metric units (mL, g, cm, °C, seconds);
//! clients convert for display based on the user's `units` preference.

use serde::{Deserialize, Serialize};

use crate::error::{bad, AppResult};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Side {
    Left,
    Right,
    Both,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum FeedMethod {
    Breast,
    Bottle,
    /// Breast + bottle supplement in one session.
    Combo,
    Solids,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Milk {
    BreastMilk,
    Formula,
    Mixed,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum PoopColor {
    Yellow,
    Green,
    Brown,
    Black,
    Red,
    Gray,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum PoopConsistency {
    Runny,
    Mushy,
    Mucousy,
    Pebbles,
    Solid,
}

/// Potty training: what happened on a trip to the potty.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Potty {
    /// Sat on the potty, nothing came.
    SatDry,
    /// Peed and/or pooped in the potty.
    Success,
    /// Peed and/or pooped outside the potty.
    Accident,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum HealthKind {
    Medicine,
    Temperature,
    Vaccine,
    Appointment,
    Symptom,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Feed {
    pub method: FeedMethod,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub left_seconds: Option<u32>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub right_seconds: Option<u32>,
    /// Side the breastfeed started on.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub start_side: Option<Side>,
    /// Bottle amount in millilitres.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub amount_ml: Option<f64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub milk: Option<Milk>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub formula_name: Option<String>,
    /// What was eaten (solids).
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub foods: Option<String>,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct Sleep {
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub location: Option<String>,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct Diaper {
    #[serde(default)]
    pub wet: bool,
    #[serde(default)]
    pub dirty: bool,
    #[serde(default)]
    pub dry: bool,
    #[serde(default)]
    pub rash: bool,
    #[serde(default)]
    pub blowout: bool,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub color: Option<PoopColor>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub consistency: Option<PoopConsistency>,
    /// Set for a potty entry (the same card and form as diapers); `wet`/`dirty` are then
    /// pee/poo and `dry` goes with `sat_dry`.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub potty: Option<Potty>,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct Pump {
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub left_ml: Option<f64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub right_ml: Option<f64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub left_seconds: Option<u32>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub right_seconds: Option<u32>,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct Growth {
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub weight_g: Option<f64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub length_cm: Option<f64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub head_cm: Option<f64>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Health {
    pub kind: HealthKind,
    /// Medicine, vaccine, doctor or symptom name.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub name: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub dose: Option<f64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub dose_unit: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub temperature_c: Option<f64>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Activity {
    /// e.g. bath, tummy_time, outdoor, play, read, nail_trim, vitamin
    pub kind: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Milestone {
    pub name: String,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct NoteDetails {}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum Details {
    Feed(Feed),
    Sleep(Sleep),
    Diaper(Diaper),
    Pump(Pump),
    Growth(Growth),
    Health(Health),
    Activity(Activity),
    Milestone(Milestone),
    Note(NoteDetails),
}

pub const EVENT_TYPES: [&str; 9] = [
    "feed", "sleep", "diaper", "pump", "growth", "health", "activity", "milestone", "note",
];

fn non_negative(field: &str, v: Option<f64>, max: f64) -> AppResult<()> {
    match v {
        Some(x) if !x.is_finite() || x < 0.0 => bad(format!("{field} must be a positive number")),
        Some(x) if x > max => bad(format!("{field} looks too large ({x})")),
        _ => Ok(()),
    }
}

fn not_blank(field: &str, v: &Option<String>) -> AppResult<()> {
    match v {
        Some(s) if !s.trim().is_empty() => Ok(()),
        _ => bad(format!("{field} is required")),
    }
}

impl Details {
    pub fn type_name(&self) -> &'static str {
        match self {
            Details::Feed(_) => "feed",
            Details::Sleep(_) => "sleep",
            Details::Diaper(_) => "diaper",
            Details::Pump(_) => "pump",
            Details::Growth(_) => "growth",
            Details::Health(_) => "health",
            Details::Activity(_) => "activity",
            Details::Milestone(_) => "milestone",
            Details::Note(_) => "note",
        }
    }

    pub fn validate(&self, start: i64, end: Option<i64>, note: &Option<String>) -> AppResult<()> {
        if let Some(end) = end {
            if end < start {
                return bad("end must be after start");
            }
            if end - start > 7 * 24 * 3600 * 1000 {
                return bad("an event cannot last more than 7 days");
            }
        }
        match self {
            Details::Feed(f) => {
                non_negative("amount_ml", f.amount_ml, 2000.0)?;
                if f.milk.is_some() && matches!(f.method, FeedMethod::Breast | FeedMethod::Solids) {
                    return bad("milk only applies to bottle or combo feeds");
                }
                if f.start_side == Some(Side::Both) {
                    return bad("start_side must be left or right");
                }
            }
            Details::Sleep(_) => {
                if end.is_none() {
                    return bad("sleep needs an end time (use a sleep timer for a nap in progress)");
                }
            }
            Details::Diaper(d) => {
                if !(d.wet || d.dirty || d.dry) {
                    return bad("a diaper must be wet, dirty or dry");
                }
                if (d.color.is_some() || d.consistency.is_some()) && !d.dirty {
                    return bad("color and consistency only apply to dirty diapers");
                }
                match d.potty {
                    Some(Potty::SatDry) if d.wet || d.dirty => return bad("sat_dry cannot be wet or dirty"),
                    Some(Potty::Success | Potty::Accident) if !(d.wet || d.dirty) => {
                        return bad("a potty success or accident must be wet (pee) or dirty (poo)")
                    }
                    Some(_) if d.blowout => return bad("blowout only applies to diapers"),
                    _ => {}
                }
            }
            Details::Pump(p) => {
                non_negative("left_ml", p.left_ml, 1000.0)?;
                non_negative("right_ml", p.right_ml, 1000.0)?;
            }
            Details::Growth(g) => {
                if g.weight_g.is_none() && g.length_cm.is_none() && g.head_cm.is_none() {
                    return bad("growth needs weight_g, length_cm or head_cm");
                }
                non_negative("weight_g", g.weight_g, 50_000.0)?;
                non_negative("length_cm", g.length_cm, 200.0)?;
                non_negative("head_cm", g.head_cm, 80.0)?;
            }
            Details::Health(h) => match h.kind {
                HealthKind::Temperature => match h.temperature_c {
                    Some(t) if (25.0..=45.0).contains(&t) => {}
                    Some(t) => return bad(format!("temperature_c {t} is out of range (25-45 °C)")),
                    None => return bad("temperature_c is required"),
                },
                HealthKind::Medicine | HealthKind::Vaccine | HealthKind::Symptom => {
                    not_blank("name", &h.name)?;
                    non_negative("dose", h.dose, 10_000.0)?;
                }
                HealthKind::Appointment => {}
            },
            Details::Activity(a) => not_blank("kind", &Some(a.kind.clone()))?,
            Details::Milestone(m) => not_blank("name", &Some(m.name.clone()))?,
            Details::Note(_) => not_blank("note", note)?,
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn roundtrip_tagged() {
        let d: Details = serde_json::from_value(json!({
            "type": "feed", "method": "bottle", "amount_ml": 120, "milk": "formula"
        }))
        .unwrap();
        assert_eq!(d.type_name(), "feed");
        let v = serde_json::to_value(&d).unwrap();
        assert_eq!(v["amount_ml"], json!(120.0));
        assert_eq!(v["type"], "feed");
    }

    #[test]
    fn validation() {
        let d: Details = serde_json::from_value(json!({"type": "diaper"})).unwrap();
        assert!(d.validate(0, None, &None).is_err());
        let d: Details = serde_json::from_value(json!({"type": "sleep"})).unwrap();
        assert!(d.validate(0, None, &None).is_err());
        assert!(d.validate(0, Some(1000), &None).is_ok());
        assert!(d.validate(1000, Some(0), &None).is_err());
    }

    #[test]
    fn potty() {
        let v = |j| serde_json::from_value::<Details>(j).unwrap().validate(0, None, &None);
        assert!(v(json!({"type": "diaper", "potty": "sat_dry", "dry": true})).is_ok());
        assert!(v(json!({"type": "diaper", "potty": "sat_dry", "wet": true})).is_err());
        assert!(v(json!({"type": "diaper", "potty": "success", "dirty": true, "color": "brown"})).is_ok());
        assert!(v(json!({"type": "diaper", "potty": "accident", "dry": true})).is_err());
        assert!(v(json!({"type": "diaper", "potty": "accident", "wet": true, "blowout": true})).is_err());
    }
}
