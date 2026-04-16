---
created: 2026-04-15
updated: 2026-04-15
project: updatedays2026
tags: [evidence, dashboard, agent-plan, codex, inventory, github-pages]
status: ready-for-agent
---

# Evidence.dev Dashboard — Agent Plan v2
## UDPP26 GOV-03 Demo: "CoE + Power BI was 2020. This is 2026."

This file is an instruction manifest for a Codex / Claude Code session.
Read it completely before writing any file. Follow sections in order.

---

## Demo narrative to keep in mind throughout

The dashboard must make one argument without saying it explicitly:

> **Inventory is just data. Treat it like data and everything else follows.**

The audience should see a governance portal that feels like a product, not
a BI report. The "wow" comes from three things working together:

1. The visual quality — dark, modern, nothing like Power BI
2. The data story — real tenant, real drift, real signals, named environments
3. The meta-story — one page shows the literal SQL and markdown that built it

On stage, the presenter will say:
*"CoE Starter Kit with Power BI was the 2020 answer. This runs on a Fabric
Lakehouse, was built entirely with SQL and markdown, and was never opened
in a GUI."*

The killer data point: the CoE environment itself has a 133-flow delta.
The governance tool is the most out-of-sync environment in the tenant.
Use this in narrative copy where appropriate.

---

## Known data

Use these exact figures in hardcoded narrative where referenced:

```
Total environments:    17
Total resources:       641  (flows 305, agents 135, apps 201)
Governance signals:    33   (5.1% of resources flagged)
  - orphaned:          17
  - premium_not_in_solution: 11
  - broken_connections: 3
  - shared_with_tenant: 2

Environments with delta (has_delta = true): 16 of 17
Largest flow deltas:
  CoE:                 133 flows
  Default Dumpyard:     51 flows
  Jukka PAYG:           43 flows
  Jukka's US Preview Dev: 32 flows
```

---

## Step 0 — Scaffold the project

```bash
npx degit evidence-dev/template pp-inventory-portal
cd pp-inventory-portal
npm install
```

Remove the template demo pages:

```bash
rm -rf pages/
mkdir pages
```

Initialise as a Git repo immediately:

```bash
git init
git add .
git commit -m "chore: scaffold Evidence project"
```

Create the GitHub repo `pp-inventory-portal` (public) and push:

```bash
git remote add origin https://github.com/jukkan/pp-inventory-portal.git
git push -u origin main
```

---

## Step 1 — Source configuration

### 1a. Create source directory

```bash
mkdir -p sources/pp_inventory
```

### 1b. Write `sources/pp_inventory/connection.yaml`

```yaml
name: pp_inventory
type: mssql
options:
  server: ${FABRIC_SQL_SERVER}
  database: pp_inventory
  authenticationType: azure-active-directory-service-principal-secret
  spclientid: ${AZURE_CLIENT_ID}
  spclientsecret: ${AZURE_CLIENT_SECRET}
  sptenantid: ${AZURE_TENANT_ID}
  encrypt: true
  trustServerCertificate: false
```

### 1c. Write `.env` for local dev

```
FABRIC_SQL_SERVER=<guid>.datawarehouse.fabric.microsoft.com
AZURE_CLIENT_ID=<service-principal-client-id>
AZURE_CLIENT_SECRET=<client-secret>
AZURE_TENANT_ID=<tenant-id>
```

Confirm `.env` is already in `.gitignore` (Evidence's template includes
it by default — verify before committing anything).

### 1d. Write source SQL files

All files go in `sources/pp_inventory/`.

**`estate_summary.sql`**

```sql
select
  count(distinct environment_id)                        as environment_count,
  sum(inv_flow_count)                                   as total_flows,
  sum(inv_agent_count)                                  as total_agents,
  sum(inv_app_count)                                    as total_apps,
  sum(inv_flow_count + inv_agent_count + inv_app_count) as total_resources,
  sum(case when has_delta = 'true' then 1 else 0 end)   as environments_with_drift,
  sum(abs(flow_delta) + abs(app_delta) + abs(agent_delta)) as total_drift_units
from silver_environments
```

**`signal_summary.sql`**

```sql
select
  count(*)                                                    as total_signals,
  sum(case when signal = 'orphaned' then 1 else 0 end)        as orphaned_count,
  sum(case when signal = 'broken_connections' then 1 else 0 end) as broken_count,
  sum(case when signal = 'premium_not_in_solution' then 1 else 0 end) as premium_count,
  sum(case when signal = 'shared_with_tenant' then 1 else 0 end) as shared_count
from silver_governance_signals
```

**`signals_by_environment.sql`**

```sql
select
  environment_name,
  signal,
  count(*) as signal_count
from silver_governance_signals
group by environment_name, signal
order by environment_name, signal
```

**`environment_drift.sql`**

```sql
select
  environment_name,
  environment_type,
  inv_flow_count,
  coe_flow_count,
  flow_delta,
  inv_app_count,
  coe_app_count,
  app_delta,
  inv_agent_count,
  coe_agent_count,
  agent_delta,
  abs(flow_delta) + abs(app_delta) + abs(agent_delta) as total_drift,
  has_delta
from silver_environments
order by (abs(flow_delta) + abs(app_delta) + abs(agent_delta)) desc
```

**`resources_with_signals.sql`**

```sql
select
  r.resource_id,
  r.display_name,
  r.resource_type,
  r.environment_name,
  r.environment_type,
  r.created_at,
  r.is_orphaned,
  r.has_broken_connections,
  r.shared_with_tenant,
  r.has_premium_connectors,
  r.is_solution_artifact,
  case
    when r.is_orphaned = 'true'            then 'orphaned'
    when r.has_broken_connections = 'true' then 'broken'
    when r.shared_with_tenant = 'true'     then 'overshared'
    when r.has_premium_connectors = 'true'
     and r.is_solution_artifact = 'false'  then 'premium-risk'
    else 'clean'
  end as primary_signal
from silver_resources r
order by
  case
    when r.is_orphaned = 'true'            then 1
    when r.has_broken_connections = 'true' then 2
    when r.shared_with_tenant = 'true'     then 3
    when r.has_premium_connectors = 'true'
     and r.is_solution_artifact = 'false'  then 4
    else 5
  end,
  r.environment_name,
  r.display_name
```

**`type_breakdown.sql`**

```sql
select
  resource_type,
  count(*)                                                           as resource_count,
  sum(case when is_orphaned = 'true' then 1 else 0 end)             as orphaned,
  sum(case when has_broken_connections = 'true' then 1 else 0 end)  as broken,
  sum(case when has_premium_connectors = 'true'
            and is_solution_artifact = 'false' then 1 else 0 end)   as premium_risk
from silver_resources
group by resource_type
order by resource_count desc
```

**`signal_dist.sql`**

```sql
select
  case
    when is_orphaned = 'true'            then 'orphaned'
    when has_broken_connections = 'true' then 'broken'
    when shared_with_tenant = 'true'     then 'overshared'
    when has_premium_connectors = 'true'
     and is_solution_artifact = 'false'  then 'premium-risk'
    else 'clean'
  end as signal,
  resource_type,
  count(*) as count
from silver_resources
group by signal, resource_type
order by signal, resource_type
```

**`drift_by_type.sql`**

```sql
select 'Flows'  as resource_type,
       sum(inv_flow_count)  as native_count,
       sum(coe_flow_count)  as coe_count,
       sum(flow_delta)      as delta
from silver_environments
union all
select 'Apps',
       sum(inv_app_count),
       sum(coe_app_count),
       sum(app_delta)
from silver_environments
union all
select 'Agents',
       sum(inv_agent_count),
       sum(coe_agent_count),
       sum(agent_delta)
from silver_environments
```

After writing all SQL files, run sources locally to confirm before
writing pages:

```bash
npm run sources
```

All queries must succeed and row counts must match the known data above
before proceeding to Step 2.

---

## Step 2 — Configuration

### `evidence.config.yaml`

This project deploys to GitHub Pages as a project site at
`jukkan.github.io/pp-inventory-portal/`. The `basePath` is required
for all internal links and assets to resolve correctly.

**Option A — project site at default GitHub Pages URL:**

```yaml
title: PP Inventory Portal
description: Power Platform governance · UDPP26 GOV-03
theme:
  colorScheme: dark
  brandColor: "#6366f1"
deployment:
  basePath: /pp-inventory-portal
pages:
  - title: Overview
    path: /
    icon: home
  - title: Environments
    path: /environments
    icon: layers
  - title: Resources
    path: /resources
    icon: list
  - title: How This Was Built
    path: /how-it-works
    icon: code
```

**Option B — custom subdomain (e.g. `inventory.jukkan.com`):**

If using a custom domain, remove `basePath` entirely and add a `CNAME`
file to the project root containing just the domain:

```
inventory.jukkan.com
```

The GitHub Actions deploy step will copy this to the build output.
Point the DNS A record for `inventory.jukkan.com` at GitHub Pages IPs:
`185.199.108.153`, `185.199.109.153`, `185.199.110.153`, `185.199.111.153`.
Then in the repo settings → Pages → Custom domain, enter the domain.
HTTPS is provisioned automatically.

**Choose one option and proceed. Option B produces a cleaner demo URL.**
For the session, `inventory.jukkan.com` is preferable to
`jukkan.github.io/pp-inventory-portal/`. Update all references in
`/how-it-works` accordingly.

---

## Step 3 — GitHub Actions workflow

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy to GitHub Pages

on:
  push:
    branches: [main]
  workflow_dispatch:        # manual trigger — use before conference for
                            # a fresh data build without a code change

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    permissions:
      contents: write       # required for peaceiris/actions-gh-pages

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up Node
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run sources
        run: npm run sources
        env:
          FABRIC_SQL_SERVER:   ${{ secrets.FABRIC_SQL_SERVER }}
          AZURE_CLIENT_ID:     ${{ secrets.AZURE_CLIENT_ID }}
          AZURE_CLIENT_SECRET: ${{ secrets.AZURE_CLIENT_SECRET }}
          AZURE_TENANT_ID:     ${{ secrets.AZURE_TENANT_ID }}

      - name: Build
        run: npm run build
        env:
          FABRIC_SQL_SERVER:   ${{ secrets.FABRIC_SQL_SERVER }}
          AZURE_CLIENT_ID:     ${{ secrets.AZURE_CLIENT_ID }}
          AZURE_CLIENT_SECRET: ${{ secrets.AZURE_CLIENT_SECRET }}
          AZURE_TENANT_ID:     ${{ secrets.AZURE_TENANT_ID }}

      - name: Deploy to gh-pages
        uses: peaceiris/actions-gh-pages@v4
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: ./build
          cname: inventory.jukkan.com   # remove this line if using
                                         # Option A (no custom domain)
```

### GitHub Secrets to configure

In the repo: Settings → Secrets and variables → Actions → New repository
secret. Add all four:

| Secret name | Value |
|---|---|
| `FABRIC_SQL_SERVER` | `<guid>.datawarehouse.fabric.microsoft.com` |
| `AZURE_CLIENT_ID` | Service Principal client ID |
| `AZURE_CLIENT_SECRET` | Service Principal client secret |
| `AZURE_TENANT_ID` | Entra tenant ID |

These are injected only at build time. The static HTML output contains
no credentials. The Lakehouse SQL endpoint requires a valid Entra token
to query — the published site has no path back to the data source.

### Enable Pages in repo settings

After the first successful workflow run:
Settings → Pages → Source → Deploy from branch → `gh-pages` → `/ (root)`.

GitHub creates the `gh-pages` branch automatically on the first deploy.
If the branch doesn't appear, trigger the workflow manually from the
Actions tab before configuring Pages.

---

## Step 4 — Pages

Write the following files. Each is a complete Evidence markdown page.
Query names in fenced blocks must exactly match the SQL filenames from
Step 1d (without the `.sql` extension, prefixed with the source name).

---

### `pages/index.md`

```markdown
---
title: PP Inventory Portal
---

# Power Platform Tenant Governance

<LastRefreshed prefix="Data as of" />

This portal is built entirely from SQL queries against a Microsoft Fabric
Lakehouse. No GUI was opened to create it. Every number is live from
the tenant's native inventory API and CoE Starter Kit exports.

---

## Estate at a glance

```sql estate
select * from pp_inventory.estate_summary
```

```sql signals
select * from pp_inventory.signal_summary
```

<Grid cols=4>
  <BigValue
    data={estate}
    value=total_resources
    title="Total resources"
    fmt="#,##0"
  />
  <BigValue
    data={signals}
    value=total_signals
    title="Resources with signals"
    fmt="#,##0"
    description="of 641 inventoried"
  />
  <BigValue
    data={estate}
    value=environments_with_drift
    title="Environments with drift"
    fmt="#,##0"
    description="CoE vs native mismatch"
  />
  <BigValue
    data={estate}
    value=total_drift_units
    title="Total drift units"
    fmt="#,##0"
    description="Δ flows + apps + agents"
  />
</Grid>

---

## Governance signals

```sql sig_breakdown
select
  signal,
  count(*) as resource_count
from silver_governance_signals
group by signal
order by resource_count desc
```

<Grid cols=2>
  <BarChart
    data={sig_breakdown}
    x=signal
    y=resource_count
    title="Signals by type"
    colorPalette={['#f87171','#fb923c','#fbbf24','#a78bfa']}
    labels=true
  />
  <Grid cols=2>
    <BigValue
      data={signals}
      value=orphaned_count
      title="Orphaned"
      description="No valid owner, active 90d"
    />
    <BigValue
      data={signals}
      value=broken_count
      title="Broken connections"
      description="At least one broken connector"
    />
    <BigValue
      data={signals}
      value=premium_count
      title="Premium, not in solution"
      description="Licensing + ALM exposure"
    />
    <BigValue
      data={signals}
      value=shared_count
      title="Shared with tenant"
      description="Everyone in org can access"
    />
  </Grid>
</Grid>

---

## Governance debt by environment

```sql heatmap_data
select * from pp_inventory.signals_by_environment
```

<Heatmap
  data={heatmap_data}
  x=signal
  y=environment_name
  value=signal_count
  title="Signal count per environment"
  nullsZero=true
  colorScale={['#1e293b','#7f1d1d','#991b1b','#dc2626','#ef4444']}
  xAxisTitle="Signal type"
  yAxisTitle=""
/>

> **Reading this chart:** Each cell shows how many resources in that
> environment carry that governance signal. Empty cells mean zero.
> Environments without any signals do not appear.

---

## Resource breakdown by type

```sql types
select * from pp_inventory.type_breakdown
```

<DataTable data={types} rows=10>
  <Column id=resource_type title="Type" />
  <Column id=resource_count title="Count" fmt="#,##0" />
  <Column id=orphaned title="Orphaned" fmt="#,##0" />
  <Column id=broken title="Broken" fmt="#,##0" />
  <Column id=premium_risk title="Premium risk" fmt="#,##0" />
</DataTable>

---

*Built with [Evidence.dev](https://evidence.dev) · Source: Fabric
Lakehouse `pp_inventory` · Data from native Power Platform Inventory
API + CoE Starter Kit Dataverse export ·
[How this was built →](/how-it-works)*
```

---

### `pages/environments.md`

```markdown
---
title: Environment Drift
---

# CoE vs Native Inventory Drift

The CoE Starter Kit and the native Power Platform Inventory API are
two different snapshots of the same estate. They should agree.
**They don't — and the gap tells a story.**

```sql drift
select * from pp_inventory.environment_drift
```

<Alert status="warning">
  The **CoE environment** has a flow delta of 133 — the largest in the
  tenant. The tool designed to track everything is itself the most
  out-of-sync environment. This is not unusual: CoE captures deleted
  and historical records that native inventory no longer shows.
  Understanding which source is "right" depends on the question being
  asked.
</Alert>

---

## Drift by environment

<DataTable
  data={drift}
  rows=20
  search=true
>
  <Column id=environment_name title="Environment"
    linkPrefix="/environment/" />
  <Column id=environment_type title="Type" />
  <Column id=inv_flow_count title="Native flows" fmt="#,##0" />
  <Column id=coe_flow_count title="CoE flows" fmt="#,##0" />
  <Column id=flow_delta title="Δ flows"
    fmt="+#,##0;-#,##0;0" contentType=delta downIsGood=true />
  <Column id=inv_app_count title="Native apps" fmt="#,##0" />
  <Column id=app_delta title="Δ apps"
    fmt="+#,##0;-#,##0;0" contentType=delta downIsGood=true />
  <Column id=inv_agent_count title="Native agents" fmt="#,##0" />
  <Column id=agent_delta title="Δ agents"
    fmt="+#,##0;-#,##0;0" contentType=delta downIsGood=true />
  <Column id=total_drift title="Total Δ" fmt="#,##0" />
</DataTable>

---

## What drift means in practice

**Positive delta (CoE > native):** CoE is holding records for resources
that no longer appear in native current-state inventory. This is usually
deleted artifacts that CoE retains for historical tracking.

**Negative delta (native > CoE):** Native has resources that CoE has
not yet synced — typically newly created resources in environments where
the CoE sync has not run since creation.

> CoE is better for historical governance and lifecycle tracking.
> Native inventory is better for current-state baseline.
> **You need both — but you need to know which answers which question.**

---

## Drift by resource type

```sql drift_by_type
select * from pp_inventory.drift_by_type
```

<BarChart
  data={drift_by_type}
  x=resource_type
  y={['native_count','coe_count']}
  type=grouped
  title="Native vs CoE counts by resource type"
  labels=true
/>
```

---

### `pages/resources.md`

```markdown
---
title: Resource Browser
---

# Resource Browser

641 resources across 17 environments. Filter by environment or signal
status. Click an environment name to drill into that environment.

```sql resources
select * from pp_inventory.resources_with_signals
```

<Dropdown
  name=env_filter
  data={resources}
  value=environment_name
  title="Filter by environment"
  defaultValue="All"
/>

<Dropdown
  name=signal_filter
  data={resources}
  value=primary_signal
  title="Filter by signal"
  defaultValue="All"
/>

```sql filtered_resources
select *
from pp_inventory.resources_with_signals
where
  ('{env_filter}'    = 'All' or environment_name = '{env_filter}')
  and ('{signal_filter}' = 'All' or primary_signal  = '{signal_filter}')
order by
  case primary_signal
    when 'orphaned'     then 1
    when 'broken'       then 2
    when 'overshared'   then 3
    when 'premium-risk' then 4
    else 5
  end,
  display_name
```

<DataTable data={filtered_resources} rows=25 search=true>
  <Column id=display_name title="Name" />
  <Column id=resource_type title="Type" />
  <Column id=environment_name title="Environment"
    linkPrefix="/environment/" />
  <Column id=environment_type title="Env type" />
  <Column id=primary_signal title="Signal"
    contentType=colorscale scaleColor=red />
  <Column id=created_at title="Created" />
</DataTable>

---

## Signal distribution across resource types

```sql signal_dist
select * from pp_inventory.signal_dist
```

<BarChart
  data={signal_dist}
  x=resource_type
  y=count
  series=signal
  type=stacked
  title="Resources by type and signal status"
/>
```

---

### `pages/environment/[environment].md`

Templated page — Evidence generates one page per environment row.

```markdown
---
title: "{params.environment}"
---

# {params.environment}

```sql env_summary
select
  environment_type,
  inv_flow_count, coe_flow_count, flow_delta,
  inv_app_count,  coe_app_count,  app_delta,
  inv_agent_count, coe_agent_count, agent_delta,
  abs(flow_delta) + abs(app_delta) + abs(agent_delta) as total_drift
from silver_environments
where environment_name = '{params.environment}'
```

```sql env_resources
select
  r.display_name,
  r.resource_type,
  r.created_at,
  r.is_solution_artifact,
  r.has_premium_connectors,
  coalesce(s.signal, 'clean') as signal
from silver_resources r
left join silver_governance_signals s
  on r.resource_id = s.resource_id
where r.environment_name = '{params.environment}'
order by
  case coalesce(s.signal, 'clean')
    when 'orphaned'               then 1
    when 'broken_connections'     then 2
    when 'shared_with_tenant'     then 3
    when 'premium_not_in_solution' then 4
    else 5
  end,
  r.display_name
```

<Grid cols=4>
  <BigValue
    data={env_summary}
    value=inv_flow_count
    title="Flows (native)"
    fmt="#,##0"
  />
  <BigValue
    data={env_summary}
    value=inv_app_count
    title="Apps (native)"
    fmt="#,##0"
  />
  <BigValue
    data={env_summary}
    value=inv_agent_count
    title="Agents (native)"
    fmt="#,##0"
  />
  <BigValue
    data={env_summary}
    value=total_drift
    title="Total drift"
    fmt="#,##0"
    description="vs CoE snapshot"
  />
</Grid>

{#if env_summary[0].total_drift > 0}
<Alert status="warning">
  This environment has a drift of **{env_summary[0].total_drift}** units
  between CoE and native inventory.
  Flows: {env_summary[0].flow_delta} ·
  Apps: {env_summary[0].app_delta} ·
  Agents: {env_summary[0].agent_delta}
</Alert>
{/if}

---

## Resources

<DataTable data={env_resources} rows=25 search=true>
  <Column id=display_name title="Name" />
  <Column id=resource_type title="Type" />
  <Column id=signal title="Signal"
    contentType=colorscale scaleColor=red />
  <Column id=is_solution_artifact title="In solution" />
  <Column id=has_premium_connectors title="Premium" />
  <Column id=created_at title="Created" />
</DataTable>

[← All environments](/environments) · [All resources](/resources)
```

Alongside this, create `pages/environment/[environment].params.js`:

```js
import { db } from '@evidence-dev/db-commons'

export async function load() {
  const rows = await db.query(
    `select distinct environment_name as environment
     from silver_environments
     order by environment_name`
  )
  return {
    params: rows.map(r => ({ environment: r.environment }))
  }
}
```

This generates one static page per environment at build time.
The 17 environment pages are pre-rendered — no server required.

---

### `pages/how-it-works.md`

This is the centrepiece of the on-stage narrative. Open the overview,
show the heatmap, then navigate here last. End on the code.

```markdown
---
title: How This Was Built
---

# How this portal was built

**No GUI was opened. No drag-and-drop. No scheduled refresh wizard.**

This entire portal was generated from:
- SQL queries against a Microsoft Fabric Lakehouse
- Markdown files in a Git repository  
- One `npm run build` command

The tool is [Evidence.dev](https://evidence.dev) — open source, MIT
licensed. The data lives in a Fabric F2 capacity on Azure Sponsorship
credits. The build output is a static HTML site deployed to GitHub Pages
via a GitHub Actions workflow on every `git push`.

---

## The full stack

| Layer | Technology | How it was built |
|---|---|---|
| Data capture | Power Platform Inventory API + CoE Dataverse export | Python scripts, PAC CLI |
| Storage | Fabric Lakehouse (Delta tables) | PySpark notebook, Fabric REST API |
| Transformation | PySpark notebooks (bronze → silver) | Claude Code CLI + Fabric MCP |
| Portal | Evidence.dev | Claude Code CLI / Codex |
| Hosting | GitHub Pages | `git push` → GitHub Actions |

**Total GUI interactions to build this portal: 0.**

---

## Example: The heatmap on the overview page

The governance heatmap is this SQL query in
`sources/pp_inventory/signals_by_environment.sql`:

~~~sql
select
  environment_name,
  signal,
  count(*) as signal_count
from silver_governance_signals
group by environment_name, signal
order by environment_name, signal
~~~

And this Evidence markdown in `pages/index.md`:

~~~
<Heatmap
  data={heatmap_data}
  x=signal
  y=environment_name
  value=signal_count
  colorScale={['#1e293b','#7f1d1d','#991b1b','#dc2626','#ef4444']}
/>
~~~

That is the entire definition of the chart. The SQL runs once at build
time against the Fabric Lakehouse SQL analytics endpoint. The output is
a pre-rendered static HTML file that loads in milliseconds — no database
connection required at read time.

---

## Example: The CoE drift alert

The alert on the [CoE environment page](/environment/CoE) is not
hardcoded. It is conditional Evidence markup that fires whenever
`total_drift > 0`:

~~~
{#if env_summary[0].total_drift > 0}
<Alert status="warning">
  This environment has a drift of {env_summary[0].total_drift} units.
</Alert>
{/if}
~~~

The 133-flow delta in the CoE environment triggers this automatically
from the data. A different tenant, different numbers — same code.

---

## The deployment pipeline

Every `git push` to `main` triggers this GitHub Actions workflow:

~~~yaml
- run: npm run sources    # queries Fabric Lakehouse
- run: npm run build      # generates static HTML
- uses: peaceiris/actions-gh-pages@v4
  with:
    publish_dir: ./build  # pushes to gh-pages branch
~~~

Credentials are stored as GitHub Actions secrets — never in the
repository. The static output has no connection strings. The Fabric SQL
analytics endpoint requires a valid Entra token to query; the published
site has no path back to it.

To rebuild with fresh data without a code change: Actions tab →
"Deploy to GitHub Pages" → Run workflow.

---

## The 2020 answer vs the 2026 answer

**2020:** Install CoE Starter Kit (multiple components, multiple days),
wait for initial sync (24–48h), build Power BI reports manually,
maintain a scheduled refresh, manage a data gateway, explain to users
why the numbers don't match native inventory.

**2026:** Capture inventory via API (Python, 10 minutes), land in Fabric
Lakehouse (notebook, 30 minutes), generate portal from SQL + markdown
(Claude Code, 2 hours). Deploy with `git push`. One afternoon.

The underlying principle has not changed:
*Inventory is data. Treat it like data.*

What changed is that the tooling finally caught up.

---

*Source: [github.com/jukkan/pp-inventory-portal](https://github.com/jukkan/pp-inventory-portal)*
```

---

## Step 5 — Local verification before push

```bash
# Run sources to populate the local cache
npm run sources

# Start dev server
npm run dev
```

Open `http://localhost:3000` and manually check each page:

- [ ] Overview — KPI numbers match (641 resources, 33 signals, 16 drifting)
- [ ] Heatmap renders with correct environment names
- [ ] Environments — CoE row shows 133 in the flow delta column
- [ ] CoE environment drilldown — amber alert renders
- [ ] Resources — both dropdowns populate; filter works
- [ ] "Jukka's Test Cloud" environment page renders (apostrophe test)
- [ ] "Jukka's US Preview Dev" environment page renders (apostrophe test)
- [ ] How This Was Built — renders completely with code blocks

Then run a strict build to catch any SQL or component errors:

```bash
npm run build:strict
```

This must pass with zero errors before committing. Fix any failures
before proceeding.

---

## Step 6 — Push and confirm deployment

```bash
git add .
git commit -m "feat: initial Evidence portal with governance dashboard"
git push origin main
```

Then:

1. Watch the Actions tab — the workflow should complete in ~3–5 minutes
2. After the first run, go to Settings → Pages → Source → `gh-pages` →
   `/ (root)` → Save
3. If using a custom domain, enter it in Settings → Pages → Custom domain
4. Wait for HTTPS provisioning (~5 minutes on first deploy)
5. Open the live URL and repeat the manual checks from Step 5

---

## Step 7 — Pre-conference data refresh

The F2 capacity will be paused between now and the conference. Before
the session, do the following in this order:

1. Resume the F2 capacity:
   ```bash
   az rest --method post \
     --url "https://management.azure.com/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Fabric/capacities/{name}/resume?api-version=2023-11-01"
   ```

2. Trigger a fresh build from the Actions tab:
   Actions → "Deploy to GitHub Pages" → Run workflow → Run workflow

3. Wait for the workflow to complete (~3–5 minutes)

4. Verify the live URL still loads correctly

5. After confirming, pause the capacity again:
   ```bash
   az rest --method post \
     --url "https://management.azure.com/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Fabric/capacities/{name}/suspend?api-version=2023-11-01"
   ```

The static site remains live after the capacity is paused — GitHub Pages
serves the pre-built HTML with no dependency on Fabric at read time.

---

## Step 8 — Completion report

Write `data/curated/evidence-setup-report.md` in the pp-inventory repo:

```markdown
## Evidence Portal — Setup Report
## Completed: <timestamp>

URL: https://inventory.jukkan.com  (or jukkan.github.io/pp-inventory-portal)
Repo: https://github.com/jukkan/pp-inventory-portal

Pages generated:
- / (Overview)
- /environments
- /resources
- /environment/[environment] (17 pages)
- /how-it-works

Build time: <seconds>
Build output size: <MB>
Strict build: pass / fail

Apostrophe environment pages verified:
- /environment/Jukka's Test Cloud: pass / fail
- /environment/Jukka's US Preview Dev: pass / fail

Known issues or caveats:
```

---

## Error handling

**TDS auth failure in `npm run sources`**
Confirm the Service Principal has Viewer access to the
`pp-inventory-demo` workspace in Fabric Admin, not just the Azure
capacity. Capacity-level permissions do not grant SQL analytics
endpoint access.

**Apostrophe environments return empty data or 404**
Evidence interpolates `{params.environment}` as a string directly into
SQL. Environment names containing apostrophes (`Jukka's`) need escaping.
If the pages are blank, wrap the interpolation in a SQL `replace`:

```sql
where environment_name = replace('{params.environment}', chr(39), '''')
```

or handle it in the params file by URL-encoding. Test both pages
specifically.

**Heatmap is blank after successful sources run**
Query `silver_governance_signals` directly in SSMS / Azure Data Studio
against the Fabric SQL endpoint to confirm rows exist and column names
match. The heatmap requires at least one non-null `signal_count` row
to render.

**`delta` column shows wrong colour direction**
Evidence treats positive delta as good (green) by default. For drift
columns where larger absolute delta = worse, set `downIsGood=true` on
each delta Column component.

**GitHub Actions workflow fails on `npm run sources`**
Check that all four secrets are set correctly in the repo
(Settings → Secrets and variables → Actions). A missing or
misspelled secret produces a connection error, not an auth error —
the error message may not clearly indicate which value is wrong.
Verify each secret value matches the local `.env` that works.

**`[environment].params.js` throws a module error**
Evidence's params API may differ slightly between versions. If the
`import { db }` pattern does not resolve, check the installed Evidence
version's documentation for the current params API. As a fallback,
hardcode the environment list:

```js
export async function load() {
  return {
    params: [
      { environment: "CoE" },
      { environment: "Default Dumpyard" },
      // ... all 17 environment names
    ]
  }
}
```

This is inelegant but stable if the dynamic query path is blocked.

**`basePath` links are broken locally but correct on GitHub Pages**
This is expected. The `basePath` setting only applies to the production
build. Local dev runs at `localhost:3000` without the prefix. Do not
test navigation with the base path from `npm run dev`.

---

*End of agent plan.*
