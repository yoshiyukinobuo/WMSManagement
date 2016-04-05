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
|---|---|
| Stock = append-only ledger, stock derived (§8) | `StockMovement` (AppendOnly), SQL view `stock_levels`, `Inventory::Ledger` (row lock per lot) |
| FR-M1..M5 master data | `MasterCrudController` + Sites/Zones/Locations/Customers/Items controllers |
| FR-R1..R6 receiving | `Receiving::AddLine`, `ReceiptLine#reconcile_sources` (3-source mismatch flag), `Inventory::Putaway` (zone check), Active Storage slip photos |
| FR-S1..S5 shipping | `Shipping::Allocate` (FIFO/FEFO via `ALLOCATION_RULE`), `Shipping::Confirm` (blocks held lots) |
| FR-I1..I5 inventory | `StockController`, `LotsController`, `MovementsController`, `Stocktakes::*` |
| FR-T1..T8 temperature (§9) | `Temperature::Detector`, `ManualEntry`, `CsvImporter`, `MissingDataCheck`, `ExposureCalculator`, `Excursions::*`, `Alerts`/`AlertMailer` |
| Key rule: exposed lots from movement history ∩ excursion window | `Temperature::ExposureCalculator` + `Temperature::Presence` |
| FR-X1..X3 reports | `ReportsController` (CSV with BOM for Excel), daily stock, zone log, print styles |
| FR-A1..A3 admin | `UsersController`, `AuditLogsController`, `Imports::StockOpening` (validate → commit → rollback by batch) |
| FR-B1 label-ready ID | `Lot#internal_id` (`YK-XXXXXXXX`, unique, generated from the first receipt) |
| §5 roles, site scoping | `Permissions`, `User#accessible_site_ids`, `Model.accessible_by(user)` |
| §11 audit | `Auditable` concern → `audit_logs` |

## 6. Decisions I made where the document says [To confirm]
- Allocation default **FIFO**, switchable with `ALLOCATION_RULE=fefo` or per order on the allocation form.
- Putaway **blocks** on temperature mismatch; supervisors/admins can override with a checkbox (audited).
- Tolerance period for door-open spikes is per zone and defaults to **0** (off).
- Alerts: **email only** (Active Mailer, `MAILER_FROM`). Configure SMTP for production.
- Zone-to-lot compatibility is exact match on type (frozen/chilled/constant/ambient). Refine after discovery.
- Excel import takes **opening stock only**, strict (any row error blocks the batch). Sheet structure is unknown, so
  header aliases (English and Japanese) are used instead of a mapping UI.

## 7. Known gaps / simplifications (please read)
- **Phase 2 (barcode/QR), processing, cross-dock, bonded cargo, cross-site dashboard: not built**, as in the document.
- `temperature_readings` is **not partitioned by month yet** (needs a composite primary key; do it once real volumes
  and retention are known). The unique index and `measured_at` indexes are in place.
- Excursion detection never rewrites a **closed** excursion. A correction that would remove a closed excursion does not
  delete it (decisions are permanent by design).
- Zones fed only by batch loggers (SD/USB) will raise missing-data alerts between uploads; raise the expected interval.
- Excursion exposure is computed per lot from movements, not per pallet.
- Import rollback uses bulk delete on purpose and is audited; it is refused if the lots were touched afterwards.
- The UI strings are Japanese only (model/enum labels use `config/locales/ja.yml`).
- Login uses the Rails 8 authentication generator (sessions + password reset mail). Configure mail for resets.
- No browser-version gate (`allow_browser`) so older handheld terminals work.

## 8. Next steps
1. Run discovery (design doc M0): get the real Excel WMS, sensor models and floor flow; adjust fields and rules.
2. Production: set `SECRET_KEY_BASE`/credentials, `MAILER_FROM`, SMTP, object storage for Active Storage, backups.
3. Phase 2: label printing and scan-driven flows on top of `Lot#internal_id`.
