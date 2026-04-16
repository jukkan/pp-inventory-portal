select
  count(*)                                                    as total_signals,
  sum(case when signal = 'orphaned' then 1 else 0 end)        as orphaned_count,
  sum(case when signal = 'broken_connections' then 1 else 0 end) as broken_count,
  sum(case when signal = 'premium_not_in_solution' then 1 else 0 end) as premium_count,
  sum(case when signal = 'shared_with_tenant' then 1 else 0 end) as shared_count
from silver_governance_signals
