select signal, resource_type, count(*) as count
from (
  select
    case
      when is_orphaned             = 1 then 'orphaned'
      when has_broken_connections  = 1 then 'broken'
      when shared_with_tenant      = 1 then 'overshared'
      when premium_not_in_solution = 1 then 'premium-risk'
      else 'clean'
    end as signal,
    resource_type
  from silver_resources
) t
group by signal, resource_type
order by signal, resource_type
