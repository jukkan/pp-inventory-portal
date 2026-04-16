select
  r.resource_id,
  r.display_name,
  r.resource_type,
  r.environment_name,
  r.environment_type,
  r.created_at,
  CAST(r.is_orphaned             AS INT) as is_orphaned,
  CAST(r.has_broken_connections  AS INT) as has_broken_connections,
  CAST(r.shared_with_tenant      AS INT) as shared_with_tenant,
  CAST(r.has_premium_connectors  AS INT) as has_premium_connectors,
  CAST(r.is_solution_artifact    AS INT) as is_solution_artifact,
  case
    when r.is_orphaned             = 1 then 'orphaned'
    when r.has_broken_connections  = 1 then 'broken'
    when r.shared_with_tenant      = 1 then 'overshared'
    when r.premium_not_in_solution = 1 then 'premium-risk'
    else 'clean'
  end as primary_signal
from silver_resources r
order by
  case
    when r.is_orphaned             = 1 then 1
    when r.has_broken_connections  = 1 then 2
    when r.shared_with_tenant      = 1 then 3
    when r.premium_not_in_solution = 1 then 4
    else 5
  end,
  r.environment_name,
  r.display_name
