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
select * from pp_inventory.signal_totals
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
