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
