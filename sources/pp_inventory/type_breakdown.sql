select
  resource_type,
  CAST(count(*) AS INT) as resource_count,
  CAST(sum(case when is_orphaned            = 1 then 1 else 0 end) AS INT) as orphaned,
  CAST(sum(case when has_broken_connections = 1 then 1 else 0 end) AS INT) as broken,
  CAST(sum(case when premium_not_in_solution = 1 then 1 else 0 end) AS INT) as premium_risk
from silver_resources
group by resource_type
order by count(*) desc
