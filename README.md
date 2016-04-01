# ヨコウン倉庫管理 (Yokoun Warehouse Web App)

Phase 1 implementation of the *Detailed Design Document v0.1* (Oct 28, 2026).
**Ruby on Rails 8** · **Hotwire (Turbo + Stimulus) + Tailwind + TypeScript (esbuild)** · **PostgreSQL**

> This code was written without being able to run Ruby, a database or a browser in the authoring environment.
> It has **not been executed or tested yet**. Expect a first round of small fixes. Step 4 below runs the test suite,
> which is the quickest way to find them.

## 1. Requirements (Ubuntu)
```bash
sudo apt install -y build-essential git curl libssl-dev libreadline-dev zlib1g-dev libyaml-dev libffi-dev \
  libgmp-dev libpq-dev postgresql postgresql-contrib libvips
sudo -u postgres createuser -s $USER
# Ruby 3.3+ and Node LTS (e.g. via mise), then:  corepack enable
```

## 2. Create the app
```bash
unzip yokoun-wms.zip && cd yokoun-wms
./setup.sh wms        # rails new + overlay + migrations + seeds (prints the admin password)
cd wms && bin/dev     # http://localhost:3000
```
`setup.sh` runs `rails new` (PostgreSQL, esbuild, Tailwind), `bin/rails generate authentication`, installs
`rails-i18n csv roo` and TypeScript, copies `overlay/` on top, re-stamps the migrations, sets time zone `Tokyo`
and locale `ja`, then runs `db:create db:migrate db:seed`.

## 3. First login
Seeds create `admin@example.com` (or `$ADMIN_EMAIL`) with a random password printed once (or `$ADMIN_PASSWORD`).
Then: create real sites, zones (with alert limits), locations, customers, users (ユーザー menu).

## 4. Tests and type check
```bash
bin/rails test        # ledger, receiving, shipping, excursion detection/exposure, CSV import, permissions, request flow
yarn typecheck        # tsc --noEmit (esbuild strips types without checking them)
```

## 5. Design document → code map
| Design doc | Where |
