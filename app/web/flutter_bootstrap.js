{{flutter_js}}
{{flutter_build_config}}

// File names stay the same between releases (main.dart.js…), so ask for this build's copy
// explicitly; otherwise a browser or proxy cache can keep serving the previous app.
const buildVersion = {{flutter_service_worker_version}};
for (const build of _flutter.buildConfig.builds) {
  if (build.mainJsPath) build.mainJsPath += "?v=" + buildVersion;
}

// No service worker: remove the one older versions installed (it served cached app files).
if ("serviceWorker" in navigator) {
  navigator.serviceWorker.getRegistrations().then((regs) => regs.forEach((r) => r.unregister()));
}

// tool/finish_web_build.sh moves assets/ and canvaskit/ into v/<hash>/ and fills this in, so a new
// release never mixes in an old cached icon font or engine.
const assetVersion = "__ASSET_VERSION__";
const versioned = !assetVersion.startsWith("__");
_flutter.loader.load({
  config: versioned ? { assetBase: `v/${assetVersion}/`, canvasKitBaseUrl: `v/${assetVersion}/canvaskit/` } : {},
});
