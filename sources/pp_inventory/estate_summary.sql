select
  count(distinct environment_id)                                as environment_count,
  CAST(sum(inv_flow_count)  AS INT)                             as total_flows,
  CAST(sum(inv_agent_count) AS INT)                             as total_agents,
  CAST(sum(inv_app_count)   AS INT)                             as total_apps,
  CAST(sum(inv_flow_count + inv_agent_count + inv_app_count) AS INT) as total_resources,
  sum(case when has_delta = 1 then 1 else 0 end)                as environments_with_drift,
  CAST(sum(
    ABS(CAST(flow_delta  AS INT)) +
    ABS(CAST(app_delta   AS INT)) +
    ABS(CAST(agent_delta AS INT))
  ) AS INT)                                                     as total_drift_units
from silver_environments
