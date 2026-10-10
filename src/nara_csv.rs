//! Nara Baby CSV export ("Export data" in the Nara app) converted to events. Also reads
//! Nestling's own export (`csv_export`), which adds a few columns in the same style.
//! The app has a Dart port for serverless mode (`app/lib/local/nara_csv.dart`); keep the two in step.
//!
//! One row per record. Common columns: `Type`, `Profile Name`, `Start Date/time (Epoch)` (ms),
//! `Note`, `Time Zone`, `_profileKey`, `_activityKey` (the same `t-…` key as the live API, so
//! importing both ways matches up). Type-specific columns are prefixed with `[<Type>] `, e.g.
//! `[Breastfeed] Left Duration (Seconds)`, `[Bottle Feed] Breast Milk Volume` + `… Unit`.
//! A `Profile` row carries the child's birth date and sex.

use std::collections::{BTreeMap, HashMap};

use chrono::{NaiveDate, NaiveDateTime, TimeZone};
use serde_json::{Map, Value};

use crate::{model::*, nara::Converted};

/// A Nara child profile found in the export.
#[derive(Debug, Clone, Default, PartialEq)]
pub struct Profile {
    pub name: Option<String>,
    pub birth_date: Option<NaiveDate>,
    /// `female` / `male` / `other`.
    pub sex: Option<String>,
}

#[derive(Debug, Default)]
pub struct CsvImport {
    /// Converted records with the original row (kept in the event's `raw` column).
    pub records: Vec<(Converted, Value)>,
    /// Reason → count.
    pub skipped: BTreeMap<String, u32>,
    /// Nara profile key → profile.
    pub profiles: HashMap<String, Profile>,
    pub rows: usize,
}

struct Row<'a> {
    cols: &'a HashMap<String, usize>,
    rec: &'a csv::StringRecord,
}

impl Row<'_> {
    fn get(&self, col: &str) -> Option<&str> {
        self.cols.get(col).and_then(|&i| self.rec.get(i)).map(str::trim).filter(|v| !v.is_empty())
    }
    fn num(&self, col: &str) -> Option<f64> {
        self.get(col).and_then(|v| v.replace(',', ".").parse::<f64>().ok()).filter(|v| v.is_finite())
    }
    fn secs(&self, col: &str) -> Option<u32> {
        self.num(col).filter(|v| *v > 0.0).map(|v| v.round() as u32)
    }
    /// `<col>` with its `<col> Unit` sibling (e.g. `[Growth] Weight` + `[Growth] Weight Unit`).
    fn qty(&self, col: &str) -> Option<(f64, String)> {
        let v = self.num(col).filter(|v| *v > 0.0)?;
        Some((v, self.get(&format!("{col} Unit")).unwrap_or("").to_uppercase()))
    }
    fn has_column(&self, col: &str) -> bool {
        self.cols.contains_key(col)
    }
    fn json(&self, headers: &csv::StringRecord) -> Value {
        let mut m = Map::new();
        for (h, v) in headers.iter().zip(self.rec.iter()) {
            if !v.is_empty() {
                m.insert(h.to_string(), Value::String(v.to_string()));
            }
        }
        Value::Object(m)
    }
}

fn round(x: f64, places: i32) -> f64 {
    let f = 10f64.powi(places);
    (x * f).round() / f
}

fn to_ml((v, unit): (f64, String)) -> f64 {
    match unit.as_str() {
        "OZ" | "FLOZ" | "FL OZ" | "FL. OZ" => round(v * 29.5735, 1),
        "L" => round(v * 1000.0, 1),
        _ => round(v, 1),
    }
}

fn to_g((v, unit): (f64, String)) -> f64 {
    match unit.as_str() {
        "KG" => round(v * 1000.0, 1),
        "LB" | "LBS" => round(v * 453.592, 1),
        "OZ" => round(v * 28.3495, 1),
        _ => round(v, 1),
    }
}

fn to_cm((v, unit): (f64, String)) -> f64 {
    match unit.as_str() {
        "IN" | "INCH" | "INCHES" => round(v * 2.54, 2),
        "MM" => round(v / 10.0, 2),
        _ => round(v, 2),
    }
}

fn to_c((v, unit): (f64, String)) -> f64 {
    if unit.starts_with('F') { round((v - 32.0) * 5.0 / 9.0, 2) } else { round(v, 2) }
}

fn side(v: Option<&str>) -> Option<Side> {
    // End sides can carry a suffix, e.g. "LEFT.nonTimer".
    match v?.split('.').next()?.to_uppercase().as_str() {
        "LEFT" | "L" => Some(Side::Left),
        "RIGHT" | "R" => Some(Side::Right),
        _ => None,
    }
}

fn color(v: Option<&str>) -> Option<PoopColor> {
    match v?.to_uppercase().as_str() {
        "YELLOW" | "MUSTARD" => Some(PoopColor::Yellow),
        "GREEN" => Some(PoopColor::Green),
        "BROWN" | "TAN" => Some(PoopColor::Brown),
        "BLACK" => Some(PoopColor::Black),
        "RED" => Some(PoopColor::Red),
        "GRAY" | "GREY" | "WHITE" => Some(PoopColor::Gray),
        _ => None,
    }
}

fn consistency(v: Option<&str>) -> Option<PoopConsistency> {
    let v = v?.to_uppercase();
    if v.starts_with("RUN") || v.starts_with("WATER") {
        Some(PoopConsistency::Runny)
    } else if v.starts_with("MUSH") || v.starts_with("SOFT") {
        Some(PoopConsistency::Mushy)
    } else if v.starts_with("MUC") {
        Some(PoopConsistency::Mucousy)
    } else if v.starts_with("PEBBLE") || v.starts_with("HARD") {
        Some(PoopConsistency::Pebbles)
    } else if v.starts_with("SOLID") || v.starts_with("FIRM") {
        Some(PoopConsistency::Solid)
    } else {
        None
    }
}

/// Nestling's own `[Diaper] Potty` column (see `csv_export.rs`).
fn potty(v: &str) -> Option<Potty> {
    let v = v.to_lowercase();
    if v.contains("accident") {
        Some(Potty::Accident)
    } else if v.contains("dry") {
        Some(Potty::SatDry)
    } else if v.contains("potty") || v.contains("success") {
        Some(Potty::Success)
    } else {
        None
    }
}

/// `Tummy time` → `tummy_time`.
fn activity_kind(v: &str) -> String {
    let s: String = v
        .trim()
        .to_lowercase()
        .chars()
        .map(|c| if c.is_alphanumeric() { c } else { '_' })
        .collect();
    let s = s.split('_').filter(|p| !p.is_empty()).collect::<Vec<_>>().join("_");
    if s.is_empty() { "activity".into() } else { s }
}

/// Epoch ms column, or the local date/time column read in the row's time zone.
fn time(row: &Row, epoch_col: &str, local_col: &str) -> Option<i64> {
    if let Some(ms) = row.num(epoch_col) {
        return Some(ms as i64);
    }
    let local = NaiveDateTime::parse_from_str(row.get(local_col)?, "%Y-%m-%d %H:%M:%S").ok()?;
    let tz: chrono_tz::Tz = row.get("Time Zone").and_then(|t| t.parse().ok()).unwrap_or(chrono_tz::UTC);
    tz.from_local_datetime(&local).earliest().map(|t| t.timestamp_millis())
}

/// Bottle volume (mL) and milk type from the `[Bottle Feed]` columns.
fn bottle_amount(row: &Row) -> (Option<f64>, Option<Milk>) {
    let breast = row.qty("[Bottle Feed] Breast Milk Volume").map(to_ml);
    let formula = row.qty("[Bottle Feed] Formula Volume").map(to_ml);
    let total = row.qty("[Bottle Feed] Volume").map(to_ml);
    let kind = row.get("[Bottle Feed] Type").unwrap_or("").to_lowercase();
    let milk = match (breast.is_some(), formula.is_some()) {
        (true, true) => Some(Milk::Mixed),
        (true, false) => Some(Milk::BreastMilk),
        (false, true) => Some(Milk::Formula),
        _ if kind.contains("breast") && kind.contains("formula") => Some(Milk::Mixed),
        _ if kind.contains("breast") => Some(Milk::BreastMilk),
        _ if kind.contains("formula") => Some(Milk::Formula),
        _ => None,
    };
    let amount = match (breast, formula) {
        (None, None) => total,
        (b, f) => Some(round(b.unwrap_or(0.0) + f.unwrap_or(0.0), 1)),
    };
    (amount, milk)
}

/// One row → one or more records (a medical row with a medicine and a temperature gives two).
fn convert_row(row: &Row) -> Result<Vec<(String, Details, i64, Option<i64>)>, String> {
    let ty = row.get("Type").ok_or("missing Type")?;
    let start = time(row, "Start Date/time (Epoch)", "Start Date/time").ok_or("missing start time")?;
    let id = row.get("_activityKey").ok_or("missing _activityKey")?.to_string();
    let one = |d: Details, end: Option<i64>| Ok(vec![(id.clone(), d, start, end)]);

    match ty.to_lowercase().as_str() {
        "breastfeed" => {
            let left = row.secs("[Breastfeed] Left Duration (Seconds)");
            let right = row.secs("[Breastfeed] Right Duration (Seconds)");
            let total = left.unwrap_or(0) + right.unwrap_or(0);
            let end = (total > 0).then(|| start + total as i64 * 1000);
            one(
                Details::Feed(Feed {
                    method: FeedMethod::Breast,
                    left_seconds: left,
                    right_seconds: right,
                    start_side: side(row.get("[Breastfeed] Begin Side")),
                    amount_ml: None,
                    milk: None,
                    formula_name: None,
                    foods: None,
                }),
                end,
            )
        }
        "combo feed" => {
            // Nestling's own export: a breastfeed with a bottle top-up in one row.
            let left = row.secs("[Breastfeed] Left Duration (Seconds)");
            let right = row.secs("[Breastfeed] Right Duration (Seconds)");
            let total = left.unwrap_or(0) + right.unwrap_or(0);
            let (amount, milk) = bottle_amount(row);
            one(
                Details::Feed(Feed {
                    method: FeedMethod::Combo,
                    left_seconds: left,
                    right_seconds: right,
                    start_side: side(row.get("[Breastfeed] Begin Side")),
                    amount_ml: amount,
                    milk,
                    formula_name: row.get("[Bottle Feed] Formula Name").map(String::from),
                    foods: None,
                }),
                (total > 0).then(|| start + total as i64 * 1000),
            )
        }
        "bottle feed" => {
            let (amount, milk) = bottle_amount(row);
            one(
                Details::Feed(Feed {
                    method: FeedMethod::Bottle,
                    left_seconds: None,
                    right_seconds: None,
                    start_side: None,
                    amount_ml: amount,
                    milk,
                    formula_name: row.get("[Bottle Feed] Formula Name").map(String::from),
                    foods: None,
                }),
                None,
            )
        }
        "solids" | "solid" | "solid food" => one(
            Details::Feed(Feed {
                method: FeedMethod::Solids,
                left_seconds: None,
                right_seconds: None,
                start_side: None,
                amount_ml: None,
                milk: None,
                formula_name: None,
                foods: row.get("[Solids] Food").or(row.get("[Solids] Foods")).map(String::from),
            }),
            None,
        ),
        "diaper" => {
            let kind = row.get("[Diaper] Type").unwrap_or("").to_lowercase();
            let detail = row.get("[Diaper] Detail").unwrap_or("").to_lowercase();
            let dirty = kind.contains("dirty") || kind.contains("poo");
            let potty = row.get("[Diaper] Potty").and_then(potty);
            let d = Diaper {
                wet: kind.contains("wet") || kind.contains("pee"),
                dirty,
                dry: kind.contains("dry"),
                rash: detail.contains("rash"),
                blowout: dirty && detail.contains("blowout"),
                color: if dirty { color(row.get("[Diaper] Dirty Color")) } else { None },
                consistency: if dirty { consistency(row.get("[Diaper] Dirty Texture")) } else { None },
                potty,
            };
            if !(d.wet || d.dirty || d.dry) {
                return Err("empty diaper".into());
            }
            one(Details::Diaper(d), None)
        }
        "sleep" => {
            let end = time(row, "[Sleep] End Date/time (Epoch)", "[Sleep] End Date/time")
                .or_else(|| row.secs("[Sleep] Duration (Seconds)").map(|s| start + s as i64 * 1000))
                .filter(|e| *e >= start)
                .ok_or("sleep without an end")?;
            one(Details::Sleep(Sleep { location: row.get("[Sleep] Location").map(String::from) }), Some(end))
        }
        "growth" => {
            let g = Growth {
                weight_g: row.qty("[Growth] Weight").map(to_g),
                length_cm: row.qty("[Growth] Height").map(to_cm),
                head_cm: row.qty("[Growth] Head Size").map(to_cm),
            };
            if g.weight_g.is_none() && g.length_cm.is_none() && g.head_cm.is_none() {
                return Err("empty growth".into());
            }
            one(Details::Growth(g), None)
        }
        "medical" => {
            let mut out = Vec::new();
            if let Some(meds) = row.get("[Medical] Medication") {
                // Several medicines can share a cell, one per line.
                let name = meds.lines().map(str::trim).filter(|l| !l.is_empty()).collect::<Vec<_>>().join(", ");
                out.push((
                    id.clone(),
                    Details::Health(Health {
                        kind: HealthKind::Medicine,
                        name: Some(name),
                        dose: row.num("[Medical] Dose").filter(|d| *d > 0.0),
                        dose_unit: row.get("[Medical] Dose Unit").map(String::from),
                        temperature_c: None,
                    }),
                    start,
                    None,
                ));
            }
            if let Some(t) = row.qty("[Medical] Temperature").map(to_c) {
                // Keep the plain key for the first record so re-imports match.
                let key = if out.is_empty() { id.clone() } else { format!("{id}#temperature") };
                out.push((
                    key,
                    Details::Health(Health { kind: HealthKind::Temperature, name: None, dose: None, dose_unit: None, temperature_c: Some(t) }),
                    start,
                    None,
                ));
            }
            // Nestling's own columns.
            for (col, kind, suffix) in [
                ("[Medical] Vaccine", HealthKind::Vaccine, "vaccine"),
                ("[Medical] Symptom", HealthKind::Symptom, "symptom"),
                ("[Medical] Appointment", HealthKind::Appointment, "appointment"),
            ] {
                if let Some(name) = row.get(col) {
                    let key = if out.is_empty() { id.clone() } else { format!("{id}#{suffix}") };
                    out.push((
                        key,
                        Details::Health(Health { kind, name: Some(name.to_string()), dose: None, dose_unit: None, temperature_c: None }),
                        start,
                        None,
                    ));
                }
            }
            if out.is_empty() {
                return Err("empty medical record".into());
            }
            Ok(out)
        }
        "pump" => {
            let p = Pump {
                left_ml: row.qty("[Pump] Left Volume").map(to_ml),
                right_ml: row.qty("[Pump] Right Volume").map(to_ml),
                left_seconds: row.secs("[Pump] Left Duration (Seconds)"),
                right_seconds: row.secs("[Pump] Right Duration (Seconds)"),
            };
            let secs = p.left_seconds.unwrap_or(0).max(p.right_seconds.unwrap_or(0));
            one(Details::Pump(p), (secs > 0).then(|| start + secs as i64 * 1000))
        }
        "note" => {
            row.get("Note").ok_or("empty note")?;
            one(Details::Note(NoteDetails {}), None)
        }
        "routine" | "activity" => one(
            Details::Activity(Activity { kind: activity_kind(row.get("[Routine] Routine").unwrap_or("")) }),
            None,
        ),
        "milestone" | "baby first" | "baby firsts" => {
            let name = row.get("[Milestone] Milestone").or(row.get("[Baby First] Name")).or(row.get("Note")).ok_or("milestone without a name")?;
            one(Details::Milestone(Milestone { name: name.to_string() }), None)
        }
        other => Err(format!("unsupported type: {other}")),
    }
}

/// Parse a Nara CSV export.
pub fn parse(text: &str) -> Result<CsvImport, String> {
    let text = text.strip_prefix('\u{feff}').unwrap_or(text);
    let mut rdr = csv::ReaderBuilder::new().flexible(true).from_reader(text.as_bytes());
    let headers = rdr.headers().map_err(|e| format!("not a CSV file: {e}"))?.clone();
    let cols: HashMap<String, usize> = headers.iter().enumerate().map(|(i, h)| (h.trim().to_string(), i)).collect();
    if !cols.contains_key("Type") || !cols.contains_key("_activityKey") {
        return Err("this doesn't look like a Nara export (expected \"Type\" and \"_activityKey\" columns)".into());
    }

    let mut out = CsvImport::default();
    for rec in rdr.records() {
        let rec = rec.map_err(|e| format!("CSV error: {e}"))?;
        out.rows += 1;
        let row = Row { cols: &cols, rec: &rec };
        let profile_key = row.get("_profileKey").map(String::from);
        if let (Some(key), Some(name)) = (&profile_key, row.get("Profile Name")) {
            out.profiles.entry(key.clone()).or_default().name.get_or_insert_with(|| name.to_string());
        }
        if row.get("Type").is_some_and(|t| t.eq_ignore_ascii_case("profile")) {
            if let Some(key) = profile_key {
                let p = out.profiles.entry(key).or_default();
                p.birth_date = row.get("[Profile] Birth Date").and_then(|d| NaiveDate::parse_from_str(d, "%Y-%m-%d").ok());
                p.sex = row.get("[Profile] Sex").map(|s| match s.to_uppercase().as_str() {
                    "FEMALE" | "F" | "GIRL" => "female".to_string(),
                    "MALE" | "M" | "BOY" => "male".to_string(),
                    _ => "other".to_string(),
                });
            }
            continue;
        }
        match convert_row(&row) {
            Ok(mut items) => {
                // Nestling's export states every end exactly (none included); trust it over
                // the end implied by durations.
                if row.has_column("End Date/time (Epoch)") {
                    let end = time(&row, "End Date/time (Epoch)", "End Date/time");
                    for item in &mut items {
                        if !matches!(item.1, Details::Sleep(_)) || end.is_some() {
                            item.3 = end;
                        }
                    }
                }
                let raw = row.json(&headers);
                for (source_id, details, start_at, end_at) in items {
                    out.records.push((
                        Converted { source_id, child_key: profile_key.clone(), start_at, end_at, note: row.get("Note").map(String::from), details },
                        raw.clone(),
                    ));
                }
            }
            Err(reason) => *out.skipped.entry(reason).or_default() += 1,
        }
    }

    // A record without a profile key belongs to the only child when there is just one.
    if out.profiles.len() == 1 {
        let key = out.profiles.keys().next().cloned();
        for (c, _) in &mut out.records {
            if c.child_key.is_none() {
                c.child_key = key.clone();
            }
        }
    }
    Ok(out)
}

#[cfg(test)]
mod tests {
    use super::*;

    // Same header as a real export; rows are made-up data.
    const HEADER: &str = "\"Type\",\"Profile Name\",\"Start Date/time\",\"Start Date/time (Epoch)\",\"Created By Caregiver\",\"Last Updated By Caregiver\",\"Note\",\"Time Zone\",\"[Breastfeed] Begin Side\",\"[Breastfeed] End Side\",\"[Breastfeed] Left Duration (Seconds)\",\"[Breastfeed] Right Duration (Seconds)\",\"[Bottle Feed] Type\",\"[Bottle Feed] Breast Milk Volume\",\"[Bottle Feed] Breast Milk Volume Unit\",\"[Bottle Feed] Formula Name\",\"[Bottle Feed] Formula Volume\",\"[Bottle Feed] Formula Volume Unit\",\"[Bottle Feed] Volume\",\"[Bottle Feed] Volume Unit\",\"[Diaper] Type\",\"[Diaper] Detail\",\"[Diaper] Dirty Color\",\"[Diaper] Dirty Texture\",\"[Medical] Medication\",\"[Medical] Temperature\",\"[Medical] Temperature Unit\",\"[Sleep] Duration (Seconds)\",\"[Sleep] End Date/time\",\"[Sleep] End Date/time (Epoch)\",\"[Growth] Head Size\",\"[Growth] Head Size Unit\",\"[Growth] Height\",\"[Growth] Height Unit\",\"[Growth] Weight\",\"[Growth] Weight Unit\",\"[Routine] Routine\",\"[Profile] Birth Date\",\"[Profile] Birth Date (Adjusted)\",\"[Profile] Sex\",\"[Profile] Type\",\"_familyKey\",\"_profileKey\",\"_activityKey\"";

    /// A CSV line with the given columns set (quoted like Nara does), everything else empty.
    fn line(cells: &[(&str, &str)]) -> String {
        let mut rdr = csv::Reader::from_reader(HEADER.as_bytes());
        let headers = rdr.headers().unwrap().clone();
        headers
            .iter()
            .map(|h| match cells.iter().find(|(k, _)| *k == h) {
                Some((_, v)) => format!("\"{}\"", v.replace('"', "\"\"")),
                None => String::new(),
            })
            .collect::<Vec<_>>()
            .join(",")
    }

    fn sample() -> String {
        let common = |ty: &'static str, epoch: &'static str, key: &'static str| {
            vec![("Type", ty), ("Profile Name", "Mia"), ("Start Date/time (Epoch)", epoch), ("Time Zone", "America/Toronto"), ("_familyKey", "f-1"), ("_profileKey", "c-1"), ("_activityKey", key)]
        };
        let with = |mut base: Vec<(&'static str, &'static str)>, extra: &[(&'static str, &'static str)]| {
            base.extend_from_slice(extra);
            line(&base)
        };
        let rows = [
            with(common("Breastfeed", "1791412200000", "t-bf"), &[("[Breastfeed] Begin Side", "LEFT"), ("[Breastfeed] End Side", "RIGHT.nonTimer"), ("[Breastfeed] Left Duration (Seconds)", "600"), ("[Breastfeed] Right Duration (Seconds)", "300")]),
            with(common("Bottle Feed", "1791388800000", "t-bottle"), &[("[Bottle Feed] Type", "Breast Milk"), ("[Bottle Feed] Breast Milk Volume", "60"), ("[Bottle Feed] Breast Milk Volume Unit", "ML")]),
            with(common("Bottle Feed", "1787881500000", "t-bottle2"), &[("[Bottle Feed] Volume", "2"), ("[Bottle Feed] Volume Unit", "OZ")]),
            with(common("Diaper", "1782994839301", "t-diaper"), &[("Note", "Big one"), ("[Diaper] Type", "Dirty Wet"), ("[Diaper] Detail", "Blowout"), ("[Diaper] Dirty Color", "YELLOW"), ("[Diaper] Dirty Texture", "RUN")]),
            with(common("Medical", "1788717700000", "t-med"), &[("[Medical] Medication", "Drops A\nDrops B"), ("[Medical] Temperature", "101.3"), ("[Medical] Temperature Unit", "F")]),
            with(common("Medical", "1785868380000", "t-empty"), &[]),
            with(common("Sleep", "1783353600000", "t-sleep"), &[("Time Zone", "US/Eastern"), ("[Sleep] Duration (Seconds)", "3000"), ("[Sleep] End Date/time (Epoch)", "1783356600000")]),
            with(common("Growth", "1785816000000", "t-growth"), &[("[Growth] Head Size", "38"), ("[Growth] Head Size Unit", "CM"), ("[Growth] Height", "56"), ("[Growth] Height Unit", "CM"), ("[Growth] Weight", "4.55"), ("[Growth] Weight Unit", "KG")]),
            with(common("Routine", "1783606440000", "t-routine"), &[("[Routine] Routine", "Tummy time")]),
            line(&[("Type", "Breastfeed"), ("Profile Name", "Mia"), ("Start Date/time (Epoch)", "1782428432492"), ("[Breastfeed] Begin Side", "LEFT"), ("[Breastfeed] Left Duration (Seconds)", "1581"), ("[Breastfeed] Right Duration (Seconds)", "0"), ("_activityKey", "t-noprofile")]),
            line(&[("Type", "Profile"), ("Profile Name", "Mia"), ("[Profile] Birth Date", "2026-05-30"), ("[Profile] Sex", "FEMALE"), ("[Profile] Type", "CHILD"), ("_profileKey", "c-1")]),
            with(common("Pump", "1783606440000", "t-pump"), &[]),
        ];
        format!("\u{feff}{HEADER}\n{}\n", rows.join("\n"))
    }

    fn find<'a>(r: &'a CsvImport, id: &str) -> &'a Converted {
        &r.records.iter().find(|(c, _)| c.source_id == id).unwrap_or_else(|| panic!("{id} missing")).0
    }

    #[test]
    fn parses_every_type() {
        let r = parse(&sample()).unwrap();
        assert_eq!(r.rows, 12);
        assert_eq!(r.profiles["c-1"], Profile { name: Some("Mia".into()), birth_date: NaiveDate::from_ymd_opt(2026, 5, 30), sex: Some("female".into()) });

        let bf = find(&r, "t-bf");
        let Details::Feed(f) = &bf.details else { panic!() };
        assert_eq!((f.left_seconds, f.right_seconds, f.start_side), (Some(600), Some(300), Some(Side::Left)));
        assert_eq!(bf.end_at, Some(1791412200000 + 900_000));

        let Details::Feed(b) = &find(&r, "t-bottle").details else { panic!() };
        assert_eq!((b.method, b.amount_ml, b.milk), (FeedMethod::Bottle, Some(60.0), Some(Milk::BreastMilk)));
        let Details::Feed(b2) = &find(&r, "t-bottle2").details else { panic!() };
        assert_eq!((b2.amount_ml, b2.milk), (Some(59.1), None));

        let d = find(&r, "t-diaper");
        let Details::Diaper(dd) = &d.details else { panic!() };
        assert!(dd.wet && dd.dirty && dd.blowout && !dd.rash);
        assert_eq!((dd.color, dd.consistency), (Some(PoopColor::Yellow), Some(PoopConsistency::Runny)));
        assert_eq!(d.note.as_deref(), Some("Big one"));
        assert_eq!(d.start_at, 1782994839301);

        let Details::Health(med) = &find(&r, "t-med").details else { panic!() };
        assert_eq!((med.kind, med.name.as_deref()), (HealthKind::Medicine, Some("Drops A, Drops B")));
        let Details::Health(temp) = &find(&r, "t-med#temperature").details else { panic!() };
        assert_eq!(temp.temperature_c, Some(38.5));

        assert_eq!(find(&r, "t-sleep").end_at, Some(1783356600000));
        let Details::Growth(g) = &find(&r, "t-growth").details else { panic!() };
        assert_eq!((g.weight_g, g.length_cm, g.head_cm), (Some(4550.0), Some(56.0), Some(38.0)));
        let Details::Activity(a) = &find(&r, "t-routine").details else { panic!() };
        assert_eq!(a.kind, "tummy_time");

        // No profile key, but only one child in the export.
        assert_eq!(find(&r, "t-noprofile").child_key.as_deref(), Some("c-1"));

        assert_eq!(r.skipped.get("empty medical record"), Some(&1));
        // Pump rows are read too (amounts and durations come from Nestling's own export).
        assert!(matches!(find(&r, "t-pump").details, Details::Pump(_)));
        assert_eq!(r.records.len(), 11);
    }

    #[test]
    fn falls_back_to_local_time() {
        let csv = "Type,Start Date/time,Time Zone,[Diaper] Type,_activityKey\nDiaper,2026-07-06 12:00:00,US/Eastern,Wet,t-1\n";
        let r = parse(csv).unwrap();
        assert_eq!(r.records[0].0.start_at, 1783353600000);
    }

    #[test]
    fn rejects_other_csv() {
        assert!(parse("a,b\n1,2\n").is_err());
    }

    /// `NARA_CSV=/path/to/export.csv cargo test real_export -- --ignored --nocapture`
    #[test]
    #[ignore]
    fn real_export() {
        let path = std::env::var("NARA_CSV").expect("set NARA_CSV");
        let r = parse(&std::fs::read_to_string(path).unwrap()).unwrap();
        let mut by_type: BTreeMap<&str, u32> = BTreeMap::new();
        for (c, _) in &r.records {
            *by_type.entry(c.details.type_name()).or_default() += 1;
        }
        let invalid = r.records.iter().filter(|(c, _)| c.details.validate(c.start_at, c.end_at, &c.note).is_err()).count();
        println!("rows {} records {} by_type {by_type:?} skipped {:?} profiles {:?} invalid {invalid}", r.rows, r.records.len(), r.skipped, r.profiles);
    }
}
