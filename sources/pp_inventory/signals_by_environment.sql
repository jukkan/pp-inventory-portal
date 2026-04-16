select
  environment_name,
  signal,
  count(*) as signal_count
from silver_governance_signals
group by environment_name, signal
order by environment_name, signal
