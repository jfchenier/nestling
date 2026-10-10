//! CSV export in the same layout as the CSV export `nara_csv` imports: one row per record, a
//! `Profile` row per child, the same column names and units with their `… Unit` columns. Data
//! that layout has no column for (pumping, combo feeds, doses, vaccines, sleep location,
//! notes…) goes in extra columns named the same way, which `nara_csv` reads back, so an export
//! re-imports without losing anything.

use std::collections::HashMap;

use chrono::TimeZone;
use chrono_tz::Tz;

use crate::model::*;

/// Columns, in order. The first block matches the format we import; the second is ours.
pub const COLUMNS: &[&str] = &[
    "Type",
    "Profile Name",
    "Start Date/time",
    "Start Date/time (Epoch)",
    "Created By Caregiver",
    "Last Updated By Caregiver",
    "Note",
    "Time Zone",
    "[Breastfeed] Begin Side",
    "[Breastfeed] End Side",
    "[Breastfeed] Left Duration (Seconds)",
    "[Breastfeed] Right Duration (Seconds)",
    "[Bottle Feed] Type",
    "[Bottle Feed] Breast Milk Volume",
    "[Bottle Feed] Breast Milk Volume Unit",
    "[Bottle Feed] Formula Name",
    "[Bottle Feed] Formula Volume",
    "[Bottle Feed] Formula Volume Unit",
    "[Bottle Feed] Volume",
    "[Bottle Feed] Volume Unit",
    "[Diaper] Type",
    "[Diaper] Detail",
    "[Diaper] Dirty Color",
    "[Diaper] Dirty Texture",
    "[Medical] Medication",
    "[Medical] Temperature",
    "[Medical] Temperature Unit",
    "[Sleep] Duration (Seconds)",
    "[Sleep] End Date/time",
    "[Sleep] End Date/time (Epoch)",
    "[Growth] Head Size",
    "[Growth] Head Size Unit",
    "[Growth] Height",
    "[Growth] Height Unit",
    "[Growth] Weight",
    "[Growth] Weight Unit",
    "[Routine] Routine",
    "[Profile] Birth Date",
    "[Profile] Birth Date (Adjusted)",
    "[Profile] Sex",
    "[Profile] Type",
    // Nestling's own columns.
    "[Solids] Food",
    "[Diaper] Potty",
    "[Sleep] Location",
    "[Pump] Left Volume",
    "[Pump] Left Volume Unit",
    "[Pump] Right Volume",
    "[Pump] Right Volume Unit",
    "[Pump] Left Duration (Seconds)",
    "[Pump] Right Duration (Seconds)",
    "[Medical] Dose",
    "[Medical] Dose Unit",
    "[Medical] Vaccine",
    "[Medical] Symptom",
    "[Medical] Appointment",
    "[Milestone] Milestone",
    "[Milestone] Tooth",
    "End Date/time",
    "End Date/time (Epoch)",
    "_familyKey",
    "_profileKey",
    "_activityKey",
];

pub struct ExportChild {
    pub id: String,
    pub name: String,
    pub birth_date: Option<String>,
    pub sex: Option<String>,
}

pub struct ExportEvent {
    pub id: String,
    pub child_id: String,
    pub start_at: i64,
    pub end_at: Option<i64>,
    pub details: Details,
    pub note: Option<String>,
    pub created_by: Option<String>,
    pub updated_by: Option<String>,
    /// Id in the system it was imported from (kept as `_activityKey` so re-imports match).
    pub source_id: Option<String>,
}

/// `120.0` → `120`, `3.25` → `3.25`.
fn num(v: f64) -> String {
    let s = format!("{v:.3}");
    s.trim_end_matches('0').trim_end_matches('.').to_string()
}

fn side(s: Side) -> &'static str {
    match s {
        Side::Left => "LEFT",
        Side::Right => "RIGHT",
        Side::Both => "BOTH",
    }
}

/// `tummy_time` → `Tummy time`.
fn label(kind: &str) -> String {
    let s = kind.replace('_', " ");
    let mut c = s.chars();
    c.next().map(|f| f.to_uppercase().collect::<String>() + c.as_str()).unwrap_or_default()
}

struct Row(HashMap<&'static str, String>);

impl Row {
    fn set(&mut self, col: &'static str, v: impl Into<String>) {
        debug_assert!(COLUMNS.contains(&col), "unknown column {col}");
        let v = v.into();
        if !v.is_empty() {
            self.0.insert(col, v);
        }
    }
    fn opt<T: ToString>(&mut self, col: &'static str, v: Option<T>) {
        if let Some(v) = v {
            self.set(col, v.to_string());
        }
    }
    fn qty(&mut self, col: &'static str, unit_col: &'static str, v: Option<f64>, unit: &str) {
        if let Some(v) = v {
            self.set(col, num(v));
            self.set(unit_col, unit);
        }
    }
    fn cells(&self) -> Vec<&str> {
        COLUMNS.iter().map(|c| self.0.get(c).map(String::as_str).unwrap_or("")).collect()
    }
}

/// The whole family as CSV (UTF-8 with a BOM so spreadsheet apps read accents right).
pub fn write(family_id: &str, tz: Tz, children: &[ExportChild], events: &[ExportEvent], names: &HashMap<String, String>) -> String {
    let local = |ms: i64| tz.timestamp_millis_opt(ms).single().map(|t| t.format("%Y-%m-%d %H:%M:%S").to_string()).unwrap_or_default();
    let child_names: HashMap<&str, &str> = children.iter().map(|c| (c.id.as_str(), c.name.as_str())).collect();
    let mut w = csv::WriterBuilder::new().quote_style(csv::QuoteStyle::Always).from_writer(vec![]);
    w.write_record(COLUMNS).expect("in-memory write");

    for c in children {
        let mut r = Row(HashMap::new());
        r.set("Type", "Profile");
        r.set("Profile Name", c.name.clone());
        r.opt("[Profile] Birth Date", c.birth_date.as_ref());
        r.opt("[Profile] Sex", c.sex.as_ref().map(|s| s.to_uppercase()));
        r.set("_familyKey", family_id);
        r.set("_profileKey", c.id.clone());
        w.write_record(r.cells()).expect("in-memory write");
    }

    for e in events {
        let mut r = Row(HashMap::new());
        r.set("Profile Name", child_names.get(e.child_id.as_str()).copied().unwrap_or(""));
        r.set("Start Date/time", local(e.start_at));
        r.set("Start Date/time (Epoch)", e.start_at.to_string());
        r.opt("Created By Caregiver", e.created_by.as_ref().and_then(|u| names.get(u)));
        r.opt("Last Updated By Caregiver", e.updated_by.as_ref().and_then(|u| names.get(u)));
        r.opt("Note", e.note.as_ref());
        r.set("Time Zone", tz.name());
        r.set("_familyKey", family_id);
        r.set("_profileKey", e.child_id.clone());
        r.set("_activityKey", e.source_id.clone().unwrap_or_else(|| e.id.clone()));
        // Exact end of every record (the type columns only imply some of them).
        if let Some(end) = e.end_at {
            r.set("End Date/time", local(end));
            r.set("End Date/time (Epoch)", end.to_string());
        }

        match &e.details {
            Details::Feed(f) => {
                let breast = matches!(f.method, FeedMethod::Breast | FeedMethod::Combo);
                let bottle = matches!(f.method, FeedMethod::Bottle | FeedMethod::Combo);
                r.set(
                    "Type",
                    match f.method {
                        FeedMethod::Breast => "Breastfeed",
                        FeedMethod::Bottle => "Bottle Feed",
                        FeedMethod::Combo => "Combo Feed",
                        FeedMethod::Solids => "Solids",
                    },
                );
                if breast {
                    r.opt("[Breastfeed] Begin Side", f.start_side.map(side));
                    let (l, rt) = (f.left_seconds.unwrap_or(0), f.right_seconds.unwrap_or(0));
                    let end_side = match (l > 0, rt > 0, f.start_side) {
                        (true, true, Some(Side::Left)) => Some("RIGHT"),
                        (true, true, Some(Side::Right)) => Some("LEFT"),
                        (true, false, _) => Some("LEFT"),
                        (false, true, _) => Some("RIGHT"),
                        _ => None,
                    };
                    r.opt("[Breastfeed] End Side", end_side);
                    r.opt("[Breastfeed] Left Duration (Seconds)", f.left_seconds);
                    r.opt("[Breastfeed] Right Duration (Seconds)", f.right_seconds);
                }
                if bottle {
                    match f.milk {
                        Some(Milk::BreastMilk) => {
                            r.set("[Bottle Feed] Type", "Breast Milk");
                            r.qty("[Bottle Feed] Breast Milk Volume", "[Bottle Feed] Breast Milk Volume Unit", f.amount_ml, "ML");
                        }
                        Some(Milk::Formula) => {
                            r.set("[Bottle Feed] Type", "Formula");
                            r.qty("[Bottle Feed] Formula Volume", "[Bottle Feed] Formula Volume Unit", f.amount_ml, "ML");
                        }
                        Some(Milk::Mixed) => {
                            r.set("[Bottle Feed] Type", "Breast Milk and Formula");
                            r.qty("[Bottle Feed] Volume", "[Bottle Feed] Volume Unit", f.amount_ml, "ML");
                        }
                        None => r.qty("[Bottle Feed] Volume", "[Bottle Feed] Volume Unit", f.amount_ml, "ML"),
                    }
                    r.opt("[Bottle Feed] Formula Name", f.formula_name.as_ref());
                }
                r.opt("[Solids] Food", f.foods.as_ref());
            }
            Details::Sleep(s) => {
                r.set("Type", "Sleep");
                if let Some(end) = e.end_at {
                    r.set("[Sleep] Duration (Seconds)", ((end - e.start_at) / 1000).to_string());
                    r.set("[Sleep] End Date/time", local(end));
                    r.set("[Sleep] End Date/time (Epoch)", end.to_string());
                }
                r.opt("[Sleep] Location", s.location.as_ref());
            }
            Details::Diaper(d) => {
                r.set("Type", "Diaper");
                let kinds: Vec<&str> = [(d.dirty, "Dirty"), (d.wet, "Wet"), (d.dry, "Dry")].into_iter().filter(|(on, _)| *on).map(|(_, k)| k).collect();
                r.set("[Diaper] Type", kinds.join(" "));
                let details: Vec<&str> = [(d.blowout, "Blowout"), (d.rash, "Rash")].into_iter().filter(|(on, _)| *on).map(|(_, k)| k).collect();
                r.set("[Diaper] Detail", details.join(" "));
                r.opt("[Diaper] Dirty Color", d.color.map(|c| format!("{c:?}").to_uppercase()));
                r.opt("[Diaper] Dirty Texture", d.consistency.map(|c| format!("{c:?}").to_uppercase()));
                r.opt(
                    "[Diaper] Potty",
                    d.potty.map(|p| match p {
                        Potty::SatDry => "Sat but dry",
                        Potty::Success => "Potty",
                        Potty::Accident => "Accident",
                    }),
                );
            }
            Details::Pump(p) => {
                r.set("Type", "Pump");
                r.qty("[Pump] Left Volume", "[Pump] Left Volume Unit", p.left_ml, "ML");
                r.qty("[Pump] Right Volume", "[Pump] Right Volume Unit", p.right_ml, "ML");
                r.opt("[Pump] Left Duration (Seconds)", p.left_seconds);
                r.opt("[Pump] Right Duration (Seconds)", p.right_seconds);
            }
            Details::Growth(g) => {
                r.set("Type", "Growth");
                r.qty("[Growth] Weight", "[Growth] Weight Unit", g.weight_g.map(|g| g / 1000.0), "KG");
                r.qty("[Growth] Height", "[Growth] Height Unit", g.length_cm, "CM");
                r.qty("[Growth] Head Size", "[Growth] Head Size Unit", g.head_cm, "CM");
            }
            Details::Health(h) => {
                r.set("Type", "Medical");
                let name = h.name.clone().unwrap_or_default();
                match h.kind {
                    HealthKind::Medicine => {
                        r.set("[Medical] Medication", name);
                        r.opt("[Medical] Dose", h.dose.map(num));
                        r.opt("[Medical] Dose Unit", h.dose_unit.as_ref());
                    }
                    HealthKind::Temperature => r.qty("[Medical] Temperature", "[Medical] Temperature Unit", h.temperature_c, "C"),
                    HealthKind::Vaccine => r.set("[Medical] Vaccine", name),
                    HealthKind::Symptom => r.set("[Medical] Symptom", name),
                    HealthKind::Appointment => r.set("[Medical] Appointment", name),
                }
            }
            Details::Activity(a) => {
                r.set("Type", "Routine");
                r.set("[Routine] Routine", label(&a.kind));
            }
            Details::Milestone(m) => {
                r.set("Type", "Milestone");
                r.set("[Milestone] Milestone", m.name.clone());
                if let Some(t) = &m.tooth {
                    r.set("[Milestone] Tooth", t.clone());
                }
            }
            Details::Note(_) => r.set("Type", "Note"),
        }
        w.write_record(r.cells()).expect("in-memory write");
    }
    let body = String::from_utf8(w.into_inner().expect("in-memory write")).expect("UTF-8 input");
    format!("\u{feff}{body}")
}
