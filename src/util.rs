use chrono::{DateTime, NaiveDateTime, SecondsFormat, TimeZone};
use chrono_tz::Tz;
use rand::Rng;
use sha2::{Digest, Sha256};

use crate::error::{bad, AppResult};

pub fn now_ms() -> i64 {
    chrono::Utc::now().timestamp_millis()
}

pub fn new_id() -> String {
    uuid::Uuid::now_v7().to_string()
}

/// 32 random bytes, hex encoded.
pub fn random_token() -> String {
    let bytes: [u8; 32] = rand::thread_rng().gen();
    hex::encode(bytes)
}

/// Short human-friendly code (no ambiguous characters) for family invites.
pub fn invite_code() -> String {
    const ALPHABET: &[u8] = b"ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    let mut rng = rand::thread_rng();
    (0..8)
        .map(|_| ALPHABET[rng.gen_range(0..ALPHABET.len())] as char)
        .collect()
}

pub fn sha256_hex(s: &str) -> String {
    hex::encode(Sha256::digest(s.as_bytes()))
}

pub fn parse_tz(s: &str) -> AppResult<Tz> {
    s.parse::<Tz>()
        .or_else(|_| bad(format!("unknown timezone '{s}' (use an IANA name like 'America/New_York')")))
}

/// Parse a user-supplied time. Accepts:
/// - "now"
/// - RFC 3339 with offset: "2026-10-08T11:30:00-04:00" or "...Z"
/// - local time without offset, interpreted in the family's timezone: "2026-10-08T11:30"
pub fn parse_time(s: &str, tz: Tz) -> AppResult<i64> {
    let s = s.trim();
    if s.eq_ignore_ascii_case("now") {
        return Ok(now_ms());
    }
    if let Ok(dt) = DateTime::parse_from_rfc3339(s) {
        return Ok(dt.timestamp_millis());
    }
    const FORMATS: [&str; 6] = [
        "%Y-%m-%dT%H:%M:%S%.f",
        "%Y-%m-%dT%H:%M:%S",
        "%Y-%m-%dT%H:%M",
        "%Y-%m-%d %H:%M:%S%.f",
        "%Y-%m-%d %H:%M:%S",
        "%Y-%m-%d %H:%M",
    ];
    for fmt in FORMATS {
        if let Ok(naive) = NaiveDateTime::parse_from_str(s, fmt) {
            return match tz.from_local_datetime(&naive).earliest() {
                Some(dt) => Ok(dt.timestamp_millis()),
                None => bad(format!("'{s}' does not exist in timezone {tz}")),
            };
        }
    }
    bad(format!(
        "invalid time '{s}' (use 'now', '2026-10-08T11:30' or '2026-10-08T11:30:00-04:00')"
    ))
}

pub fn parse_opt_time(s: &Option<String>, tz: Tz) -> AppResult<Option<i64>> {
    match s {
        Some(s) => parse_time(s, tz).map(Some),
        None => Ok(None),
    }
}

/// Format epoch ms as RFC 3339 in the given timezone, e.g. "2026-10-08T11:30:00-04:00".
/// RFC 3339 in UTC, for times that belong to no family (accounts, tokens).
pub fn fmt_utc(ms: i64) -> String {
    fmt_time(ms, chrono_tz::UTC)
}

pub fn fmt_time(ms: i64, tz: Tz) -> String {
    match tz.timestamp_millis_opt(ms).single() {
        Some(dt) => dt.to_rfc3339_opts(SecondsFormat::Secs, true),
        None => String::new(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_times() {
        let tz: Tz = "America/New_York".parse().unwrap();
        let a = parse_time("2026-10-08T11:30:00-04:00", tz).unwrap();
        let b = parse_time("2026-10-08T11:30", tz).unwrap();
        let c = parse_time("2026-10-08 15:30:00Z".replace(' ', "T").as_str(), tz).unwrap();
        assert_eq!(a, b);
        assert_eq!(a, c);
        assert_eq!(fmt_time(a, tz), "2026-10-08T11:30:00-04:00");
        assert!(parse_time("yesterday", tz).is_err());
    }
}
