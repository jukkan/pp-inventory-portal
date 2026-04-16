select
  environment_name,
  environment_type,
  CAST(inv_flow_count  AS INT) as inv_flow_count,
  CAST(coe_flow_count  AS INT) as coe_flow_count,
  CAST(flow_delta      AS INT) as flow_delta,
  CAST(inv_app_count   AS INT) as inv_app_count,
  CAST(coe_app_count   AS INT) as coe_app_count,
  CAST(app_delta       AS INT) as app_delta,
  CAST(inv_agent_count AS INT) as inv_agent_count,
  CAST(coe_agent_count AS INT) as coe_agent_count,
  CAST(agent_delta     AS INT) as agent_delta,
  CAST(
    ABS(CAST(flow_delta  AS INT)) +
    ABS(CAST(app_delta   AS INT)) +
    ABS(CAST(agent_delta AS INT))
  AS INT) as total_drift,
  CAST(has_delta AS INT) as has_delta
from silver_environments
order by
  ABS(CAST(flow_delta  AS INT)) +
  ABS(CAST(app_delta   AS INT)) +
  ABS(CAST(agent_delta AS INT)) desc
