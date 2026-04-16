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
{#if env_drift[0].total_drift > 0}
<Alert status="warning">
  This environment has a drift of {env_drift[0].total_drift} units.
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
