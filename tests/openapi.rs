//! `docs/openapi.yaml` must list exactly the routes in `src/routes/mod.rs`, with the same methods.
//! (A plain text check: no YAML parser needed.)

use std::collections::BTreeSet;

const METHODS: [&str; 5] = ["get", "post", "put", "patch", "delete"];

/// `(path, method)` for every `.route(...)` in the router.
fn router_routes() -> BTreeSet<(String, String)> {
    let src = include_str!("../src/routes/mod.rs");
    let mut out = BTreeSet::new();
    for chunk in src.split(".route(").skip(1) {
        // The route's own text: up to the parenthesis that closes `.route(`.
        let mut depth = 1;
        let end = chunk
            .char_indices()
            .find(|&(_, c)| {
                match c {
                    '(' => depth += 1,
                    ')' => depth -= 1,
                    _ => {}
                }
                depth == 0
            })
            .map_or(chunk.len(), |(i, _)| i);
        let route = &chunk[..end];
        let path = route.split('"').nth(1).expect("route path");
        for m in METHODS {
            // `get(handler)` or `.get(handler)`, but not `module::get`.
            let found = route.match_indices(&format!("{m}(")).any(|(i, _)| {
                let before = route[..i].chars().last();
                matches!(before, Some(c) if !c.is_alphanumeric() && c != '_' && c != ':')
            });
            if found {
                out.insert((path.to_string(), m.to_string()));
            }
        }
    }
    out
}

/// `(path, method)` for every operation in the spec.
fn spec_routes() -> BTreeSet<(String, String)> {
    let spec = include_str!("../docs/openapi.yaml");
    let paths = spec.split("\npaths:\n").nth(1).expect("paths section");
    let paths = paths.split("\ncomponents:\n").next().unwrap();
    let mut out = BTreeSet::new();
    let mut current = None;
    for line in paths.lines() {
        if let Some(p) = line.strip_prefix("  /").and_then(|l| l.strip_suffix(':')) {
            current = Some(format!("/{p}"));
        } else if let (Some(path), Some(m)) = (&current, line.strip_prefix("    ").and_then(|l| l.strip_suffix(':'))) {
            if METHODS.contains(&m) {
                out.insert((path.clone(), m.to_string()));
            }
        }
    }
    out
}

#[test]
fn spec_matches_router() {
    let router = router_routes();
    let spec = spec_routes();
    assert!(router.len() > 40, "router parse looks wrong: {router:?}");
    let missing: Vec<_> = router.difference(&spec).collect();
    let extra: Vec<_> = spec.difference(&router).collect();
    assert!(missing.is_empty() && extra.is_empty(), "docs/openapi.yaml is out of step with src/routes/mod.rs\nnot in the spec: {missing:?}\nnot in the router: {extra:?}");
}
