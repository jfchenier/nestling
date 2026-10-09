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

_flutter.loader.load();
