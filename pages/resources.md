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
from ${resources}
where
  ('${inputs.env_filter.value}'    = 'All' or environment_name = '${inputs.env_filter.value}')
  and ('${inputs.signal_filter.value}' = 'All' or primary_signal  = '${inputs.signal_filter.value}')
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
