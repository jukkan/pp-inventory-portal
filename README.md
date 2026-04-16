# PP Inventory Portal

A governance dashboard for a Microsoft Power Platform tenant. Shows every environment, every app, flow, and agent — and flags the ones that need attention.

**Live site:** [inventory.jukkan.com](https://inventory.jukkan.com)

## What this is

This is a static website that presents Power Platform inventory data. The data lives in a Microsoft Fabric Lakehouse. At build time, SQL queries run against that Lakehouse and the results are baked into static HTML pages. No database connection is needed when someone views the site.

The site is built with [Evidence.dev](https://evidence.dev), an open-source tool that turns SQL + Markdown into data-rich websites. Think of it as a static site generator that understands databases.

## How it works

```
Fabric Lakehouse ──SQL──▶ Evidence build ──HTML──▶ GitHub Pages
     (data)              (this repo)               (hosting)
```

1. **Data lives in Fabric.** A Lakehouse called `pp_inventory` holds three silver-layer tables: environments, resources, and governance signals. These are populated by a separate data pipeline (see [pp-inventory](https://github.com/jukkan/pp-inventory)).

2. **SQL queries define the dashboard.** The `sources/` folder contains 9 SQL files. Each one is a standalone query against the Lakehouse — things like "count resources by type" or "list flagged resources with their signals."

3. **Markdown pages define the UI.** The `pages/` folder contains Markdown files with embedded chart and table components. Evidence compiles these into interactive HTML.

4. **GitHub Actions builds and deploys.** On every push to `main`, a workflow installs the ODBC driver, runs all SQL queries against Fabric, builds the static site, and deploys it to GitHub Pages.

## Why these technology choices

### Why Evidence.dev instead of Power BI?

Power BI is the obvious choice for Microsoft data, but this project makes a different argument: governance dashboards should be code, not drag-and-drop. Code means version control, pull requests, repeatable builds, and zero vendor lock-in. Evidence produces a fast static site that works without a Power BI license.

### Why a custom Fabric connector?

Evidence ships with a SQL Server connector built on `tedious` (a JavaScript TDS library). Tedious cannot connect to Fabric's SQL analytics endpoint — it fails during the TDS login handshake. This is a known limitation.

The workaround is a custom connector (`packages/fabric-connector/`) that uses `msnodesqlv8` instead. This library delegates to the native Microsoft ODBC Driver 18, which handles Fabric's authentication correctly. The connector authenticates as a service principal using `ActiveDirectoryServicePrincipal` mode in the ODBC connection string.

### Why a service principal instead of interactive login?

The GitHub Actions workflow runs without a human present. A service principal (an Entra ID app registration) lets the build authenticate programmatically. The SP has read-only (Viewer) access to the Fabric workspace.

### Why GitHub Pages instead of Azure Static Web Apps?

Simplicity. The site is static HTML with no server-side logic. GitHub Pages is free, requires zero configuration, and deploys automatically from the same repository that holds the source code.

## Architecture diagram

See [ARCHITECTURE.md](ARCHITECTURE.md) for a visual breakdown.

## Project structure

```
pages/                    # Markdown + Evidence components → the website
  index.md                # Overview dashboard with KPIs, charts, heatmap
  environments.md         # CoE drift comparison across environments
  resources.md            # Filterable resource browser
  environment/[name].md   # Per-environment detail pages (templated)
  how-it-works.md         # Meta page explaining the build process

sources/pp_inventory/     # SQL queries that run against Fabric at build time
  estate_summary.sql      # Total environments, resources, signal %
  signal_summary.sql      # Flagged resource count
  signal_totals.sql       # Breakdown by signal type
  signals_by_environment.sql  # Heatmap data
  environment_drift.sql   # CoE vs native environment comparison
  resources_with_signals.sql  # Full resource list with flags
  type_breakdown.sql      # Resources grouped by type
  signal_dist.sql         # Signal distribution across resource types
  drift_by_type.sql       # Drift broken down by resource type

packages/fabric-connector/  # Custom Evidence source plugin
  index.cjs               # ODBC-based connector using msnodesqlv8

.github/workflows/deploy.yml  # CI/CD pipeline
```

## Local development

### Prerequisites

- Node.js 20+
- [ODBC Driver 18 for SQL Server](https://learn.microsoft.com/sql/connect/odbc/download-odbc-driver-for-sql-server)
- Access credentials (service principal with Fabric workspace Viewer role)

### Setup

```bash
npm install

# Create sources/pp_inventory/connection.options.yaml with base64-encoded credentials:
#   clientid: <base64-encoded client ID>
#   clientsecret: <base64-encoded client secret>

npm run sources   # runs SQL queries against Fabric, caches results locally
npm run dev       # starts dev server at http://localhost:3000
```

### Build

```bash
npm run build     # produces static site in ./build
```

## Deployment

Automatic on every push to `main`. The GitHub Actions workflow:

1. Installs Microsoft ODBC Driver 18 on the Ubuntu runner
2. Runs `npm ci` to install dependencies (including native compilation of msnodesqlv8)
3. Runs all 9 SQL queries against the Fabric Lakehouse
4. Builds the static site
5. Deploys to the `gh-pages` branch

Credentials are stored as GitHub Actions secrets (`FABRIC_CLIENT_ID`, `FABRIC_CLIENT_SECRET`).

To refresh data without changing code, trigger the workflow manually from the Actions tab.

## Related

The data pipeline that populates the Fabric Lakehouse lives in [jukkan/pp-inventory](https://github.com/jukkan/pp-inventory).
