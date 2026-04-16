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
