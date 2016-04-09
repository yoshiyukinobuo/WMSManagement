#!/usr/bin/env bash
# Yokoun WMS bootstrap: generates a fresh Rails app, then layers the WMS code on top.
# Usage: ./setup.sh [app_name]      (default app name: wms)
set -euo pipefail

APP_NAME="${1:-wms}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

need() { command -v "$1" >/dev/null 2>&1 || { echo "ERROR: '$1' not found. Install it first (see README)."; exit 1; }; }
need ruby; need node; need yarn; need git

gem list -i rails >/dev/null 2>&1 || gem install rails
rails new "$APP_NAME" --database=postgresql --javascript=esbuild --css=tailwind
cd "$APP_NAME"

bundle add rails-i18n csv roo

# Rails 8 built-in authentication (User, Session, SessionsController, PasswordsController)
bin/rails generate authentication
ls db/migrate | grep -q active_storage || bin/rails active_storage:install

# TypeScript instead of plain JS entrypoints
rm -f app/javascript/application.js app/javascript/controllers/index.js \
      app/javascript/controllers/application.js app/javascript/controllers/hello_controller.js

# WMS code (everything except migrations)
tar -C "$HERE/overlay" --exclude='./db/migrate' -cf - . | tar -xf -

# Migrations: re-stamp so they sort after the generator's migrations
ts=$(date -u -d '+1 minute' +%Y%m%d%H%M%S)
for f in "$HERE"/overlay/db/migrate/*.rb; do
  name=$(basename "$f" | sed -E 's/^[0-9]+_//')
  cp "$f" "db/migrate/${ts}_${name}"
  ts=$((ts + 1))
done

# Japan defaults: time zone and locale
sed -i '/config.load_defaults/a\    config.time_zone = "Tokyo"\n    config.i18n.default_locale = :ja\n    config.i18n.available_locales = [:ja, :en]' config/application.rb

# TypeScript tooling
yarn add --dev typescript
node -e "const fs=require('fs');const p=JSON.parse(fs.readFileSync('package.json'));p.scripts=p.scripts||{};p.scripts.typecheck='tsc --noEmit';fs.writeFileSync('package.json',JSON.stringify(p,null,2)+'\n')"

set +e
bin/rails db:create db:migrate db:seed || echo "NOTE: DB step failed. Start PostgreSQL, then run: bin/rails db:create db:migrate db:seed"
echo
echo "Done. cd $APP_NAME && bin/dev   then open http://localhost:3000"
