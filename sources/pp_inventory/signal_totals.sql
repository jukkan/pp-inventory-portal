select
  signal,
  count(*) as resource_count
from silver_governance_signals
group by signal
order by resource_count desc
