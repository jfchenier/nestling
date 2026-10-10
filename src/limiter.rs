//! Brakes on password guessing: failed sign-ins are counted per account and per client address
//! over a sliding window, kept in memory (a restart forgets them).

use std::{
    collections::{HashMap, VecDeque},
    net::{IpAddr, SocketAddr},
    sync::Mutex,
};

use axum::{extract::ConnectInfo, http::HeaderMap};

use crate::error::{AppError, AppResult};

const WINDOW_MS: i64 = 15 * 60 * 1000;
/// Failed sign-ins on one account before it is locked for the rest of the window.
pub const PER_ACCOUNT: usize = 5;
/// Failed sign-ins (and sign-ups) from one address before it is locked.
pub const PER_ADDRESS: usize = 20;
/// Above this many keys, keys with nothing recent are forgotten.
const MAX_KEYS: usize = 10_000;

#[derive(Default)]
pub struct Limiter {
    hits: Mutex<HashMap<String, VecDeque<i64>>>,
}

impl Limiter {
    /// Fails with 429 when `key` already reached `max` hits in the window.
    pub fn check(&self, key: &str, max: usize, now: i64) -> AppResult<()> {
        let mut hits = self.hits.lock().unwrap();
        let Some(q) = hits.get_mut(key) else { return Ok(()) };
        while q.front().is_some_and(|&t| t <= now - WINDOW_MS) {
            q.pop_front();
        }
        match q.front() {
            Some(&oldest) if q.len() >= max => {
                let minutes = (oldest + WINDOW_MS - now + 59_999) / 60_000;
                Err(AppError::TooManyRequests(format!(
                    "too many attempts: try again in {minutes} minute{}",
                    if minutes == 1 { "" } else { "s" }
                )))
            }
            _ => Ok(()),
        }
    }

    pub fn hit(&self, key: &str, now: i64) {
        let mut hits = self.hits.lock().unwrap();
        if hits.len() >= MAX_KEYS {
            hits.retain(|_, q| q.back().is_some_and(|&t| t > now - WINDOW_MS));
        }
        hits.entry(key.to_string()).or_default().push_back(now);
    }

    pub fn clear(&self, key: &str) {
        self.hits.lock().unwrap().remove(key);
    }
}

/// The client's address: the one a reverse proxy reports (`X-Real-IP`, else the last
/// `X-Forwarded-For` entry, which the proxy appended), else the connection's.
pub fn client_addr(headers: &HeaderMap, conn: Option<&ConnectInfo<SocketAddr>>) -> String {
    let header = |name: &str| headers.get(name).and_then(|v| v.to_str().ok());
    let proxied = header("x-real-ip")
        .or_else(|| header("x-forwarded-for").and_then(|v| v.rsplit(',').next()))
        .and_then(|v| v.trim().parse::<IpAddr>().ok());
    match (proxied, conn) {
        (Some(ip), _) => ip.to_string(),
        (None, Some(ConnectInfo(addr))) => addr.ip().to_string(),
        (None, None) => "unknown".into(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn locks_after_max_and_unlocks_after_window() {
        let l = Limiter::default();
        for i in 0..3 {
            l.check("k", 3, i).unwrap();
            l.hit("k", i);
        }
        assert!(matches!(l.check("k", 3, 10), Err(AppError::TooManyRequests(_))));
        l.check("other", 3, 10).unwrap();
        // The first hit leaves the window: one more try.
        l.check("k", 3, WINDOW_MS).unwrap();
        l.clear("k");
        l.check("k", 1, 10).unwrap();
    }

    #[test]
    fn reads_proxy_headers() {
        let mut h = HeaderMap::new();
        assert_eq!(client_addr(&h, None), "unknown");
        h.insert("x-forwarded-for", "1.2.3.4, 10.0.0.2".parse().unwrap());
        assert_eq!(client_addr(&h, None), "10.0.0.2");
        h.insert("x-real-ip", "5.6.7.8".parse().unwrap());
        assert_eq!(client_addr(&h, None), "5.6.7.8");
    }
}
