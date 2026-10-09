#!/bin/sh
# Run after `flutter build web`. Flutter's file names don't change between releases (the icon
# font, main.dart.js…), so browsers and proxies can keep serving old copies. This gives every
# release its own URLs:
#   - assets/ and canvaskit/ move to v/<hash>/ (the bootstrap passes that as assetBase),
#   - index.html loads flutter_bootstrap.js?v=<hash> (index.html itself is never cached),
#   - the bootstrap loads main.dart.js?v=<build>.
# It also replaces Flutter's deprecated service worker with one that removes itself.
set -eu
cd "$(dirname "$0")/.."
web=build/web
assets=$(cd "$web" && find assets canvaskit -type f | sort | xargs sha256sum | sha256sum | cut -c1-12)
rm -rf "$web/v" # left over from a previous build in the same folder
mkdir -p "$web/v/$assets"
mv "$web/assets" "$web/canvaskit" "$web/v/$assets/"
sed -i "s|__ASSET_VERSION__|$assets|" "$web/flutter_bootstrap.js"
boot=$(sha256sum "$web/flutter_bootstrap.js" | cut -c1-12)
sed -i "s|src=\"flutter_bootstrap.js\"|src=\"flutter_bootstrap.js?v=$boot\"|" "$web/index.html"
grep -q "flutter_bootstrap.js?v=$boot" "$web/index.html"
cp web/kill_service_worker.js "$web/flutter_service_worker.js"
echo "web build: assets v/$assets, bootstrap $boot"
