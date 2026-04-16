select
  count(distinct environment_id)                        as environment_count,
  sum(inv_flow_count)                                   as total_flows,
  sum(inv_agent_count)                                  as total_agents,
  sum(inv_app_count)                                    as total_apps,
  sum(inv_flow_count + inv_agent_count + inv_app_count) as total_resources,
  sum(case when has_delta = 'true' then 1 else 0 end)   as environments_with_drift,
  sum(abs(flow_delta) + abs(app_delta) + abs(agent_delta)) as total_drift_units
from silver_environments
