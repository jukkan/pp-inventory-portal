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
