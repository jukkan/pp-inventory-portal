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
  The <b>CoE environment</b> has a flow delta of 133 — the largest in the
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
