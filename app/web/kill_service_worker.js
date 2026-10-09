// Replaces build/web/flutter_service_worker.js (see Dockerfile). Browsers that still run the
// service worker of an older Nestling release fetch this file to update it: it drops the old
// caches, unregisters itself and reloads open tabs so they get the current app.
self.addEventListener("install", () => self.skipWaiting());
self.addEventListener("activate", (event) => {
  event.waitUntil(
    (async () => {
      for (const key of await caches.keys()) await caches.delete(key);
      await self.registration.unregister();
      for (const client of await self.clients.matchAll({ type: "window" })) client.navigate(client.url);
    })(),
  );
});
