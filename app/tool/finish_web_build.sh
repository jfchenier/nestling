#!/bin/sh
# Run after `flutter build web`. Flutter's file names don't change between releases, so give
# flutter_bootstrap.js a per-build URL in index.html (index.html itself is never cached);
# the bootstrap then loads main.dart.js?v=<build>. Also replace Flutter's deprecated service
# worker with one that removes itself.
set -eu
cd "$(dirname "$0")/.."
web=build/web
version=$(sha256sum "$web/flutter_bootstrap.js" | cut -c1-12)
sed -i "s|src=\"flutter_bootstrap.js\"|src=\"flutter_bootstrap.js?v=$version\"|" "$web/index.html"
grep -q "flutter_bootstrap.js?v=$version" "$web/index.html"
cp web/kill_service_worker.js "$web/flutter_service_worker.js"
echo "web build $version"
