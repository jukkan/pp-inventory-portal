---
title: "{params.environment_name}"
---

# {params.environment_name}

```sql env_drift
select * from pp_inventory.environment_drift
where environment_name = '${params.environment_name}'
```

```sql env_resources
select * from pp_inventory.resources_with_signals
where environment_name = '${params.environment_name}'
```

<Grid cols=4>
  <BigValue
    data={env_drift}
    value=inv_flow_count
    title="Flows (native)"
    fmt="#,##0"
  />
  <BigValue
    data={env_drift}
    value=inv_app_count
    title="Apps (native)"
    fmt="#,##0"
  />
  <BigValue
    data={env_drift}
    value=inv_agent_count
    title="Agents (native)"
    fmt="#,##0"
  />
  <BigValue
    data={env_drift}
    value=total_drift
    title="Total drift"
    fmt="#,##0"
    description="vs CoE snapshot"
  />
</Grid>

{#if env_drift[0].total_drift > 0}
<Alert status="warning">
  This environment has a drift of <b>{env_drift[0].total_drift}</b> units
  between CoE and native inventory.
  Flows: {env_drift[0].flow_delta} ·
  Apps: {env_drift[0].app_delta} ·
  Agents: {env_drift[0].agent_delta}
</Alert>
{/if}

---

## Resources

<DataTable data={env_resources} rows=25 search=true>
  <Column id=display_name title="Name" />
  <Column id=resource_type title="Type" />
  <Column id=primary_signal title="Signal"
    contentType=colorscale scaleColor=red />
  <Column id=is_solution_artifact title="In solution" />
  <Column id=has_premium_connectors title="Premium" />
  <Column id=created_at title="Created" />
</DataTable>

[← All environments](/environments) · [All resources](/resources)
